#!/usr/bin/env bash

# shellcheck disable=all

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
# 获取CPU信息
get_cpu_info() {
    local cpu_model cpu_cores cpu_freq
    local cpu_l1_cache cpu_l2_cache cpu_l3_cache cache_level cache_type cache_size cache_bytes

    # CPU型号 核心数 频率
    cpu_model="$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
    cpu_cores="$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo 2> /dev/null)"
    cpu_freq="$(awk -F: '/cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"

    # CPU缓存
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
            cpu_l2_cache="$cache_bytes"
            ;;
        3:Unified)
            cpu_l3_cache="$cache_bytes"
            ;;
        esac
    done < <(
        for cache_path in /sys/devices/system/cpu/cpu0/cache/index*; do
            [ -r "$cache_path/level" ] || continue
            [ -r "$cache_path/type" ] || continue
            [ -r "$cache_path/size" ] || continue
            printf '%s|%s|%s\n' "$(< "$cache_path/level")" "$(< "$cache_path/type")" "$(< "$cache_path/size")"
        done
    )

    # 信息汇总
    RESULT_CPU_MODEL="$cpu_model"
    RESULT_CPU_CORES="$cpu_cores"
    RESULT_CPU_FREQ="$cpu_freq"
    RESULT_CPU_CACHEL1="$(format_bytes "$cpu_l1_cache")"
    RESULT_CPU_CACHEL2="$(format_bytes "$cpu_l2_cache")"
    RESULT_CPU_CACHEL3="$(format_bytes "$cpu_l3_cache")"
}

# 执行基本系统信息检测
exec_system_info_check() {
    get_cpu_info

    # 系统在线时间
    if is_have_cmd uptime; then
        SYSTEM_UPTIME="$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hour",m+0,"min"}')"
    else
        SYSTEM_UPTIME="$(awk '{print int($1/3600)"h "int(($1%3600)/60)"m "int($1%60)"s"}' /proc/uptime)"
    fi

    # 系统负载
    if is_have_cmd uptime; then
        LOAD_AVG="$(uptime | grep -o 'load averages\{0,1\}: .*' | sed 's/load averages\{0,1\}: //')"
    else
        LOAD_AVG="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2> /dev/null)"
    fi

    CPU_AES="$(grep -i 'aes' /proc/cpuinfo)"       # 检查 AES-NI 指令集支持
    CPU_VIRT="$(grep -Ei 'vmx|svm' /proc/cpuinfo)" # 检查 VM-x/AMD-V 支持

    # 架构
    if is_have_cmd getconf; then
        SYSTEM_BIT="$(getconf LONG_BIT 2> /dev/null)"
    else
        echo "$SYSTEM_ARCH" | grep -q "64" && SYSTEM_BIT="64" || SYSTEM_BIT="32"
    fi
    # 内核
    if [ -r /proc/sys/kernel/osrelease ]; then
        SYSTEM_KERNEL="$(< /proc/sys/kernel/osrelease)"
    else
        SYSTEM_KERNEL="$(uname -r 2> /dev/null)"
    fi
    # TCP拥塞控制算法
    if [ -r /proc/sys/net/ipv4/tcp_congestion_control ]; then
        TCP_CONGESTION="$(< /proc/sys/net/ipv4/tcp_congestion_control)"
    else
        TCP_CONGESTION="$(sysctl -n net.ipv4.tcp_congestion_control 2> /dev/null)"
    fi
}

get_os_arch() {
    local arch

    if is_have_cmd arch; then
        arch="$(arch 2> /dev/null)"
    else
        arch="$(uname -m 2> /dev/null)"
    fi
    SYSTEM_ARCH="$arch"
}

