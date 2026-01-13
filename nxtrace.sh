#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
#
# Based on from: https://github.com/nxtrace/NTrace-core
#                https://github.com/nxtrace/NTrace-V1
# Description: This script installs or updates the latest nexttrace version, overcoming the official script's restriction to only stable versions.
# Copyright (c) 2025-2026 honeok <i@honeok.com>

set -eEu

_red() { printf "\033[31m%b\033[0m\n" "$*"; }
_green() { printf "\033[92m%b\033[0m\n" "$*"; }
_yellow() { printf "\033[93m%b\033[0m\n" "$*"; }
_err_msg() { printf "\033[41m\033[1mError\033[0m %b\n" "$*"; }
_suc_msg() { printf "\033[42m\033[1mSuccess\033[0m %b\n" "$*"; }
_info_msg() { printf "\033[43m\033[1mInfo\033[0m %b\n" "$*"; }

# Default variable values
TEMP_DIR="$(mktemp -d)"
GITHUB_PROXY='https://v6.gh-proxy.org/'

trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

VERSION="${VERSION:-}"
VERSION="v${VERSION#v}"

# The channel to install from:
#   * stable
#   * dev
DEFAULT_CHANNEL_VALUE="stable"
CHANNEL="${CHANNEL:-}"
if [ -z "$CHANNEL" ]; then
    CHANNEL="$DEFAULT_CHANNEL_VALUE"
fi

clear() {
    [ -t 1 ] && tput clear 2> /dev/null || printf "\033[2J\033[H" || command clear
}

# Print error message and exit
die() {
    _err_msg >&2 "$(_red "$@")"
    exit 1
}

cd "$TEMP_DIR" > /dev/null 2>&1 || die "Can't access temporary work dir."

while [ "$#" -gt 0 ]; do
    case "$1" in
    --channel)
        CHANNEL="$2"
        shift
        ;;
    --debug)
        set -x
        ;;
    --version)
        VERSION="v${2#v}"
        shift
        ;;
    --*)
        _yellow "Illegal option $1"
        ;;
    esac
    shift $(($# > 0 ? 1 : 0))
done

case "$CHANNEL" in
stable)
    DOWNLOAD_URL="https://github.com/nxtrace/NTrace-core"
    RELEASES_URL="https://api.github.com/repos/nxtrace/NTrace-core/releases"
    ;;
dev)
    DOWNLOAD_URL="https://github.com/nxtrace/NTrace-V1"
    RELEASES_URL="https://api.github.com/repos/nxtrace/NTrace-V1/releases"
    ;;
*)
    die "unknown CHANNEL $CHANNEL: use either stable or dev."
    ;;
esac

get_cmd_path() {
    # -f: 忽略shell内置命令和函数, 只考虑外部命令
    # -p: 只输出外部命令的完整路径
    type -f -p "$1"
}

is_have_cmd() {
    get_cmd_path "$1" > /dev/null 2>&1
}

curl() {
    local RET
    # 添加 --fail 不然404退出码也为0
    # 32位cygwin已停止更新, 证书可能有问题, 添加 --insecure
    # centos7 curl 不支持 --retry-connrefused --retry-all-errors 因此手动 retry
    for ((i = 1; i <= 5; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        RET="$?"
        if [ "$RET" -eq 0 ]; then
            return
        else
            # 403 404 错误或达到重试次数
            if [ "$RET" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$RET"
            fi
            sleep 1
        fi
    done
}

is_not_root() {
    [ "$(id -u)" -ne 0 ]
}

check_cdn() {
    if [[ -n "$GITHUB_PROXY" && "$(curl -Ls http://www.qualcomm.cn/cdn-cgi/trace | grep '^loc=' | cut -d= -f2 | grep .)" != "CN" ]]; then
        GITHUB_PROXY=""
    fi
}

is_darwin() {
    [ "$(uname -s 2> /dev/null)" = "Darwin" ]
}

is_linux() {
    [ "$(uname -s 2> /dev/null)" = "Linux" ]
}

is_writable() {
    [ -w "$1" ]
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
        i*86) OS_ARCH="386" ;;
        amd64 | x86_64) OS_ARCH="amd64" ;;
        arm64 | armv8 | aarch64) OS_ARCH="arm64" ;;
        armv7*) OS_ARCH="armv7" ;;
        mips) OS_ARCH="mips" ;;
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

do_install() {
    if is_have_cmd nexttrace; then
        tee >&2 <<- 'EOF'
			Warning: the "nexttrace" command appears to already exist on this system.
            Press Ctrl +C to abort this script if you do not want to overwrite it.
		EOF
        (sleep 5)
    fi

    if is_not_root; then
        die "This installer needs the ability to run commands as root."
    fi

    check_sys
    check_arch

    [ -n "$VERSION" ] || VERSION="$(curl -Ls "${GITHUB_PROXY}${RELEASES_URL}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)"
    curl -L "${GITHUB_PROXY}${DOWNLOAD_URL}/releases/download/${VERSION}/nexttrace_${OS_NAME}_${OS_ARCH}" -o nexttrace || die "NextTrace download failed."

    if is_writable "/usr/local/bin"; then
        BIN_WORKDIR="/usr/local/bin/nexttrace"
    else
        BIN_WORKDIR="/usr/bin/nexttrace"
    fi

    command install -m 755 ./nexttrace "$BIN_WORKDIR"

    if is_have_cmd nexttrace; then
        _suc_msg "$(_green "NextTrace is now available on your system.")"
        "$BIN_WORKDIR" --version
    else
        die "NextTrace installation failed, please try again"
    fi
}

clear
check_cdn
do_install
