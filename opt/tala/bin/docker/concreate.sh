#!/bin/bash
# FileName: vmcreate.sh

#set -e

logme () {
    exec </dev/null
    exec >$LOGDIR/$CMDNAME.$(date +%Y%m%d-%H%M%S).$$.log
    exec 2>&1
renice +20 -p $$
}

set -x 
CMDNAME=$(basename "$0")
CMDOPT=$*


FLG_H=
FLG_N=
FLG_C=
FLG_M=
FLG_D=
FLG_O=
FLG_R=
FLG_B=

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi

## print usage

PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-n guest_machine_name] [-c cpu_core] [-m container_memory_size] [-d container_hdd_size] [-p md5_password] [-o distribution] [-b] [-r] 
          -H: HostID
	  -n: container name
	  -c: container cpu core
	  -m: container memomy size (MByte)
	  -d: container hdd size (GByte)
	  -p: root password
	  -o: os distribution 
	  -r: reinstall container.
	  -b: boot"
    exit 1
}


TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"
DOCKER="/usr/bin/docker"

#logme



## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE


while getopts H:n:c:m:d:p:o:rb OPT
do
	case ${OPT} in
		"H" ) FLG_H="TRUE" ; readonly CON_NUM="${OPTARG}" ;;
		"n" ) FLG_N="TRUE" ; readonly CON_NAME="${OPTARG}" ;;
		"c" ) FLG_C="TRUE" ; readonly CON_CORE="${OPTARG}" ;;
		"m" ) FLG_M="TRUE" ; readonly CON_MEMSIZE_MB="${OPTARG}" ;;
		"o" ) FLG_O="TRUE" ; readonly CON_OS_OPTION="${OPTARG}" ;;
		"p" ) FLG_P="TRUE" ; readonly USER_PASS="${OPTARG}" ;;
		"r" ) FLG_R="TRUE" ;;
		"b" ) FLG_B="TRUE" ;;
		\? ) PRINT_USAGE ;; 
	esac
done

CON_PASS=$(sh -c "python -c 'import crypt; print crypt.crypt(\"$USER_PASS\", \"a2\")'")


## CONが指定されて無い場合は処理を停止する。
if [ "$FLG_N" = "TRUE" ]; then
	echo "CON_NAME : ${CON_NAME} 指定されました。 " 
else
	exit 1
fi

## 初回作成 or リインストール
if [ "$FLG_R" = "TRUE" ]; then
    echo "skip check host server resource"
fi

## パスワードが指定されて無い場合は処理を停止する。
if [ "$FLG_P" = "TRUE" ]; then
	echo "CON_PASS : ${CON_PASS}"
#else
#	exit 1
fi



# OS install
case $CON_OS_OPTION in
  ubuntu1404_x86-64)
    #DIST="ubuntu:14.04"
    DIST="tala/ubuntu:14.04"
    ;;
  ubuntu1604_x86-64)
    DIST="ubuntu:16.04"
    ;;
  *)
    echo "指定のディストリビューションは存在しません。"
    exit 1
    ;;
esac

CONTAINER_ID=$(${DOCKER} run -i -t --privileged -d -m ${CON_MEMSIZE_MB}m --name=${CON_NAME}  --restart=always ${DIST} /sbin/init || exit 1)

[ $? -eq 1 ] && exit 1

# get docker pid, ip address (allocated by docker)
#PID=$(docker inspect --format '{{.State.Pid}}' $CONTAINER_ID)
##IPADDR=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_ID)
#IPSUB=$(docker inspect --format '{{.NetworkSettings.IPPrefixLen}}' $CONTAINER_ID)

PID=`docker inspect --format '{{.State.Pid}}' $CONTAINER_ID`
IPADDR=`docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_ID`
IPSUB=`docker inspect --format '{{.NetworkSettings.IPPrefixLen}}' $CONTAINER_ID`

set +x
echo -------------------------------------
echo Container NAME $CON_NAME
echo Container ID  : $CONTAINER_ID
echo Container PID : $PID
echo Allocated IP  : $IPADDR/$IPSUB
echo -------------------------------------
set -x


BRCTL="/sbin/brctl"
NSENTER="/usr/bin/nsenter"

VETH=$(brctl show | awk /docker0/'{print $4}')
$BRCTL delif $VETH docker0
$BRCTL delif docker0 $VETH
$BRCTL addif br0 $VETH

# del allocated ip cddress
$NSENTER -t $PID -n ip addr del $IPADDR/$IPSUB dev eth0

# get ip address from dhcp
$NSENTER -t $PID -n -- dhclient eth0
#dhclient -r




# reset default gateway address
DEFGW=$(ip route | awk '/default/ { print $3 }')
$NSENTER -t $PID -n route add default gw $DEFGW eth0

# print ip addr
$NSENTER -t $PID -n ip addr

# admin user
CON_PASS=$(sh -c "python -c 'import crypt; print crypt.crypt(\"$USER_PASS\", \"a2\")'")
$NSENTER -t $PID -n echo "CREATE_HOME yes" >> /etc/login.defs
$NSENTER -t $PID -n useradd "ubuntu" -s /bin/bash -g 0
$NSENTER -t $PID -n usermod -p "${CON_PASS}" ubuntu


if [ "$FLG_B" = "TRUE" ]; then
        echo "vm create and start successfully"
else
        echo "vm create successfully"
fi

IPADDR_NEW=$($NSENTER -t $PID -n ip a s eth0  | awk '$1~/^inet$/{print $2}')

set +x
echo -------------------------------------
echo Container NAME $CON_NAME
echo New IP  : $IPADDR_NEW
echo -------------------------------------
set -x
exit 0

