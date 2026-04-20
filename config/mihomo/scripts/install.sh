#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>

set -eE

# MAJOR.MINOR.PATCH
# shellcheck disable=SC2034
readonly SCRIPT_VERSION='v1.0.0'

_red() {
    printf "\033[31m%b\033[0m\n" "$*"
}

_yellow() {
    printf "\033[33m%b\033[0m\n" "$*"
}

_err_msg() {
    printf "\033[41m\033[1mError\033[0m %b\n" "$*"
}

# 各变量默认值
GITHUB_PROXY="https://v6.gh-proxy.org/"
GITHUB_REPO="MetaCubeX/mihomo"
GITHUB_REPO_URL="https://github.com/$GITHUB_REPO"
PROJECT_NAME="${GITHUB_REPO##*/}"
TEMP_DIR="$(mktemp -d 2> /dev/null)"

trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

VERSION="${VERSION#v}"

clear() {
    [ -t 1 ] && tput clear 2> /dev/null || printf "\033[2J\033[H" || command clear
}

# https://unix.stackexchange.com/questions/604260/best-range-for-custom-exit-code-in-linux
die() {
    local rc

    rc="${2:-"169"}"
    _err_msg >&2 "$(_red "$1")"
    exit "$rc"
}

get_cmd_path() {
    type -f -p "$1"
}

is_have_cmd() {
    get_cmd_path "$1" > /dev/null 2>&1
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
        else
            die "The package manager is not supported."
        fi
    done
}

curl() {
    local rc

    is_have_cmd curl || install_pkg curl

    # 添加 --fail 不然404退出码也为0
    # 32位cygwin已停止更新, 证书可能有问题, 添加 --insecure
    # centos7 curl 不支持 --retry-connrefused --retry-all-errors 因此手动 retry
    for ((i = 1; i <= 5; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        rc="$?"
        if [ "$rc" -eq 0 ]; then
            return
        else
            # 403 404 错误或达到重试次数
            if [ "$rc" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$rc"
            fi
            sleep 1
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
    if [ -z "$GEOIP_COUNTRY_CODE" ]; then
        if ! GEOIP_COUNTRY_CODE="$(curl -L http://www.qualcomm.cn/cdn-cgi/trace | grep '^loc=' | cut -d= -f2 | grep .)"; then
            die "Can not get location."
        fi
        echo >&2 "Location: $GEOIP_COUNTRY_CODE"
    fi
    [ "$GEOIP_COUNTRY_CODE" = CN ]
}

has_ipv4() {
    ip -4 route get 151.101.65.1 > /dev/null 2>&1
}

has_ipv6() {
    ip -6 route get 2a04:4e42:200::485 > /dev/null 2>&1
}

check_cdn() {
    if is_in_china; then
        return
    elif ! has_ipv4 && has_ipv6; then
        return
    else
        GITHUB_PROXY=""
    fi
}

check_sys() {
    if is_linux; then
        OS_NAME="linux"
    elif is_darwin; then
        OS_NAME="darwin"
    else
        die "System is not supported."
    fi
}

check_arch() {
    if is_linux; then
        case "$(uname -m 2> /dev/null)" in
        i?86) OS_ARCH="386" ;;
        amd64 | x86_64) OS_ARCH="amd64" ;;
        arm64 | armv8 | aarch64) OS_ARCH="arm64" ;;
        armv5*) OS_ARCH="armv5" ;;
        armv6*) OS_ARCH="armv6" ;;
        armv7*) OS_ARCH="armv7" ;;
        ppc64le) OS_ARCH="ppc64le" ;;
        riscv64) OS_ARCH="riscv64" ;;
        s390x) OS_ARCH="s390x" ;;
        *) die "Architecture is not supported." ;;
        esac
    elif is_darwin; then
        case "$(uname -m 2> /dev/null)" in
        amd64 | x86_64) OS_ARCH="amd64" ;;
        arm64 | armv8 | aarch64) OS_ARCH="arm64" ;;
        *) die "Architecture is not supported." ;;
        esac
    else
        die "Architecture is not supported."
    fi
}

download_mihomo() {
    [ -n "$VERSION" ] || VERSION="$(curl -Ls "${GITHUB_PROXY}https://api.github.com/repos/$GITHUB_REPO/releases" 2>&1 | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | sort -rV | head -n 1)"
    curl -L -O "$GITHUB_PROXY$GITHUB_REPO_URL/releases/download/v$VERSION/$PROJECT_NAME-$OS_NAME-$OS_ARCH-v$VERSION.gz" || die "$PROJECT_NAME download failed."
    gzip -cdf "$PROJECT_NAME-$OS_NAME-$OS_ARCH-v$VERSION.gz" > "$PROJECT_NAME"
    chmod +x "$PROJECT_NAME"
}

install_mihomo_svc() {
    if [ ! -f /etc/systemd/system/mihomo.service ]; then
        tee /etc/systemd/system/mihomo.service > /dev/null << 'EOF'
[Unit]
Description=Mihomo Service, Another Clash Kernel.
Documentation=https://wiki.metacubex.one
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable --now mihomo
    fi
}

pushd "$TEMP_DIR" > /dev/null 2>&1 || die "Can't access temporary work dir."

while [ "$#" -gt 0 ]; do
    case "$1" in
    --debug)
        set -x
        ;;
    --version)
        VERSION="${2#v}"
        shift
        ;;
    --*)
        _yellow "Illegal option $1"
        ;;
    esac
    shift $(($# > 0 ? 1 : 0))
done

check_sys
check_arch
check_cdn

install_mihomo
