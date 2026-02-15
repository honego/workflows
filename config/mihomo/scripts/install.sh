#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>

# References:
# https://github.com/MetaCubeX/Meta-Docs

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
: "${GITHUB_REPO:="MetaCubeX/mihomo"}"
: "${PROJECT_NAME:="${GITHUB_REPO##*/}"}"
: "${DOWNLOAD_URL:="https://github.com/$GITHUB_REPO"}"
: "${RELEASES_URL:="$DOWNLOAD_URL/releases"}"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

VERSION="${VERSION#v}"

clear() {
    [ -t 1 ] && tput clear 2> /dev/null || printf "\033[2J\033[H" || command clear
}

# https://unix.stackexchange.com/questions/604260/best-range-for-custom-exit-code-in-linux
die() {
    local RC
    RC="${2:-"169"}"
    _err_msg >&2 "$(_red "$1")"
    exit "$RC"
}

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

get_cmd_path() {
    # -f: 忽略shell内置命令和函数, 只考虑外部命令
    # -p: 只输出外部命令的完整路径
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
        elif is_have_cmd pacman; then
            pacman -S --noconfirm --needed "$pkg"
        else
            die "The package manager is not supported."
        fi
    done
}

curl() {
    local RET

    is_have_cmd curl || install_pkg curl

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

is_darwin() {
    [ "$(uname -s 2> /dev/null)" = "Darwin" ]
}

is_linux() {
    [ "$(uname -s 2> /dev/null)" = "Linux" ]
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
        case "$(uname -m 2> /dev/null || arch 2> /dev/null)" in
        amd64 | x86_64) OS_ARCH="amd64" ;;
        arm64 | armv8 | aarch64) OS_ARCH="arm64" ;;
        *) die "Architecture is not supported." ;;
        esac
    else
        die "Architecture is not supported."
    fi
}

do_install_service() {
    curl -Ls -O https://fastly.jsdelivr.net/gh/MetaCubeX/mihomo@Meta/.github/release/mihomo.service

    sed -i 's#ExecStart=.*/mihomo -d /etc/mihomo#ExecStart=/usr/local/bin/mihomo -d /etc/mihomo#' mihomo.service
    install -m 0644 mihomo.service /etc/systemd/system/mihomo.service
    systemctl daemon-reload
    systemctl enable mihomo --now
}

do_install() {
    check_sys
    check_arch

    [ -n "$VERSION" ] || VERSION="$(curl -Ls "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>&1 | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    curl -L -O "$RELEASES_URL/download/v$VERSION/$PROJECT_NAME-$OS_NAME-$OS_ARCH-v$VERSION.gz" || die "$PROJECT_NAME download failed."
    gzip -cdf "$PROJECT_NAME-$OS_NAME-$OS_ARCH-v$VERSION.gz" > "$PROJECT_NAME"
}

pushd "$TEMP_DIR" > /dev/null 2>&1 || die "Can't access temporary work dir."

do_install
