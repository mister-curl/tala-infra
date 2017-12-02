#!/bin/bash
TALA_SERVER="192.168.25.3"
TALADIR="/opt/tala/"

#readonly BM_MAC_LIST="$(ifconfig -a | awk '/HWaddr/{print $5}' | tr '[A-Z]' '[a-z]' )"
#for mactpl in ${BM_MAC_LIST[*]} ;do
#	mac=$(echo "01-${mactpl}" | tr ":" "-")
#	SCRIPT="${TALADIR}/bin/live/tmp/${mac}.sh"
#	scp -o 'StrictHostKeyChecking no' ${TALA_SERVER}:${SCRIPT} /root/${mac}.sh && ( bash /root/${mac}.sh && exit 0 )
#done


readonly BM_MAC_LIST=($(ifconfig -a | awk '/HWaddr/{print $5}' | tr '[A-Z]' '[a-z]' ))
mac=$(echo "01-${BM_MAC_LIST[0]}" | tr ":" "-")
SCRIPT="${TALADIR}/bin/live/tmp/${mac}.sh"
scp -o 'StrictHostKeyChecking no' ${TALA_SERVER}:${SCRIPT} /root/${mac}.sh && ( bash /root/${mac}.sh && exit 0 )
