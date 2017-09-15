#!/bin/bash
## This Script Included  Ubuntu/CentOS image 
set -x

while : ;do
        #LIST=($(cat /proc/net/dev | grep -v Inter | grep -v face |grep -v lo | awk -F: '{print $1}' ))
        LIST=($(ifconfig -a | grep Ethernet | awk '{print $1}' ))
        if [ ${#LIST[*]} -ge 1 ] ; then
                break
        fi
        sleep 1
done
for list in ${LIST[*]} ;do
    echo "auto $list" >>  /etc/network/interfaces
    echo "iface $list inet dhcp"  >>  /etc/network/interfaces
done
systemctl restart networking.service
