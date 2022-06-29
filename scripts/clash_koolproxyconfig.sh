#! /bin/sh

# shadowsocks script for HND router with kernel 4.1.27 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
eval `dbus export merlinclash`
SOFT_DIR=/koolshare
KP_DIR=$SOFT_DIR/merlinclash/koolproxy
lan_ipaddr=$(nvram get lan_ipaddr)
LOCK_FILE=/var/lock/koolproxy.lock
LOG_FILE=/tmp/upload/merlinclash_log.txt

OS=$(uname -r)
#=======================================

set_lock(){
	exec 1000>"$LOCK_FILE"
	flock -x 1000
}

unset_lock(){
	flock -u 1000
	rm -rf "$LOCK_FILE"
}
urldecode(){
  echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x\1/g;')"
}
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
b(){
	if [ -f "/bin/base64" ]; then #HND是这个
		base=base64
		echo $base
	elif [ -f "/koolshare/bin/base64_decode" ]; then #HND有这个
		base=base64_decode
		echo $base
	elif [ -f "/koolshare/bin/base64" ]; then #网件R7K是这个
		base=base64
		echo $base
	elif [ -f "/sbin/base64" ]; then
		base=base64
		echo $base
	else
		echo_date "【错误】固件缺少base64decode文件，无法正常订阅，直接退出" >> $LOG_FILE
		echo_date "解决办法请查看MerlinClash Wiki" >> $LOG_FILE
		echo BBABBBBC >> $LOG_FILE
		exit 1
	fi
}

