#!/bin/bash

DIR=$(ipmitool lan print 2  |grep -v "Source" | grep "IP Address" | awk '{print $4}')

DEPLOY="192.168.25.3"
mkdir /root/getinfo
cd /root/getinfo
lshw -json > lshw.json
ifconfig -a > ifconfig-a
cat /proc/cpuinfo > cpuinfo
cat /proc/meminfo > meminfo
cat /proc/diskstats > diskstats
lspci > lspci
cd /root/

tar czvf getinfo.tgz getinfo/

ssh -o 'StrictHostKeyChecking no' ${DEPLOY} "mkdir -p /opt/tala/nodes/${DIR}"
scp -o 'StrictHostKeyChecking no' getinfo.tgz ${DEPLOY}:/opt/tala/nodes/${DIR}
ssh -o 'StrictHostKeyChecking no' ${DEPLOY} "tar zxvf /opt/tala/nodes/${DIR}/getinfo.tgz  -C /opt/tala/nodes/${DIR}"
