#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

set -eEuo pipefail

PROJECT_TOP="$(git rev-parse --show-toplevel 2> /dev/null)"
REMOTE="${REMOTE:-origin}"
SRC_BRANCH="${1:-release}"
DST_BRANCH="${2:-master}"

cd "$PROJECT_TOP"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: working tree or index is not clean."
    exit 1
fi

git fetch "$REMOTE" --prune
git switch "$DST_BRANCH"
git reset --hard "$REMOTE/$SRC_BRANCH"
git push --force-with-lease "$REMOTE" "$DST_BRANCH"
echo "Success: $DST_BRANCH has been overwritten by $SRC_BRANCH"
