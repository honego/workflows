#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Description:
# Copyright (c) 2025-2026 honeok <i@honeok.com>
#
# References:
# https://github.com/LemonBench/LemonBench
# https://github.com/masonr/yet-another-bench-script
# https://github.com/spiritLHLS/ecs

_red() {
    printf "\033[31m%b\033[0m\n" "$*"
}

_green() {
    printf "\033[32m%b\033[0m\n" "$*"
}

_yellow() {
    printf "\033[33m%b\033[0m\n" "$*"
}

_cyan() {
    printf "\033[36m%b\033[0m\n" "$*"
}

get_cmd_path() {
    # arch 云镜像不带 which
    # command -v 包括脚本里面的方法
    # ash 无效
    type -f -p "$1"
}

is_have_cmd() {
    get_cmd_path "$1" > /dev/null 2>&1
}

# 分隔符打印
print_sep() {
    local sep
    [ -n "$1" ] && [ -n "$2" ] || return 1

    printf -v sep '%*s' "$1" ''
    printf '%s\n' "${sep// /$2}"
}

# 标题打印
print_title() {
    local LC_CTYPE title line_width title_width pad_width left_width right_width index current_char current_code dash_buffer

    LC_CTYPE=C.UTF-8 # UTF-8 按字符截取
    title="$*"       # 接收函数全部参数作为标题文本
    line_width=60    # 基准宽度
    title_width=0    # 初始化标题显示宽度
    pad_width=0      # 初始化左右两侧 '-' 的总宽度
    left_width=0     # 初始化左侧 '-' 数量
    right_width=0    # 初始化右侧 '-' 数量
    index=0          # 初始化循环下标
    current_char=''  # 初始化当前字符
    current_code=0   # 初始化当前字符编码值
    dash_buffer=''   # 初始化横杠缓冲区

    # 计算标题显示宽度
    for ((index = 0; index < ${#title}; index++)); do
        current_char="${title:index:1}"
        printf -v current_code '%d' "'$current_char"

        if ((current_code >= 0 && current_code <= 127)); then
            ((title_width += 1))
        else
            ((title_width += 2))
        fi
    done

    # 标题左右各预留 1 个空格
    if ((title_width + 2 > line_width)); then
        printf '%s\n' "$title"
        return
    fi

    # 按 60 个 '-' 的基准宽度计算左右两边需要补多少个 '-'
    pad_width=$((line_width - title_width - 2))
    left_width=$((pad_width / 2))
    right_width=$((pad_width - left_width))

    # 输出左侧 '-' 空格 标题 空格
    printf -v dash_buffer '%*s' "$left_width" ''
    printf '%s %s ' "${dash_buffer// /-}" "$title"

    # 输出右侧 '-' 并换行
    printf -v dash_buffer '%*s' "$right_width" ''
    printf '%s\n' "${dash_buffer// /-}"
}

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

## 基本系统信息
# 系统信息模块 -> 获取CPU信息
get_cpu_info() {
    local cpu_model cpu_cores cpu_freq
    local cpu_l1_cache cpu_l2_cache cpu_l3_cache cache_level cache_type cache_size cache_bytes
    local cpu_aes cpu_virt

    # CPU型号 核心数 频率
    cpu_model="$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
    cpu_cores="$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo 2> /dev/null)"
    cpu_freq="$(awk -F: '/cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"

    # CPU缓存 L1 合并, L2 / L3 按 sum of all 合并
    cpu_l1_cache=0
    cpu_l2_cache=0
    cpu_l3_cache=0
    while IFS='|' read -r cache_level cache_type cache_size; do
        case "$cache_size" in
        *K) cache_bytes=$((${cache_size%K} * 1024)) ;;
        *M) cache_bytes=$((${cache_size%M} * 1024 * 1024)) ;;
        *G) cache_bytes=$((${cache_size%G} * 1024 * 1024 * 1024)) ;;
        *) cache_bytes="$cache_size" ;;
        esac

        case "$cache_level:$cache_type" in
        1:Data | 1:Instruction)
            cpu_l1_cache=$((cpu_l1_cache + cache_bytes))
            ;;
        2:Unified)
            cpu_l2_cache=$((cpu_l2_cache + cache_bytes))
            ;;
        3:Unified)
            cpu_l3_cache=$((cpu_l3_cache + cache_bytes))
            ;;
        esac
    done < <(
        for cache_path in /sys/devices/system/cpu/cpu*/cache/index*; do
            [ -r "$cache_path/level" ] || continue
            [ -r "$cache_path/type" ] || continue
            [ -r "$cache_path/size" ] || continue
            [ -r "$cache_path/shared_cpu_list" ] || continue
            printf '%s|%s|%s|%s\n' \
                "$(< "$cache_path/level")" \
                "$(< "$cache_path/type")" \
                "$(< "$cache_path/size")" \
                "$(< "$cache_path/shared_cpu_list")"
        done | sort -u | cut -d'|' -f1-3
    )

    cpu_aes="$(grep -i 'aes' /proc/cpuinfo)"       # 检查 AES-NI 指令集支持
    cpu_virt="$(grep -Ei 'vmx|svm' /proc/cpuinfo)" # 检查 VM-x/AMD-V 支持

    # 信息汇总
    RESULT_CPU_MODEL="$cpu_model"
    RESULT_CPU_CORES="$cpu_cores"
    RESULT_CPU_FREQ="$cpu_freq"
    RESULT_CPU_CACHEL1="$(format_bytes "$cpu_l1_cache")"
    RESULT_CPU_CACHEL2="$(format_bytes "$cpu_l2_cache")"
    RESULT_CPU_CACHEL3="$(format_bytes "$cpu_l3_cache")"
    RESULT_CPU_AES="$cpu_aes"
    RESULT_CPU_VIRT="$cpu_virt"
}

