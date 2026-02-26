#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>
#
# References:
# https://www.nodeseek.com/post-179931-1
# https://coka.uk/index.php/archives/10/#cl-1

set -eE

# MAJOR.MINOR.PATCH
# shellcheck disable=SC2034
readonly SCRIPT_VERSION='v1.0.0'

_red() {
    printf "\033[31m%b\033[0m\n" "$*"
}

_err_msg() {
    printf "\033[41m\033[1mError\033[0m %b\n" "$*"
}

# 各变量默认值
TEMP_DIR="$(mktemp -d 2> /dev/null)"
: "${GITHUB_REPO:="zhboner/realm"}"
: "${PROJECT_NAME:="${GITHUB_REPO##*/}"}"

# 终止信号捕获
trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

clear() {
    [ -t 1 ] && tput clear 2> /dev/null || printf "\033[2J\033[H" || command clear
}

die() {
    _err_msg >&2 "$(_red "$@")"
    exit 1
}

cd "$TEMP_DIR" > /dev/null 2>&1 || die "Unable to enter the work path."

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

is_glibc() {
    if ldd --version 2>&1 | grep -iq "glibc"; then
        return
    elif getconf GNU_LIBC_VERSION > /dev/null 2>&1; then
        return
    elif [ -n "$(ls /lib/ld-linux* 2> /dev/null)" ] || [ -n "$(ls /lib64/ld-linux* 2> /dev/null)" ]; then
        return
    else
        return 1
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
        case "$(uname -m 2> /dev/null || arch 2> /dev/null)" in
        x86_64) OS_ARCH="x86_64" ;;
        aarch64) OS_ARCH="aarch64" ;;
        *) die "Architecture is not supported." ;;
        esac
    elif is_darwin; then
        case "$(uname -m 2> /dev/null || arch 2> /dev/null)" in
        x86_64) OS_ARCH="x86_64" ;;
        aarch64) OS_ARCH="aarch64" ;;
        *) die "Architecture is not supported." ;;
        esac
    else
        die "Architecture is not supported."
    fi
}

install_realm() {
    VERSION="$(curl -Ls "https://api.github.com/repos/$GITHUB_REPO/releases" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | sort -rV | head -n 1)"

    if is_glibc; then
        GLIBC="gnu"
    else
        GLIBC="musl"
    fi

    curl -L -O "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/$PROJECT_NAME-$OS_ARCH-unknown-$OS_NAME-$GLIBC.tar.gz"
    tar fx "$PROJECT_NAME-$OS_ARCH-unknown-$OS_NAME-$GLIBC.tar.gz" -C /usr/local/bin
}

clear
check_sys
check_arch
install_realm
