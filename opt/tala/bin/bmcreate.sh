#!/bin/bash
#set -e
set -x 

CMDNAME=$(basename "$0")
CMDOPT=$*

. /opt/tala/bin/common.cfg

FLG_H=
FLG_d=
FLG_U=
readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

logme

echo "==========================="
echo "CMDNAME : $CMDNAME"
echo "CMD_OPT : $CMDOPT"
echo "==========================="



## root ユーザ以外で実行された場合、スクリプトを終了
if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
	PRINT_USAGE
fi

## print usage
EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
    exit 1
}

PRINT_USAGE () {
    echo "usage: bash $CMDNAME  [-H hostid ]  
          -H: host id
          "
    EXIT
}



## オプション値の確認
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


# bmgetinfo.shが先に実行されていない場合は強制州施用
if [ -d /opt/tala/nodes/${HOST_ID} ] ;then
   echo "bmgetinfo.sh が実行されていることを確認しました"
else
   echo "bmgetinfo.shを事前に実行してください"
   exit 1
fi
    




# APIのStatus を構築中に変更
${CURL} -H "Content-type: application/json" -d '{ "status": "BM構築中" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 
${CURL} -H "Content-type: application/json" -d '{ "type": "" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/type/ 



# 対象ホストの情報取得
readonly BM_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .hostname)"
readonly IPMI_IP="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_ip_address)"
readonly IPMI_NAME="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_user_name)"
readonly IPMI_PASS="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .ipmi_password)"
readonly VNC_PORT="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .vnc_port)"
readonly DIST_OPTION="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .os)"
readonly USER_PASS="$(${CURL} ${URL_BASE}/nodes/${HOST_ID}/ | ${JQ} .password)"
TALA_SERVER=$(grep tala-server /etc/hosts | awk '{print $1}')

## Setting File change
BM_IP=
readonly BM_MAC_LIST="$(awk '/HWaddr/{print $5}' ${TALADIR}/nodes/${HOST_ID}/getinfo/ifconfig-a | tr '[A-Z]' '[a-z]' )"
for mactpl in ${BM_MAC_LIST[*]} ;do
	# making tftpconfig
	mac=$(echo "01-${mactpl}" | tr ":" "-")
	cp -p /tftpboot/pxelinux.cfg/mac_tpl /tftpboot/pxelinux.cfg/${mac}

	## making scripts
	TPL_SCRIPT="${TALADIR}/bin/live/osinstall.sh.tpl"
	SCRIPT="${TALADIR}/bin/live/tmp/${mac}.sh"
	cp -p ${TPL_SCRIPT} ${SCRIPT}
        case ${DIST_OPTION} in
                "ubuntu1404_x86-64" ) sed -i -e "s/__OS_IMG__/Ubuntu1404_master.img.gz/g" ${SCRIPT} ;;
                "ubuntu1604_x86-64" ) sed -i -e "s/__OS_IMG__/Ubuntu1604_master.img.gz/g" ${SCRIPT} ;;
                "centos6_x86-64" ) sed -i -e "s/__OS_IMG__/CentOS6_master.img.gz/g" ${SCRIPT} ;;
                "centos7_x86-64" ) sed -i -e "s/__OS_IMG__/CentOS7_master.img.gz/g" ${SCRIPT} ;;
                 \? ) PRINT_USAGE 
		     ;;
	    esac

	sed -i -e "s/__USER_PASS__/${USER_PASS}/g" ${SCRIPT}
	sed -i -e "s/__BM_NAME__/${BM_NAME}/g" ${SCRIPT}
	sed -i -e "s/__TALASERVER__/${TALA_SERVER}/g" ${SCRIPT}
	sed -i -e "s/__VNC_PORT__/${VNC_PORT}/g" ${SCRIPT}

done

systemctl reload-or-restart tftpd-hpa.service

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

    TIME=$(( TIME + 10 ))
    sleep 10
done


set +x
echo "=========OS_INSTALL LOG START============="
cat ${TALADIR}/log/${BM_NAME}.log
rm ${TALADIR}/log/${BM_NAME}.log
echo "=========OS_INSTALL LOG END============="
set -x

BM_IP=
for mac in ${BM_MAC_LIST[*]} ;do
	# BMで利用するIPの返却
	if [ "$BM_IP" = "" ] ;then 
		BM_IP=$(grep -E "ethernet|lease" /var/lib/dhcp/dhcpd.leases | grep -B1 $mac |awk '/lease/{print $2}'|tail -1)
${CURL} -H "Content-type: application/json" -d "{ \"ip_address\": \""${BM_IP}"\" }" -X POST ${URL_BASE}/nodes/${HOST_ID}/ip_address/
${CURL} -H "Content-type: application/json" -d "{ \"mac_address\": \""${mac}"\" }" -X POST ${URL_BASE}/nodes/${HOST_ID}/mac_address/
	else
		break
	fi
done
${CURL} -H "Content-type: application/json" -d '{ "status": "BM構築完了" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/status/ 

for mactpl in ${BM_MAC_LIST[*]} ;do
	# BM対象の一時利用スクリプトの削除
	mac=$(echo "01-${mactpl}" | tr ":" "-")
	 rm -f  ${SCRIPT}
	rm -f  /tftpboot/pxelinux.cfg/${mac}
done

# zabix
bash /opt/tala/bin/zabbixapi.sh -H ${HOST_ID} -n $BM_NAME -i $BM_IP -m ${BM_MAC_LIST[0]}


${CURL} -H "Content-type: application/json" -d '{ "type": "BeraMetal" }' -X POST ${URL_BASE}/nodes/${HOST_ID}/type/ 
echo "script end"
