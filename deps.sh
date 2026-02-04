#!/usr/bin/env bash

set -eE

SCRIPT="$(realpath "$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)/$(basename "${BASH_SOURCE:-$0}")")"
SCRIPT_DIR="$(dirname "$(realpath "$SCRIPT")")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 官方稳定版
# https://github.com/openresty/docker-openresty
bump_stable() {
    local OFFICIAL VAR OFFICIAL_VALUE LOCAL_VALUE
    OFFICIAL="$(curl -Ls https://raw.githubusercontent.com/openresty/docker-openresty/master/alpine/Dockerfile)"

    cd stable > /dev/null 2>&1 || exit 169
    for VAR in \
        RESTY_OPENSSL_VERSION \
        RESTY_OPENSSL_PATCH_VERSION \
        RESTY_PCRE_VERSION \
        RESTY_PCRE_SHA256; do
        OFFICIAL_VALUE="$(grep -o "$VAR=\"[^\"]*\"" <<< "$OFFICIAL" | cut -d'"' -f2)"
        LOCAL_VALUE="$(grep -o "$VAR=\"[^\"]*\"" Dockerfile | cut -d'"' -f2)"

        [ "$OFFICIAL_VALUE" = "$LOCAL_VALUE" ] && continue
        sed -i "s/$VAR=\"$LOCAL_VALUE\"/$VAR=\"$OFFICIAL_VALUE\"/" Dockerfile
    done
    cd ..
}

cd "$PARENT_DIR" > /dev/null 2>&1 || exit 169
bump_stable
