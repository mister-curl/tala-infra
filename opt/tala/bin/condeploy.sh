#!/bin/bash
# FileName: condeploy.sh

#set -e
set -x

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

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi

EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/containers/${HOST_ID}/status/ 
    exit 1
}

## print usage
PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H HostID] 
          -H: HostID(container id)"
    EXIT
}

TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"

logme


## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H: OPT
do
	case ${OPT} in
		"H" ) FLG_H="TRUE" ; readonly CON_ID="${OPTARG}" ;;
		\? ) PRINT_USAGE ;; 
	esac
done

if [ "$FLG_H" = "TRUE" ]; then
        echo "CON_ID : ${CON_ID} 指定されました。 "
else
	PRINT_USAGE
fi

readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# APIのStatus を構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "Container構築中" }' -X POST ${URL_BASE}/containers/${CON_ID}/status/ 



# 対象ホストの情報取得
readonly HOST_IP="$(${CURL} ${URL_BASE}/containers/${CON_ID}/ | ${JQ} .host_server)"
readonly CON_NAME="$(${CURL} ${URL_BASE}/containers/${CON_ID}/ | ${JQ} .hostname)"
readonly CON_OS_OPTION="$(${CURL} ${URL_BASE}/containers/${CON_ID}/ | ${JQ} .os)"
readonly USER_PASS="$(${CURL} ${URL_BASE}/containers/${CON_ID}/ | ${JQ} .password)"

su - admin -c  "ssh admin@$HOST_IP \"sudo bash $TALADIR/bin/concreate.sh -H $CON_ID -n $CON_NAME  -o $CON_OS_OPTION -p $USER_PASS \" "


sleep 1
readonly CON_MAC="$(${CURL} ${URL_BASE}/containers/${CON_ID}/ | ${JQ} .mac_address)"
CON_IP=$(grep -E "ethernet|lease" /var/lib/dhcp/dhcpd.leases | grep -i -B1 $CON_MAC |awk '/lease/{print $2}')

${CURL} -H "Content-type: application/json" -d "{ \"ip_address\": \""${CON_IP}"\" }" -X POST ${URL_BASE}/containers/${CON_ID}/ip_address/
exit 0

