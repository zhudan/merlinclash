#!/bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
eval $(dbus export merlinclash_)
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
#

ln -sf /koolshare/merlinclash/koolproxy/data/rules/user.txt /tmp/upload/user.txt
if [ -f "/koolshare/merlinclash/yaml_basic/routerrules.yaml" ]; then
   ln -sf /koolshare/merlinclash/yaml_basic/routerrules.yaml /tmp/upload/clash_routerrules.txt 
fi
http_response $1

