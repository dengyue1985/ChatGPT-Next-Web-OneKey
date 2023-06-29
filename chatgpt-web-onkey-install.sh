#!/usr/bin/env bash

#====================================================
#	System Request:Debian 9+/Ubuntu 18.04+/Centos 7+
#	Author:	dengyue
#	Dscription: ChatGPT Web Management
#	email: dengyue1985@hotmail.com
#====================================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
stty erase ^?

cd "$(
  cd "$(dirname "$0")" || exit
  pwd
)" || exit

# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

# 变量
script_version="1.0.1"
github_branch="main"
nginx_conf="/etc/nginx/nginx.conf"
VERSION=$(echo "${VERSION}" | awk -F "[()]" '{print $2}')

function print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}
function print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}
function is_root() {
  if [[ 0 == "$UID" ]]; then
    print_ok "当前用户是 root 用户，开始安装流程"
  else
    print_error "当前用户不是 root 用户，请切换到 root 用户后重新执行脚本"
    exit 1
  fi
}

function judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 完成"
    sleep 1
  else
    print_error "$1 失败"
    exit 1
  fi
}

function system_check() {
  source '/etc/os-release'

  if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    print_ok "当前系统为 Centos ${VERSION_ID} ${VERSION}"
    INS="yum install -y"
    UNINS="yum remove"
    ${INS} curl
  elif [[ "${ID}" == "ol" ]]; then
    print_ok "当前系统为 Oracle Linux ${VERSION_ID} ${VERSION}"
    INS="yum install -y"
    UNINS="yum remove"
    ${INS} curl	
  elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 9 ]]; then
    print_ok "当前系统为 Debian ${VERSION_ID} ${VERSION}"
    INS="apt install -y"
    UNINS="apt remove"
    ${INS} curl
    apt update
  elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 18 ]]; then
    print_ok "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
    INS="apt install -y"
    UNINS="apt remove"
    ${INS} curl
    apt update
  else
    print_error "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内"
    exit 1
  fi

  if [[ $(grep "nogroup" /etc/group) ]]; then
    cert_group="nogroup"
  fi

  $INS dbus

  # 关闭各类防火墙
  systemctl stop firewalld
  systemctl disable firewalld
  systemctl stop nftables
  systemctl disable nftables
  systemctl stop ufw
  systemctl disable ufw
}


