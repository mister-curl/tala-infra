#!/bin/bash
# FileName: conpower.sh

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

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi


PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H HostID]  [-n guest_machine_name] [-O Actions]
          -H: HostID
	  -n: container name
	  -O: Action"
    exit 1
}


TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"
DOCKER="/usr/bin/docker"

#logme



## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE


while getopts H:n:O: OPT
do
	case ${OPT} in
		"H" ) FLG_H="TRUE" ; readonly HOST_ID="${OPTARG}" ;;
		"n" ) FLG_N="TRUE" ; readonly CON_NAME="${OPTARG}" ;;
		"O" ) FLG_O="TRUE" ; readonly OPE="${OPTARG}" ;;
		\? ) PRINT_USAGE ;; 
	esac
done


## CON_IDが指定されて無い場合は処理を停止する。
if [ "$FLG_H" = "TRUE" ]; then
	echo "CON_ID : ${CON_ID} 指定されました。 " 
else
	PRINT_USAGE
fi
## CONが指定されて無い場合は処理を停止する。
if [ "$FLG_N" = "TRUE" ]; then
	echo "CON_NAME : ${CON_NAME} 指定されました。 " 
else
	PRINT_USAGE
fi

## OPEが指定されて無い場合は処理を停止する。
if [ "$FLG_O" = "TRUE" ]; then
	echo "OPE : ${OPE} 指定されました。 " 
else
	PRINT_USAGE
fi

set +x
echo -------------------------------------
echo Container NAME $CON_NAME
echo OPERATION  $OPE
echo -------------------------------------
set -x

readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

if [ "$OPE" = "on" ] ;then
    
    $DOCKER start $CON_NAME

    PID=`docker inspect --format '{{.State.Pid}}' $CON_NAME`
    IPADDR=`docker inspect --format '{{.NetworkSettings.IPAddress}}' $CON_NAME`
    IPSUB=`docker inspect --format '{{.NetworkSettings.IPPrefixLen}}' $CON_NAME`

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

    # reset default gateway address
    DEFGW=$(ip route | awk '/default/ { print $3 }')
    $NSENTER -t $PID -n route add default gw $DEFGW eth0

    # print ip addr
    IPADDR_NEW=$($NSENTER -t $PID -n ip a s eth0  | awk '$1~/^inet$/{print $2}')

    set +x
    echo -------------------------------------
    echo Container NAME $CON_NAME
    echo New IP  : $IPADDR_NEW
    echo -------------------------------------
    set -x


    ${CURL} -H "Content-type: application/json" -d "{ \"ip_address\": \""${IPADDR_NEW}"\" }" -X POST ${URL_BASE}/containers/${HOST_ID}/ip_address/
    ${CURL} -H "Content-type: application/json" -d '{ "status": "wakeup now" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/

elif [ "$OPE" = "off" ] ;then
    ${DOCKER} kill ${CON_NAME}
    ${CURL} -H "Content-type: application/json" -d '{ "status": "shutting now" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/
elif [ "$OPE" = "status" ] ;then
    STATUS=$($DOCKER ps | grep -q ${CON_NAME} && echo 0 || echo 1)
    echo $STATUS
    if [ "$STATUS" = "0" ] ;then
        ${CURL} -H "Content-type: application/json" -d '{ "status": "on" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/
    elif [ "$STATUS" = "1" ] ;then
        ${CURL} -H "Content-type: application/json" -d '{ "status": "off" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/
    else
        ${CURL} -H "Content-type: application/json" -d '{ "status": "error" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/
    fi
fi



exit 0

