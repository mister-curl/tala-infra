#!/bin/bash
# Description ; install to KVM node

set -x


mkdir -p /opt/tala/bin
mkdir -p /opt/tala/log
mkdir -p /opt/tala/images
# log
exec > >(tee /opt/tala/log/bm2kvm.sh.log) 2>&1

test "$TERM" = linux && setterm -blank 0


HOSTNAME=$(hostname)
PATH=/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin
cd $(dirname $0)
HERE=(env - PATH=$PATH pwd)
CURL="/usr/bin/curl"
APTCMD="/usr/bin/apt-get"
SYSTEM=$(dmidecode -t 1 | grep 'Product Name' | awk -F": " '{print $2}')

$APTCMD update

# # os check 
test $(id -u) -eq 0 || { echo "try sudo sh $0"; exit 1; }
DIST=$(cat /etc/lsb-release | awk -F= '/CODENAME/ {print $2}')
[ "$DIST" = "xenial" ] || { echo 'Wrong DISTribution release.'; exit 1; }
test $(uname -m) = 'x86_64' || { echo 'Wrong os-arch.'; exit 1; }


# interface
while : ;do
        LIST=($(ifconfig -a | grep Ethernet | awk '{print $1}' ))
        if [ ${#LIST[*]} -ge 1 ] ; then
                break
        fi
        sleep 1
done


# netcfg
cat << 'EOF' > /etc/modules
8021q
nf_conntrack_ipv4
EOF

$APTCMD -y install qemu-kvm libvirt-bin
$APTCMD -y install gdisk patch libreadline5 lvm2 xfsprogs


# libvirt qemu-kvm
virsh net-destroy default
virsh net-autostart --disable default

sed -i 's/#max_processes = 0/max_processes = 65536/' /etc/libvirt/qemu.conf
sed -i 's/#security_driver = "selinux"/security_driver = "none"/' /etc/libvirt/qemu.conf

cat << "EOF" > /etc/security/limits.d/90-nproc.conf
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.

root       soft    nproc     unlimited
EOF

# virt tool
cat << "EOF" > /var/cache/debconf/config.dat

Name: libguestfs/update-appliance
Template: libguestfs/update-appliance
Value: false
Owners: libguestfs-tools
Flags: seen
EOF

$APTCMD -y install libguestfs-tools iotop virt-top

# Development Tools
$APTCMD -y install vlan ifenslave ethtool sysstat conntrack ebtables vim moreutils
$APTCMD -y install xmlstarlet kpartx dump cifs-utils gddrescue
$APTCMD -y install bc ipcalc sipcalc at genisoimage pv gcc curl cgroup-bin

sed -i '\%^ENABLED% s/false/true/' /etc/default/sysstat

update-alternatives --set editor /usr/bin/vim.basic

# sysctl
cat << 'EOF' >> /etc/sysctl.conf
net.netfilter.nf_conntrack_max = 524288
net.ipv4.ip_local_port_range = 58001 65535

# Controls the default maxmimum size of a mesage queue
kernel.msgmnb = 65536

# Controls the maximum size of a message, in bytes
kernel.msgmax = 65536

# Controls the maximum shared segment size, in bytes
kernel.shmmax = 68719476736

# Controls the maximum number of shared memory segments, in pages
kernel.shmall = 4294967296

net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.netdev_max_backlog = 5000
EOF

sed -i '/^exit 0$/d' /etc/rc.local
echo "sysctl -p" >> /etc/rc.local


# disable module
echo "blacklist bluetooth " >> /etc/modprobe.d/blacklist.conf

# fix keyboard layoout
sed -i 's/^XKBMODEL=.*$/XKBMODEL="jp106"/' /etc/default/keyboard
sed -i 's/^XKBLAYOUT=.*$/XKBLAYOUT="jp"/' /etc/default/keyboard



mv -f /opt/tala/bin/qemu /etc/libvirt/hooks/qemu


mv -f /etc/network/interfaces{,.orig}


while : ;do
        LIST=($(ifconfig -a | grep Ethernet | awk '{print $1}' ))
        if [ ${#LIST[*]} -ge 1 ] ; then
                break
        fi
        sleep 1
done

cat << 'EOF' > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto br0
iface br0 inet dhcp
EOF

echo "bridge_ports ${LIST[0]}" >> /etc/network/interfaces

cat <<EOF
######################################################################
#######               install is complete.                 ###########
######################################################################
EOF

touch /home/admin/lock

sleep 4
reboot

