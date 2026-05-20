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

FROM base AS dist

LABEL org.opencontainers.image.authors="honeok <i@honeok.com>"

ARG NGINX_VERSION=""
ARG ZSTD_VERSION=""
ARG HEADERS_MORE_VERSION=""

ENV NGINX_VERSION=$NGINX_VERSION
ENV ZSTD_VERSION=$ZSTD_VERSION
ENV HEADERS_MORE_VERSION=$HEADERS_MORE_VERSION

# https://freenginx.org/en/docs/configure.html
# https://github.com/nginx/pkg-oss/blob/master/alpine/Makefile
ARG NGINX_BUILD_ARGS="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_ssl_preread_module \
    --with-compat \
    "

# https://sourceware.org/binutils/docs/ld/Options.html
# -Os                         Optimize for smaller binary size.
# -fstack-clash-protection    Enable Stack Clash protection.
# -Wformat                    Check printf/scanf-style format strings.
# -Werror=format-security     Treat unsafe format-string warnings as errors.
# -g                          Generate debug symbols; usually stripped later.
ARG NGX_CFLAGS="--with-cc-opt='-Os -fstack-clash-protection -Wformat -Werror=format-security -g'"
ENV NGX_CFLAGS=$NGX_CFLAGS

# -Wl,--as-needed             Only link libraries that are actually needed.
# -Wl,-O1                     Enable basic linker optimizations.
# -Wl,--sort-common           Sort common symbols during linking.
# -Wl,-z,relro                Make relocation sections read-only after linking.
# -Wl,-z,now                  Resolve symbols at startup, enables full RELRO.
ARG NGX_LDFLAGS="--with-ld-opt='-Wl,--as-needed,-O1,--sort-common -Wl,-z,relro -Wl,-z,now'"
ENV NGX_LDFLAGS=$NGX_LDFLAGS

RUN set -ex \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
# https://github.com/nginx/pkg-oss/blob/master/alpine/alpine/APKBUILD-base.in
    && apk add --update --no-cache --virtual .build-deps \
        build-base \
        linux-headers \
        openssl-dev \
        pcre2-dev \
        zlib-dev \
    && apk add --no-cache \
        curl \
        gettext-envsubst \
        tzdata \
    && cd /tmp \
    && curl -Ls http://freenginx.org/download/freenginx-${NGINX_VERSION}.tar.gz -o freenginx-${NGINX_VERSION}.tar.gz \
    && tar fxz freenginx-${NGINX_VERSION}.tar.gz \
    && cd freenginx-${NGINX_VERSION} \
    && eval ./configure ${NGINX_BUILD_ARGS} ${NGX_CFLAGS} ${NGX_LDFLAGS} \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make -j$(getconf _NPROCESSORS_ONLN) install
