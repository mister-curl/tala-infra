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
FLG_N=
FLG_C=
FLG_M=
FLG_D=
FLG_O=
FLG_R=
FLG_B=

if [ "$(id -u)" -ne 0 ];then
	echo 'This script is supposed to run under root.'
	exit 1
fi

## print usage
EXIT () {
    ${CURL} -H "Content-type: application/json" -d '{ "status": "インストール失敗" }' -X POST ${URL_BASE}/vms/${HOST_ID}/status/
    exit 1
}

PRINT_USAGE () {
    echo "usage: bash $CMDNAME [-n guest_machine_name] [-c cpu_core] [-m vm_memory_size] [-d vm_hdd_size] [-p md5_password] [-o distribution] [-r] 
          -H: HostID(vm id)
	  -n: vm name
	  -c: vm cpu core
	  -m: vm memomy size (MByte)
	  -d: vm hdd size (GByte)
	  -p: root password
	  -o: os distribution 
	  -r: reinstall vm.
	  "
    EXIT
}


TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"
IMG_DIR="${TALADIR}/web/images"

logme

echo $CMDNAME
echo $CMDOPT


mk_ubuntu1404() {
	ddrescue "/${IMG_DIR}/${VM_OS}_master.img" "${SOURCE_DEV}" -q --block-size=4096 --force || PRINT_USAGE
	sync

	## fix disk partition
	gdisk "${SOURCE_DEV}" <<-EOF
	p
	x
	e
	m

	d
	3

	n
	3


	8300

	p
	w
	y
	EOF


	## 設定ファイル修正
	MOUNTPOINT=$(mktemp -d) || PRINT_USAGE
	${KPARTX} -a "${SOURCE_DEV}"
	sync
	sleep 4
	mount "/dev/mapper/loop1p3" "${MOUNTPOINT}" 
	tune2fs -c -1 -i 0 "/dev/mapper/${VG_NAME}-${LV_VOL}p3"
	resize2fs "/dev/mapper/${VG_NAME}-${LV_VOL}p3"

	# hostname
	echo "${VM_NAME%%.*}" > "${MOUNTPOINT}"/etc/hostname
	sed -i -e "s/ubuntu.localdomain/${VM_NAME}/" "${MOUNTPOINT}"/etc/hosts
	sed -i -e "s/ubuntu/${VM_NAME%%.*}/" "${MOUNTPOINT}"/etc/hosts


	rm -rf "${MOUNTPOINT}"/root/anaconda-ks.cfg
	rm -rf "${MOUNTPOINT}"/root/install.log
	rm -rf "${MOUNTPOINT}"/root/install.log.syslog
	rm -rf "${MOUNTPOINT}"/root/.lesshst

	rm -rf "${MOUNTPOINT}"/var/lib/dhclient/*
	rm -rf "${MOUNTPOINT}"/etc/dhcp/dhclient-eth0.conf
	rm -rf "${MOUNTPOINT}"/tmp/*
	rm -rf "${MOUNTPOINT}"/tmp/.[A-z]*
	rm -rf "${MOUNTPOINT}"/var/log/btmp
	rm -rf "${MOUNTPOINT}"/var/log/wtmp
	rm -rf "${MOUNTPOINT}"/etc/ssh/ssh_host_*

	touch "${MOUNTPOINT}"/var/log/wtmp
	touch "${MOUNTPOINT}"/var/log/faillog
	touch "${MOUNTPOINT}"/var/log/lastlog

	# パスワード設定
	chroot "${MOUNTPOINT}" usermod -p "${VM_PASS}" ubuntu

	# adminユーザ作成
        echo "CREATE_HOME yes" >> ${MOUNTPOINT}/etc/login.defs 
        chroot "${MOUNTPOINT}" useradd "admin" -s /bin/bash -g 0 
	mkdir ${MOUNTPOINT}/home/admin/.ssh
	cp /home/admin/.ssh/authorized_keys ${MOUNTPOINT}/home/admin/.ssh/authorized_keys
	chroot "${MOUNTPOINT}" usermod -p "${VM_PASS}" admin

	# 初回起動時にsshの鍵を作成しなおす
	sed -i -e "/exit 0/d" "${MOUNTPOINT}/etc/rc.local"
	cat <<-'EOF' >> ${MOUNTPOINT}/etc/rc.local
	test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
	sed -i -e "/dpkg-reconfigure/d" /etc/rc.local
	exit 0
	EOF
	chmod 751 ${MOUNTPOINT}/etc/rc.local


	# mkfs
	FSTAB="${MOUNTPOINT}/etc/fstab"
	BLKID_SWAP=$(/sbin/blkid -o value -s UUID "/dev/mapper/${VG_NAME}-${LV_VOL}p2") || PRINT_USAGE
	BLKID_ROOT=$(/sbin/blkid -o value -s UUID "/dev/mapper/${VG_NAME}-${LV_VOL}p3") || PRINT_USAGE

	OLDSWAPID=$(grep -v ^# "${FSTAB}" | awk '$3=="swap" {print $1}')
	OLDROOTID=$(grep -v ^# "${FSTAB}" | awk '$2=="/" {print $1}')

	sed -i 's/'${OLDROOTID}'/UUID='${BLKID_ROOT}'/' "${FSTAB}"
	sed -i 's/'${OLDSWAPID}'/UUID='${BLKID_SWAP}'/' "${FSTAB}"

	# 後始末
	cd || PRINT_USAGE
	umount -l "${MOUNTPOINT}" || PRINT_USAGE

	${KPARTX} -d "${SOURCE_DEV}"
	rmdir "${MOUNTPOINT}"

}

mk_ubuntu1604() {

	IMAGE="/opt/tala/images/Ubuntu1604_master.img"
        if [ ! -f $IMAGE ] ;then 
		curl 192.168.25.3/images/Ubuntu1604_master.img.gz -o $IMAGE.gz
		gunzip $IMAGE.gz 
	fi
	ddrescue "$IMAGE" "${SOURCE_DEV}" -q --force || PRINT_USAGE
	sync

	## fix disk partition
	gdisk "${SOURCE_DEV}" <<-EOF
	p
	x
	e
	m

	d
	3

	n
	3


	8300

	p
	w
	y
	EOF


	## 設定ファイル修正
	MOUNTPOINT=$(mktemp -d) || PRINT_USAGE
	${KPARTX} -a "${SOURCE_DEV}"
	sync
	sleep 2
	mount "/dev/mapper/loop0p3" "${MOUNTPOINT}" || PRINT_USAGE
	tune2fs -c -1 -i 0 "/dev/mapper/loop0p3"
	resize2fs "/dev/mapper/loop0p3"

	# hostname
	echo "${VM_NAME%%.*}" > "${MOUNTPOINT}"/etc/hostname
	sed -i -e "s/ubuntu.localdomain/${VM_NAME}/" "${MOUNTPOINT}"/etc/hosts
	sed -i -e "s/ubuntu/${VM_NAME%%.*}/" "${MOUNTPOINT}"/etc/hosts


	# 不要ファイル削除
	rm -rf "${MOUNTPOINT}"/root/anaconda-ks.cfg
	rm -rf "${MOUNTPOINT}"/root/install.log
	rm -rf "${MOUNTPOINT}"/root/install.log.syslog
	rm -rf "${MOUNTPOINT}"/root/.lesshst

	rm -rf "${MOUNTPOINT}"/var/lib/dhclient/*
	rm -rf "${MOUNTPOINT}"/etc/dhcp/dhclient-eth0.conf
	rm -rf "${MOUNTPOINT}"/tmp/*
	rm -rf "${MOUNTPOINT}"/tmp/.[A-z]*
	rm -rf "${MOUNTPOINT}"/var/log/btmp
	rm -rf "${MOUNTPOINT}"/var/log/wtmp
	rm -rf "${MOUNTPOINT}"/etc/ssh/ssh_host_*

	touch "${MOUNTPOINT}"/var/log/wtmp
	touch "${MOUNTPOINT}"/var/log/faillog
	touch "${MOUNTPOINT}"/var/log/lastlog


	# パスワード設定
	chroot "${MOUNTPOINT}" usermod -p "${VM_PASS}" ubuntu
	
	# adminユーザ作成
        echo "CREATE_HOME yes" >> ${MOUNTPOINT}/etc/login.defs 
        chroot "${MOUNTPOINT}" useradd "admin" -s /bin/bash -g 0 
	mkdir ${MOUNTPOINT}/home/admin/.ssh
	cp /home/admin/.ssh/authorized_keys ${MOUNTPOINT}/home/admin/.ssh/authorized_keys
	chroot "${MOUNTPOINT}" usermod -p "${VM_PASS}" admin



	# 初回起動時にsshの鍵を作成しなおす
	sed -i -e "/exit 0/d" "${MOUNTPOINT}/etc/rc.local"
	cat <<-'EOF' >> ${MOUNTPOINT}/etc/rc.local
	test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
	sed -i -e "/dpkg-reconfigure/d" /etc/rc.local
	exit 0
	EOF
	chmod 751 ${MOUNTPOINT}/etc/rc.local


	# mkfs
	FSTAB="${MOUNTPOINT}/etc/fstab"
	BLKID_SWAP=$(/sbin/blkid -o value -s UUID "/dev/mapper/loop0p2") || PRINT_USAGE
	BLKID_ROOT=$(/sbin/blkid -o value -s UUID "/dev/mapper/loop0p3") || PRINT_USAGE

	OLDSWAPID=$(grep -v ^# "${FSTAB}" | awk '$3=="swap" {print $1}')
	OLDROOTID=$(grep -v ^# "${FSTAB}" | awk '$2=="/" {print $1}')

	sed -i 's/'${OLDROOTID}'/UUID='${BLKID_ROOT}'/' "${FSTAB}"
	sed -i 's/'${OLDSWAPID}'/UUID='${BLKID_SWAP}'/' "${FSTAB}"


        cd ${MOUNTPOINT}
        wget http://repo.zabbix.com/zabbix/3.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.0-1+trusty_all.deb
        rm -f ${MOUNTPOINT}/etc/resolv.conf
        echo 'nameserver 8.8.4.4' > ${MOUNTPOINT}/etc/resolv.conf
        chroot ${MOUNTPOINT} dpkg -i /zabbix-release_3.0-1+trusty_all.deb
        chroot ${MOUNTPOINT} apt-get update

        chroot ${MOUNTPOINT} apt install zabbix-agent -y
        sed -i "s/127.0.0.1/192.168.25.3/g" ${MOUNTPOINT}/etc/zabbix/zabbix_agentd.conf
        chroot ${MOUNTPOINT} systemctl enable zabbix-agent
        sed -i 2i"-A INPUT -p tcp -m state --state NEW -m tcp --dport 10050 -j ACCEPT" ${MOUNTPOINT} /etc/iptables/iptables.rules

        umount ${MOUNTPOINT}	

	# 後始末
	cd || PRINT_USAGE
	umount -l "${MOUNTPOINT}" || PRINT_USAGE

	${KPARTX} -d "${SOURCE_DEV}"
	rmdir "${MOUNTPOINT}"

}


## オプション値の確認
## 必要なオプションが空の場合、および不正なオプションがあった場合はスクリプトを終了

[ "$#" -ge 1 ] || PRINT_USAGE


while getopts H:n:c:m:d:p:o:r OPT
do
	case ${OPT} in
		"H" ) FLG_H="TRUE" ; readonly VM_ID="${OPTARG}" ;;
		"n" ) FLG_N="TRUE" ; readonly VM_NAME="${OPTARG}" ;;
		"c" ) FLG_C="TRUE" ; readonly VM_CORE="${OPTARG}" ;;
		"m" ) FLG_M="TRUE" ; readonly VM_MEMSIZE_MB="${OPTARG}" ;;
		"d" ) FLG_D="TRUE" ; readonly VM_DISKSIZE_GB="${OPTARG}" ;;
		"o" ) FLG_O="TRUE" ; readonly VM_OS_OPTION="${OPTARG}" ;;
		"p" ) FLG_P="TRUE" ; readonly USER_PASS="${OPTARG}" ;;
		"r" ) FLG_R="TRUE" ;;
		\? ) PRINT_USAGE ;; 
	esac
done

VM_DISKSIZE_MB=$((VM_DISKSIZE_GB * 1024))
VM_MEMSIZE_KB=$((VM_MEMSIZE_MB * 1024))
VM_PASS=$(sh -c "python -c 'import crypt; print crypt.crypt(\"$USER_PASS\", \"a2\")'")

VIRSH="/usr/bin/virsh"
KPARTX="/sbin/kpartx"
BRCTL="/sbin/brctl"
IFCONFIG="/sbin/ifconfig"

## VM_IDが指定されて無い場合は処理を停止する。
if [ "$FLG_H" = "TRUE" ]; then
	echo "VM_ID : ${VM_ID} 指定されました。 " 
else
	PRINT_USAGE
fi

## VMが指定されて無い場合は処理を停止する。
if [ "$FLG_N" = "TRUE" ]; then
	echo "VM_NAME : ${VM_NAME} 指定されました。 " 
else
	PRINT_USAGE
fi

## CPU COREが指定されて無い場合は処理を停止する。

if [ "$FLG_C" = "TRUE" ]; then
	echo "VM_CORE : ${VM_CORE} 指定されました。 " 
else
	PRINT_USAGE
fi

## MEMORY SIZEが指定されて無い場合は処理を停止する。
if [ "$FLG_M" = "TRUE" ]; then
	echo "VM_MEMSIZE_MB : ${VM_MEMSIZE_MB} 指定されました。 " 
else
	PRINT_USAGE
fi

## DISK SIZEが指定されて無い場合は処理を停止する。
if [ "$FLG_D" = "TRUE" ]; then
	echo "VM_DISKSIZE_GB : ${VM_DISKSIZE_GB} 指定されました。 " 
else
	PRINT_USAGE
fi

## OSが指定されて無い場合は処理を停止する。
if [ "$FLG_O" = "TRUE" ]; then
	echo "VM_OS_OPTION : ${VM_OS_OPTION} 指定されました。 " 
else
	PRINT_USAGE
fi

## パスワードが指定されて無い場合は処理を停止する。
if [ "$FLG_P" = "TRUE" ]; then
	echo "VM_PASS : ${VM_PASS}"
else
	PRINT_USAGE
fi



## VM 領域作成
[ -d /vm ] ||  mkdir /vm
SOURCE_DEV=/vm/$VM_NAME
fallocate -l ${VM_DISKSIZE_MB}MB ${SOURCE_DEV}  

# OS install
case $VM_OS_OPTION in
  ubuntu1404_x86-64)
    mk_ubuntu1404
    ;;
  ubuntu1604_x86-64)
    mk_ubuntu1604
    ;;
  *)
    echo "指定のディストリビューションは存在しません。"
    PRINT_USAGE
    ;;
esac
 

## virsh define
TMPXML="/opt/tala/bin/libvirtxml.tpl"

IF_LIST=($(ifconfig -a | grep Ethernet| grep -v vn | grep -v br | awk '{print $1}' ))
BRIDGE0="br0"

if $BRCTL show | grep -q $BRIDGE0 /dev/null 2>&1  ;then
:
else
    $BRCTL addbr $BRIDGE0
fi 

$BRCTL addif $BRIDGE0 ${IF_LIST[0]}
$IFCONFIG $BRIDGE0 up

VM_VNC="$(echo "${VM_ID} + 10000" | bc)"
VMNIC0="vn${VM_ID}-0"
VM_MACBASE0=$(echo "obase=16 ; ibase=10 ; ${VM_ID} + 100000" | bc)
VMMAC0=$(printf 9C:A3:BA:0 ; echo "${VM_MACBASE0}" | perl -ne '1 while $_ =~ s/(.*\w)(\w{2})/$1:$2/; print;')

IFS=':'; set $VMMAC0; unset IFS
LINK_LOCAL="fe80::$(printf %02x $((0x$1 ^ 2)))$2:${3}ff:fe$4:$5$6"

sed -e "s@__VM_NAME__@${VM_NAME}@" \
    -e "s@__VM_CORE__@${VM_CORE}@" \
    -e "s@__VM_NUM__@${VM_ID}@" \
    -e "s@__VM_MEMSIZE__@${VM_MEMSIZE_KB}@" \
    -e "s@__VM_DISKPATH__@${SOURCE_DEV}@" \
    -e "s@__BRIDGE0__@${BRIDGE0}@" \
    -e "s@__VM_NIC0__@${VMNIC0}@" \
    -e "s@__VM_MAC0__@${VMMAC0}@" \
    -e "s@__VM_VNC__@${VM_VNC}@" \
    ${TMPXML} > /etc/libvirt/qemu/"${VM_NAME}".xml


${VIRSH} define "/etc/libvirt/qemu/${VM_NAME}.xml" || PRINT_USAGE


## finish create

$VIRSH autostart ${VM_NAME}

$VIRSH start ${VM_NAME}
echo "vm create and start successfully"

sleep 20


IPTABLES="/sbin/iptables"
IPTABLES_SAVE="/sbin/iptables-save"
$IPTABLES -I INPUT 2 -m state --state NEW -m tcp -p tcp --dport ${VM_VNC} -j ACCEPT
$IPTABLES_SAVE > /etc/iptables/iptables.rules
readonly CURL="/usr/bin/curl -s"
readonly JQ="/usr/bin/jq -r"
readonly URL_BASE="http://59.106.215.39:8000/tala/api/v1"

${CURL} -H "Content-type: application/json" -d "{ \"mac_address\": \""${VMMAC0}"\" }" -X POST ${URL_BASE}/vms/${VM_ID}/mac_address/

exit 0

