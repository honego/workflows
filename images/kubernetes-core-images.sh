#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>

set -eEuo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

: "${ALIYUN_REGISTRY:?missing ALIYUN_REGISTRY}"
: "${ALIYUN_NAMESPACE:="$GITHUB_REPOSITORY_OWNER"}"

_log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

sync_img() {
    local img="$1" tag="$2"

    docker "pull registry.k8s.io/$img":"$tag"
    docker tag "registry.k8s.io/$img":"$tag" "$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$img":"$tag"
    docker push "$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$img":"$tag"
}

# Bump pause image version
update_pause() {
    local latest_version current_version

    latest_version="$(skopeo list-tags docker://registry.k8s.io/pause | jq -r '.Tags[]' | grep -E '^[0-9]+(\.[0-9]+){1,2}$' | sort -V | tail -n 1)"
    current_version="$(sed -En 's#^(.*/)?pause:([0-9]+(\.[0-9]+){1,2}(-[0-9]+)?)$#\2#p' kubernetes-core-images.md)"

    if [[ "$(printf '%s\n%s\n' "$latest_version" "$current_version" | sort -V | head -n 1)" == "$latest_version" ]]; then
        return
    fi

    _log "Pause update: $current_version -> $latest_version"
    sed -Ei "s#^((.*/)?pause:)[0-9]+(\.[0-9]+){1,2}(-[0-9]+)?\$#\1${latest_version}#" kubernetes-core-images.md
    sync_img "pause" "$latest_version"
}

update_pause
