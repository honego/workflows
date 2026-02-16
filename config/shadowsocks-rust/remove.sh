#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>

systemctl disable --now shadowsocks.service
rm -f /etc/systemd/system/shadowsocks.service
rm -rf /etc/shadowsocks-rust
