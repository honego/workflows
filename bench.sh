#!/usr/bin/env bash

## 基本系统信息
get_system_info() {
    # CPU信息
    CPU_MODEL="$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
    CPU_CORES="$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo 2> /dev/null)"
    CPU_FREQ="$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"

    CPU_AES="$(grep -i 'aes' /proc/cpuinfo)"       # 检查 AES-NI 指令集支持
    CPU_VIRT="$(grep -Ei 'vmx|svm' /proc/cpuinfo)" # 检查 VM-x/AMD-V 支持
}

print_system_info() {
    echo -e "CPU Model\t: $CPU_MODEL"
    echo -e "CPU Cores\t: $CPU_CORES"
    echo -e "CPU Frequency\t: $CPU_FREQ"

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
}

get_system_info
print_system_info
