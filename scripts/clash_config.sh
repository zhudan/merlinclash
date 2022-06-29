#!/bin/sh

source /koolshare/scripts/base.sh
eval `dbus export merlinclash`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
mkdir -p /tmp/upload
LOG_FILE=/tmp/upload/merlinclash_log.txt
SIMLOG_FILE=/tmp/upload/merlinclash_simlog.txt
rm -rf $LOG_FILE
rm -rf $SIMLOG_FILE
echo "" > /tmp/upload/merlinclash_log.txt
echo "" > $SIMLOG_FILE
http_response "$1"

get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}

dbus set merlinclash_dnsmasqplan="overwrite"
mcenable=$(get merlinclash_enable)
mkenable=$(get merlinclash_koolproxy_enable)
dnsmasqplan=$(get merlinclash_dnsmasqplan)
dnsgoclash=$(get merlinclash_dnsgoclash)
prepare(){
	[ -n "`cat /etc/dnsmasq.conf|grep no-resolv`" ] && sed -i '/no-resolv/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep servers-file`" ] && sed -i '/servers-file/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br1`" ] && sed -i '/dhcp-option-force=br1/d' /etc/dnsmasq.conf
	[ -n "`cat /etc/dnsmasq.conf|grep dhcp-option-force=br2`" ] && sed -i '/dhcp-option-force=br2/d' /etc/dnsmasq.conf
	#[ -n "`cat /etc/dnsmasq.conf|grep resolv-file`" ] && sed -i '/resolv-file/d' /etc/dnsmasq.conf
	# compatible with official mod dnsmasq-fastlookup
	#[ -n "`cat /etc/dnsmasq.conf|grep script-arp`" ] && sed -i '/script-arp/d' /etc/dnsmasq.conf
	# compatible with merlin dnsmasq-fastlookup
	#[ -n "`cat /etc/dnsmasq.conf|grep dhcp-name-match`" ] && sed -i '/dhcp-name-match/d' /etc/dnsmasq.conf
}

case $ACTION in
start)
	if [ "$mcenable" == "1" ];then
		if [ "$dnsmasqplan" == "overwrite" ]; then
			[ ! -L "/jffs/scripts/dnsmasq.postconf" ] && ln -sf /koolshare/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq.postconf && echo_date "创建dnsmasq.postconf软链接" >> $LOG_FILE

			sh /koolshare/merlinclash/clashconfig.sh start >> /tmp/upload/merlinclash_log.txt
		else
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig_0101.sh start >> /tmp/upload/merlinclash_log.txt
		fi
	fi
	;;
start_nat)
	if [ "$mcenable" == "1" ];then
		if [ "$dnsmasqplan" == "overwrite" ]; then
			[ ! -L "/jffs/scripts/dnsmasq.postconf" ] && ln -sf /koolshare/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq.postconf && echo_date "创建dnsmasq.postconf软链接" >> $LOG_FILE
			if [ "$dnsgoclash" == "1" ]; then
				sh /koolshare/merlinclash/clashconfig.sh restart >> /tmp/upload/merlinclash_log.txt
			else
				sh /koolshare/merlinclash/clashconfig.sh start_nat >> /tmp/upload/merlinclash_log.txt
			fi
		else
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig_0101.sh start_nat >> /tmp/upload/merlinclash_log.txt
		fi
	fi
	;;
esac

case $2 in
start)
	if [ "$mcenable" == "1" ];then
		echo start >> /tmp/upload/merlinclash_log.txt
		if [ "$dnsmasqplan" == "overwrite" ]; then
			[ ! -L "/jffs/scripts/dnsmasq.postconf" ] && ln -sf /koolshare/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq.postconf && echo_date "创建dnsmasq.postconf软链接" >> $LOG_FILE

			sh /koolshare/merlinclash/clashconfig.sh restart >> /tmp/upload/merlinclash_log.txt
		else
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig_0101.sh restart >> /tmp/upload/merlinclash_log.txt
		fi
	else
		#echo stop >> /tmp/upload/merlinclash_log.txt
		if [ "$dnsmasqplan" == "overwrite" ]; then
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig.sh stop >> /tmp/upload/merlinclash_log.txt
		else
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig_0101.sh stop >> /tmp/upload/merlinclash_log.txt
		fi
	fi

	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	echo BBABBBBC >> $SIMLOG_FILE
	;;
upload)
	#echo upload >> /tmp/upload/merlinclash_log.txt
	sh /koolshare/merlinclash/clashconfig.sh upload
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
update)
	#echo update >> /tmp/upload/merlinclash_log.txt
	sh /koolshare/merlinclash/clash_update_ipdb.sh
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	
	;;
quicklyrestart)
	if [ "$mcenable" == "1" ];then
		echo "快速重启" >> /tmp/upload/merlinclash_log.txt
		if [ "$dnsmasqplan" == "overwrite" ]; then
			[ ! -L "/jffs/scripts/dnsmasq.postconf" ] && ln -sf /koolshare/merlinclash/conf/dnsmasq.postconf /jffs/scripts/dnsmasq.postconf && echo_date "创建dnsmasq.postconf软链接" >> $LOG_FILE
			sh /koolshare/merlinclash/clashconfig.sh quicklyrestart >> /tmp/upload/merlinclash_log.txt
		else
			rm -rf /jffs/scripts/dnsmasq.postconf
			prepare
			sed -i '$a no-resolv' /etc/dnsmasq.conf
			sed -i '$a servers-file=/tmp/resolv.dnsmasq' /etc/dnsmasq.conf
			sh /koolshare/merlinclash/clashconfig_0101.sh quicklyrestart >> /tmp/upload/merlinclash_log.txt
		fi
	else
		echo "请先启用MerlinClash" >> /tmp/upload/merlinclash_log.txt		
	fi
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	echo BBABBBBC >> $SIMLOG_FILE
	;;
iptquicklyrestart)
	if [ "$mcenable" == "1" ];then
		echo "重建iptables" >> /tmp/upload/merlinclash_log.txt
		if [ "$dnsmasqplan" == "overwrite" ]; then
			sh /koolshare/merlinclash/clashconfig.sh start_nat >> /tmp/upload/merlinclash_log.txt
		else
			sh /koolshare/merlinclash/clashconfig_0101.sh start_nat >> /tmp/upload/merlinclash_log.txt
		fi
	else
		echo "请先启用MerlinClash" >> /tmp/upload/merlinclash_log.txt		
	fi
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	echo BBABBBBC >> $SIMLOG_FILE
	;;
dnsmasqrestart)
	sh /koolshare/scripts/clash_dnsmasqrestart.sh >> /tmp/upload/merlinclash_log.txt
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	echo BBABBBBC >> $SIMLOG_FILE
	;;
unblockmusicrestart)
	if [ "$mcenable" == "1" ];then
		echo "网易云音乐解锁快速重启" >> /tmp/upload/merlinclash_log.txt
		sh /koolshare/scripts/clash_unblockneteasemusic.sh restart
	else
		echo "请先启用MerlinClash" >> /tmp/upload/merlinclash_log.txt		
	fi
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
koolproxyrestart)
	if [ "$mcenable" == "1" ] && [ "$mkenable" == "1" ];then
		echo "KoolProxy重启" >> /tmp/upload/merlinclash_log.txt
		sh /koolshare/scripts/clash_koolproxyconfig.sh restart
	else
		if [ "$mcenable" != "1" ]; then
			echo "请先启用MerlinClash" >> /tmp/upload/merlinclash_log.txt	
		fi
		if [ "$mkenable" != "1" ]; then
			echo "请先启用KoolProxy" >> /tmp/upload/merlinclash_log.txt	
		fi	
	fi
	echo BBABBBBC >> /tmp/upload/merlinclash_log.txt
	;;
esac