#!/bin/bash
# Description ; install to KVM node

set -x


mkdir -p /opt/tala/bin
mkdir -p /opt/tala/log
mkdir -p /opt/tala/images
# log
exec > >(tee /opt/tala/log/bm2docker.sh.log) 2>&1

test "$TERM" = linux && setterm -blank 0


HOSTNAME=$(hostname)
PATH=/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin
cd $(dirname $0)
HERE=(env - PATH=$PATH pwd)
CURL="/usr/bin/curl"
APTCMD="/usr/bin/apt-get"
DOCKER="/usr/bin/docker"
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

$APTCMD -y install bridge-utils bc ipcalc sipcalc at genisoimage pv gcc curl cgroup-bin

$CURL -sSL https://get.docker.com/ | sh


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


# option
echo 'DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"' >> /etc/default/docker

systemctl start docker
systemctl enable docker


$DOCKER pull ubuntu:14.04
$DOCKER pull ubuntu:16.04
$DOCKER pull centos:6
$DOCKER pull centos:7


## docker image build
cd /opt/tala/bin/dockerfile/ubuntu1404
$DOCKER build --no-cache -t tala/ubuntu:14.04 .

cd /opt/tala/bin/dockerfile/ubuntu1604
$DOCKER build --no-cache -t tala/ubuntu:16.04 .




# inteface
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


# iptables
cat << 'EOF' > /etc/iptables/iptables.rules
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF



cat <<EOF
######################################################################
#######               install is complete.                 ###########
######################################################################
EOF

touch /home/admin/lock

sleep 4
reboot

