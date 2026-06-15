#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2026 honeok <i@honeok.com>
#
# Thanks:
# https://ip.v2too.top

set -eEu

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# Cloudflare 基础变量
: "${CLOUDFLARE_API_TOKEN:?missing CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ZONE_ID:?missing CLOUDFLARE_ZONE_ID}"
: "${CLOUDFLARE_RECORD_NAME:?missing CLOUDFLARE_RECORD_NAME}"

curl() {
    local rc

    # 添加 --fail 不然404退出码也为0
    # 32位cygwin已停止更新, 证书可能有问题, 添加 --insecure
    # centos7 curl 不支持 --retry-connrefused --retry-all-errors 因此手动 retry
    for ((i = 1; i <= 5; i++)); do
        command curl --connect-timeout 10 --fail --insecure "$@"
        rc="$?"
        if [ "$rc" -eq 0 ]; then
            return
        else
            # 403 404 错误或达到重试次数
            if [ "$rc" -eq 22 ] || [ "$i" -eq 5 ]; then
                return "$rc"
            fi
            sleep 0.5
        fi
    done
}

# 获取数据源
CLOUDFLARE_BESTIP_API="$(
    curl -Ls https://ip.v2too.top/api/nodes |
        jq -r '
            map(select(.carrier == "ct"))
            | sort_by(-(.speed | tonumber? // 0))
            | .[:5][]
            | .ip
        '
)"

# 获取当前 Cloudflare DNS 记录
CLOUDFLARE_DNS_RECORDS="$(
    curl -Ls -G "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data-urlencode "type=A" \
        --data-urlencode "name=$CLOUDFLARE_RECORD_NAME" \
        --data-urlencode "per_page=1000"
)"

main() {
    local cloudflare_create_body

    while IFS= read -r ip; do
        [ -n "$ip" ] || continue # 跳过空行

        cloudflare_create_body="$(
            jq -n \
                --arg type 4 \
                --arg name "$CLOUDFLARE_RECORD_NAME" \
                --arg content "$ip" \
                --argjson ttl 60 \
                --argjson proxied false \
                '{
                type: $type,
                name: $name,
                content: $content,
                ttl: $ttl,
                proxied: $proxied
            }'
        )"

        curl -Ls -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "$cloudflare_create_body" | jq .
    done <<< "$CLOUDFLARE_BESTIP_API"
}

main "$@"
