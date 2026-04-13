#!/usr/bin/env bash

## 基本系统信息
# CPU信息
CPU_MODEL="$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
echo -e "Processor\t: $CPU_MODEL"

CPU_CORES="$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo 2> /dev/null)"
CPU_FREQ="$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')"
echo -e "CPU cores\t: $CPU_CORES @ $CPU_FREQ"
