#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# Description:
# follow bash bible: https://github.com/dylanaraps/pure-bash-bible
# Copyright (c) 2025 honeok <i@honeok.com>

# shellcheck disable=all

set -eE

get_ifaces() {
    local IFACE_PATH IFACE_NAME

    for IFACE_PATH in /sys/class/net/*; do
        [ -e "$IFACE_PATH" ] || continue
        IFACE_NAME="${IFACE_PATH##*/}"
        if [ "$IFACE_NAME" != "lo" ]; then
            echo "$IFACE_NAME"
        fi
    done
}

get_bytes() {
    local TARGET_IFACE RX_PATH TX_PATH RX_BYTES TX_BYTES

    TARGET_IFACE="$1"
    RX_PATH="/sys/class/net/$TARGET_IFACE/statistics/rx_bytes"
    TX_PATH="/sys/class/net/$TARGET_IFACE/statistics/tx_bytes"

    if [ -r "$RX_PATH" ] && [ -r "$TX_PATH" ]; then
        RX_BYTES="$(< "$RX_PATH")"
        TX_BYTES="$(< "$TX_PATH")"
        echo "$RX_BYTES $TX_BYTES"
    fi
}
