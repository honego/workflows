#!/usr/bin/env bash

# https://1024.day/d/1967

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
    mv -f ssserver /usr/local/bin
}

install_service() {
    tee > /etc/systemd/system/shadowsocks.service <<- EOF
[Unit]
Description=Shadowsocks Rust Server
Documentation=
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ssserver -c $CORE_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now shadowsocks.service
}

check_glibc

install_ss
install_service
