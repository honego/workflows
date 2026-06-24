#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Description: This script is used to rotate web server logs and push message to tgbot and bark server.
# Copyright (c) 2025-2026 honeok <i@honeok.com>

set -eEuo pipefail

# 各变量默认值
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BOT_TOKEN=""
CHAT_ID=""
BARK_URL=""
BARK_TOKEN=""

# 设置PATH环境变量
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
# 环境变量用于在debian或ubuntu操作系统中设置非交互式 (noninteractive) 安装模式
export DEBIAN_FRONTEND=noninteractive

die() {
    echo >&2 "Error: $*"
    exit 1
}

_exists() {
    local _CMD="$1"
    if type "$_CMD" > /dev/null 2>&1; then
        return
    elif command -v "$_CMD" > /dev/null 2>&1; then
        return
    elif which "$_CMD" > /dev/null 2>&1; then
        return
    else
        return 1
    fi
}

curl() {
    local RET
    for ((i = 1; i <= 3; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        RET="$?"
        if [ "$RET" -eq 0 ]; then
            return
        else
            if [ "$RET" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$RET"
            fi
            sleep 1
        fi
    done
}

pkg_install() {
    for pkg in "$@"; do
        if _exists dnf; then
            dnf install -y "$pkg"
        elif _exists yum; then
            yum install -y "$pkg"
        elif _exists apt-get; then
            apt-get update
            apt-get install -y -q "$pkg"
        elif _exists apk; then
            apk add --no-cache "$pkg"
        elif _exists pacman; then
            pacman -S --noconfirm --needed "$pkg"
        else
            die "The package manager is not supported."
        fi
    done
}

check_root() {
    if [ "$EUID" -ne 0 ] || [ "$(id -ru)" -ne 0 ]; then
        die "This script must be run as root."
    fi
}

check_cmd() {
    local -a INSTALL_PKG
    INSTALL_PKG=("curl" "gzip")

    for pkg in "${INSTALL_PKG[@]}"; do
        if ! _exists "$pkg" > /dev/null 2>&1; then
            pkg_install "$pkg"
        fi
    done
}

check_srv() {
    local -a WEB_SRV
    WEB_SRV=("nginx" "openresty" "tengine")
    for ((i = 0; i < ${#WEB_SRV[@]}; i++)); do
        if docker ps --filter "name=${WEB_SRV[i]}" -q | grep -q .; then
            CONTAINER_NAME="${WEB_SRV[i]}"
            break
        fi
    done

    if [ -z "$CONTAINER_NAME" ]; then
        die "No matching servers found."
    fi
}

# 日志截断
log_rotate() {
    local START_TIME
    START_TIME="$(date +%Y-%m-%d-%S)"

    cd "${SCRIPT_DIR:?}" > /dev/null 2>&1 || die "Cannot enter directory."
    mv -f logs/access.log "logs/access_$START_TIME.log" > /dev/null 2>&1
    mv -f logs/error.log "logs/error_$START_TIME.log" > /dev/null 2>&1
    docker exec "$CONTAINER_NAME" nginx -s reopen > /dev/null 2>&1
    gzip "logs/access_$START_TIME.log" > /dev/null 2>&1
    gzip "logs/error_$START_TIME.log" > /dev/null 2>&1
    find logs -type f -name "*.log.gz" -mtime +7 -exec rm -f {} \; > /dev/null 2>&1
}

send_msg() {
    local MESSAGE="$1"

    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        curl -Ls -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"$MESSAGE\"}" > /dev/null 2>&1 || true
    fi
    if [ -n "$BARK_TOKEN" ]; then
        curl -Ls -X POST "https://${BARK_URL:-api.day.app}/$BARK_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$CONTAINER_NAME\",\"body\":\"${MESSAGE//$'\n'/\\n}\"}" > /dev/null 2>&1 || true
    fi
}

ip_address() {
    local IPV4_ADDRESS IPV6_ADDRESS

    IPV4_ADDRESS="$(curl -Ls -4 http://www.qualcomm.cn/cdn-cgi/trace 2> /dev/null | grep -i '^ip=' | cut -d'=' -f2 || true)"
    IPV6_ADDRESS="$(curl -Ls -6 http://www.qualcomm.cn/cdn-cgi/trace 2> /dev/null | grep -i '^ip=' | cut -d'=' -f2 || true)"

    if [[ -n "$IPV4_ADDRESS" && "$IPV4_ADDRESS" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        PUBLIC_IP="$IPV4_ADDRESS"
        MASKED_IP="$(awk -F. 'NF==4{print $1"."$2".*.*"} NF!=4{print ""}' <<< "$IPV4_ADDRESS")"
        return
    fi
    if [[ -n "$IPV6_ADDRESS" && "$IPV6_ADDRESS" == *":"* ]]; then
        PUBLIC_IP="[$IPV6_ADDRESS]"
        MASKED_IP="$(awk -F: '{print $1":"$2":"$3":*:*:*:*:*"}' <<< "$IPV6_ADDRESS")"
        return
    fi

    die "No valid public ip."
}

ip_info() {
    local IP_API

    IP_API="$(curl -Ls "https://api.ipbase.com/v1/json/$PUBLIC_IP")"
    SERVER_CITY="$(sed -En 's/.*"(city_name|cityName|city)":[ ]*"([^"]+)".*/\2/p' <<< "$IP_API")"
}

# 构建消息推送
const_msg() {
    local END_TIME
    END_TIME="$(date -u '+%Y-%m-%d %H:%M:%S' -d '+8 hours')"

    ip_address
    ip_info

    send_msg "$END_TIME
$MASKED_IP $SERVER_CITY
$CONTAINER_NAME complete log rotation!"
}

check_root
check_cmd
check_srv
log_rotate
const_msg
