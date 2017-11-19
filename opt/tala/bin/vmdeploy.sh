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

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi

EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/vms/${HOST_ID}/status/
    exit 1
}

## print usage
PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H HostID] 
          -H: HostID(vm id)"
    EXIT
}

TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"

#logme


## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H: OPT
do
	case ${OPT} in
		"H" ) FLG_H="TRUE" ; readonly VM_ID="${OPTARG}" ;;
		\? ) PRINT_USAGE ;; 
	esac
done


if [ "$FLG_H" = "TRUE" ]; then
        echo "VM_ID : ${VM_ID} 指定されました。 "
else
        PRINT_USAGE
fi

readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# APIのStatus を構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "VM構築中" }' -X POST ${URL_BASE}/vms/${VM_ID}/status/ 



# 対象ホストの情報取得
readonly HOST_IP="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .host_server)"
readonly VM_NAME="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .hostname)"
readonly VM_CORE="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .allocate_cpu)"
readonly VM_MEMSIZE_MB="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .allocate_memory)"
readonly VM_DISKSIZE_GB="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .allocate_disk)"
readonly VM_OS_OPTION="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .os)"
readonly USER_PASS="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .password)"

VM_PASS=$(sh -c "python -c 'import crypt; print crypt.crypt(\"$USER_PASS\", \"a2\")'")
su - admin -c  "ssh admin@$HOST_IP \"sudo bash $TALADIR/bin/vmcreate.sh -H $VM_ID -n $VM_NAME -c $VM_CORE -m $VM_MEMSIZE_MB -d $VM_DISKSIZE_GB -o $VM_OS_OPTION -p $USER_PASS \" "


sleep 1
readonly VM_MAC="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .mac_address)"
VM_IP=$(grep -E "ethernet|lease" /var/lib/dhcp/dhcpd.leases | grep -i -B1 $VM_MAC |awk '/lease/{print $2}')

${CURL} -H "Content-type: application/json" -d "{ \"ip_address\": \""${VM_IP}"\" }" -X POST ${URL_BASE}/vms/${VM_ID}/ip_address/
exit 0

