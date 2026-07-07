#!/usr/bin/env bash

set -eEu

# Bump pause image version
update_pause() {
    local latest_version current_version

    latest_version="$(skopeo list-tags docker://registry.k8s.io/pause | jq -r '.Tags[]' | grep -E '^[0-9]+(\.[0-9]+){1,2}$' | sort -V | tail -n 1)"
    current_version="$(sed -En 's#^(.*/)?pause:([0-9]+(\.[0-9]+){1,2}(-[0-9]+)?)$#\2#p' kubernetes-core-images.md)"

    if [[ "$(printf '%s\n%s\n' "$latest_version" "$current_version" | sort -V | head -n 1)" == "$latest_version" ]]; then
        return
    fi

    sed -Ei "s#^((.*/)?pause:)[0-9]+(\.[0-9]+){1,2}(-[0-9]+)?\$#\1${latest_version}#" kubernetes-core-images.md
}

update_pause
