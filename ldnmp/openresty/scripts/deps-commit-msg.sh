#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>
#                           <honeok7@gmail.com>

set -eE

generate_commit_msg() {
    if git diff --quiet && git diff --cached --quiet; then
        return
    fi

    git diff -U0 | grep -E "^\+\+\+ b/|[-+]ARG " | awk '
    /^\+\+\+ b\// {
        if ($0 ~ /\/edge\//) cat = "edge"
        else if ($0 ~ /\/stable\//) cat = "stable"
        else if ($0 ~ /\/luarocks\//) cat = "luarocks"
        else cat = "other"
        next
    }
    {
        symbol = substr($1, 1, 1)
        split($0, a, "\"")
        var_part = a[1]; val = a[2]
        var = var_part
        sub(/^[-+]ARG /, "", var); sub(/[= ]+$/, "", var)

        if (symbol == "-") old[cat, var] = val
        else new[cat, var] = val
    }
    END {
        n = split("edge luarocks stable", order, " ")
        first_section = 1

        for (i=1; i<=n; i++) {
            c = order[i]; first_in_cat = 1
            for (combined in old) {
                split(combined, sep, SUBSEP)
                if (sep[1] == c) {
                    v = sep[2]
                    if (v ~ /PATCH_VERSION/) continue

                    if (first_in_cat) {
                        if (!first_section) printf "\n"
                        printf "%s:\n", c
                        first_in_cat = 0; first_section = 0
                    }

                    o = old[combined]; n = new[combined]
                    if (length(o) > 20) o = substr(o, 1, 8)
                    if (length(n) > 20) n = substr(n, 1, 8)

                    printf "- Updates `%s` from %s to %s\n", v, o, n
                }
            }
        }
    }'
}

generate_commit_msg
