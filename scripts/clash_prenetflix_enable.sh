#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
get(){
	a=$(echo $(dbus get $1))
	a=$(echo $(dbus get $1))
	echo $a
}
mcenable=$(get merlinclash_enable)
mcprenetflix=$(get merlinclash_prenetflix)
mcprenetflixdtime_enable=$(get merlinclash_prenetflix_delay_time_enable)
mcprenetflix_dtime=$(get merlinclash_prenetflix_delay_time)
if [ "$mcenable" == "1" ] && [ "$mcprenetflix" == "1" ] && [ "$mcprenetflixdtime_enable" == "1" ];then
		sed -i '/clash_prenetflix/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
		pretime=$mcprenetflix_dtime
		cru a clash_prenetflix */$pretime" * * * * /bin/sh /koolshare/merlinclash/clashconfig.sh prenetflix"
else
	sed -i '/clash_prenetflix/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
fi
http_response "$1"
