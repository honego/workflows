#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

# git merge "$MERGE_BRANCH" --no-ff --no-edit --log --signoff

set -eEuo pipefail

MERGE_BRANCH="${1:?Usage: $0 <branch-name>}"
SRC_TOP="$(git rev-parse --show-toplevel 2> /dev/null)"
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD --short | sed 's|.*/||' 2> /dev/null ||
    git ls-remote --symref origin HEAD | sed -n 's|^ref: refs/heads/\([^[:space:]]*\).*|\1|p' 2> /dev/null)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

pushd "$SRC_TOP" || exit 1

git pull --rebase origin "$CURRENT_BRANCH" 1> /dev/null

# Master: ... -- M1 -- M2 -- M3 (HEAD)
#                 \
# Branch:          R1 -- R2 -- R3
RAW_LOG="$(git log --pretty=format:'%h %s' "HEAD..$MERGE_BRANCH")"

# 格式化日志
INDENTED_LOG="  ${RAW_LOG//$'\n'/$'\n'  }"

# 拼接日志
# * branch name:
#   hash message
CHANGELOG="* $MERGE_BRANCH:
$INDENTED_LOG"

# 执行合并但不提交
# --no-ff: 强制生成Merge Commit保留分支历史
# --no-commit: 暂停提交 允许修改Commit Message
git merge "$MERGE_BRANCH" --no-ff --no-commit

# 提交并写入changelog
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    git commit -m "Merge branch '$MERGE_BRANCH'" -m "$CHANGELOG" --signoff
else
    git commit -m "Merge branch '$MERGE_BRANCH' into $CURRENT_BRANCH" -m "$CHANGELOG" --signoff
fi

git push origin "$CURRENT_BRANCH"

echo "Success"
popd 1> /dev/null
exit 0
