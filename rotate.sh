#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Description: This script is used to rotate web server logs and push message to tgbot and bark server.
# Copyright (c) 2025-2026 honeok <i@honeok.com>

set -eEuo pipefail

# 各变量默认值
: "${SCRIPT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)}"
: "${USER_AGENT:="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"}"

# Variables required for the notification
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
: "${BARK_API_URL:="api.day.app"}"
BARK_API_TOKEN=""

# 设置PATH环境变量
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
# 环境变量用于在debian或ubuntu操作系统中设置非交互式 (noninteractive) 安装模式
export DEBIAN_FRONTEND=noninteractive

die() {
    echo >&2 "Error: $*"
    exit 1
}

get_cmd_path() {
    # arch 云镜像不带 which
    # command -v 包括脚本里面的方法
    # ash 无效
    type -f -p "$1"
}

is_have_cmd() {
    get_cmd_path "$1" > /dev/null 2>&1
}

curl() {
    local rc

    # 添加 --fail 不然404退出码也为0
    # 32位cygwin已停止更新, 证书可能有问题, 添加 --insecure
    # centos7 curl 不支持 --retry-connrefused --retry-all-errors 因此手动 retry
    for ((i = 1; i <= 3; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        rc="$?"
        if [ "$rc" -eq 0 ]; then
            return
        else
            # 403 404 错误或达到重试次数
            if [ "$rc" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$rc"
            fi
            sleep 0.5
        fi
    done
}

install_pkg() {
    for pkg in "$@"; do
        if is_have_cmd dnf; then
            dnf install -y "$pkg"
        elif is_have_cmd yum; then
            yum install -y "$pkg"
        elif is_have_cmd apt-get; then
            apt-get update
            apt-get install -y -q "$pkg"
        elif is_have_cmd apk; then
            apk add --no-cache "$pkg"
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
    local -a deps_pkg
    deps_pkg=("curl" "gzip")

    for pkg in "${deps_pkg[@]}"; do
        if ! is_have_cmd "$pkg" > /dev/null 2>&1; then
            install_pkg "$pkg"
        fi
    done
}

check_srv() {
    local -a web_srvs
    web_srvs=("freenginx" "nginx" "openresty" "tengine")

    for ((i = 0; i < ${#web_srvs[@]}; i++)); do
        if docker ps --filter "name=${web_srvs[i]}" -q | grep -q .; then
            CONTAINER_NAME="${web_srvs[i]}"
            break
        fi
    done

    if [ -z "$CONTAINER_NAME" ]; then
        die "No matching servers found."
    fi
}

# 日志截断
log_rotate() {
    local start_time
    start_time="$(date -u '+%Y-%m-%d-%S' -d '+8 hours')"

    cd "${SCRIPT_DIR:?}" > /dev/null 2>&1 || die "Cannot enter directory."
    mv -f logs/access.log "logs/access_$start_time.log" > /dev/null 2>&1
    mv -f logs/error.log "logs/error_$start_time.log" > /dev/null 2>&1
    docker exec "$CONTAINER_NAME" nginx -s reopen > /dev/null 2>&1
    gzip "logs/access_$start_time.log" > /dev/null 2>&1
    gzip "logs/error_$start_time.log" > /dev/null 2>&1
    find logs -type f -name "*.log.gz" -mtime +7 -exec rm -f {} \; > /dev/null 2>&1
}

send_msg() {
    local message="$1"

    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -Ls -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$message\"}" > /dev/null 2>&1 || true
    fi
    if [ -n "$BARK_API_TOKEN" ]; then
        curl -Ls -X POST "https://$BARK_API_URL/$BARK_API_TOKEN" \
            -A "$USER_AGENT" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$CONTAINER_NAME\",\"body\":\"${message//$'\n'/\\n}\"}" > /dev/null 2>&1 || true
    fi
}

ip_address() {
    local ipv4_addr ipv6_addr
    ipv4_addr="$(curl -Ls -4 http://www.qualcomm.cn/cdn-cgi/trace 2> /dev/null | grep -i '^ip=' | cut -d'=' -f2 || true)"
    ipv6_addr="$(curl -Ls -6 http://www.qualcomm.cn/cdn-cgi/trace 2> /dev/null | grep -i '^ip=' | cut -d'=' -f2 || true)"

    if [[ -n "$ipv4_addr" && "$ipv4_addr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        PUBLIC_IP="$ipv4_addr"
        MASKED_IP="$(awk -F. 'NF==4{print $1"."$2".*.*"} NF!=4{print ""}' <<< "$ipv4_addr")"
        return
    fi
    if [[ -n "$ipv6_addr" && "$ipv6_addr" == *":"* ]]; then
        PUBLIC_IP="[$ipv6_addr]"
        MASKED_IP="$(awk -F: '{print $1":"$2":"$3":*:*:*:*:*"}' <<< "$ipv6_addr")"
        return
    fi
    die "No valid public ip."
}

ip_info() {
    local ip_api

    ip_api="$(curl -Ls "https://api.ipbase.com/v1/json/$PUBLIC_IP")"
    SERVER_CITY="$(sed -En 's/.*"(city_name|cityName|city)":[ ]*"([^"]+)".*/\2/p' <<< "$ip_api")"
}

# 构建消息推送
const_msg() {
    local end_time
    end_time="$(date -u '+%Y-%m-%d %H:%M:%S' -d '+8 hours')"

    ip_address
    ip_info

    send_msg "$end_time
$MASKED_IP $SERVER_CITY
$CONTAINER_NAME complete log rotation!"
}

check_root
check_cmd
check_srv
log_rotate
const_msg
