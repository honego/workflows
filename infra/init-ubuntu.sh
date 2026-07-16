#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

is_in_china() {
    if [ -z "$COUNTRY" ]; then
        if ! COUNTRY="$(curl -Ls -k http://www.qualcomm.cn/cdn-cgi/trace | grep '^loc=' | cut -d= -f2 | grep .)"; then
            echo "Can not get location."
            exit 1
        fi
        echo "Location: $COUNTRY" >&2
    fi
    [ "$COUNTRY" = CN ]
}

apt-get update
apt-get install -y bash-completion chrony curl dnsutils lrzsz net-tools tar unzip vim wget xz-utils

systemctl disable --now ssh.socket
systemctl mask ssh.socket
systemctl enable --now ssh.service

systemctl disable --now systemd-resolved.service
systemctl mask systemd-resolved.service
rm -f /etc/resolv.conf
if is_in_china; then
    echo "nameserver 223.5.5.5" >> /etc/resolv.conf
    echo "nameserver 119.29.29.29" >> /etc/resolv.conf
else
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# 卸载 UFW
systemctl disable --now ufw
apt-get autoremove --purge -y ufw

# 卸载 Snap
# https://jimyag.com/posts/ubuntusnap-ubuntu-snap-apt
systemctl disable --now snapd.socket
apt-get autoremove --purge -y snapd

# 日志
sed -i -E \
    -e 's|^#?\s*SystemMaxUse=.*|SystemMaxUse=300M|' \
    -e 's|^#?\s*SystemKeepFree=.*|SystemKeepFree=1G|' \
    -e 's|^#?\s*SystemMaxFileSize=.*|SystemMaxFileSize=100M|' \
    -e 's|^#?\s*SystemMaxFiles=.*|SystemMaxFiles=3|' \
    /etc/systemd/journald.conf
systemctl restart systemd-journald

tee -a /etc/security/limits.conf > /dev/null << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072
EOF

# 内核升级
bash <(curl -Ls https://fastly.jsdelivr.net/gh/honeok/tools@master/infra/xanmod.sh) --longterm --mirror

apt-get clean
apt-get autoremove --purge -y
rm -rf /var/lib/apt/lists/*      # 清理索引文件
rm -rf /var/cache/apt/archives/* # 清理安装包残留
