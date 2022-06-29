#!/bin/sh

source /koolshare/scripts/base.sh
LOG_FILE=/tmp/upload/merlinclash_node_mark.log
eval `dbus export merlinclash_`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOGFILE=/tmp/upload/merlinclash_log.txt
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
yamlname=$(get merlinclash_yamlsel)
#配置文件路径
yamlpath=/koolshare/merlinclash/yaml_use/$yamlname.yaml
#提取配置认证码
secret=$(cat $yamlpath | awk '/secret:/{print $2}' | sed 's/"//g')
#提取配置监听端口
ecport=$(cat $yamlpath | awk -F: '/external-controller/{print $3}')

lan_ipaddr=$(nvram get lan_ipaddr)

name=clash

#闪存配置文件夹
dirconf=/koolshare/merlinclash/mark
#内存目录文件夹
dirtmp=/tmp/clash
mcenable=$(get merlinclash_enable)

#在内存里对比并保存节点记忆文件到闪存，放进程守护里定时运行
setmark () {
	if [ "$mcenable" == "1" ]; then
		if [ ! -z "$(pidof clash)" -a ! -z "$(netstat -anp | grep clash)" -a ! -n "$(grep "Parse config error" /tmp/clash_run.log)" ] ; then
			echo_date "Clash运行正常，开始记录节点设置" >> $LOG_FILE
			[ ! -d $dirtmp/mark ] && mkdir -p $dirtmp/mark
			[ ! -d $dirconf ] && mkdir -p $dirconf
			echo_date "创建/tmp/clash/mark文件夹,存放策略组节点记录" >> $LOG_FILE
			get_save(){
				if curl --version > /dev/null 2>&1;then
					curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
				elif [ -n "$(wget --help 2>&1|grep '\-\-method')" ];then
					wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
				fi
			}
			echo_date "获取面板节点设置" >> $LOG_FILE
			get_save http://$lan_ipaddr:$ecport/proxies | awk -F "{" '{for(i=1;i<=NF;i++) print $i}' | grep -E '^"all".*"Selector"' >  $dirtmp/mark/clash_web_check_${yamlname}.txt
			if [ -s "$dirtmp/mark/clash_web_check_${yamlname}.txt" ]; then
				while read line ;do
					def=$(echo $line | awk -F "[[,]" '{print $2}')
					now=$(echo $line | grep -oE '"now".*",' | sed 's/"now"://g'| sed 's/,//g')
					[ "$def" != "$now" ] && echo $line | grep -oE '"name".*"now".*",' | sed 's/"name"://g' | sed 's/"now"://g'| sed 's/"//g' >> $dirtmp/mark/clash_web_save_${yamlname}.txt
				done < $dirtmp/mark/clash_web_check_${yamlname}.txt
				rm -rf $dirtmp/mark/clash_web_check_${yamlname}.txt
				echo_date "对比文件，如果有变动且不为空则写入磁盘，否则清除临时文件" >> $LOG_FILE
				if [ -s $dirtmp/mark/clash_web_save_${yamlname}.txt ];then
					diff $dirtmp/mark/clash_web_save_${yamlname}.txt $dirconf/${yamlname}.txt
					[ "$?" = 0 ] && (rm -rf $dirtmp/mark/clash_web_save_${yamlname}.txt && echo_date "策略组未发生变化，清除临时文件" >> $LOG_FILE)  || (mv -f $dirtmp/mark/clash_web_save_${yamlname}.txt $dirconf/${yamlname}.txt && echo_date "策略组发生变化，重新创建记忆文件" >> $LOG_FILE)
				else
					echo_date "未定位到临时保存文件：$dirtmp/mark/clash_web_save_${yamlname}.txt" >> $LOG_FILE
					rm -rf $dirtmp/mark/clash_web_save_${yamlname}.txt
				fi
			else
				echo_date "获取策略组节点发生异常" >> $LOG_FILE
			fi
		else
			echo_date "Clash进程出现问题，删除保存节点定时任务" >> $LOGFILE
			if [ -n "$(cru l | grep autosermark)" ]; then
				echo_date 删除自动获取节点信息任务... >> $LOGFILE
				sed -i '/autosermark/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
			fi
			if [ -n "$(cru l | grep autologdel)" ]; then
				echo_date 删除日志监测任务... >> $LOGFILE
				sed -i '/autologdel/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
			fi
			exit 1
		fi
	fi
}

