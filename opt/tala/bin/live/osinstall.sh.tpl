#!/bin/bash

set -x

CMDNAME=$(basename "$0")
CMDOPT=$*

logme () {
    exec </dev/null
    exec >${LOGDIR}/${CMDNAME}_${DATE}.log
    exec 2>&1
renice +20 -p $$
}

DATE=$(date +%Y%m%d-%H%M%S)

TALADIR="/opt/tala"
LOGDIR="${TALADIR}/log/"
BINDIR="${TALADIR}/bin/"
mkdir -p ${LOGDIR}
mkdir -p ${BINDIR}


logme


OS_IMG=__OS_IMG__
USER_PASS_ORG=__USER_PASS__
BM_NAME=__BM_NAME__
TALA_SERVER=__TALASERVER__
VNC_PORT=__VNC_PORT__

#USER_PASS=$(python -c 'import crypt; print crypt.crypt("$USER_PASS_ORG", "a2")')
USER_PASS=$(sh -c "python -c 'import crypt; print crypt.crypt(\"$USER_PASS_ORG\", \"a2\")'")


XFSDUMP=xfsdump-3.0.4-4.el6_6.1.x86_64.rpm
XFSPROGS=xfsprogs-3.1.1-20.el6.x86_64.rpm
GDIKS=gdisk-0.8.10-1.el6.x86_64.rpm
curl ${TALA_SERVER}/${XFSDUMP} -o ${XFSDUMP}
curl ${TALA_SERVER}/${XFSPROGS} -o ${XFSPROGS}
curl ${TALA_SERVER}/${GDIKS} -o ${GDIKS}
rpm -ivh $XFSDUMP $XFSPROGS $GDIKS

#dd if=/dev/zero of=/dev/sda bs=8M oflag=direct
ssh ${TALA_SERVER} dd if=/opt/tala/web/images/${OS_IMG} | gzip -dc | dd of=/dev/sda


if [ "$OS_IMG" = "CentOS7_master.img.gz" ] ;then

	gdisk /dev/sda <<-EOF
	p
	x
	e
	m
        
	d
	4
        
	n
	4
        
        
	0700
        
	p
	w
	y
	EOF
	
	MOUNTPOINT="/mnt/"
	kpartx -a /dev/sda
	mount -t xfs /dev/mapper/sda4  ${MOUNTPOINT}
	    xfs_growfs ${MOUNTPOINT}
	    echo "${BM_NAME}" >  ${MOUNTPOINT}/etc/hostname
	umount ${MOUNTPOINT}
	kpartx -d /dev/sda

elif [ "$OS_IMG" = "Ubuntu1404_master.img.gz" ] ;then

	gdisk /dev/sda <<-EOF
	p
	x
	e
	m
        
	d
	3
        
	n
	3
        
        
	0700
        
	p
	w
	y
	EOF

	MOUNTPOINT="/mnt/"
	kpartx -a /dev/sda
	mount /dev/mapper/sda3  ${MOUNTPOINT}
	    tune2fs -c -1 -i 0 "/dev/mapper/sda3"
	    resize2fs "/dev/mapper/sda3"
            chroot "${MOUNTPOINT}" useradd "admin" -s /bin/bash -g 0 
	    echo "${BM_NAME}" >  ${MOUNTPOINT}/etc/hostname
	    echo "CREATE_HOME=yes" >> ${MOUNTPOINT}//etc/login.defs

		cat <<- EOF > ${MOUNTPOINT}/etc/rc.local	    
			#!/bin/sh -e
			update-grub2
			sed -i -e "/update-grub2/d" /etc/rc.local
			exit 0
		EOF
	    mkdir -p ${MOUNTPOINT}/root/.ssh/
	    mkdir -p ${MOUNTPOINT}/home/admin/.ssh/
	    chroot "${MOUNTPOINT}" chown admin.  /home/admin/.ssh/

	    scp ${TALA_SERVER}:/home/admin/.ssh/id_rsa.pub ${MOUNTPOINT}/home/admin/.ssh/authorized_keys


	echo "admin ALL=(ALL:ALL) NOPASSWD:ALL" >> ${MOUNTPOINT}/etc/sudoers

	mkdir -p ${MOUNTPOINT}${LOGDIR}
	mkdir -p ${MOUNTPOINT}${BINDIR}
	chroot "${MOUNTPOINT}" chown -R admin. ${TALADIR}

	umount ${MOUNTPOINT}
	kpartx -d /dev/sda

	#xfs_repair /dev/sda

