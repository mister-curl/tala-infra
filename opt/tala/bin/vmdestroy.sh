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

## print usage

PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H HostID] 
          -H: HostID(vm id)"
    exit 1
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
		"H" ) FLG_H="TRUE" ; readonly VM_ID="${OPTARG}" ;;
		\? ) PRINT_USAGE ;; 
	esac
done

readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# 対象ホストの情報取得
readonly HOST_IP="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .host_server)"
readonly VM_NAME="$(${CURL} ${URL_BASE}/vms/${VM_ID}/ | ${JQ} .hostname)"

su - admin -c  "ssh admin@$HOST_IP \"sudo bash $TALADIR/bin/vmremove.sh -n $VM_NAME \" "



exit 0

