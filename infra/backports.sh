#!/bin/bash

# shellcheck source=/dev/null
. /etc/os-release

echo "deb http://deb.debian.org/debian $VERSION_CODENAME-backports main" | tee /etc/apt/sources.list.d/backports.list
apt-get update
apt-get install -y -t "$VERSION_CODENAME-backports" "linux-image-cloud-$(dpkg --print-architecture)"
rm -f /etc/apt/sources.list.d/backports.list
