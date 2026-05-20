# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 honeok <i@honeok.com>

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS base

FROM base AS builder

ARG NGINX_VERSION=""
ARG ZSTD_VERSION=""
ARG HEADERS_MORE_VERSION=""

RUN set -ex \
    && apk add --update --no-cache --virtual .build-deps \
        brotli-dev \
        build-base \
        curl \
        git \
        lz4-dev \
        openssl-dev \
        pcre2-dev \
        xz-dev \
        zlib-dev \
    && cd /tmp \
    && curl -Ls http://freenginx.org/download/freenginx-${NGINX_VERSION}.tar.gz -o freenginx-${NGINX_VERSION}.tar.gz \
    && tar fxz freenginx-${NGINX_VERSION}.tar.gz \
    && git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli \
    && curl -Ls https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz -o zstd-${ZSTD_VERSION}.tar.gz \
    && tar fxz zstd-${ZSTD_VERSION}.tar.gz \
    && cd zstd-${ZSTD_VERSION} \
    && make clean \
    && CFLAGS="-fPIC" make -j$(getconf _NPROCESSORS_ONLN) \
    && make -j$(getconf _NPROCESSORS_ONLN) install \
    && cd /tmp \
    && git clone --depth=10 https://github.com/tokers/zstd-nginx-module.git \
    && curl -Ls https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz -o v${HEADERS_MORE_VERSION}.tar.gz \
    && tar fxz v${HEADERS_MORE_VERSION}.tar.gz \
    && cd freenginx-${NGINX_VERSION} \
    && ./configure \
        --with-compat \
        --add-dynamic-module=../ngx_brotli \
        --add-dynamic-module=../zstd-nginx-module \
        --add-dynamic-module=../headers-more-nginx-module-${HEADERS_MORE_VERSION} \
    && make modules \
    && strip objs/*.so \
    && apk del --no-network .build-deps \
    && rm -rf /var/cache/apk/*

# ENV NGINX_VERSION=$NGINX_VERSION
# ENV ZSTD_VERSION=$ZSTD_VERSION
# ENV HEADERS_MORE_VERSION=$HEADERS_MORE_VERSION