function dependency_install() {
  ${INS} lsof tar
  judge "安装 lsof tar"

  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    ${INS} crontabs
  else
    ${INS} cron
  fi
  judge "安装 crontab"

  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    touch /var/spool/cron/root && chmod 600 /var/spool/cron/root
    systemctl start crond && systemctl enable crond
  else
    touch /var/spool/cron/crontabs/root && chmod 600 /var/spool/cron/crontabs/root
    systemctl start cron && systemctl enable cron

  fi
  judge "crontab 自启动配置 "

  ${INS} unzip
  judge "安装 unzip"

  ${INS} curl
  judge "安装 curl"

  # upgrade systemd
  ${INS} systemd
  judge "安装/升级 systemd"

  if [[ "${ID}" == "centos" ]]; then
    ${INS} pcre pcre-devel zlib-devel epel-release openssl openssl-devel
  elif [[ "${ID}" == "ol" ]]; then
    ${INS} pcre pcre-devel zlib-devel openssl openssl-devel
    # Oracle Linux 不同日期版本的 VERSION_ID 比较乱 直接暴力处理。如出现问题或有更好的方案，请提交 Issue。
    yum-config-manager --enable ol7_developer_EPEL >/dev/null 2>&1
    yum-config-manager --enable ol8_developer_EPEL >/dev/null 2>&1
  else
    ${INS} libpcre3 libpcre3-dev zlib1g-dev openssl libssl-dev
  fi
  ${INS} jq
}
function basic_optimization() {
  # 最大文件打开数
  sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  echo '* soft nofile 65536' >>/etc/security/limits.conf
  echo '* hard nofile 65536' >>/etc/security/limits.conf

  # RedHat 系发行版关闭 SELinux
  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
  fi
}
function domain_check() {
  domain_ip=$(curl -sm8 ipget.net/?ip="$1")
  print_ok "正在获取 IP 地址信息，请耐心等待"
  wgcfv4_status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
  wgcfv6_status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
  if [[ ${wgcfv4_status} =~ "on"|"plus" ]] || [[ ${wgcfv6_status} =~ "on"|"plus" ]]; then
    # 关闭wgcf-warp，以防误判VPS IP情况
    wg-quick down wgcf >/dev/null 2>&1
    print_ok "已关闭 wgcf-warp"
  fi
  local_ipv4=$(curl -4 ip.sb)
  local_ipv6=$(curl -6 ip.sb)
  if [[ -z ${local_ipv4} && -n ${local_ipv6} ]]; then
    # 纯IPv6 VPS，自动添加DNS64服务器以备acme.sh申请证书使用
    echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
    print_ok "识别为 IPv6 Only 的 VPS，自动添加 DNS64 服务器"
  fi
  echo -e "域名通过 DNS 解析的 IP 地址：${domain_ip}"
  echo -e "本机公网 IPv4 地址： ${local_ipv4}"
  echo -e "本机公网 IPv6 地址： ${local_ipv6}"
  sleep 2
  if [[ ${domain_ip} == "${local_ipv4}" ]]; then
    print_ok "域名通过 DNS 解析的 IP 地址与 本机 IPv4 地址匹配"
    sleep 2
  elif [[ ${domain_ip} == "${local_ipv6}" ]]; then
    print_ok "域名通过 DNS 解析的 IP 地址与 本机 IPv6 地址匹配"
    sleep 2
  else
  print_error "请确保域名添加了正确的 A / AAAA 记录，否则将无法正常使用 web服务"
    print_error "域名通过 DNS 解析的 IP 地址与 本机 IPv4 / IPv6 地址不匹配，是否继续安装？（y/n）" && read -r install
    case $install in
    [yY][eE][sS] | [yY])
      print_ok "继续安装"
      sleep 2
      ;;
    *)
      print_error "安装终止"
      exit 2
      ;;
    esac
  fi
}

function port_exist_check() {
  if [[ 0 -eq $(lsof -i:"$1" | grep -i -c "listen") ]]; then
    print_ok "$1 端口未被占用"
    sleep 1
  else
    print_error "检测到 $1 端口被占用，以下为 $1 端口占用信息"
    lsof -i:"$1"
    print_error "5s 后将尝试自动 kill 占用进程"
    sleep 5
    lsof -i:"$1" | awk '{print $2}' | grep -v "PID" | xargs kill -9
    print_ok "kill 完成"
    sleep 1
  fi
}

function update_script() {
  ol_version=$(curl -L -s https://raw.githubusercontent.com/dengyue1985/ChatGPT-Web-onekey/${github_branch}/install.sh | grep "script_version=" | head -1 | awk -F '=|"' '{print $3}')
  if [[ "$script_version" != "$(echo -e "$script_version\n$ol_version" | sort -rV | head -1)" ]]; then
    print_ok "存在新版本，是否更新 [Y/N]?"
    read -r update_confirm
    case $update_confirm in
    [yY][eE][sS] | [yY])
      wget -N --no-check-certificate https://raw.githubusercontent.com/dengyue1985/ChatGPT-Web-onekey/${github_branch}/install.sh
      print_ok "更新完成"
      print_ok "您可以通过 bash $0 执行本程序"
      exit 0
      ;;
    *) ;;
    esac
  else
    print_ok "当前版本为最新版本"
    print_ok "您可以通过 bash $0 执行本程序"
  fi
}
function modify_nginx_port() {
  read -rp "请输入端口号(默认：443)：" PORT
  [ -z "$PORT" ] && PORT="443"
  if [[ $PORT -le 0 ]] || [[ $PORT -gt 65535 ]]; then
    print_error "请输入 0-65535 之间的值"
    exit 1
  fi
  port_exist_check $PORT
  sed -i "/listen 80;/c \\\tlinsten ${PORT};" ${nginx_conf}
  sed -i "/proxy_set_header Host \$host/c \\\t  proxy_set_header Host \$host:${PORT};" ${nginx_conf}
  judge "Nginx 端口 修改"
}

