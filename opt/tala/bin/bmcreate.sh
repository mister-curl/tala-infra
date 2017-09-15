#!/bin/bash
#set -e
set -x 

CMDNAME=$(basename "$0")
CMDOPT=$*

. /opt/tala/bin/common.cfg

FLG_H=
FLG_d=
FLG_U=

#logme

echo "==========================="
echo "CMDNAME : $CMDNAME"
echo "CMD_OPT : $CMDOPT"
echo "==========================="



## root ユーザ以外で実行された場合、スクリプトを終了
if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
	EXIT
fi

## print usage
EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
    exit 1
}

PRINT_USAGE () {
    echo "usage: bash $CMDNAME  [-H hostid ]  [-U username ] [-P md5_password] [-d distribution]  
          -H: host id
          -d: distribution
          -U: user name
          "
    EXIT
}



## オプション値の確認
[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H:d:U: OPT
do
        case ${OPT} in
                "H" ) FLG_H="TRUE" ; readonly HOST_ID="${OPTARG}";;
                "d" ) FLG_d="TRUE" ; readonly DIST_OPTION="${OPTARG}" ;;
                "U" ) FLG_U="TRUE" ; readonly USER_NAME="${OPTARG}" ;;
                \? ) PRINT_USAGE ;; 
        esac
done

if [ "$FLG_H" = "TRUE" ]; then
	echo "HOST_ID : ${HOST_ID} 指定されました。 " 
else
	EXIT
fi
if [ "$FLG_d" = "TRUE" ]; then
	echo "DIST_OPTION : ${DIST_OPTION} 指定されました。 " 
else
	EXIT
fi

if [ "$FLG_U" = "TRUE" ]; then
	echo "USER_NAME : ${USER_NAME} 指定されました。 " 
else
	EXIT
fi


readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

# APIのStatus を構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "構築中" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 



# 対象ホストの情報取得
readonly BM_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .hostname)"
readonly IPMI_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_ip_address)"
readonly IPMI_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_user_name)"
readonly IPMI_PASS="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_password)"

readonly USER_PASS="test"
#readonly USER_PASS="$($CURL $URL_BASE/users/$USER_NAME | jq .)" 

TALA_SERVER=$(grep tala-server /etc/hosts | awk '{print $1}')

## Setting File change
[ -L /tftpboot ] && unlink /tftpboot

ln -s /tftpboot_deploy /tftpboot || EXIT

systemctl reload-or-restart tftpd-hpa.service


## Chenge setting 
SCRIPT="${TALADIR}/bin/live/osinstall.sh"
rm -f ${SCRIPT}
cp -p  ${SCRIPT}{.tpl,}
    case ${DIST_OPTION} in
        "ubuntu1404_x86-64" ) sed -i -e "s/__OS_IMG__/Ubuntu1404_master.img.gz/g" ${SCRIPT} ;;
        "ubuntu1604_x86-64" ) sed -i -e "s/__OS_IMG__/Ubuntu1604_master.img.gz/g" ${SCRIPT} ;;
        "centos6_x86-64" ) sed -i -e "s/__OS_IMG__/CentOS6_master.img.gz/g" ${SCRIPT} ;;
        "centos7_x86-64" ) sed -i -e "s/__OS_IMG__/CentOS7_master.img.gz/g" ${SCRIPT} ;;
        \? ) PRINT_USAGE 
	     ;;
    esac

sed -i -e "s/__USER_NAME__/${USER_NAME}/g" ${SCRIPT}
sed -i -e "s/__USER_PASS__/${USER_PASS}/g" ${SCRIPT}
sed -i -e "s/__BM_NAME__/${BM_NAME}/g" ${SCRIPT}
sed -i -e "s/__TALASERVER__/${TALA_SERVER}/g" ${SCRIPT}


# IPMI setting
sudo ipmitool -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS} chassis bootdev pxe || EXIT
sudo ipmitool -I lanplus -H ${IPMI_IP} -U ${IPMI_NAME} -P ${IPMI_PASS}  power reset || EXIT

# timeout 20minits (7200)
TIME_OUT=7200
TIME=0
rm -f "${TALADIR}/log/${BM_NAME}.log"

while true ;do
    if [ -f ${TALADIR}/log/${BM_NAME}.log ] ;then
        break
    elif [ "$TIME" -gt "${TIME_OUT}" ] ;then
        EXIT 
    fi

    TIME=$(( TIME + 1 ))
    sleep 10
done


set +x
echo "=========OS_INSTALL LOG============="
cat ${TALADIR}/log/${BM_NAME}.log
rm ${TALADIR}/log/${BM_NAME}.log
echo "=========OS_INSTALL LOG============="
set -x

BM_IP=
readonly BM_MAC_LIST="$(awk '/HWaddr/{print $5}' ${TALADIR}/nodes/${HOST_ID}/getinfo/ifconfig-a | tr '[A-Z]' '[a-z]' )"
for mac in ${BM_MAC_LIST[*]} ;do
	if [ "$BM_IP" = "" ] ;then 
		BM_IP=$(grep -E "ethernet|lease" /var/lib/dhcp/dhcpd.leases | grep -B1 $mac |awk '/lease/{print $2}')
	else
		break
	fi
done
${CURL} -H "Content-type: application/json" -d "{ \"ip_address\": \""${BM_IP}"\" }" -X POST ${URL_BASE}/nodes/${HOST_ID}/ip_address/


${CURL} -H "Content-type: application/json" -d '{ "status": "構築完了" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 

echo "script end"
