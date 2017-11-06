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
PRINT_USAGE () {
    echo "usage: bash $CMDNAME  [-H hostid ] "
    exit 1
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
	exit 1
fi


TALA_SERVER=$(grep tala-server /etc/hosts | awk '{print $1}')
SCRIPT="${TALADIR}/bin/kvm/bm2kvm.sh"


readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# APIステータスを構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "KVM構築中" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 

# 対象ホストの情報取得
readonly BM_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ip_address)"
readonly BM_IP="192.168.25.19" 

rm -f /home/admin/.ssh/known_hosts
# timeout 20minits (7200)
SSH_TIME_OUT=7200
SSH_TIME=0

while true ;do
SSH_STATUS=$(su - admin -c  "ssh -oStrictHostKeyChecking=no admin@$BM_IP 'test -d /opt/tala && echo true || echo faile ' " )
    if [ "$SSH_STATUS" = "true" ] ;then
        break
    elif [ "$SSH_TIME" -gt "${SSH_TIME_OUT}" ] ;then
        exit 1
    fi
    SSH_TIME=$(( SSH_TIME + 1 ))
    sleep 10
done


su - admin -c  "scp -oStrictHostKeyChecking=no ${TALADIR}/bin/kvm/bm2kvm.sh admin@$BM_IP:$TALADIR/bin/bm2kvm.sh "
su - admin -c  "scp ${TALADIR}/bin/kvm/libvirtxml.tpl admin@$BM_IP:$TALADIR/bin/libvirtxml.tpl "
su - admin -c  "scp ${TALADIR}/bin/kvm/vmcreate.sh admin@$BM_IP:$TALADIR/bin/vmcreate.sh"
su - admin -c  "scp ${TALADIR}/bin/kvm/vmremove.sh admin@$BM_IP:$TALADIR/bin/vmremove.sh "
su - admin -c  "scp ${TALADIR}/bin/kvm/qemu admin@$BM_IP:$TALADIR/bin/qemu"
su - admin -c  "ssh admin@$BM_IP \"sudo bash $TALADIR/bin/bm2kvm.sh  \"  "

# timeout 20minits (7200)
TIME_OUT=7200
TIME=0

while true ;do
STATUS=$(su - admin -c  "ssh admin@$BM_IP 'test -f /home/admin/lock && echo true || echo faile '  " )
    if [ "$STATUS" = "true" ] ;then
        break
    elif [ "$TIME" -gt "${TIME_OUT}" ] ;then
        exit 1
    fi

    TIME=$(( TIME + 1 ))
    sleep 10
done

#su - admin -c  "scp admin@$BM_IP:$TALADIR/log/bm2kvm.sh.log  ${TALADIR}/log/${BM_IP}_kvm.log"

set +x
#echo "==============KVM INSTALL LOG =========================="
#cat ${TALADIR}/log/$BM_IP_kvm.log


${CURL} -H "Content-type: application/json" -d '{ "status": "KVM構築完了" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
echo "script end"
