### Alteeve's Niche! Inc. - Anvil! Intelligent Availability™ Platform
# License: GPLv2
# Built:   2016-06-06 21:18:37
# Target:  Network Install (PXE)
# OS:      RHEL
# Machine: Anvil! Node #01

### Setup values.
# Run a text-based install
install
text

# Installing from Striker 02's PXE server.
url --url=http://10.20.4.2/rhel6/x86_64/img/

# Set the language and keyboard type.
lang en_CA.UTF-8
keyboard us

# Set the system clock to UTC and then define the timezone.
timezone --utc America/Toronto

# This sets the (first) ethernet device. There is currently no way to map
# device names to physical interfaces. For this reason, we use DHCP for install
# and configure the network manually post-install.
network --device eth0 --bootproto dhcp --onboot yes --hostname new-node01.alteeve.com

# This is the root user's password. The one below should be taken as an example
# and changed as it is a terrible password.
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
rootpw Initial1

# Default admin user account.
user --name=admin --plaintext --password=Initial1

# At this time, Striker does not yet work with SELinux in enforcing mode. This
# is expected to change in a (near) future release.
firewall --service=ssh
selinux --enforcing

# There is no need for the 'first boot' menu system to run, so we will disable
# it.
firstboot --disable

# Set the installation logging level.
logging --level=debug

# Enable httpd so that the local repo is available on boot.
services --enabled httpd,gpm,iptables
services --disabled kdump

# Reboot when the install is finished.
reboot

# This runs a script (below) that generates the partitioning information
# depending on a rudamentary test for available storage devices.
%include /tmp/part-include

# This is a very minimal installation. It is just enough to get the nodes ready
# for the Stage-2 'Install Manifest' run from the Striker dashboard.
%packages
# We clobber the groups XML repodata, so we specify the packages directly.
# Core - mandatory
acl
attr
audit
basesystem
bash
coreutils
cpio
cronie
dhclient
e2fsprogs
filesystem
glibc
initscripts
iproute
iptables
iptables-ipv6
iputils
kbd
ncurses
openssh-server
passwd
policycoreutils
procps
redhat-support-tool
rhnsd
rootfiles
rpm
rsyslog
selinux-policy-targeted
setup
shadow-utils
subscription-manager
sudo
util-linux-ng
vim-minimal
yum
yum-rhn-plugin

# Core - Default
aic94xx-firmware
atmel-firmware
b43-openfwwf
bfa-firmware
efibootmgr
grub
ipw2100-firmware
ipw2200-firmware
ivtv-firmware
iwl100-firmware
iwl1000-firmware
iwl3945-firmware
iwl4965-firmware
iwl5000-firmware
iwl5150-firmware
iwl6000-firmware
iwl6000g2a-firmware
iwl6050-firmware
kernel-firmware
kexec-tools
libertas-usb8388-firmware
postfix
ql2100-firmware
ql2200-firmware
ql23xx-firmware
ql2400-firmware
ql2500-firmware
rt61pci-firmware
rt73usb-firmware
xorg-x11-drv-ati-firmware
zd1211-firmware

# Core - Optional
dracut-network

# Others - Common to nodes and dashboards
-kdump
alteeve-repo
gpm
perl
perl-Crypt-SSLeay
%end


# Now it's time for the first chroot'ed configuration steps.
%post --log=/tmp/post-install_chroot.log


# Tell the machine to save downloaded RPM updates (for possible distribution to
# other machines for low-bandwidth users). It also makes sure all NICs start on
# boot.
echo 'Configuring yum to keep its cache.'
sed -i 's/keepcache=0/keepcache=1/g' /etc/yum.conf

# Disable DNS lookup for SSH so that logins are quick when there is not Internet
# access.
echo 'Configuring sshd to not use DNS or GSSAPI authentication for fast logins without internet connections.'
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config 
sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' /etc/ssh/sshd_config

# Show details on boot.
echo 'Setting plymouth to use detailed boot screen'
plymouth-set-default-theme details --rebuild-initrd
sed -i 's/ rhgb//'  /boot/grub/grub.conf
sed -i 's/ quiet//' /boot/grub/grub.conf

# Setup 'list-ips', which will display the node's post-stage-1 IP address
# without the user having to log in.
echo /sbin/striker/list-ips >> /etc/rc.local


# Download 'list-ips' from the Striker we're installing from.
echo "Downloading 'list-ips'."
mkdir /sbin/striker
curl http://10.20.4.2/rhel6/x86_64/img/Striker/striker-master/tools/list-ips > /sbin/striker/list-ips
chown root:root /sbin/striker/list-ips
chmod 755 /sbin/striker/list-ips