# 系统信息模块 -> 获取内存及Swap信息
get_mem_info() {
    local mem_total mem_available mem_free mem_buffers mem_cached mem_used mem_total_bytes mem_used_bytes
    local swap_total swap_free swap_used swap_total_bytes swap_used_bytes

    mem_total="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"         # 总物理内存
    mem_available="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2> /dev/null)" # 可用内存
    mem_free="$(awk '/^MemFree:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"           # 完全空闲内存
    mem_buffers="$(awk '/^Buffers:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"        # 可回收的缓存内存
    mem_cached="$(awk '/^Cached:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"          # 页缓存

    # 如果系统不支持 MemAvailable 字段 则使用其他字段估算可用内存
    if ! [[ "$mem_available" =~ ^[0-9]+$ ]]; then
        mem_available=$((mem_free + mem_buffers + mem_cached))
    fi

    # 已用内存 = 总内存 - 可用内存
    mem_used=$((mem_total - mem_available))
    [ "$mem_used" -lt 0 ] && mem_used=0

    # byte 转换
    mem_total_bytes=$((mem_total * 1024))
    mem_used_bytes=$((mem_used * 1024))

    # 已用内存 / 总内存
    RESULT_MEM_INFO="$(format_bytes "$mem_used_bytes") / $(format_bytes "$mem_total_bytes")"

    # 交换分区 / 交换文件信息
    swap_total="$(awk '/^SwapTotal:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"
    swap_free="$(awk '/^SwapFree:/ {print $2; exit}' /proc/meminfo 2> /dev/null)"
    swap_used=$((swap_total - swap_free))
    [ "$swap_used" -lt 0 ] && swap_used=0

    swap_total_bytes=$((swap_total * 1024))
    swap_used_bytes=$((swap_used * 1024))

    if [ "$swap_total" -eq 0 ]; then
        RESULT_SWAP_INFO="[ no swap partition or swap file detected ]"
    else
        RESULT_SWAP_INFO="$(format_bytes "$swap_used_bytes") / $(format_bytes "$swap_total_bytes")"
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

# 系统信息模块 -> 获取虚拟化信息
# https://github.com/TyIsI/virt-what
# https://dmo.ca/blog/detecting-virtualization-on-linux
get_vm_info() {
    local sys_vendor product_name product_version dmi virt cgroup hypervisor_type xen_caps cpu_vendor

    RESULT_VIRT_TYPE="Unknown"

    # 读取 DMI/SMBIOS 基本信息, 用于识别云平台或常见虚拟化环境
    sys_vendor="$(cat /sys/class/dmi/id/sys_vendor 2> /dev/null)"
    product_name="$(cat /sys/class/dmi/id/product_name 2> /dev/null)"
    product_version="$(cat /sys/class/dmi/id/product_version 2> /dev/null)"
    dmi="$sys_vendor $product_name $product_version"

    if command -v systemd-detect-virt > /dev/null 2>&1; then
        virt="$(systemd-detect-virt 2> /dev/null)"
        case "$virt" in
        amazon)
            RESULT_VIRT_TYPE="Amazon"
            return 0
            ;;
        bochs)
            RESULT_VIRT_TYPE="BOCHS"
            return 0
            ;;
        docker)
            RESULT_VIRT_TYPE="Docker"
            return 0
            ;;
        google)
            RESULT_VIRT_TYPE="Google"
            return 0
            ;;
        kvm | qemu)
            RESULT_VIRT_TYPE="KVM"
            return 0
            ;;
        lxc | lxc-libvirt)
            RESULT_VIRT_TYPE="LXC"
            return 0
            ;;
        microsoft)
            RESULT_VIRT_TYPE="Hyper-V"
            return 0
            ;;
        none)
            RESULT_VIRT_TYPE="Dedicated"
            return 0
            ;;
        openvz)
            RESULT_VIRT_TYPE="OpenVZ"
            return 0
            ;;
        oracle)
            RESULT_VIRT_TYPE="VirtualBox"
            return 0
            ;;
        parallels)
            RESULT_VIRT_TYPE="Parallels"
            return 0
            ;;
        rkt)
            RESULT_VIRT_TYPE="RKT"
            return 0
            ;;
        systemd-nspawn)
            RESULT_VIRT_TYPE="Systemd-nspawn"
            return 0
            ;;
        uml)
            RESULT_VIRT_TYPE="UML"
            return 0
            ;;
        vmware)
            RESULT_VIRT_TYPE="VMware"
            return 0
            ;;
        wsl)
            RESULT_VIRT_TYPE="WSL"
            return 0
            ;;
        xen)
            RESULT_VIRT_TYPE="Xen"
            return 0
            ;;
        zvm)
            RESULT_VIRT_TYPE="S390 Z/VM"
            return 0
            ;;
        esac
    fi

    # 检查容器环境特征
    cgroup="$(cat /proc/1/cgroup 2> /dev/null)"
    case "$cgroup" in
    *docker*)
        RESULT_VIRT_TYPE="Docker"
        return 0
        ;;
    *lxc*)
        RESULT_VIRT_TYPE="LXC"
        return 0
        ;;
    esac

    [ -f /.dockerenv ] && RESULT_VIRT_TYPE="Docker" && return 0
    grep -qa 'container=lxc' /proc/1/environ 2> /dev/null && RESULT_VIRT_TYPE="LXC" && return 0
    [ -d /proc/vz ] && [ ! -d /proc/bc ] && RESULT_VIRT_TYPE="OpenVZ" && return 0
    [ -c /dev/lxss ] && RESULT_VIRT_TYPE="WSL" && return 0

    # 通过 DMI/SMBIOS 信息识别云平台或常见虚拟化产品
    case "$dmi" in
    *Amazon*EC2* | *Amazon*)
        RESULT_VIRT_TYPE="Amazon"
        return 0
        ;;
    *Google*Compute*Engine* | *Google*)
        RESULT_VIRT_TYPE="Google"
        return 0
        ;;
    *HVM*domU*)
        RESULT_VIRT_TYPE="Xen-DomU"
        return 0
        ;;
    *KVM* | *QEMU*)
        RESULT_VIRT_TYPE="KVM"
        return 0
        ;;
    *Microsoft*Corporation*Virtual*Machine* | *Hyper-V*)
        RESULT_VIRT_TYPE="Hyper-V"
        return 0
        ;;
    *Parallels*)
        RESULT_VIRT_TYPE="Parallels"
        return 0
        ;;
    *VirtualBox* | *innotek* | *Oracle*)
        RESULT_VIRT_TYPE="VirtualBox"
        return 0
        ;;
    *VMware*)
        RESULT_VIRT_TYPE="VMware"
        return 0
        ;;
    *Xen*)
        RESULT_VIRT_TYPE="Xen"
        return 0
        ;;
    esac

    # 检查 Xen 相关接口
    hypervisor_type="$(cat /sys/hypervisor/type 2> /dev/null)"
    [ "$hypervisor_type" = "xen" ] && RESULT_VIRT_TYPE="Xen" && return 0

    if [ -d /proc/xen ]; then
        xen_caps="$(cat /proc/xen/capabilities 2> /dev/null)"
        if echo "$xen_caps" | grep -q "control_d" 2> /dev/null; then
            RESULT_VIRT_TYPE="Xen-Dom0"
        else
            RESULT_VIRT_TYPE="Xen-DomU"
        fi
        return 0
    fi

    # 通过 CPU hypervisor vendor 特征识别虚拟化平台
    cpu_vendor="$(awk -F: '/vendor_id|Hypervisor vendor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2> /dev/null)"
    case "$cpu_vendor" in
    KVMKVMKVM)
        RESULT_VIRT_TYPE="KVM"
        return 0
        ;;
    "Microsoft Hv")
        RESULT_VIRT_TYPE="Hyper-V"
        return 0
        ;;
    VMwareVMware)
        RESULT_VIRT_TYPE="VMware"
        return 0
        ;;
    XenVMMXenVMM)
        RESULT_VIRT_TYPE="Xen"
        return 0
        ;;
    esac

    # 如果只能确认运行在 hypervisor 上, 但无法识别具体类型
    if grep -q -w hypervisor /proc/cpuinfo 2> /dev/null; then
        RESULT_VIRT_TYPE="Virtualized"
        return 0
    fi

    # Deadline
    RESULT_VIRT_TYPE="Dedicated"
}

