# 图标还原脚本（Windows PowerShell）
# 用途：本仓库通过文本方式携带 PNG 图标（tools/icon_restore/*.b64 + manifest.json）。
# 克隆后在仓库根目录执行：  powershell -ExecutionPolicy Bypass -File tools/icon_restore/restore.ps1
# 即可把 5 个 PNG 还原到 resources 对应位置。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest = Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json

foreach ($prop in $manifest.PSObject.Properties) {
    $b64File = Join-Path $PSScriptRoot $prop.Name
    $relPath = $prop.Value -replace '/', [IO.Path]::DirectorySeparatorChar
    $target = Join-Path $root $relPath
    $dir = Split-Path -Parent $target
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $b64 = (Get-Content $b64File -Raw).Trim()
    [IO.File]::WriteAllBytes($target, [Convert]::FromBase64String($b64))
    Write-Host "restored: $relPath"
}
Write-Host 'done. icons restored.'
