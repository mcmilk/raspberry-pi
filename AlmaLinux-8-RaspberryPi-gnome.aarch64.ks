# To build an image run the following as root:
# appliance-creator -c AlmaLinux-8-RaspberryPi-gnome.aarch64.ks \
#    -d -v --logfile /var/tmp/AlmaLinux-8-RaspberryPi-gnome-$(date +%Y%m%d-%s).aarch64.ks.log \
#    --cache ./cache8 --no-compress \
#    -o $(pwd) --format raw --name AlmaLinux-8-RaspberryPi-gnome-$(date +%Y%m%d-%s).aarch64 | \
#    tee /var/tmp/AlmaLinux-8-RaspberryPi-gnome-$(date +%Y%m%d-%s).aarch64.ks.log.2
#
# Basic setup information
url --url="https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/"
# root password is locked but can be reset by cloud-init later
rootpw --plaintext --lock almalinux

# Repositories to use
repo --name="baseos"    --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/
repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/aarch64/os/
repo --name="raspberrypi" --baseurl=https://repo.almalinux.org/almalinux/8/raspberrypi/aarch64/os/

# install
keyboard us --xlayouts=us --vckeymap=us
timezone --isUtc --nontp UTC
selinux --enforcing
firewall --enabled --port=22:tcp
network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,NetworkManager,chronyd
shutdown
bootloader --location=mbr
lang en_US.UTF-8

# Disk setup
clearpart --initlabel --all
part /boot --asprimary --fstype=vfat --size=500 --label=boot
part / --asprimary --fstype=ext4 --size=4500 --label=rootfs

# Package setup
%packages
@core
@gnome-desktop
firefox
dejavu-sans-fonts
dejavu-sans-mono-fonts
dejavu-serif-fonts
aajohan-comfortaa-fonts
abattis-cantarell-fonts
-caribou*
-gnome-shell-browser-plugin
-java-1.6.0-*
-java-1.7.0-*
-java-11-*
-python*-caribou*
-iwl1000-firmware
-iwl100-firmware
-iwl105-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl2030-firmware
-iwl3160-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6000g2b-firmware
-iwl6050-firmware
-iwl7260-firmware
NetworkManager-wifi
almalinux-release-raspberrypi
chrony
cloud-init
cloud-utils-growpart
e2fsprogs
net-tools
linux-firmware-raspberrypi
raspberrypi2-firmware
raspberrypi2-kernel4
nano
%end

%post
# Mandatory README file
cat >/boot/README.txt << EOF
== AlmaLinux 8 ==

To login to Raspberry Pi via SSH, you need to register SSH public key *before*
inserting SD card to Raspberry Pi. Edit user-data file and put SSH public key
in the place.

Default SSH username is almalinux.

EOF

# Data sources for cloud-init
touch /boot/meta-data /boot/user-data

cat >/boot/user-data << "EOF"
#cloud-config
#
# This is default cloud-init config file for AlmaLinux Raspberry Pi image.
#
# If you want additional customization, refer to cloud-init documentation and
# examples. Please note configurations written in this file will be usually
# applied only once at very first boot.
#
# https://cloudinit.readthedocs.io/en/latest/reference/examples.html

hostname: almalinux.local
ssh_pwauth: false

users:
  - name: almalinux
    groups: [ adm, systemd-journal ]
    sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
    lock_passwd: false
    passwd: $6$EJCqLU5JAiiP5iSS$wRmPHYdotZEXa8OjfcSsJ/f1pAYTk0/OFHV1CGvcszwmk6YwwlZ/Lwg8nqjRT0SSKJIMh/3VuW5ZBz2DqYZ4c1
    ssh_authorized_keys:
      # Put here your ssh public keys
      #- ssh-ed25519 AAAAC3Nz...

EOF

cat > /boot/config.txt << EOF
# This file is provided as a placeholder for user options
# AlmaLinux - few default config options for better graphics support
[all]
disable_overscan=1
dtoverlay=vc4-kms-v3d
camera_auto_detect=0
gpu_mem=64

## AlmaLinux - can enable this for Pi 4 and later
#[pi4]
#max_framebuffers=2
EOF

# Specific cmdline.txt files needed for raspberrypi2/3
cat > /boot/cmdline.txt << EOF
console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
EOF

# Create and initialize swapfile
(umask 077; dd if=/dev/zero of=/swapfile bs=1M count=100)
/usr/sbin/mkswap -p 4096 -L "_swap" /swapfile
cat >> /etc/fstab << EOF
/swapfile	none	swap	defaults	0	0
EOF

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# rebuild dnf cache
dnf clean all
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME
echo '%_install_langs C.utf8' > /etc/rpm/macros.image-language-conf
echo 'LANG="C.utf8"' >  /etc/locale.conf
rpm --rebuilddb

# activate gui
systemct set-default graphical.target

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id
# print disk usage
df
#
%end

%post --nochroot --erroronfail

/usr/sbin/blkid
LOOPPART=$(cat /proc/self/mounts |/usr/bin/grep '^\/dev\/mapper\/loop[0-9]p[0-9] '"$INSTALL_ROOT " | /usr/bin/sed 's/ .*//g')
VFATPART=$(cat /proc/self/mounts |/usr/bin/grep '^\/dev\/mapper\/loop[0-9]p[0-9] '"$INSTALL_ROOT"/boot | /usr/bin/sed 's/ .*//g')
echo "Found loop part for PARTUUID $LOOPPART"
BOOTDEV=$(/usr/sbin/blkid $LOOPPART|grep 'PARTUUID="........-02"'|sed 's/.*PARTUUID/PARTUUID/g;s/ .*//g;s/"//g')
echo "no chroot selected bootdev=$BOOTDEV"
if [ -n "$BOOTDEV" ];then
    cat $INSTALL_ROOT/boot/cmdline.txt
    echo sed -i "s|root=/dev/mmcblk0p2|root=${BOOTDEV}|g" $INSTALL_ROOT/boot/cmdline.txt
    sed -i "s|root=/dev/mmcblk0p2|root=${BOOTDEV}|g" $INSTALL_ROOT/boot/cmdline.txt
fi

# cloud-init: NoCloud data source must have volume label "CIDATA"
#
# This didn't work for some reasons so using fatlabel instead.
#    part /boot --asprimary --fstype=vfat --mkfsoptions="-n CIDATA"
/usr/sbin/fatlabel $VFATPART "CIDATA"

cat $INSTALL_ROOT/boot/cmdline.txt

%end