# https://github.com/chef/os_release
get_os_info() {
    # shellcheck disable=SC1091
    . /etc/os-release
    RESULT_SYSTEM_OS_FULLNAME="$PRETTY_NAME"
}

get_os_arch() {
    local arch

    if is_have_cmd arch; then
        arch="$(arch 2> /dev/null)"
    else
        arch="$(uname -m 2> /dev/null)"
    fi
    RESULT_SYSTEM_ARCH="$arch"
}

# 执行基本系统信息检测
get_system_info() {
    get_cpu_info
    get_mem_info
    get_disk_info

    # 系统在线时间
    if is_have_cmd uptime; then
        RESULT_SYSTEM_UPTIME="$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hour",m+0,"min"}')"
    else
        RESULT_SYSTEM_UPTIME="$(awk '{print int($1/3600)"h "int(($1%3600)/60)"m "int($1%60)"s"}' /proc/uptime)"
    fi

    # 系统负载
    if is_have_cmd uptime; then
        RESULT_LOAD_AVG="$(uptime | grep -o 'load averages\{0,1\}: .*' | sed 's/load averages\{0,1\}: //')"
    else
        RESULT_LOAD_AVG="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2> /dev/null)"
    fi

    get_os_info
    get_os_arch

    # 架构
    if is_have_cmd getconf; then
        RESULT_SYSTEM_BIT="$(getconf LONG_BIT 2> /dev/null)"
    else
        echo "$RESULT_SYSTEM_ARCH" | grep -q "64" && RESULT_SYSTEM_BIT="64" || RESULT_SYSTEM_BIT="32"
    fi
    # 内核
    if [ -r /proc/sys/kernel/osrelease ]; then
        RESULT_SYSTEM_KERNEL="$(< /proc/sys/kernel/osrelease)"
    else
        RESULT_SYSTEM_KERNEL="$(uname -r 2> /dev/null)"
    fi
    # TCP拥塞控制算法
    if [ -r /proc/sys/net/ipv4/tcp_congestion_control ]; then
        RESULT_TCP_CONGESTION="$(< /proc/sys/net/ipv4/tcp_congestion_control)"
    else
        RESULT_TCP_CONGESTION="$(sysctl -n net.ipv4.tcp_congestion_control 2> /dev/null)"
    fi
    get_vm_info
}

