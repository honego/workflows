#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>
#
# References:
# https://github.com/shadowsocks/shadowsocks-rust

set -eE

# 各变量默认值
TEMP_DIR="$(mktemp -d)"
CORE_NAME="shadowsocks-rust"
CORE_DIR="/etc/$CORE_NAME"

# 终止信号捕获
trap 'rm -rf "${TEMP_DIR:?}" > /dev/null 2>&1' INT TERM EXIT

die() {
    echo >&2 "Error: $*"
    exit 1
}

cd "$TEMP_DIR" > /dev/null 2>&1 || die "Unable to enter the work path."

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

install_ss() {
    local SS_VERSION OS_ARCH
    local -a FILENAMES

    SS_VERSION="$(curl -Ls https://api.github.com/repos/shadowsocks/$CORE_NAME/releases | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"

    case "$(uname -m 2> /dev/null)" in
    amd64 | x86_64) OS_ARCH="x86_64" ;;
    arm64 | armv8* | aarch64) OS_ARCH="aarch64" ;;
    *) die "unsupported cpu architecture." ;;
    esac

    FILENAMES=("shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz" "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz.sha256")
    for f in "${FILENAMES[@]}"; do
        curl -Ls -O "https://github.com/shadowsocks/$CORE_NAME/releases/download/$SS_VERSION/$f"
    done
    sha256sum -c "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz.sha256" > /dev/null 2>&1 || die "checksum verification failed."
    tar fJx "shadowsocks-$SS_VERSION.$OS_ARCH-unknown-linux-$GLIBC.tar.xz"
    chmod +x ss*
    mv -f ss* /usr/local/bin
}

gen_cfg() {
    mkdir -p "$CORE_DIR" || die "Unable to create directory."
    tee > "$CORE_DIR/config.json" <<- EOF
{
  "server": "::",
  "server_port": 8388,
  "password": "password",
  "timeout": 300,
  "method": "chacha20-ietf-poly1305",
  "mode": "tcp_and_udp"
}
EOF
}

install_service() {
    tee > /etc/systemd/system/shadowsocks.service <<- EOF
[Unit]
Description=Shadowsocks-rust Server Service
Documentation=https://github.com/shadowsocks/shadowsocks-rust
After=network.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
DynamicUser=yes
ExecStart=/usr/local/bin/ssservice server --log-without-time -c $CORE_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now shadowsocks.service
}

check_glibc

install_ss
gen_cfg
install_service