# Download 'fence_raritan_snmp' from the Striker we're installing from.
echo "Downloading 'fence_raritan_snmp'."
curl http://10.20.4.2/rhel6/x86_64/img/Tools/fence/fence_raritan_snmp > /usr/sbin/fence_raritan_snmp
chown root:root /usr/sbin/fence_raritan_snmp
chmod 755 /usr/sbin/fence_raritan_snmp

# Download 'anvil-map-network' from the Striker we're installing from.
echo "Downloading 'anvil-map-network'."
curl http://10.20.4.2/rhel6/x86_64/img/Striker/striker-master/tools/anvil-map-network > /sbin/striker/anvil-map-network
chown root:root /sbin/striker/hap-map-network
chmod 755 /sbin/striker/anvil-map-network

### TEMPORARY (Remove once https://bugzilla.redhat.com/show_bug.cgi?id=1285921 has a new resource-agents RPM).
echo "Downloading 'vm.sh'."
curl http://10.20.4.2/rhel6/x86_64/img/Tools/vm.sh > /root/vm.sh
chown root:root /root/vm.sh
chmod 755 /root/vm.sh

# Show details on boot.
echo "Setting plymouth to use detailed boot screen"
plymouth-set-default-theme details --rebuild-initrd
sed -i 's/ rhgb//'  /boot/grub/grub.conf
sed -i 's/ quiet//' /boot/grub/grub.conf

# Setup the Striker repos.
cat > /etc/yum.repos.d/striker01.repo << EOF
[striker01]
name=Striker 01 Repository
baseurl=http://10.20.4.1/rhel6/x86_64/img/
enabled=1
gpgcheck=0
skip_if_unavailable=1
priority=1
EOF

cat > /etc/yum.repos.d/striker02.repo << EOF
[striker02]
name=Striker 02 Repository
baseurl=http://10.20.4.2/rhel6/x86_64/img/
enabled=1
gpgcheck=0
skip_if_unavailable=1
priority=1
EOF
%end


# This is set to run at the end. It copies all of the kickstart logs into the
# root user's home page.
%post --nochroot
echo 'Copying all the anaconda related log files to /root/install/'

if [ ! -e '/mnt/sysimage/root/install' ]
then
	mkdir /mnt/sysimage/root/install
fi
cp -p /tmp/nochroot*   /mnt/sysimage/root/install/
cp -p /tmp/kernel*     /mnt/sysimage/root/install/
cp -p /tmp/anaconda*   /mnt/sysimage/root/install/
cp -p /tmp/ks*         /mnt/sysimage/root/install/
cp -p /tmp/program.log /mnt/sysimage/root/install/
cp -p /tmp/storage*    /mnt/sysimage/root/install/
cp -p /tmp/yum.log     /mnt/sysimage/root/install/
cp -p /tmp/ifcfg*      /mnt/sysimage/root/install/
cp -p /tmp/syslog      /mnt/sysimage/root/install/
%end


### Script to setup partitions.
%pre --log=/tmp/ks-preinstall.log

#!/bin/sh

# Prepare the disks in the script below. It checks '/proc/partitions' to see
# what configuration to use. 

###############################################################################
# Below is for 40 GiB / partitions with the balance of free space to be       #
# configured later.                                                           #
###############################################################################

# Default is to use /dev/sda. At this time, software arrays are not supported.
DRIVE="sda";

# /dev/vda KVM virtual machine
if grep -q vda /proc/partitions
then
	DRIVE="vda"
fi

# Zero-out the first 100GB to help avoid running into problems when a node that
# was previously in a cluster gets rebuilt. Only run on real hardware, tends to
# crash VMs.
if grep -q sda /proc/partitions;
then
	echo "Please be patient! Zero'ing out the first 100 GiB of /dev/${DRIVE}..."
	dd if=/dev/zero of=/dev/${DRIVE} bs=4M count=25000
fi

### Make sure we always create a GPT disk (https://access.redhat.com/solutions/55652)
echo "Creating a GPT disk label"
/usr/bin/dd bs=512 count=10 if=/dev/zero of=/dev/${DRIVE}
/usr/sbin/parted --script /dev/${DRIVE} mklabel gpt
/usr/sbin/parted -l /dev/${DRIVE}
/usr/bin/sleep  30

# Now write the partition script
echo "Done! Now creating and formatting partitions."
cat > /tmp/part-include <<END

zerombr
clearpart --all --drives=${DRIVE}
ignoredisk --only-use=${DRIVE}
bootloader --location=mbr --driveorder=${DRIVE}

part     /boot --fstype ext4 --size=512   --asprimary --ondisk=${DRIVE}
part     swap  --fstype swap --size=4096  --asprimary --ondisk=${DRIVE}
part     /     --fstype ext4 --size=40960 --asprimary --ondisk=${DRIVE}

END

%end
