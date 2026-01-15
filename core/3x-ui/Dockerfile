# Description: This dockerfile is used to build the 3x-ui image in container.
#
# Copyright (c) 2025 honeok <i@honeok.com>
# SPDX-License-Identifier: GPL-2.0
#
# References:
# https://docs.docker.com/build/building/multi-platform

FROM golang:1.25-alpine@sha256:ac09a5f469f307e5da71e766b0bd59c9c49ea460a528cc3e6686513d64a6f1fb AS builder
LABEL maintainer="honeok <i@honeok.com>"
WORKDIR /go/src/github.com/MHSanaei/3x-ui
ARG XRAY_VERSION
ARG XUI_TAG
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
COPY --chmod=755 build.sh .

RUN set -ex \
    && apk add --update --no-cache build-base curl gcc git \
    && ./build.sh "$XRAY_VERSION" \
    && git clone --depth=1 --branch "$XUI_TAG" https://github.com/MHSanaei/3x-ui.git . \
    && go build -a -trimpath -ldflags "-s -w -linkmode external -extldflags '-static'" -o /go/bin/3x-ui ./main.go

FROM alpine:3.23.2@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 AS dist
LABEL maintainer="honeok <i@honeok.com>"
WORKDIR /usr/local/bin
ARG TARGETARCH
COPY --from=builder /go/bin/3x-ui /usr/local/bin/3x-ui
COPY --from=builder /tmp/xray/xray /usr/local/bin/bin/xray-linux-${TARGETARCH}
COPY --chmod=755 docker-entrypoint.sh /
COPY *.dat /usr/local/bin/bin/
RUN set -ex \
    && apk add --update --no-cache bash ca-certificates curl tzdata
VOLUME ["/etc/x-ui"]
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/docker-entrypoint.sh"]