elif [ "$OS_IMG" = "Ubuntu1604_master.img.gz" ] ;then

	gdisk /dev/sda <<-EOF
	p
	x
	e
	m
        
	d
	3
        
	n
	3
        
        
	0700
        
	p
	w
	y
	EOF

	MOUNTPOINT="/mnt/"
	kpartx -a /dev/sda
	mount /dev/mapper/sda3  ${MOUNTPOINT}
	    tune2fs -c -1 -i 0 "/dev/mapper/sda3"
	    resize2fs "/dev/mapper/sda3"
	    chroot "${MOUNTPOINT}" systemctl enable sshd
	    echo "${BM_NAME}" >  ${MOUNTPOINT}/etc/hostname
	    echo "CREATE_HOME=yes" >> ${MOUNTPOINT}//etc/login.defs

            chroot "${MOUNTPOINT}" useradd "admin" -s /bin/bash -g 0 

	    mkdir -p ${MOUNTPOINT}/root/.ssh/
	    mkdir -p ${MOUNTPOINT}/home/admin/.ssh/
	    chroot  "${MOUNTPOINT}" chown admin.  /home/admin/.ssh/


	    scp ${TALA_SERVER}:/home/admin/.ssh/id_rsa.pub ${MOUNTPOINT}/home/admin/.ssh/authorized_keys

	echo "admin ALL=(ALL:ALL) NOPASSWD:ALL" >> ${MOUNTPOINT}/etc/sudoers

	mkdir -p ${MOUNTPOINT}${LOGDIR}
	mkdir -p ${MOUNTPOINT}${BINDIR}
	chroot "${MOUNTPOINT}" chown -R admin. ${TALADIR}

	cat <<- EOL > "${MOUNTPOINT}/opt/tala/bin/vncinit.sh" 
	#!/bin/sh
	set -x
	USER=root
	HOME=/root
	export USER HOME

	apt update	
	apt install -y vnc4server
	
	sed -i "s/vncPort = 5900 + \\\$displayNumber/vncPort = ${VNC_PORT}/" /usr/bin/vnc4server
	
	vnc4server -SecurityTypes None <<-EOF
	  password
	  password
	EOF
	
	iptables -I INPUT 2 -m state --state NEW -m tcp -p tcp --dport ${VNC_PORT} -j ACCEPT
	iptables-save > /etc/iptables/iptables.rules
	
	echo "vnc4server -SecurityTypes None" >> /etc/rc.local
	sed -i "/vncinit.sh/d" /etc/rc.local
	
	EOL

	sed -i "/exit 0/d" ${MOUNTPOINT}/etc/rc.local
	echo "bash /opt/tala/bin/vncinit.sh" >> ${MOUNTPOINT}/etc/rc.local


	cd ${MOUNTPOINT}
	wget http://repo.zabbix.com/zabbix/3.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.0-1+trusty_all.deb
	rm -f ${MOUNTPOINT}/etc/resolv.conf
        echo 'nameserver 8.8.4.4' > ${MOUNTPOINT}/etc/resolv.conf
	chroot ${MOUNTPOINT} dpkg -i /zabbix-release_3.0-1+trusty_all.deb
	chroot ${MOUNTPOINT} apt-get update

	chroot ${MOUNTPOINT} apt install zabbix-agent -y 
	sed -i "s/127.0.0.1/192.168.25.3/g" ${MOUNTPOINT}/etc/zabbix/zabbix_agentd.conf
	chroot ${MOUNTPOINT} systemctl enable zabbix-agent
	sed -i 7i"-A INPUT -p tcp -m state --state NEW -m tcp --dport 10050 -j ACCEPT" /etc/iptables/iptables.rules

	umount ${MOUNTPOINT}
	kpartx -d /dev/sda

	#xfs_repair /dev/sda

fi


ipmitool chassis bootdev disk options=persistent

date

scp ${LOGDIR}/${CMDNAME}_${DATE}.log ${TALA_SERVER}:/opt/tala/log/${BM_NAME}.log

sleep 30
reboot
