#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Description:
# Copyright (c) 2026 honeok <i@honeok.com>

set -eEuo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_IMAGES_FILE="./kubernetes-core-images.md"
: "${ALIYUN_REGISTRY:?missing ALIYUN_REGISTRY}"
: "${ALIYUN_NAMESPACE:="$GITHUB_REPOSITORY_OWNER"}"

_die() {
    printf '[%s] %s\n' "$(date '+%F %T')" "ERROR: $*"
    exit 1
}

_log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "INFO: $*"
}

get_latest_ver() {
    local img regex

    img="$1"
    regex="$2"
    skopeo list-tags "docker://$img" | jq -r '.Tags[]?' | grep -E -- "$regex" | sort -V | tail -n 1
}

sync_img() {
    local img="$1" tag="$2"

    docker pull "registry.k8s.io/$img:$tag"
    docker tag "registry.k8s.io/$img:$tag" "$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$img:$tag"
    docker push "$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$img:$tag"
    docker rmi --force "registry.k8s.io/$img:$tag" "$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$img:$tag"
}

# Bump pause image version
update_pause() {
    local latest_ver current_ver

    latest_ver="$(get_latest_ver "registry.k8s.io/pause" '^[0-9]+(\.[0-9]+){1,2}$')"
    current_ver="$(sed -En 's#^(.*/)?pause:([0-9]+(\.[0-9]+){1,2}(-[0-9]+)?)$#\2#p' "$CORE_IMAGES_FILE")"

    if [[ "$(printf '%s\n%s\n' "$latest_ver" "$current_ver" | sort -V | head -n 1)" == "$latest_ver" ]]; then
        return
    fi

    _log "Pause update: $current_ver -> $latest_ver"
    sed -Ei "s#^((.*/)?pause:)[0-9]+(\.[0-9]+){1,2}(-[0-9]+)?\$#\1${latest_ver}#" "$CORE_IMAGES_FILE"
    sync_img "pause" "$latest_ver"
}

# change working dir to script dir
cd "$SCRIPT_DIR" || _die "Failed to change dir to $SCRIPT_DIR"

update_pause

# get_latest_ver "registry.k8s.io/kube-apiserver" '^v[0-9]+(\.[0-9]+){2}$'
# get_latest_ver "registry.k8s.io/etcd" '^[0-9]+(\.[0-9]+){2}-[0-9]+$'
# get_latest_ver "registry.k8s.io/coredns/coredns" '^v[0-9]+(\.[0-9]+){2}$'
