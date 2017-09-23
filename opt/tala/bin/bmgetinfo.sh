#!/bin/bash
#set -e
set -x 

CMDNAME=$(basename "$0")
CMDOPT=$*

. /opt/tala/bin/common.cfg

FLG_H=

logme

## root ユーザ以外で実行された場合、スクリプトを終了
if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
        exit 1
fi

## print usage

PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H hostid ]
          -H: hostid
          "
    exit 1
}

## オプション値の確認
[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H: CMDOPT
do
        case ${CMDOPT} in
                "H" ) FLG_H="TRUE" ; readonly HOST_ID="${OPTARG}";;
                \? ) PRINT_USAGE ;; 
        esac
done

if [ "$FLG_H" != "TRUE" ] ;then
    PRINT_USAGE 
    exit 1
fi


# 対象ホストの情報取得
readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"
readonly IPMI_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_ip_address)"
readonly IPMI_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_user_name)"
readonly IPMI_PASS="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_password)"

# すでに情報がある場合には削除する
[ -d "${TALADIR}/nodes/${HOST_ID}" ] && rm -rf ${TALADIR}/nodes/${HOST_ID} 
[ -d "${TALADIR}/nodes/${IPMI_IP}" ] && rm -rf ${TALADIR}/nodes/${IPMI_IP} 

systemctl reload-or-restart tftpd-hpa.service


# IPMI setting
sudo ipmitool -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} chassis bootdev pxe || exit 1
sudo ipmitool -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS}  power reset || exit 1


# timeout 10minits (3600)
TIME_OUT=3600
TIME=0
while true ;do
    if [ -f ${TALADIR}/nodes/${IPMI_IP}/getinfo.tgz ] ;then
	mv -f ${TALADIR}/nodes/${IPMI_IP} ${TALADIR}/nodes/${HOST_ID}
        break
    elif [ "$TIME" -gt "${TIME_OUT}" ] ;then
        exit 1
    fi    

    TIME=$(( TIME + 1 ))
    sleep 10
done

shutdown -h now

exit 0 
