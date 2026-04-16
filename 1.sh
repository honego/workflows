#!/bin/bash

# 字节格式化
format_bytes() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1

    if [ "$1" -ge 1099511627776 ]; then
        awk "BEGIN { printf \"%.2f TB\n\", $1/1024/1024/1024/1024 }"
    elif [ "$1" -ge 1073741824 ]; then
        awk "BEGIN { printf \"%.2f GB\n\", $1/1024/1024/1024 }"
    elif [ "$1" -ge 1048576 ]; then
        awk "BEGIN { printf \"%.2f MB\n\", $1/1024/1024 }"
    elif [ "$1" -ge 1024 ]; then
        awk "BEGIN { printf \"%.2f KB\n\", $1/1024 }"
    else
        awk "BEGIN { printf \"%.2f B\n\", $1 }"
    fi
}

# 系统信息模块 -> 获取磁盘信息
get_disk_info() {
    local disk_root_path disk_total disk_used disk_free disk_total_bytes disk_used_bytes disk_free_bytes
    local fs_path fs_total_kib fs_used_kib fs_free_kib seen_devices

    # 根分区实际对应的设备路径
    if is_have_cmd findmnt; then
        disk_root_path="$(findmnt -n -o SOURCE / 2> /dev/null)"
    else
        disk_root_path="$(df -kP / 2> /dev/null | awk 'NR==2 {print $1}')"
    fi

    # 整机磁盘空间汇总
    disk_total=0
    disk_used=0
    disk_free=0
    seen_devices=$'\n'
    {
        read -r _
        while read -r fs_path fs_total_kib fs_used_kib fs_free_kib _; do
            [[ "$fs_path" == /dev/* ]] || continue

            case "$seen_devices" in
            *$'\n'"$fs_path"$'\n'*) continue ;;
            esac

            seen_devices+="$fs_path"$'\n'

            ((disk_total += fs_total_kib))
            ((disk_used += fs_used_kib))
            ((disk_free += fs_free_kib))
        done
    } < <(df -kP -x tmpfs -x devtmpfs -x overlay 2> /dev/null)

    # df 这里的值是 1K-blocks 转换为 byte
    disk_total_bytes=$((disk_total * 1024))
    disk_used_bytes=$((disk_used * 1024))
    disk_free_bytes=$((disk_free * 1024))

    # 信息汇总
    RESULT_DISK_PATH="$disk_root_path"
    RESULT_DISK_INFO="$(format_bytes "$disk_used_bytes") / $(format_bytes "$disk_total_bytes")"
    # shellcheck disable=SC2034
    RESULT_DISK_FREE="$(format_bytes "$disk_free_bytes")"
}

echo -e "Space Disk\t: $RESULT_DISK_INFO"
echo -e "Boot Disk\t: $RESULT_DISK_PATH"