get_ip_info() {
    local ipv4_result ipv4_asn ipv4_org ipv4_city ipv4_region ipv4_country
    local ipv6_result ipv6_asn ipv6_org ipv6_city ipv6_region ipv6_country

    ipv4_result="$(curl -Ls -4 https://ip.iplen.de/json 2> /dev/null)"
    ipv4_asn="$(jq -r '.asn' <<< "$ipv4_result")"
    ipv4_org="$(jq -r '.org' <<< "$ipv4_result")"
    ipv4_city="$(jq -r '.city' <<< "$ipv4_result")"
    ipv4_region="$(jq -r '.region' <<< "$ipv4_result")"
    ipv4_country="$(jq -r '.country' <<< "$ipv4_result")"
    if [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_city" ] && [ -n "$ipv4_region" ] && [ -n "$ipv4_country" ]; then
        RESULT_IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        RESULT_IPV4_LOCATION="$ipv4_city / $ipv4_region / $ipv4_country"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_city" ] && [ -n "$ipv4_region" ]; then
        RESULT_IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        RESULT_IPV4_LOCATION="$ipv4_city / $ipv4_region"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_city" ]; then
        RESULT_IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        RESULT_IPV4_LOCATION="$ipv4_city"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_region" ]; then
        RESULT_IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        RESULT_IPV4_LOCATION="$ipv4_region"
    else
        RESULT_IPV4_ASN_INFO="None"
        RESULT_IPV4_LOCATION="None"
    fi

    ipv6_result="$(curl -Ls -6 https://ip.iplen.de/json 2> /dev/null)"
    ipv6_asn="$(jq -r '.asn' <<< "$ipv6_result")"
    ipv6_org="$(jq -r '.org' <<< "$ipv6_result")"
    ipv6_city="$(jq -r '.city' <<< "$ipv6_result")"
    ipv6_region="$(jq -r '.region' <<< "$ipv6_result")"
    ipv6_country="$(jq -r '.country' <<< "$ipv6_result")"
    if [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ] && [ -n "$ipv6_region" ] && [ -n "$ipv6_country" ]; then
        RESULT_IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        RESULT_IPV6_LOCATION="$ipv6_city / $ipv6_region / $ipv6_country"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ] && [ -n "$ipv6_region" ]; then
        RESULT_IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        RESULT_IPV6_LOCATION="$ipv6_city / $ipv6_region"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ]; then
        RESULT_IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        RESULT_IPV6_LOCATION="$ipv6_city"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_region" ]; then
        RESULT_IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        RESULT_IPV6_LOCATION="$ipv6_region"
    else
        RESULT_IPV6_ASN_INFO="None"
        RESULT_IPV6_LOCATION="None"
    fi
}

