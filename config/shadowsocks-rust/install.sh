#!/usr/bin/env bash

# https://1024.day/d/1967

set -eE

die() {
    echo >&2 "Error: $*"
    exit 1
}

is_alpine() {
    [ -f /etc/alpine-release ]
}

check_glibc() {
    if is_alpine; then
        GLIBC="musl"
    else
        GLIBC="gnu"
    fi
}

ss_install() {
    SS_VERSION="$(curl -Ls https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"

    case "$(uname -m 2> /dev/null)" in
    amd64 | x86_64) OS_ARCH="x86_64" ;;
    arm64 | armv8* | aarch64) OS_ARCH="aarch64" ;;
    *) die "unsupported cpu architecture." ;;
    esac

    FILENAMES=("shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz" "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz.sha256")
    for f in "${FILENAMES[@]}"; do
        curl -Ls -O "https://github.com/shadowsocks/shadowsocks-rust/releases/download/$SS_VERSION/$f"
    done
    sha256sum -c "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz.sha256" > /dev/null 2>&1 || die "checksum verification failed."
    tar fJx "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz"
    mv -f ssserver /usr/local/bin/ssserver
}

check_glibc
ss_install
