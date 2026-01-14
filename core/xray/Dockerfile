# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2025 honeok <i@honeok.com>

FROM alpine:3.23.2@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 AS base # 3.23.2

FROM base AS dist
LABEL maintainer="honeok <i@honeok.com>"
ARG TARGETARCH
ARG TARGETVARIANT
ARG TZ=Asia/Shanghai
RUN set -ex \
    && apk add --no-cache --update bash ca-certificates tzdata
COPY xray-${TARGETARCH}${TARGETVARIANT} /usr/local/bin/xray
ENV TZ=$TZ
ENTRYPOINT ["/usr/local/bin/xray"]
