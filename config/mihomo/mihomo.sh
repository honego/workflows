#!/usr/bin/env bash

# shellcheck disable=all

# grep -hIor --exclude="*.md" "https://[^\"']*jsdelivr\.net[^\"']*" . | sort -u

set -eE

case "$(uname -m 2> /dev/null)" in
esac

VERSION="$(curl -Ls https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')"
