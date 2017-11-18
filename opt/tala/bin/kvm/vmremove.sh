#!/bin/bash
# FileName: vmremove.sh

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

FLG_N=

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi

## print usage

PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-n guest_machine_name] 
	  -n: vm name"
    exit 1
}

TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"

logme 

## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE


while getopts :n: OPT
do
	case ${OPT} in
		"n" ) FLG_N="TRUE" ; readonly VM_NAME="${OPTARG}" ;;
		\? ) PRINT_USAGE ;; 
	esac
done


VIRSH="/usr/bin/virsh"

SOURCE_DEV=/vm/$VM_NAME

${VIRSH} destroy ${VM_NAME}
${VIRSH} undefine ${VM_NAME} || exit 1
rm -rf $SOURCE_DEV

exit 0

