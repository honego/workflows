#!/usr/bin/env bash

## 基本系统信息
get_system_info() {
    # CPU信息
    CPU_MODEL="$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
    CPU_CORES="$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo 2> /dev/null)"
    CPU_FREQ="$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"

}

print_system_info() {
    echo -e "CPU Model\t: $CPU_MODEL"
    echo -e "CPU Cores\t: $CPU_CORES"
    echo -e "CPU Frequency\t: $CPU_FREQ"
}

get_system_info
print_system_info
