#!/bin/bash
#set -e

CMDNAME=$(basename "$0")
CMDOPT=$*

. /opt/tala/bin/common.cfg

FLG_H=

logme

echo "==========================="
echo "CMDNAME : $CMDNAME"
echo "CMD_OPT : $CMDOPT"
echo "==========================="

set -x 

## root ユーザ以外で実行された場合、スクリプトを終了
if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
        exit 1
fi

## print usage
EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
    exit 1
}

PRINT_USAGE () {
    echo "usage: bash $CMDNAME  [-H hostid ] "
    EIXT
}

### オプション値の確認
[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H: OPT
do
        case ${OPT} in
                "H" ) FLG_H="TRUE" ; readonly HOST_ID="${OPTARG}";;
                \? ) PRINT_USAGE ;; 
        esac
done

if [ "$FLG_H" = "TRUE" ]; then
	echo "HOST_ID : ${HOST_ID} 指定されました。 " 
else
	PRINT_USAGE
fi


TALA_SERVER=$(grep tala-server /etc/hosts | awk '{print $1}')

readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# APIステータスを構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "Docker構築中" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 

# 対象ホストの情報取得
readonly BM_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ip_address)"

rm -f /home/admin/.ssh/known_hosts
# timeout 20minits (7200)
SSH_TIME_OUT=7200
SSH_TIME=0

while true ;do
SSH_STATUS=$(su - admin -c  "ssh -oStrictHostKeyChecking=no admin@$BM_IP 'test -d /opt/tala && echo true || echo faile ' " )
    if [ "$SSH_STATUS" = "true" ] ;then
        break
    elif [ "$SSH_TIME" -gt "${SSH_TIME_OUT}" ] ;then
	EXIT
    fi
    SSH_TIME=$(( SSH_TIME + 10 ))
    sleep 10
done


su - admin -c  "scp -oStrictHostKeyChecking=no ${TALADIR}/bin/docker/bm2docker.sh admin@$BM_IP:$TALADIR/bin/bm2docker.sh "
su - admin -c  "scp ${TALADIR}/bin/docker/concreate.sh admin@$BM_IP:$TALADIR/bin/concreate.sh"
su - admin -c  "scp ${TALADIR}/bin/docker/conremove.sh admin@$BM_IP:$TALADIR/bin/conremove.sh "
su - admin -c  "scp ${TALADIR}/bin/docker/conpower.sh admin@$BM_IP:$TALADIR/bin/conpower.sh "
su - admin -c  "scp -r ${TALADIR}/bin/docker/dockerfile admin@$BM_IP:$TALADIR/bin/"
su - admin -c  "ssh admin@$BM_IP \"sudo bash $TALADIR/bin/bm2docker.sh  \"  "

# timeout 20minits (7200)
TIME_OUT=7200
TIME=0

while true ;do
STATUS=$(su - admin -c  "ssh admin@$BM_IP 'test -f /home/admin/lock && echo true || echo faile '  " )
    if [ "$STATUS" = "true" ] ;then
        break
    elif [ "$TIME" -gt "${TIME_OUT}" ] ;then
	EXIT
    fi

    TIME=$(( TIME + 10 ))
    sleep 10
done


${CURL} -H "Content-type: application/json" -d '{ "status": "Docker構築完了" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
${CURL} -H "Content-type: application/json" -d '{ "type": "Docker" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/type/ 
echo "script end"
