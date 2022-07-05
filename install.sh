#!/bin/bash

github_proxy="https://gh.api.99988866.xyz/"
#github_proxy="https://ghproxy.com/"
clashconfig_file="${github_proxy}https://ghproxy.com/https://raw.githubusercontent.com/zhudan/merlinclash/master/clash/clashconfig.sh"
clash_config_file="${github_proxy}https://ghproxy.com/https://raw.githubusercontent.com/zhudan/merlinclash/master/scripts/clash_config.sh"

bak(){
  bak_suffix=`date '+%Y%m%d%H%M%S'`
  cp /koolshare/merlinclash/clashconfig.sh /koolshare/merlinclash/clashconfig.sh.$bak_suffix
  cp /koolshare/scripts/clash_config.sh /koolshare/scripts/clash_config.sh.$bak_suffix
  echo "备份完成,后缀: $bak_suffix"
}

download(){
  echo "开始下载"
  curl -s -k -o /tmp/clashconfig.sh $clashconfig_file
  curl -s -k -o /tmp/clash_config.sh $clash_config_file
  echo "下载完成"
  chmod +x /tmp/clashconfig.sh
  chmod +x /tmp/clash_config.sh
  mv /tmp/clashconfig.sh /koolshare/merlinclash/clashconfig.sh
  mv /tmp/clash_config.sh /koolshare/scripts/clash_config.sh
  echo "替换文件完成"
}

bak
download

echo "安装完成, 配置DNS为后置即可使用"