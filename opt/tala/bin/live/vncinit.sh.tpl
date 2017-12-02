#!/bin/sh
set -x

VNC_PORT=__VNC_PORT__
PASSWD=__PASSWORD__

apt install -y vnc4server

sed -i "s/vncPort = 5900 + \$displayNumber/vncPort = ${VNC_PORT}/" /usr/bin/vnc4server

vnc4server -SecurityTypes None <<-EOF
 $PASSWD
 $PASSWD
EOF

iptables -I INPUT 2 -m state --state NEW -m tcp -p tcp --dport ${VNC_PORT} -j ACCEPT
iptables -I INPUT 2 -m state --state NEW -m tcp -p tcp --dport 10050 -j ACCEPT
iptables-save > /etc/iptables/iptables.rules

echo "vnc4server -SecurityTypes None" >> /etc/rc.local
