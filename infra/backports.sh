#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025 honeok <i@honeok.com>

# shellcheck disable=SC1091
. /etc/os-release

echo "deb http://deb.debian.org/debian $VERSION_CODENAME-backports main" | tee /etc/apt/sources.list.d/backports.list
apt-get -qq update
apt-get install -y -t "$VERSION_CODENAME-backports" "linux-image-cloud-$(dpkg --print-architecture 2> /dev/null)"
rm -f /etc/apt/sources.list.d/backports.list > /dev/null 2>&1 || true
