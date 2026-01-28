#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

# git merge "$BRANCH" --no-ff --no-edit --log --signoff

set -eEu

BRANCH="${1:?Usage: $0 <branch-name>}"

# Master: ... -- M1 -- M2 -- M3 (HEAD)
#                 \
# Branch:          R1 -- R2 -- R3
CHANGELOG="$(git log --pretty=format:'* %h %s' "HEAD..$BRANCH")"

# 执行合并但不提交
# --no-ff: 强制生成Merge Commit 保留分支历史
# --no-commit: 暂停提交 允许修改Commit Message
git merge "$BRANCH" --no-ff --no-commit

# 提交并写入changelog
git commit -m "Merge branch '$BRANCH'" -m "$CHANGELOG" --signoff