function modify_nginx_domain(){
  read -rp "请输入你的域名信息(eg: www.paicifang.com):" DOMAIN
  domain_check ${DOMAIN}
  sed -i "s/serveraddr.com/${DOMAIN}/g" ${nginx_conf}
  judge "Nginx 域名 修改"
}

#docker安装
function docker_install(){
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL get.docker.com -o "$HOME"/get-docker.sh
    sh "$HOME"/get-docker.sh
    judge "Docker 安装"
  else
    print_ok "Docker 已存在"
  fi
}

function chatgpt_web_install(){
  if [[ 0 -eq $(docker image ls |grep "yidadaa/chatgpt-next-web" -i -c) ]]; then
    docker pull yidadaa/chatgpt-next-web
	judge "ChatGPT-Web 安装"
  else
    print_ok "ChatGPT-Web 已存在"
  fi
}

function chatgpt_web_start(){
  while true
  do
    read -rp "请输入OpenAI平台的API Key(!!必填!!eg:sk-xxxxx):" API_KEY
    if [ -z ${API_KEY} ]; then
	  print_error "API Key 为空"
	else
	  print_ok "API Key"
	exit 0
	fi
  done
  
  read -rp "请设置WEB平台的访问密码(可选):" ACC_PWD
  
  docker run -d -p 3000:3000 --name chatgpt-web -e OPENAI_API_KEY=${API_KEY} -e CODE=${ACC_PWD} yidadaa/chatgpt-next-web
  judge "WEB平台启动"
}

function nginx_install() {
  if [[ 0 -eq $(docker image ls |grep nginx -i -c) ]]; then
    docker pull nginx
    judge "Nginx 安装"
    # 创建配置文件目录
    mkdir -p /etc/nginx >/dev/null 2>&1
  else
    print_ok "Nginx 已存在"
  fi
}
function configure_nginx() {
  cd /etc/nginx/ && rm -f nginx.conf && wget -O nginx.conf https://raw.githubusercontent.com/dengyue1985/ChatGPT-Web-onekey/${github_branch}/config/nginx.conf      
  modify_nginx_port
  modify_nginx_domain
  judge "Nginx 配置 修改"
  docker run --name chatgpt-nginx -v ${nginx_conf}:/etc/nginx/nginx.conf -d nginx
  judge "Nginx 启动"
}

function restart_nginx() {
  docker restart nginx
  judge "Nginx 启动"
}

function install_web() {
  is_root
  system_check
  dependency_install
  basic_optimization
  docker_install
  chatgpt_web_install
  chatgpt_web_start
  nginx_install
  configure_nginx
}

menu() {
  update_script
  echo -e "\t ChatGPT-Web 安装管理脚本 ${Red}[${script_version}]${Font}"
  echo -e "\t---authored by dengyue---"
  echo -e "\thttps://github.com/dengyue1985/ChatGPT-Web-onekey/\n"

  echo -e "—————————————— 安装向导 ——————————————"""
  echo -e "${Green}0.${Font}  升级 脚本"
  echo -e "${Green}1.${Font}  安装 Web服务 (ChatGPT-Web + Nginx)"
  echo -e "—————————————— 配置变更 ——————————————"
  echo -e "${Green}11.${Font} 变更 连接端口"
  echo -e "${Green}12.${Font} 变更 域名"
  echo -e "—————————————— 其他选项 ——————————————"
  echo -e "${Green}21.${Font} 手动更新 SSL 证书"
  echo -e "${Green}22.${Font} 退出"
  read -rp "请输入数字：" menu_num
  case $menu_num in
  0)
    update_script
    ;;
  1)
    install_web
    ;;
  11)
    modify_nginx_port
    restart_nginx
    ;;
  12)
    modify_nginx_domain
    restart_nginx
    ;;
  21)
    "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh"
    restart_nginx
    ;;
  22)
    exit 0
    ;;
  *)
    print_error "请输入正确的数字"
    ;;
  esac
}
menu "$@"