#还原节点记忆
remark(){
	if [ -s $dirconf/${yamlname}.txt ] ; then
		echo_date "▶还原节点位置记录..."
		put_save(){
			#if curl --version > /dev/null 2>&1;then
			if [ "$1" == "curl" ]; then
				curl -sS -X PUT -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$2" -d "$3" -w '%{http_code}'
			else
				wget -q --method=PUT --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" --body-data="$3" "$2" >/dev/null
			fi
		}
		#设置循环检测clash面板端口
		i=1
		while [ $i -lt 10 ];do
			sleep 1
			if curl --version > /dev/null 2>&1;then
				test=$(curl -s http://$lan_ipaddr:${ecport})
			else
				test=$(wget -q -O - http://$lan_ipaddr:${ecport})
			fi
			[ -n "$test" ] && i=10
		done
		#发送数据
		j=1
		filename=$dirconf/${yamlname}.txt
		lines=$(cat $filename | wc -l)
		#for i in `seq $num`;
		#do
		while [ "$j" -le "$lines" ]
		do
			line=$(sed -n ''$j'p' "$filename")
			group_name=$(awk -F ',' 'NR=="'${j}'" {print $1}' $dirconf/${yamlname}.txt | sed 's/ /%20/g')
			now_name=$(awk -F ',' 'NR=="'${j}'" {print $2}' $dirconf/${yamlname}.txt)
			echo_date " " >> $LOG_FILE
			echo_date " " >> $LOGFILE
			echo_date "●代理集：$group_name → 上次位置：$now_name" >> $LOG_FILE
			echo_date "●代理集：$group_name → 上次位置：$now_name" >> $LOGFILE
			http_code=$(put_save curl http://$lan_ipaddr:$ecport/proxies/${group_name} "{\"name\":\"${now_name}\"}")
			if [ "$http_code" != "204" ]; then
				echo_date "------------------------------------------" >> $LOG_FILE
				echo_date "------------------------------------------" >> $LOGFILE
				echo_date "|●--代理集：$group_name 节点还原失败，尝试使用wget还原-> " >> $LOG_FILE
				echo_date "|●--代理集：$group_name 节点还原失败，尝试使用wget还原->" >> $LOGFILE
				echo_date "------------------------------------------" >> $LOG_FILE
				echo_date "------------------------------------------" >> $LOGFILE
				put_save "wget" http://$lan_ipaddr:$ecport/proxies/${group_name} "{\"name\":\"${now_name}\"}"
			else
				echo_date "**************************************" >> $LOG_FILE
				echo_date "**************************************" >> $LOGFILE
				echo_date "******●代理集：$group_name 节点还原成功******" >> $LOG_FILE
				echo_date "******●代理集：$group_name 节点还原成功******" >> $LOGFILE
				echo_date "**************************************" >> $LOG_FILE
				echo_date "**************************************" >> $LOGFILE
			fi
			let j=j+1
		done
		echo "1i\######$(date "+%Y-%m-%d %H:%M:%S") #######" > /tmp/upload/${yamlname}_status.txt
		sed -i '$a BBABBBBC' /tmp/upload/${yamlname}_status.txt
	else
		echo_date "▶节点位置记录文件不存在 或 配置文件更换首次启动，跳过还原。" 
		rm -rf /tmp/upload/${yamlname}_status.txt
	fi

}


#检查进程端口日志都启动成功，成功就执行还原节点记录。
start_remark () {
	if [ ! -z "$(pidof $name)" -a ! -z "$(netstat -anp | grep $name)" -a ! -z "$(grep "Parse config error" /tmp/clash_run.log)" ] ; then
		remark
	else
		echo_date "remark：$name进程没启动成功或端口没监听，跳过还原节点记录。"
	fi
}

case $1 in
start_remark)
	start_remark
	;;
remark)
	remark
	;;
setmark)
	setmark
	;;
esac
