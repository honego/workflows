#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

#
# shellcheck disable=all

# 各变量默认值
: "${BINARY_NAME:="gost"}"
TEMP_DIR="$(mktemp -d)"
GITHUB_PROXYS=('' 'https://v6.gh-proxy.org/' 'https://hub.glowp.xyz/' 'https://proxy.vvvv.ee/')

trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

VERSION="${VERSION#v}"

clear() {
    [ -t 1 ] && tput clear 2> /dev/null || printf "\033[2J\033[H" || command clear
}

die() {
    _err_msg >&2 "$(_red "$@")"
    exit 1
}

cd "$TEMP_DIR" > /dev/null 2>&1 || die "Can't access temporary work dir."

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

# 检测是否需要启用Github CDN如能直接连通则不使用
check_cdn() {
    # GITHUB_PROXYS数组第一个元素为空相当于直连
    local CHECK_URL STATUS_CODE

    if is_ci; then
        return
    fi

    for PROXY_URL in "${GITHUB_PROXYS[@]}"; do
        CHECK_URL="${PROXY_URL}${RELEASES_URL}"
        STATUS_CODE="$(command curl --connect-timeout 3 --fail --insecure -Ls --output /dev/null --write-out "%{http_code}" "$CHECK_URL")"
        [ "$STATUS_CODE" = "200" ] && GITHUB_PROXY="$PROXY_URL" && break
    done
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
        armv5*) OS_ARCH="armv5" ;;
        armv6*) OS_ARCH="armv6" ;;
        armv7*) OS_ARCH="armv7" ;;
        loong64) OS_ARCH="loong64" ;;
        mips64*) OS_ARCH="mips64" ;;
        mipsle*) OS_ARCH="mipsle" ;;
        mips) OS_ARCH="mips" ;;
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

do_install() {

}

# https://github.com/go-gost/gost/releases/download/v3.2.6/gost_3.2.6_linux_amd64.tar.gz
curl -Ls https://api.github.com/repos/go-gost/gost/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/'
