#!/bin/bash

#set -e
#set -x

CMDNAME=$(basename "$0")
CMDOPT=$*

. /opt/tala/bin/common.cfg

FLG_H=""
FLG_O=""
FLG_T=""

#logme
##
#echo "==========================="
#echo "CMDNAME : $CMDNAME"
#echo "CMD_OPT : $CMDOPT"
#echo "==========================="

## root ユーザ以外で実行された場合、スクリプトを終了
if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
        exit 1
fi


PRINT_USAGE () {
    echo "usage: bash $CMDNAME  [-H hostid ]  [-O Operation] [-T type]
          -H: host id
          -O: operation on/off/restart/status
          -T: Type  vm/bm/container
         "
    exit 1
}

## オプション値の確認
[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H:O:T: OPT
do
        case ${OPT} in
                "H" ) FLG_H="TRUE" ; readonly HOST_ID="${OPTARG}";;
                "O" ) FLG_O="TRUE" ; readonly OPE="${OPTARG}" ;;
                "T" ) FLG_T="TRUE" ; readonly TYPE="${OPTARG}" ;;
                \? ) PRINT_USAGE ;;
        esac
done

if [ "$FLG_H" = "TRUE" ]; then
	echo "HOST_ID : $HOST_ID が指定されました"
else
	PRINT_USAGE
fi

if [ "$FLG_O" = "TRUE" ]; then
	echo "OPE : $OPE が指定されました"
else
	PRINT_USAGE
fi

if [ "$FLG_T" = "TRUE" ]; then
	echo "TYPE : $TYPE が指定されました"
else
	PRINT_USAGE
fi

# 対象ホストの情報取得
readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"



if [ "$TYPE" = "vm" ] ;then
    readonly HOST_IP="$(${CURL} ${URL_BASE}/vms/${HOST_ID}/ | ${JQ} .host_server)"
    readonly VM_NAME="$(${CURL} ${URL_BASE}/vms/${HOST_ID}/ | ${JQ} .hostname)"

    if [ "$OPE" = "on" ] ;then
	su - admin -c  "ssh admin@$HOST_IP \"sudo virsh start $VM_NAME \" "
	$CURL -H "Content-type: application/json" -d '{ "power": "wake up now" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/

    elif [ "$OPE" = "off" ] ;then
	su - admin -c  "ssh admin@$HOST_IP \"sudo virsh destroy $VM_NAME \" "
	$CURL -H "Content-type: application/json" -d '{ "power": "shotdown now" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/

    elif [ "$OPE" = "restart" ] ;then
	su - admin -c  "ssh admin@$HOST_IP \"sudo virsh destroy $VM_NAME \" "
	su - admin -c  "ssh admin@$HOST_IP \"sudo virsh start $VM_NAME \" "
	$CURL -H "Content-type: application/json" -d '{ "power": "restart now" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/

    elif [ "$OPE" = "status" ] ;then
	STATUS=$( su - admin -c  "ssh admin@$HOST_IP \"sudo virsh domstate $VM_NAME \" " )
	echo $STATUS
	if $(echo ${STATUS} | grep -q running ) ;then
		$CURL -H "Content-type: application/json" -d '{ "power": "on" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/
	elif $(echo ${STATUS} | grep -q "shut off" ) ;then
		$CURL -H "Content-type: application/json" -d '{ "power": "off" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/
	else
		$CURL -H "Content-type: application/json" -d '{ "power": "error" }' -X POST ${URL_BASE}/vms/${HOST_ID}/power/
	fi
    fi

elif [ "$TYPE" = "bm" ] ;then
    ## Beametal
    readonly IPMITOOL="/usr/bin/ipmitool"
    readonly IPMI_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_ip_address)"
    readonly IPMI_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_user_name)"
    readonly IPMI_PASS="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_password)"

    if [ "$OPE" = "on" ] ;then
	${IPMITOOL} -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} power on
	$CURL -H "Content-type: application/json" -d '{ "power": "wake up now" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/

    elif [ "$OPE" = "off" ] ;then
	${IPMITOOL} -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} power off
	$CURL -H "Content-type: application/json" -d '{ "power": "shotdown now" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/

    elif [ "$OPE" = "restart" ] ;then
	${IPMITOOL} -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} power cyclet
	$CURL -H "Content-type: application/json" -d '{ "power": "restart now" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/

    elif [ "$OPE" = "status" ] ;then
	STATUS=$(${IPMITOOL} -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} power status )
	echo $STATUS
	if $(echo ${STATUS} | grep -q on ) ;then
		$CURL -H "Content-type: application/json" -d '{ "power": "on" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/
	elif $(echo ${STATUS} | grep -q off ) ;then
		$CURL -H "Content-type: application/json" -d '{ "power": "off" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/
	else
		$CURL -H "Content-type: application/json" -d '{ "power": "error" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/power/
	fi
    fi
elif [ "$TYPE" = "container" ] ;then
    readonly DOCKER="/usr/bin/docker"
    readonly HOST_IP="$(${CURL} ${URL_BASE}/containers/${HOST_ID}/ | ${JQ} .host_server)"
    readonly VM_NAME="$(${CURL} ${URL_BASE}/containers/${HOST_ID}/ | ${JQ} .hostname)"


    if [ "$OPE" = "on" ] ;then
        su - admin -c  "ssh admin@$HOST_IP \"sudo /opt/tala/bin/conpower.sh -H $HOST_ID -n $VM_NAME -O on \" "

    elif [ "$OPE" = "off" ] ;then
        su - admin -c  "ssh admin@$HOST_IP \"sudo /opt/tala/bin/conpower.sh -H $HOST_ID -n $VM_NAME -O off \" "

    elif [ "$OPE" = "restart" ] ;then
        su - admin -c  "ssh admin@$HOST_IP \"sudo /opt/tala/bin/conpower.sh -H $HOST_ID -n $VM_NAME -O off \" "
        su - admin -c  "ssh admin@$HOST_IP \"sudo /opt/tala/bin/conpower.sh -H $HOST_ID -n $VM_NAME -O on \" "

    elif [ "$OPE" = "status" ] ;then
        su - admin -c  "ssh admin@$HOST_IP \"sudo /opt/tala/bin/conpower.sh -H $HOST_ID -n $VM_NAME -O status \" "
    fi

fi


exit 0