decode_url_link(){
	local link=$1
	local len=$(echo $link | wc -L)
	local mod4=$(($len%4))
	b64=$(b)
	echo_date "b64=$b64" >> LOG_FILE
	if [ "$mod4" -gt "0" ]; then
		local var="===="
		local newlink=${link}${var:$mod4}
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | $b64 -d 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | $b64 -d 2>/dev/null
	fi
}
get_lan_cidr(){
	netmask=`nvram get lan_netmask`
	local x=${netmask##*255.}
	set -- 0^^^128^192^224^240^248^252^254^ $(( (${#netmask} - ${#x})*2 )) ${x%%.*}
	x=${1%%$3*}
	suffix=$(( $2 + (${#x}/4) ))
	#prefix=`nvram get lan_ipaddr | cut -d "." -f1,2,3`
	echo $lan_ipaddr/$suffix
}

mks=$(get merlinclash_koolproxy_sourcelist)
mkm=$(get merlinclash_koolproxy_mode)
mkad=$(get merlinclash_koolproxy_acl_default)

write_sourcelist(){
	if [ -n "$mks" ];then
		echo $mks|sed 's/>/\n/g' > $KP_DIR/data/source.list
	else
		cat > $KP_DIR/data/source.list <<-EOF
			1|koolproxy.txt|http://router.houzi-blog.top:3090/koolproxy.txt|
			1|daily.txt|http://router.houzi-blog.top:3090/daily.txt|
			1|kp.dat|http://router.houzi-blog.top:3090/kp.dat|
			1|user.txt||
			
		EOF
	fi
	count=$(get merlinclash_koolproxy_custom_rule_count)
	if [ -n "$count" ];then
		i=0
		while [ "$i" -lt "$count" ]
		do
			txt=$(get merlinclash_koolproxy_custom_rule_$i)
			#开始拼接文件值，然后进行base64解码，写回文件
			content=${content}${txt}
			let i=i+1
		done
		echo $(decode_url_link $content) > /tmp/userrule.txt
		if [ -f /tmp/userrule.txt ]; then
			echo_date "中间文件已经创建" >> $LOG_FILE
			echo_date "生成新文件" >> $LOG_FILE
			cat /tmp/userrule.txt | urldecode > $KP_DIR/data/rules/user.txt
			rm -rf /tmp/userrule.txt
		fi
		#dbus remove jdqd_jd_script_content_custom
		customs=`dbus list merlinclash_koolproxy_custom_rule_ | cut -d "=" -f 1`
		for custom in $customs
		do
			dbus remove $custom
		done
	fi
	ln -sf $KP_DIR/data/rules/user.txt /tmp/upload/user.txt

}

start_koolproxy(){
	write_sourcelist
	
	echo_date 开启KP主进程！>> $LOG_FILE
	[ ! -L "$KSROOT/bin/koolproxy" ] && ln -sf $KSROOT/merlinclash/koolproxy/koolproxy $KSROOT/bin/koolproxy
	cd $KP_DIR && koolproxy --mark -d
	#cd $KP_DIR && koolproxy -d --ttl 188 --ttlport 3001 --ipv6
	[ "$?" != "0" ] && echo_date "koolproxy启动失败" >> $LOG_FILE && dbus set merlinclash_koolproxy_enable=0 && exit 1
}

stop_koolproxy(){
	if [ -n "`pidof koolproxy`" ];then
		echo_date 关闭KP主进程... >> $LOG_FILE
		kill -9 `pidof koolproxy` >/dev/null 2>&1
		killall koolproxy >/dev/null 2>&1
	fi
	flush_nat
}

add_ipset_conf(){
	echo_date 添加内置黑名单软连接...
	rm -rf /jffs/configs//dnsmasq.d/koolproxy_ipset.conf
	ln -sf /koolshare/merlinclash/koolproxy/data/koolproxy_ipset.conf /jffs/configs/dnsmasq.d/koolproxy_ipset.conf
	ln -sf /koolshare/merlinclash/koolproxy/data/koolproxy_white_update.conf /jffs/configs/dnsmasq.d/koolproxy_white_update.conf
	#wanwhitedomain=$(echo $koolproxy_wan_white_domain | base64_decode)
	#if [ -n "$koolproxy_wan_white_domain" ]; then
	#	echo_date 加载域名白名单...
	#	rm -rf $KP_DIR/data/koolproxy_white_custom.conf
	#	echo "#for koolproxy white_domain" >> $KP_DIR/data/koolproxy_white_custom.conf
	#	for koolproxy_white_domain in $wanwhitedomain
	#	do 
	#		echo "$koolproxy_white_domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_koolproxy/g" >> $KP_DIR/data/koolproxy_white_custom.conf
	#	done
	#	ln -sf $KP_DIR/data/koolproxy_white_custom.conf /jffs/configs/dnsmasq.d/koolproxy_white_custom.conf
	#else
	#	rm -rf $KP_DIR/data/koolproxy_white_custom.conf
	#fi

	#wanblackdomain=$(echo $koolproxy_wan_black_domain | base64_decode)
	#if [ -n "$koolproxy_wan_black_domain" ]; then
	#	echo_date 加载域名黑名单...
	#	rm -rf $KP_DIR/data/koolproxy_black_custom.conf	
	#	echo "#for koolproxy black_domain" >> $KP_DIR/data/koolproxy_black_custom.conf
	#	for koolproxy_black_domain in $wanblackdomain
	#	do 
	#		echo "$koolproxy_black_domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/black_koolproxy/g" >> $KP_DIR/data/koolproxy_black_custom.conf
	#	done
	#	ln -sf $KP_DIR/data/koolproxy_black_custom.conf /tmp/dnsmasq.d/koolproxy_black_custom.conf
	#else
	#	rm -rf $KP_DIR/data/koolproxy_black_custom.conf		
	#fi

	dnsmasq_restart=1
}

remove_ipset_conf(){
	if [ -L "/jffs/configs/dnsmasq.d/koolproxy_ipset.conf" ];then
		echo_date 移除黑名单软连接... >> $LOG_FILE
		rm -rf /jffs/configs/dnsmasq.d/koolproxy_ipset.conf
		dnsmasq_restart=1
	fi
}

restart_dnsmasq(){
	if [ "$dnsmasq_restart" == "1" ];then
		echo_date 重启dnsmasq进程... >> $LOG_FILE
		service restart_dnsmasq > /dev/null 2>&1
	fi
}

write_reboot_job(){
	# start setvice
	mkr=$(get merlinclash_koolproxy_reboot)
	mkrh=$(get merlinclash_koolproxy_reboot_hour)
	mkrm=$(get merlinclash_koolproxy_reboot_min)
	mkrih=$(get merlinclash_koolproxy_reboot_inter_hour)
	mkrim=$(get merlinclash_koolproxy_reboot_inter_min)
	if [ "1" == "$mkr" ]; then
		echo_date 开启插件定时重启，每天"$mkrh"时"$mkrm"分，自动重启插件... >> $LOG_FILE
		cru a c_koolproxy_reboot "$mkrm $mkrh * * * /bin/sh /koolshare/scripts/clash_koolproxyconfig.sh restart"
	elif [ "2" == "$mkr" ]; then
		echo_date 开启插件间隔重启，每隔"$mkrih"时"$mkrim"分，自动重启插件... >> $LOG_FILE
		cru a c_koolproxy_reboot "*/$mkrim */$mkrih * * * /bin/sh /koolshare/scripts/clash_koolproxyconfig.sh restart"
	fi
}

remove_reboot_job(){
	jobexist=`cru l|grep c_koolproxy_reboot`
	# kill crontab job
	if [ -n "$jobexist" ];then
		echo_date 关闭插件定时重启... >> $LOG_FILE
		sed -i '/c_koolproxy_reboot/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}

creat_ipset(){
	echo_date 创建ipset名单 >> $LOG_FILE
	ipset -! creat white_kp_list nethash
	ip_lan="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
	for ip in $ip_lan
	do
		ipset -A white_kp_list $ip >/dev/null 2>&1
	done
	
	ports=`cat /koolshare/merlinclash/koolproxy/data/rules/koolproxy.txt /koolshare/merlinclash/koolproxy/data/rules/daily.txt /koolshare/merlinclash/koolproxy/data/rules/user.txt | grep -Eo "(.\w+\:[1-9][0-9]{1,4})/" | grep -Eo "([0-9]{1,5})" | sort -un`
	for port in $ports 80
	do
		ipset -A kp_port_http $port >/dev/null 2>&1
		ipset -A kp_port_https $port >/dev/null 2>&1
	done

	ipset -A kp_port_https 443 >/dev/null 2>&1
	ipset -A black_koolproxy 110.110.110.110 >/dev/null 2>&1
	
}

get_method_name(){
	case "$1" in
	1)
		echo "IP + MAC匹配"
		;;
	2)
		echo "仅IP匹配"
		;;
	3)
		echo "仅MAC匹配"
		;;
	esac
}
get_mode_name() {
	case "$1" in
		0)
			echo "不过滤"
		;;
		1)
			echo "全局模式"
		;;
		2)
			echo "带HTTPS的全局模式"
		;;
		3)
			echo "黑名单模式"
		;;
		4)
			echo "带HTTPS的黑名单模式"
		;;
		5)
			echo "全端口模式"
		;;
	esac
}

get_base_mode_name() {
	case "$1" in
		0)
			echo "不过滤"
		;;
		1)
			echo "全局模式"
		;;
		2)
			echo "黑名单模式"
		;;							
	esac
}

