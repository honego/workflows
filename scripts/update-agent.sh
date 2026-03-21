#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

set -eE

# 各变量默认值
TEMP_DIR="$(mktemp -d 2> /dev/null)"
CORE_DIR="/opt/nezha/agent"
CORE_NAME="nezha-agent"
GITHUB_PROXY="https://v6.gh-proxy.org/"

# 终止信号捕获
trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

cd "$TEMP_DIR" > /dev/null 2>&1 || exit 1

check_root() {
    if [ "$EUID" -ne 0 ] || [ "$(id -ru)" -ne 0 ]; then
        exit 1
    fi
}

curl() {
    local RC

    # 添加 --fail 不然404退出码也为0
    # 32位cygwin已停止更新, 证书可能有问题, 添加 --insecure
    # centos7 curl 不支持 --retry-connrefused --retry-all-errors 因此手动 retry
    for ((i = 1; i <= 5; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        RC="$?"
        if [ "$RC" -eq 0 ]; then
            return
        else
            # 403 404 错误或达到重试次数
            if [ "$RC" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$RC"
            fi
            sleep 0.5
        fi
    done
}

is_darwin() {
    [ "$(uname -s 2> /dev/null)" = "Darwin" ]
}

is_linux() {
    [ "$(uname -s 2> /dev/null)" = "Linux" ]
}

is_in_china() {
    if [ -z "$COUNTRY" ]; then
        # www.cloudflare.com/dash.cloudflare.com 国内访问的是美国服务器 而且部分地区被墙
        # www.prologis.cn
        # www.autodesk.com.cn
        # www.keysight.com.cn
        if ! COUNTRY="$(curl -L http://www.qualcomm.cn/cdn-cgi/trace | grep '^loc=' | cut -d= -f2 | grep .)"; then
            exit 1
        fi
        echo >&2 "Location: $COUNTRY"
    fi
    [ "$COUNTRY" = CN ]
}

check_sys() {
    if is_linux; then
        OS_NAME="linux"
    elif is_darwin; then
        OS_NAME="darwin"
    else
        exit 1
    fi
}

check_arch() {
    case "$(uname -m 2> /dev/null)" in
    386 | i*86) OS_ARCH="386" ;;
    amd64 | x86_64) OS_ARCH="amd64" ;;
    arm64 | armv8 | aarch64) OS_ARCH="arm" ;;
    *) exit 1 ;;
    esac
}

check_cdn() {
    if is_in_china; then
        return
    else
        GITHUB_PROXY=""
    fi
}

# 更新内核
update_core() {
    local LATEST_VER CURRENT_VER

    LATEST_VER="$(curl -Ls "${GITHUB_PROXY}https://api.github.com/repos/nezhahq/agent/releases" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | sort -rV | head -n 1)"
    CURRENT_VER="$(eval "$CORE_DIR/$CORE_NAME" -v | awk '{print $3}')"

    if [[ "$(printf '%s\n%s\n' "$LATEST_VER" "$CURRENT_VER" | sort -V | head -n1)" == "$LATEST_VER" ]]; then
        return
    fi

    curl -L -O "${GITHUB_PROXY}https://github.com/nezhahq/agent/releases/download/v$LATEST_VER/${CORE_NAME}_${OS_NAME}_${OS_ARCH}.zip"
    curl -L -O "${GITHUB_PROXY}https://github.com/nezhahq/agent/releases/download/v$LATEST_VER/checksums.txt"
    sha256sum --ignore-missing -c checksums.txt > /dev/null 2>&1 || exit 1

    unzip -qo "${CORE_NAME}_${OS_NAME}_${OS_ARCH}.zip" -d "$CORE_DIR"
    chmod +x "$CORE_DIR/$CORE_NAME" > /dev/null 2>&1
}

restart_agent() {
    local RESTART_CMD

    if [ -f /etc/alpine-release ]; then
        RESTART_CMD="rc-service nezha-agent restart"
    else
        RESTART_CMD="systemctl restart nezha-agent.service --quiet"
    fi

    for ((i = 1; i <= 3; i++)); do
        if eval "$RESTART_CMD" > /dev/null 2>&1; then
            return
        fi
        if [ "$i" -lt 3 ]; then
            sleep 1
        fi
    done

    exit 1
}

check_root
check_sys
check_arch
check_cdn
update_core
restart_agent
