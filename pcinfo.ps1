# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

# 系统信息
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "系统版本   : $($os.Caption) ($($os.OSArchitecture))" -ForegroundColor Cyan

# CPU 信息
$c = Get-CimInstance Win32_Processor
Write-Host "CPU 型号   : $($c.Name)" -ForegroundColor Cyan
Write-Host "CPU 数量   : $($c.NumberOfCores) 核心 / $($c.NumberOfLogicalProcessors) 线程" -ForegroundColor Cyan

# 内存信息 (总量 + 插槽明细)
$m = Get-CimInstance Win32_PhysicalMemory
$totalMem = 0; foreach($st in $m){ $totalMem += $st.Capacity }
Write-Host "内存       : $([math]::Round($totalMem / 1GB, 2)) GB" -ForegroundColor Cyan
foreach ($stick in $m) {
    Write-Host "  └─ 插槽  : $($stick.DeviceLocator) | $($stick.Manufacturer) | $([math]::Round($stick.Capacity / 1GB, 0)) GB | $($stick.Speed) MHz" -ForegroundColor Cyan
}

# 主板信息
$b = Get-CimInstance Win32_BaseBoard
Write-Host "主板型号   : $($b.Manufacturer) $($b.Product)" -ForegroundColor Cyan

# GPU 信息
$g = Get-CimInstance Win32_VideoController | Where-Object {
    $_.AdapterRAM -ge 1GB -and
    $_.Name -notmatch "Intel|Virtual|Microsoft|Basic|UHD|Iris"
}
foreach ($card in $g) {
    Write-Host "GPU 型号   : $($card.Name) ($([math]::Round($card.AdapterRAM / 1GB, 2)) GB 显存)" -ForegroundColor Cyan
}
