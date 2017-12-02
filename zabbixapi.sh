#!/bin/bash

#set -x 

URL='http://localhost/zabbix/api_jsonrpc.php '
ZABBIX_USER=admin
ZABBIX_PASSWORD=zabbix

. /opt/tala/bin/common.cfg

FLG_H=
FLG_d=
FLG_U=
readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

logme () {
    exec </dev/null
    exec >$LOGDIR/$CMDNAME.$(date +%Y%m%d-%H%M%S).$$.log
    exec 2>&1
renice +20 -p $$
}

CMDNAME=$(basename "$0")
CMDOPT=$*



if [ "$(id -u)" -ne 0 ];then
        echo 'This script is supposed to run under root.'
        exit 1
fi



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
    exit 1
}


## print usage
PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-H HostID]
          -H: HostID(container id)
          -n: Hostname
          -i: IP
          -m: mac"
    EXIT
}

create_token() {
  PARAMS=$(cat << EOS
      {
          "jsonrpc": "2.0",
          "method": "user.login",
          "params": {
              "user": "${ZABBIX_USER}",
              "password": "${ZABBIX_PASSWORD}"
          },
          "id": 1
      }
EOS
  )

  curl -s -H 'Content-Type:application/json-rpc'  ${URL}       -d "${PARAMS}" | /usr/bin/jq -r '.result'
  #curl -s -H 'Content-Type:application/json-rpc'  ${URL}  -d "${PARAMS}"
}


create_host() {
  PARAMS=$(cat << EOS
    {
        "jsonrpc": "2.0",
        "method": "host.create",
        "params": {
            "host": "$HOST_NAME",
            "interfaces": [
                {
                    "type": 1,
                    "main": 1,
                    "useip": 1,
                    "ip": "$IP",
                    "dns": "",
                    "port": "10050"
                }
            ],
            "groups": [
                {
                    "groupid": "2"
                }
            ],
            "templates": [
                {
                    "templateid": "10001"
                }
            ],
            "inventory_mode": 0,
            "inventory": {
                "macaddress_a": "$MAC"
            }
        },
        "id": 1,
        "auth": "$TOKEN"
    }
EOS
  )
  curl -s -H 'Content-Type:application/json-rpc'  ${URL}       -d "${PARAMS}"
}


add_template(){


:
}




## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE

while getopts :H:n:i:m: OPT
do
        case ${OPT} in
                "H" ) FLG_H="TRUE" ; readonly ID="${OPTARG}" ;;
                "n" ) FLG_n="TRUE" ; readonly HOST_NAME="${OPTARG}" ;;
                "i" ) FLG_i="TRUE" ; readonly IP="${OPTARG}" ;;
                "m" ) FLG_m="TRUE" ; readonly MAC="${OPTARG}" ;;
                \? ) PRINT_USAGE ;;
        esac
done

if [ "$FLG_H" = "TRUE" ]; then
        echo "CON_ID : ${CON_ID} 指定されました。 "
else
        PRINT_USAGE
fi


TOKEN=$(create_token)
#echo $TOKEN
create_host
