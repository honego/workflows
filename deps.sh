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

bump_edge() {
    local EDGE_OPENSSL_VERSION LOCAL_OPENSSL_VERSION EDGE_PCRE2_VERSION LOCAL_PCRE2_VERSION PCRE_SHA512

    cd edge > /dev/null 2>&1 || exit 169

    EDGE_OPENSSL_VERSION="$(curl -Ls https://api.github.com/repos/teddysun/openresty/contents/patches | grep '"name"' | cut -d '"' -f4 | grep '^openssl' | sort -V | tail -n1 | cut -d- -f2)"
    LOCAL_OPENSSL_VERSION="$(grep -o 'RESTY_OPENSSL_VERSION="[^"]*"' Dockerfile | head -n1 | cut -d'"' -f2)"
    if [ -n "$EDGE_OPENSSL_VERSION" ] && [ "$EDGE_OPENSSL_VERSION" != "$LOCAL_OPENSSL_VERSION" ]; then
        sed -i "s#RESTY_OPENSSL_VERSION=\"[^\"]*\"#RESTY_OPENSSL_VERSION=\"$EDGE_OPENSSL_VERSION\"#" Dockerfile
        sed -i "s#RESTY_OPENSSL_PATCH_VERSION=\"[^\"]*\"#RESTY_OPENSSL_PATCH_VERSION=\"$EDGE_OPENSSL_VERSION\"#" Dockerfile
    fi

    EDGE_PCRE2_VERSION="$(curl -Ls https://raw.githubusercontent.com/teddysun/openresty/main/util/build-win32.sh | sed -n 's/^PCRE=.*-\([0-9.]\+\).*/\1/p' | head -n 1)"
    LOCAL_PCRE2_VERSION="$(grep -o 'RESTY_PCRE_VERSION="[^"]*"' Dockerfile | head -n1 | cut -d'"' -f2)"
    if [ -n "$EDGE_PCRE2_VERSION" ] && [ "$EDGE_PCRE2_VERSION" != "$LOCAL_PCRE2_VERSION" ]; then
        sed -i "s#RESTY_PCRE_VERSION=\"[^\"]*\"#RESTY_PCRE_VERSION=\"$EDGE_PCRE2_VERSION\"#" Dockerfile

        # 更新SHA512
        curl -Ls -O "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$EDGE_PCRE2_VERSION/pcre2-$EDGE_PCRE2_VERSION.tar.gz"
        PCRE_SHA512="$(sha512sum "pcre2-$EDGE_PCRE2_VERSION.tar.gz" | awk '{print $1}')"
        rm -f "pcre2-$EDGE_PCRE2_VERSION.tar.gz" || exit 169
        sed -i "s#RESTY_PCRE_SHA512=\"[^\"]*\"#RESTY_PCRE_SHA512=\"$PCRE_SHA512\"#" Dockerfile
    fi

    cd ..
}

cd "$PARENT_DIR" > /dev/null 2>&1 || exit 169
bump_stable
bump_edge