print_system_info() {
    print_title "System Information"

    echo -e "CPU Model\t: $RESULT_CPU_MODEL"
    echo -e "CPU Cores\t: $RESULT_CPU_CORES"
    echo -e "CPU Frequency\t: $RESULT_CPU_FREQ"
    if [ -n "$RESULT_CPU_CACHEL1" ] && [ -n "$RESULT_CPU_CACHEL2" ] && [ -n "$RESULT_CPU_CACHEL3" ]; then
        echo -e "CPU Cache\t: L1: $RESULT_CPU_CACHEL1 / L2: $RESULT_CPU_CACHEL2 / L3: $RESULT_CPU_CACHEL3"
    fi
    if [ -n "$RESULT_CPU_AES" ]; then
        echo -e "AES-NI\t\t: \xe2\x9c\x93 Enabled"
    else
        echo -e "AES-NI\t\t: \xe2\x9c\x97 Disabled"
    fi
    if [ -n "$RESULT_CPU_VIRT" ]; then
        echo -e "VM-x/AMD-V\t: \xe2\x9c\x93 Enabled"
    else
        echo -e "VM-x/AMD-V\t: \xe2\x9c\x97 Disabled"
    fi
    echo -e "Memory\t\t: $RESULT_MEM_INFO"
    echo -e "Swap\t\t: $RESULT_SWAP_INFO"
    echo -e "Space Disk\t: $RESULT_DISK_INFO"
    echo -e "Boot Disk\t: $RESULT_DISK_PATH"
    echo -e "System Uptime\t: $RESULT_SYSTEM_UPTIME"
    echo -e "Load Average\t: $RESULT_LOAD_AVG"
    echo -e "OS\t\t: $RESULT_SYSTEM_OS_FULLNAME"
    echo -e "Arch\t\t: $RESULT_SYSTEM_ARCH ($RESULT_SYSTEM_BIT Bit)"
    echo -e "Kernel\t\t: $RESULT_SYSTEM_KERNEL"
    echo -e "TCP Congestion\t: $RESULT_TCP_CONGESTION"
    echo -e "Virtualization\t: $RESULT_VIRT_TYPE"
}

print_ip_info() {
    if [ -n "$RESULT_IPV4_ASN_INFO" ] && [ "$RESULT_IPV4_ASN_INFO" != "None" ]; then
        echo -e "IPv4 ASN\t: $RESULT_IPV4_ASN_INFO"
    fi
    if [ -n "$RESULT_IPV4_LOCATION" ] && [ "$RESULT_IPV4_LOCATION" != "None" ]; then
        echo -e "IPv4 Location\t: $RESULT_IPV4_LOCATION"
    fi
    if [ -n "$RESULT_IPV6_ASN_INFO" ] && [ "$RESULT_IPV6_ASN_INFO" != "None" ]; then
        echo -e "IPv6 ASN\t: $RESULT_IPV6_ASN_INFO"
    fi
    if [ -n "$RESULT_IPV6_LOCATION" ] && [ "$RESULT_IPV6_LOCATION" != "None" ]; then
        echo -e "IPv6 Location\t: $RESULT_IPV6_LOCATION"
    fi
}

get_system_info
get_ip_info

print_system_info
print_ip_info
