#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025 honeok <i@honeok.com>

# shellcheck disable=all

systemctl stop docker.socket
systemctl stop docker.service
systemctl stop containerd.service

apt-get purge -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin containerd.io runc
apt-get autoremove -y --remove

umount -f /var/lib/docker/overlay2/*/merged

rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -rf /run/docker
rm -rf /run/containerd
rm -rf /var/run/docker*

ip link show docker0 > /dev/null 2>&1 && ip link delete docker0

which iptables > /dev/null 2>&1 && {
    iptables -F
    iptables -t nat -F
    iptables -X DOCKER > /dev/null 2>&1
    iptables -X DOCKER-BRIDGE > /dev/null 2>&1
    iptables -X DOCKER-CT > /dev/null 2>&1
    iptables -X DOCKER-FORWARD > /dev/null 2>&1
    iptables -X DOCKER-INTERNAL > /dev/null 2>&1
    iptables -X DOCKER-USER > /dev/null 2>&1
    iptables -t nat -X DOCKER > /dev/null 2>&1
    iptables -t nat -D POSTROUTING -s 172.17.0.0/16 -j MASQUERADE > /dev/null 2>&1
}
