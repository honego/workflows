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

## functions library
get_latest_ver() {
    local img regex

    img="$1"
    regex="${2:-}"

    if [ -z "$regex" ]; then
        case "$img" in
        *pause)
            regex='^[0-9]+(\.[0-9]+){1,2}$'
            ;;
        *kube-apiserver | *kube-controller-manager | *kube-scheduler | *kube-proxy | *coredns/coredns)
            regex='^v[0-9]+(\.[0-9]+){2}$'
            ;;
        *etcd)
            regex='^[0-9]+(\.[0-9]+){2}-[0-9]+$'
            ;;
        esac
    fi
    skopeo list-tags "docker://$img" | jq -r '.Tags[]?' | grep -E -- "$regex" | sort -V | tail -n 1
}

get_current_ver() {
    local img regex

    img="$1"
    regex="${2:-}"

    if [ -z "$regex" ]; then
        case "$img" in
        *pause)
            regex='^[0-9]+(\.[0-9]+){1,2}$'
            ;;
        *kube-apiserver | *kube-controller-manager | *kube-scheduler | *kube-proxy | *coredns/coredns)
            regex='^v[0-9]+(\.[0-9]+){2}$'
            ;;
        *etcd)
            regex='^[0-9]+(\.[0-9]+){2}-[0-9]+$'
            ;;
        esac
    fi
    awk -F: -v img="$img" '$1 == img { print $2; exit }' "$CORE_IMAGES_FILE" | grep -E -- "$regex"
}

ver_gt() {
    local l="$1" c="$2"

    [[ "$l" != "$c" && "$(printf '%s\n' "$l" "$c" | sort -V | tail -n 1)" == "$l" ]]
}

update_img_ver() {
    local img="$1" ver="$2"

    sed -Ei "s#^($(printf '%s\n' "$img" | sed 's#[][(){}.^$*+?|/\\]#\\&#g')):[^[:space:]]+\$#\1:${ver}#" "$CORE_IMAGES_FILE"
    # Pass environment variables to github to trigger automatic commits.
    echo "bump_version=1" >> "$GITHUB_OUTPUT"
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

    latest_ver="$(get_latest_ver "registry.k8s.io/pause")"
    current_ver="$(get_current_ver "registry.k8s.io/pause")"
    ver_gt "$latest_ver" "$current_ver" || return
    _log "Pause update: $current_ver -> $latest_ver"
    update_img_ver "registry.k8s.io/pause" "$latest_ver"
    sync_img "pause" "$latest_ver"
}

# change working dir to script dir
cd "$SCRIPT_DIR" || _die "Failed to change dir to $SCRIPT_DIR"

update_pause

# get_latest_ver "registry.k8s.io/pause"
# get_latest_ver "registry.k8s.io/kube-apiserver"
# get_latest_ver "registry.k8s.io/kube-controller-manager"
# get_latest_ver "registry.k8s.io/kube-scheduler"
# get_latest_ver "registry.k8s.io/kube-proxy"
# get_latest_ver "registry.k8s.io/etcd"
# get_latest_ver "registry.k8s.io/coredns/coredns"

# get_current_ver "registry.k8s.io/pause"
# get_current_ver "registry.k8s.io/kube-apiserver"
# get_current_ver "registry.k8s.io/kube-controller-manager"
# get_current_ver "registry.k8s.io/kube-scheduler"
# get_current_ver "registry.k8s.io/kube-proxy"
# get_current_ver "registry.k8s.io/etcd"
# get_current_ver "registry.k8s.io/coredns/coredns"
