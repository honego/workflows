#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

set -eEuo pipefail

MERGE_BRANCH="${1:?Usage: $0 <branch-name>}"
SRC_TOP="$(git rev-parse --show-toplevel 2> /dev/null)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

pushd "$SRC_TOP" || exit 1

git pull --rebase origin "$CURRENT_BRANCH" 1> /dev/null

git merge --ff-only "$MERGE_BRANCH"

git push origin "$CURRENT_BRANCH"

echo "Success"
popd 1> /dev/null
exit 0
