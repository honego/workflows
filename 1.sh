#!/bin/bash

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
        docker)
            RESULT_VIRT_TYPE="Docker"
            return 0
            ;;
        google)
            RESULT_VIRT_TYPE="Google"
            return 0
            ;;
        kvm)
            RESULT_VIRT_TYPE="KVM"
            return 0
            ;;
        lxc | lxc-libvirt)
            RESULT_VIRT_TYPE="LXC"
            return 0
            ;;
        microsoft)
            RESULT_VIRT_TYPE="Azure"
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
        qemu)
            RESULT_VIRT_TYPE="QEMU"
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
    *HVM*domU* | *Xen*)
        RESULT_VIRT_TYPE="Xen"
        return 0
        ;;
    *KVM* | *QEMU*)
        RESULT_VIRT_TYPE="KVM"
        return 0
        ;;
    *Microsoft*Corporation*Virtual*Machine* | *Hyper-V*)
        RESULT_VIRT_TYPE="Azure"
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
    esac

    # 检查 Xen 相关接口
    hypervisor_type="$(cat /sys/hypervisor/type 2> /dev/null)"
    [ "$hypervisor_type" = "xen" ] && RESULT_VIRT_TYPE="Xen" && return 0
    [ -d /proc/xen ] && RESULT_VIRT_TYPE="Xen" && return 0

    xen_caps="$(cat /proc/xen/capabilities 2> /dev/null)"
    [ -n "$xen_caps" ] && RESULT_VIRT_TYPE="Xen" && return 0

    # 通过 CPU hypervisor vendor 特征识别虚拟化平台
    cpu_vendor="$(awk -F: '/vendor_id|Hypervisor vendor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2> /dev/null)"
    case "$cpu_vendor" in
    KVMKVMKVM)
        RESULT_VIRT_TYPE="KVM"
        return 0
        ;;
    "Microsoft Hv")
        RESULT_VIRT_TYPE="Azure"
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
    RESULT_VIRT_TYPE="Physical"
}

get_vm_info
echo -e "虚拟化类型: $RESULT_VIRT_TYPE"