get_os_info() {
    # https://github.com/chef/os_release
    # shellcheck disable=SC1091
    . /etc/os-release
    SYSTEM_OS_FULLNAME="$PRETTY_NAME"
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
        IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        IPV4_LOCATION="$ipv4_city / $ipv4_region / $ipv4_country"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_city" ] && [ -n "$ipv4_region" ]; then
        IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        IPV4_LOCATION="$ipv4_city / $ipv4_region"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_city" ]; then
        IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        IPV4_LOCATION="$ipv4_city"
    elif [ -n "$ipv4_asn" ] && [ -n "$ipv4_org" ] && [ -n "$ipv4_region" ]; then
        IPV4_ASN_INFO="AS$ipv4_asn $ipv4_org"
        IPV4_LOCATION="$ipv4_region"
    else
        IPV4_ASN_INFO="None"
        IPV4_LOCATION="None"
    fi

    ipv6_result="$(curl -Ls -6 https://ip.iplen.de/json 2> /dev/null)"
    ipv6_asn="$(jq -r '.asn' <<< "$ipv6_result")"
    ipv6_org="$(jq -r '.org' <<< "$ipv6_result")"
    ipv6_city="$(jq -r '.city' <<< "$ipv6_result")"
    ipv6_region="$(jq -r '.region' <<< "$ipv6_result")"
    ipv6_country="$(jq -r '.country' <<< "$ipv6_result")"
    if [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ] && [ -n "$ipv6_region" ] && [ -n "$ipv6_country" ]; then
        IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        IPV6_LOCATION="$ipv6_city / $ipv6_region / $ipv6_country"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ] && [ -n "$ipv6_region" ]; then
        IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        IPV6_LOCATION="$ipv6_city / $ipv6_region"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_city" ]; then
        IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        IPV6_LOCATION="$ipv6_city"
    elif [ -n "$ipv6_asn" ] && [ -n "$ipv6_org" ] && [ -n "$ipv6_region" ]; then
        IPV6_ASN_INFO="AS$ipv6_asn $ipv6_org"
        IPV6_LOCATION="$ipv6_region"
    else
        IPV6_ASN_INFO="None"
        IPV6_LOCATION="None"
    fi
}

print_system_info() {
    echo -e "Basic System Information:"
    print_sep 30 -

    echo -e "CPU Model\t: $RESULT_CPU_MODEL"
    echo -e "CPU Cores\t: $RESULT_CPU_CORES"
    echo -e "CPU Frequency\t: $RESULT_CPU_FREQ"
    if [ -n "$RESULT_CPU_CACHEL1" ] && [ -n "$RESULT_CPU_CACHEL2" ] && [ -n "$RESULT_CPU_CACHEL3" ]; then
        echo -e "CPU Cache\t: L1: $RESULT_CPU_CACHEL1 / L2: $RESULT_CPU_CACHEL2 / L3: $RESULT_CPU_CACHEL3"
    fi
    echo -e "System Uptime\t: $SYSTEM_UPTIME"
    echo -e "Load Average\t: $LOAD_AVG"
    echo -e "OS\t\t: $SYSTEM_OS_FULLNAME"
    if [ -n "$CPU_AES" ]; then
        echo -e "AES-NI\t\t: \xe2\x9c\x93 Enabled"
    else
        echo -e "AES-NI\t\t: \xe2\x9c\x97 Disabled"
    fi
    if [ -n "$CPU_VIRT" ]; then
        echo -e "VM-x/AMD-V\t: \xe2\x9c\x93 Enabled"
    else
        echo -e "VM-x/AMD-V\t: \xe2\x9c\x97 Disabled"
    fi
    echo -e "Arch\t\t: $SYSTEM_ARCH ($SYSTEM_BIT Bit)"
    echo -e "Kernel\t\t: $SYSTEM_KERNEL"
    echo -e "TCP Congestion\t: $TCP_CONGESTION"
}

print_ip_info() {
    if [ -n "$IPV4_ASN_INFO" ] && [ "$IPV4_ASN_INFO" != "None" ]; then
        echo -e "IPv4 ASN\t: $IPV4_ASN_INFO"
    fi
    if [ -n "$IPV4_LOCATION" ] && [ "$IPV4_LOCATION" != "None" ]; then
        echo -e "IPv4 Location\t: $IPV4_LOCATION"
    fi
    if [ -n "$IPV6_ASN_INFO" ] && [ "$IPV6_ASN_INFO" != "None" ]; then
        echo -e "IPv6 ASN\t: $IPV6_ASN_INFO"
    fi
    if [ -n "$IPV6_LOCATION" ] && [ "$IPV6_LOCATION" != "None" ]; then
        echo -e "IPv6 Location\t: $IPV6_LOCATION"
    fi
}

exec_system_info_check
get_os_arch
get_os_info
get_ip_info

print_system_info
print_ip_info
