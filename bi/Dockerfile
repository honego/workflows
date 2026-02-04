# syntax=docker/dockerfile:1
# SPDX-License-Identifier: MIT
#
# Description: This dockerfile is used to build the bi image in container.
# Copyright (c) 2025-2026 The JdsGame Authors. All rights reserved.

FROM registry.cn-chengdu.aliyuncs.com/jdsgame/bi-base:v26.2.4-1fb76b4@sha256:60b8afc0f9c547663660b37b158f2ea44f072046dfd52ef7f9cb9e7b76384389
WORKDIR /app
COPY . .
RUN set -ex \
    && install -m 755 docker-entrypoint.sh /docker-entrypoint.sh \
    && rm -f docker-entrypoint.sh .env aerich_env.py \
    && rm -rf /var/cache/apk/* logs/*
EXPOSE 8000
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/docker-entrypoint.sh"]
