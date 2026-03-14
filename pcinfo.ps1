# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 honeok <i@honeok.com>

# CPU 信息
$c = Get-CimInstance Win32_Processor; Write-Host "Processor     : $($c.Name) [Cores: $($c.NumberOfCores), Threads: $($c.NumberOfLogicalProcessors)]" -ForegroundColor Cyan

# 内存信息
$m = Get-CimInstance Win32_PhysicalMemory; foreach ($stick in $m) { Write-Host "Memory        : $($stick.Manufacturer) $([math]::Round($stick.Capacity / 1GB, 2)) GB [Speed: $($stick.Speed) MHz]" -ForegroundColor Cyan }

# 获取主板核心信息
$b = Get-CimInstance Win32_BaseBoard; Write-Host "Motherboard   : $($b.Manufacturer) $($b.Product) [SN: $($b.SerialNumber)]" -ForegroundColor Cyan

# GPU
$g = Get-CimInstance Win32_VideoController; foreach ($card in $g) { Write-Host "Graphics Card : $($card.Name) [VRAM: $([math]::Round($card.AdapterRAM / 1GB, 2)) GB]" -ForegroundColor Cyan }
