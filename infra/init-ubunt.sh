#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bash-completion chrony curl dnsutils lrzsz net-tools tar unzip vim wget xz-utils

systemctl disable --now ssh.socket
systemctl mask ssh.socket
systemctl enable --now ssh.service

systemctl disable --now ufw
apt-get autoremove --purge -y ufw

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

# 卸载 Snap
# https://jimyag.com/posts/ubuntusnap-ubuntu-snap-apt
systemctl disable --now snapd.socket
apt-get autoremove --purge -y snapd

# 内核升级
bash <(curl -Ls https://fastly.jsdelivr.net/gh/honeok/tools@master/infra/xanmod.sh) --longterm --mirror

apt-get autoremove --purge -y