get_jump_mode(){
	case "$1" in
		0)
			echo "-j"
		;;
		*)
			echo "-g"
		;;
	esac
}

get_action_chain() {
	case "$1" in
		0)
			echo "RETURN"
		;;
		1)
			echo "KP_HTTP"
		;;
		2)
			echo "KP_HTTPS"
		;;
		3)
			echo "KP_BLOCK_HTTP"
		;;
		4)
			echo "KP_BLOCK_HTTPS"
		;;				
		5)
			echo "KP_ALL_PORT"
		;;		
	esac
}

factor(){
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo ""
	else
		echo "$2 $1"
	fi
}

flush_nat(){
	#iptables -t nat -D KP_HTTPS -p tcp -m set ! --match-set  china_ip_route dst -j RETURN
	if [ -n "`iptables -t nat -S|grep KOOLPROXY`" ];then
		echo_date 移除nat规则... >> $LOG_FILE
		cd /tmp
		iptables -t nat -S | grep -E "KOOLPROXY|KOOLPROXY_ACT|KP_HTTP|KP_HTTPS|KP_BLOCK_HTTP|KP_BLOCK_HTTPS|KP_ALL_PORT" | sed 's/-A/iptables -t nat -D/g'|sed 1,7d > clean.sh && chmod 777 clean.sh && ./clean.sh
		iptables -t nat -X KOOLPROXY > /dev/null 2>&1
		iptables -t nat -X KOOLPROXY_ACT > /dev/null 2>&1	
		iptables -t nat -X KP_HTTP > /dev/null 2>&1
		iptables -t nat -X KP_HTTPS > /dev/null 2>&1
		iptables -t nat -X KP_BLOCK_HTTP > /dev/null 2>&1
		iptables -t nat -X KP_BLOCK_HTTPS > /dev/null 2>&1	
		iptables -t nat -X KP_ALL_PORT > /dev/null 2>&1
	fi
}

