# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

function Get-FriendlySize {
    param([double]$kbValue)
    if ($kbValue -ge 1MB) { return "$([math]::Round($kbValue / 1MB, 2) ) GB" }
    else { return "$([math]::Round($kbValue / 1KB, 0) ) MB" }
}

# 系统信息提取
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "系统版本   : $($os.Caption) ($($os.OSArchitecture))" -ForegroundColor Cyan

# CPU 信息
$c = Get-CimInstance Win32_Processor
Write-Host "CPU 型号   : $($c.Name)" -ForegroundColor Cyan
Write-Host "CPU 数量   : $($c.NumberOfCores) 核心 / $($c.NumberOfLogicalProcessors) 线程" -ForegroundColor Cyan

# 内存信息
$totalVisKB = $os.TotalVisibleMemorySize
$freeKB = $os.FreePhysicalMemory
$usedStr = Get-FriendlySize ($totalVisKB - $freeKB)
$totalStr = Get-FriendlySize $totalVisKB
Write-Host "内存       : $usedStr / $totalStr" -ForegroundColor Cyan
$m = Get-CimInstance Win32_PhysicalMemory
foreach ($stick in $m) {
    Write-Host "  └─ 插槽  : $($stick.DeviceLocator) | $($stick.Manufacturer) | $([math]::Round($stick.Capacity / 1GB, 0)) GB | $($stick.Speed) MHz" -ForegroundColor Cyan
}

# 获取主板核心信息
$b = Get-CimInstance Win32_BaseBoard
Write-Host "主板型号   : $($b.Manufacturer) $($b.Product)" -ForegroundColor Cyan

# GPU
# AdapterRAM > 1GB 物理独显基准线 过滤虚拟显卡和共享显存的核显
# 排除名称包含 Intel 或 Virtual 的设备 防止 Intel 旗舰核显干扰
$g = Get-CimInstance Win32_VideoController | Where-Object {
    $_.AdapterRAM -ge 1GB -and
    $_.Name -notmatch "Intel|Virtual|Microsoft|Basic|UHD|Iris"
}
foreach ($card in $g) {
    Write-Host "GPU 型号   : $($card.Name) ($([math]::Round($card.AdapterRAM / 1GB, 2)) GB 显存)" -ForegroundColor Cyan
}
