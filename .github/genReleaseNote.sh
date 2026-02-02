#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

set -eEuxo pipefail

PREVIOUS_VERSION="$1"
CURRENT_VERSION="$2"

((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) ||
    {
        echo >&2 "Error: bash >= 4.4 required."
        exit 69
    }

[ -n "$PREVIOUS_VERSION" ] && [ -n "$CURRENT_VERSION" ] || {
    echo "Usage: $0 <PREVIOUS_VERSION> <CURRENT_VERSION>"
    exit 64
}

generate_notes() {
    local TITLE REGULAR LOGS

    TITLE="$1"
    REGULAR="$2"
    LOGS="$(git log --reverse --pretty=format:"* %h %s by @%an" --grep="$REGULAR" -i "$PREVIOUS_VERSION..$CURRENT_VERSION" 2> /dev/null | awk '!seen[$0]++')"

    if [ -n "$LOGS" ]; then
        echo "## $TITLE"
        echo "$LOGS"
        echo ""
    fi
}

{
    generate_notes "What's Changed" "^feat"
    generate_notes "BUG & Fix" "^fix"
    generate_notes "Maintenance" "^chore\|^docs\|^refactor\|^ci\|^test"
    echo "**Full Changelog**: https://github.com/$GITHUB_REPOSITORY/compare/$PREVIOUS_VERSION...$CURRENT_VERSION"
} > release.md