lan_acess_control(){
	# lan access control

	[ -z "$mkad" ] && mkad=1
	acl_nu=`dbus list merlinclash_koolproxy_acl_mode_ | cut -d "=" -f 1 | cut -d "_" -f 5 | sort -n`
	if [ -n "$acl_nu" ]; then
		for min in $acl_nu
		do
			ipaddr=`dbus get merlinclash_koolproxy_acl_ip_$min`
			mac=`dbus get merlinclash_koolproxy_acl_mac_$min`
			proxy_name=`dbus get merlinclash_koolproxy_acl_name_$min`
			proxy_mode=`dbus get merlinclash_koolproxy_acl_mode_$min`
			#mkamt=$(get merlinclash_koolproxy_acl_method)
			#echo_date "当前访问控制匹配方法为：$(get_method_name $mkamt)" >> $LOG_FILE
			#[ "$mkamt" == "1" ] && echo_date 加载ACL规则：【$ipaddr】【$mac】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
			mac="" && echo_date 加载ACL规则：【$ipaddr】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
			#[ "$mkamt" == "3" ] && ipaddr="" && echo_date 加载ACL规则：【$mac】模式为：$(get_mode_name $proxy_mode) >> $LOG_FILE
			#echo iptables -t nat -A KOOLPROXY $(factor $ipaddr "-s") $(factor $mac "-m mac --mac-source") -p tcp $(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
			iptables -t nat -A KOOLPROXY $(factor $ipaddr "-s") $(factor $mac "-m mac --mac-source") -p tcp $(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
		done
		echo_date 加载ACL规则：其余主机模式为：$(get_mode_name $mkad) >> $LOG_FILE
	else
		echo_date 加载ACL规则：所有模式为：$(get_mode_name $mkad) >> $LOG_FILE
	fi
}


load_nat(){
	nat_ready=$(iptables -t nat -L PREROUTING -v -n --line-numbers|grep -v PREROUTING|grep -v destination)
	i=120
	# laod nat rules
	until [ -n "$nat_ready" ]
	do
	    i=$(($i-1))
	    if [ "$i" -lt 1 ];then
	        echo_date "Could not load nat rules!" >> $LOG_FILE
	        sh /koolshare/scipts/clash_koolproxyconfig.sh stop
	        exit
	    fi
	    sleep 1
		nat_ready=$(iptables -t nat -L PREROUTING -v -n --line-numbers|grep -v PREROUTING|grep -v destination)
	done
	
	echo_date 加载nat规则！ >> $LOG_FILE
	#----------------------BASIC RULES---------------------
	echo_date 写入iptables规则到nat表中... >> $LOG_FILE
	# 创建KOOLPROXY nat rule
	iptables -t nat -N KOOLPROXY
	# 创建KOOLPROXY_ACT nat rule
	iptables -t nat -N KOOLPROXY_ACT
	## 匹配TTL走TTL Port	
	#iptables -t nat -A KOOLPROXY_ACT -p tcp -m ttl --ttl-eq 188 -j REDIRECT --to 3001
	# 不匹配TTL走正常Port
	iptables -t nat -A KOOLPROXY_ACT -p tcp -j REDIRECT --to 3000
	# 局域网地址不走KP
	iptables -t nat -A KOOLPROXY -m set --match-set direct_list dst -j RETURN
	# 白名单不走KP
	iptables -t nat -A KOOLPROXY -m set --match-set white_koolproxy dst -j RETURN
	#  生成对应CHAIN
	iptables -t nat -N KP_HTTP
	# 网易云不走KP
	iptables -t nat -A KP_HTTP -p tcp -m set --match-set music dst -j RETURN
	iptables -t nat -A KP_HTTP -p tcp -m set --match-set kp_port_http dst -j KOOLPROXY_ACT

	iptables -t nat -N KP_HTTPS
	mpkp=$(get merlinclash_passkpswitch)
	if [ "$mpkp" == "1" ]; then
		echo_date "国外IP绕行开启，设置国外IP绕开koolproxy" >> $LOG_FILE
		iptables -t nat -I KP_HTTP 1 -p tcp -m set ! --match-set  china_ip_route dst -j RETURN
		iptables -t nat -I KP_HTTPS 1 -p tcp -m set ! --match-set  china_ip_route dst -j RETURN	
	fi
	iptables -t nat -A KP_HTTPS -p tcp -m set --match-set music dst -j RETURN
	iptables -t nat -A KP_HTTPS -p tcp -m set --match-set kp_port_https dst -j KOOLPROXY_ACT
	
	iptables -t nat -N KP_BLOCK_HTTP
	iptables -t nat -A KP_BLOCK_HTTP -p tcp -m set --match-set black_koolproxy dst -j KP_HTTP
	iptables -t nat -N KP_BLOCK_HTTPS
	iptables -t nat -A KP_BLOCK_HTTPS -p tcp -m set --match-set black_koolproxy dst -j KP_HTTPS	
	iptables -t nat -N KP_ALL_PORT
	# 局域网控制
	lan_acess_control
	# 剩余流量转发到缺省规则定义的链中
	iptables -t nat -A KOOLPROXY -p tcp -j $(get_action_chain $mkad)
	# 重定所有流量到 KOOLPROXY
	# 全局模式和视频模式
	#[ "$mkm" == "1" ] || [ "$mkm" == "3" ] && 
	iptables -t nat -I PREROUTING 1 -p tcp -j KOOLPROXY
	# ipset 黑名单模式
	#[ "$mkm" == "2" ] && iptables -t nat -I PREROUTING 1 -p tcp -m set --match-set black_koolproxy dst -j KOOLPROXY
}

dns_takeover(){
	lan_ipaddr=`nvram get lan_ipaddr`
	#chromecast=`iptables -t nat -L PREROUTING -v -n|grep "dpt:53"`
	chromecast_nu=`iptables -t nat -L PREROUTING -v -n --line-numbers|grep "dpt:53"|awk '{print $1}'`
	if [ "$mkm" == "2" ]; then
		if [ -z "$chromecast_nu" ]; then
			echo_date 黑名单模式开启DNS劫持 >> $LOG_FILE
			iptables -t nat -A PREROUTING -p udp -s $(get_lan_cidr) --dport 53 -j DNAT --to $lan_ipaddr:23453 >/dev/null 2>&1
		fi
	fi
}

detect_cert(){
	if [ ! -f $KP_DIR/data/private/ca.key.pem ]; then
		echo_date 检测到首次运行，开始生成KP证书，用于https过滤！ >> $LOG_FILE
		cd $KP_DIR/data && sh gen_ca.sh
		echo_date 证书生成完毕！！！ >> $LOG_FILE
	fi
}

modprobe_module(){
	if lsmod | grep xt_hl &>/dev/null; then
		echo_date "xt_hl模块已加载" >> $LOG_FILE; 
	else
		#检查是否固件是否有ip_set_hash_mac模块
		if [ -f "/lib/modules/${OS}/kernel/net/netfilter/xt_hl.ko" ]; then
			echo_date "加载xt_hl模块" >> $LOG_FILE; 
			modprobe xt_hl
		else
			echo_date "xt_hl模块不存在，将影响HTTPS过滤" >> $LOG_FILE
		fi
	fi
	if lsmod | grep xt_HL &>/dev/null; then
		echo_date "xt_HL模块已加载" >> $LOG_FILE; 
	else
		#检查是否固件是否有ip_set_hash_mac模块
		if [ -f "/lib/modules/${OS}/kernel/net/netfilter/xt_HL.ko" ]; then
			echo_date "加载xt_HL模块" >> $LOG_FILE; 
			modprobe xt_HL
		else
			echo_date "xt_HL模块不存在，将影响HTTPS过滤" >> $LOG_FILE
		fi
	fi
}
case $1 in
restart)
	#web提交触发，需要先关后开
	# now stop
	rm -rf /tmp/upload/user.txt
	remove_reboot_job
	#flush_nat
	stop_koolproxy
	remove_ipset_conf && restart_dnsmasq
	# now start
	echo_date ============================ KP启用 =========================== >> $LOG_FILE
	modprobe_module
	detect_cert
	start_koolproxy
	add_ipset_conf && restart_dnsmasq
	#creat_ipset
	load_nat
	#dns_takeover
	write_reboot_job
	#detect_start_up
	echo_date KP启用成功，请等待日志窗口自动关闭，页面会自动刷新... >> $LOG_FILE
	echo_date ============================================================= >> $LOG_FILE
	;;
stop)
	#web提交触发，需要先关后开
	echo_date ============================ 关闭KP =========================== >> $LOG_FILE
	remove_reboot_job
	add_ipset_conf && restart_dnsmasq
	#flush_nat
	stop_koolproxy
	remove_ipset_conf && restart_dnsmasq
	echo_date KP插件已关闭 >> $LOG_FILE
	echo_date ============================================================= >> $LOG_FILE
	;;
esac