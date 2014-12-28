package AN::Agent;

use base 'AN::Scanner';		# inherit from AN::Scanner

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;
use Cwd;

use File::Basename;

use File::Spec::Functions 'catdir';
use FindBin qw($Bin);
use Const::Fast;

use AN::Common;
use AN::MonitorAgent;
use AN::FlagFile;
use AN::Unix;
use AN::DBS;

use Class::Tiny qw( datatable_name datatable_schema );

# ======================================================================
# CONSTANTS
#
const my $DUMP_PREFIX => q{db::};
const my $NEWLINE => qq{\n};

const my $PROG    => ( fileparse($PROGRAM_NAME) )[0];
const my $DATATABLE_NAME   => 'agent_data';
const my $DATATABLE_SCHEMA => <<"EOSCHEMA";

id        serial primary key,
node_id   bigint references node(node_id),
value     integer,
status    status,
msg_tag   text,
msg_args  text,
timestamp timestamp with time zone    not null    default now()

EOSCHEMA

const my $NOT_WORDCHAR => qr{\W};
const my $UNDERSCORE   => q{_};

# ......................................................................
#

sub BUILD {
    my $self = shift;

    # avoid characters that DB dislikes in table name
    #
    my $name = $DATATABLE_NAME;
    $name =~ s{$NOT_WORDCHAR}{$UNDERSCORE};
    $self->datatable_name( $name );
    
    $self->datatable_schema( $DATATABLE_SCHEMA );

    croak(q{Missing Scanner constructor arg 'rate'.})
        unless $self->rate();

    $self->dbini( catdir( getcwd(), $self->dbini ));
    return;
}

sub non_blank_lines {
    my ( $str ) = @_;

    # split the string into lines
    # accept any lines which have non-blank characters
    # join lines back together into a 'paragraph'
    #
    return join q{ }, grep {/\S/} split $NEWLINE, $str;
}
sub dump_metadata {
    my $self = shift;

    my $dbs_dump = $self->dbs()->dump_metadata;
    my ($schema) = non_blank_lines $self->datatable_schema;

    my $metadata = <<"EODUMP";
${DUMP_PREFIX}name=$PROG
${DUMP_PREFIX}pid=$PID
$dbs_dump
${DUMP_PREFIX}datatable_name=@{[$self->datatable_name]}
${DUMP_PREFIX}datatable_schema="$schema"
EODUMP

    return $metadata;
}

sub insert_raw_record {
    my $self = shift;
    my ( $value, $status, $msg_tag, $msg_args ) = @_;

    $self->dbs()->insert_raw_record(
                                     { table => $self->datatable_name,
                                       with_node_table_id => 'node_id',
                                       args               => {
                                                 value  => int $value,
                                                 status => $status,
						 msg_tag => $msg_tag,
						 msg_args => $msg_args,
                                               },
                                     } );
}

sub generate_random_record {
    my $self = shift;
    
    state $first = 1;
    my $value = (int rand(1000)) / 10;
    my $status = ( $first || rand(100) > 66.0 ? 'DEBUG'
		   : $value > 90             ? 'CRISIS'
		   : $value > 80             ? 'WARNING'
		   :                            'OK'
	);
    my $msg_tag = ($first == 1            ? "$PROG first record" 
		   : $status eq 'DEBUG'   ? "$PROG debug msg"
		   : $status eq 'WARNING' ? "$PROG warning msg"
		   : $status eq 'CRISIS'  ? "$PROG crisis msg"
		   :                       '');
    my $msg_args = '';

    say scalar localtime(), ": $PROG -> $status, $msg_tag"
	if $self->verbose;
    $self->insert_raw_record( $value, $status, $msg_tag, $msg_args );
    $first = 0;
    return;
}

sub loop_core {
    my $self = shift;

    $self->generate_random_record();
}

sub run {
    my $self = shift;

    # initialize.
    #
    $self->connect_dbs();
    $self->create_marker_file( AN::FlagFile::get_tag('METADATA'),
                               $self->dump_metadata );
    
    # process until quitting time
    #
    $self->run_timed_loop_forever();

    # clean up and exit.
    #
    $self->clean_up_running_agents();
    $self->disconnect_dbs();
    $self->delete_marker_file(AN::FlagFile::get_tag('METADATA'));
}

1;
# ======================================================================
# End of File.