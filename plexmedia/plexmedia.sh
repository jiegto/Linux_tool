#!/bin/bash

#####################################################
# ssfun's Linux Tool For Plexmedia
# Author: ssfun
# Date: 2025-01-09
# Version: 1.0.0
#####################################################

# Basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

# OS arch env
OS=''
ARCH=''

# Plex env
PLEX_LIBRARY_PATH='/var/lib/plexmediaserver'
PLEX_SERVICE='/lib/systemd/system/plexmediaserver.service'

# Plex status define
declare -r PLEX_STATUS_RUNNING=1
declare -r PLEX_STATUS_NOT_RUNNING=0
declare -r PLEX_STATUS_NOT_INSTALL=255

# Utils
function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

# Root user check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

# System check
os_check() {
    LOGI "检测当前系统中..."
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    else
        LOGE "系统检测错误,当前系统不支持!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS}"
}

# Arch check
arch_check() {
    LOGI "检测当前系统架构中..."
    ARCH=$(arch)
    LOGI "当前系统架构为 ${ARCH}"
    if [[ ${ARCH} == "x86_64" || ${ARCH} == "x64" || ${ARCH} == "amd64" ]]; then
        ARCH="amd64"
    elif [[ ${ARCH} == "aarch64" || ${ARCH} == "arm64" ]]; then
        ARCH="arm64"
    else
        LOGE "检测系统架构失败,当前系统架构不支持!" && exit 1
    fi
    LOGI "系统架构检测完毕,当前系统架构为:${ARCH}"
}

# Install some common utils
install_base() {
    if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
        if ! dpkg -s wget tar >/dev/null 2>&1; then
            apt install wget tar -y
        fi
    elif [[ ${OS} == "centos" ]]; then
        if ! rpm -q wget tar >/dev/null 2>&1; then
            yum install wget tar -y
        fi
    fi
}

# Plex status check
plex_status_check() {
    if [[ ! -f "${PLEX_SERVICE}" ]]; then
        return ${PLEX_STATUS_NOT_INSTALL}
    fi
    local plex_status_temp=$(systemctl is-active plexmediaserver)
    if [[ "${plex_status_temp}" == "active" ]]; then
        return ${PLEX_STATUS_RUNNING}
    else
        return ${PLEX_STATUS_NOT_RUNNING}
    fi
}

# Get current Plex version
get_current_plex_version() {
    if [[ -f "/usr/lib/plexmediaserver/Plex Media Server" ]]; then
        echo "$(/usr/lib/plexmediaserver/Plex\ Media\ Server --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+-\w+')"
    else
        echo ""
    fi
}

# Get latest Plex version
get_latest_plex_version() {
    echo "$(wget -qO- -t1 -T2 "https://plex.tv/api/downloads/5.json" | grep -o '"version":"[^"]*' | grep -o '[^"]*$' | head -n 1)"
}

# Show Plex status
show_plex_status() {
    plex_status_check
    case $? in
    0)
        echo -e "[INF] Plex 状态: ${yellow}未运行${plain}"
        show_plex_enable_status
        ;;
    1)
        echo -e "[INF] Plex 状态: ${green}已运行${plain}"
        show_plex_enable_status
        show_plex_running_status
        ;;
    255)
        echo -e "[INF] Plex 状态: ${red}未安装${plain}"
        ;;
    esac

    # 显示当前版本和最新版本
    local current_version=$(get_current_plex_version)
    local latest_version=$(get_latest_plex_version)
    if [[ -n "${current_version}" ]]; then
        echo -e "[INF] Plex 当前版本: ${green}${current_version}${plain}"
    else
        echo -e "[INF] Plex 当前版本: ${red}无法获取${plain}"
    fi
    if [[ -n "${latest_version}" ]]; then
        echo -e "[INF] Plex 最新版本: ${green}${latest_version}${plain}"
    else
        echo -e "[INF] Plex 最新版本: ${red}无法获取${plain}"
    fi
}

# Show Plex running status
show_plex_running_status() {
    plex_status_check
    if [[ $? == ${PLEX_STATUS_RUNNING} ]]; then
        local plex_runTime=$(systemctl status plexmediaserver | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "Plex 运行时长：${plex_runTime}"
    else
        LOGE "Plex 未运行"
    fi
}

# Show Plex enable status
show_plex_enable_status() {
    local plex_enable_status_temp=$(systemctl is-enabled plexmediaserver)
    if [[ "${plex_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] Plex 是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] Plex 是否开机自启: ${red}否${plain}"
    fi
}

# Install Plex
install_plex() {
    LOGD "开始下载 Plex..."
    # Getting the latest version of Plex
    LATEST_PLEX_VERSION=$(get_latest_plex_version)
    PLEX_LINK="https://downloads.plex.tv/plex-media-server-new/${LATEST_PLEX_VERSION}/debian/plexmediaserver_${LATEST_PLEX_VERSION}_${ARCH}.deb"
    cd $(mktemp -d)
    wget -nv "${PLEX_LINK}" -O plexmediaserver.deb
    dpkg -i plexmediaserver.deb
    LOGI "Plex 已完成安装"
}

# Update Plex
update_plex() {
    LOGD "开始更新 Plex..."
    if [[ ! -f "${PLEX_SERVICE}" ]]; then
        LOGE "当前系统未安装 Plex, 更新失败"
        show_menu
        return
    fi
    os_check && arch_check
    install_plex
    LOGI "Plex 已完成升级"
}

# Uninstall Plex
uninstall_plex() {
    LOGD "开始卸载 Plex..."
    dpkg -r plexmediaserver
    rm -rf ${PLEX_LIBRARY_PATH}
    LOGI "卸载 Plex 成功"
}

# Show menu
show_menu() {
    echo -e "
  ${green}Plex 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 Plex
  ${green}2.${plain} 更新 Plex
  ${green}3.${plain} 重启 Plex 服务
  ————————————————
  ${green}4.${plain} 查看 Plex 日志
  ${green}5.${plain} 查看 Plex 报错
  ————————————————
  ${green}6.${plain} 卸载 Plex
  
 "
    show_plex_status
    echo && read -p "请输入选择[0-6]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_plex && show_menu
        ;;
    2)
        update_plex && show_menu
        ;;
    3)
        systemctl restart plexmediaserver && show_menu
        ;;
    4)
        systemctl status plexmediaserver && show_menu
        ;;
    5)
        journalctl -u plexmediaserver -p 3 -xb --no-pager && show_menu
        ;;
    6)
        uninstall_plex && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-6]"
        ;;
    esac
}

main() {
    show_menu
}

main
