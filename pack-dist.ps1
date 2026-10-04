<#
  打包：生成可以直接发给别人的 zip（dist/<name>-<version>.zip）。

  用法：  powershell -NoProfile -ExecutionPolicy Bypass -File pack-dist.ps1
  说明：
    · 内容按 package.json 的 `files` 白名单 + 安装脚本 + 许可证，**不含** node_modules/_review/dist
    · 本插件零运行时依赖、无构建步骤，所以打出来的就是"解开即可装"
    · 会强制把 .ps1 写成 **UTF-8 带 BOM**：Windows PowerShell 5.1 只有看到 BOM 才按 UTF-8 解析脚本，
      否则中文注释会被按 ANSI 解码、整个脚本解析失败（踩过这个坑）
#>
[CmdletBinding()]
param([string]$OutDir = "")

$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$manifest = Get-Content (Join-Path $root "package.json") -Raw -Encoding utf8 | ConvertFrom-Json
$name = $manifest.name
$version = $manifest.version
if (-not $OutDir) { $OutDir = Join-Path $root "dist" }

$staging = Join-Path $OutDir $name
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

# package.json 必须进包（npm 会自动带，Compress-Archive 不会 —— 少了它 DSH 认不出这是插件）
$include = @("package.json") + @($manifest.files) + @("LICENSE", "install-profile.ps1", "install.cmd")
$copied = @()
foreach ($entry in $include) {
  $source = Join-Path $root $entry
  if (-not (Test-Path $source)) { Write-Host "  跳过（不存在）：$entry" -ForegroundColor Yellow; continue }
  $target = Join-Path $staging $entry
  $parent = Split-Path -Parent $target
  if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if ((Get-Item $source).PSIsContainer) {
    Copy-Item $source $target -Recurse -Force
  } else {
    Copy-Item $source $target -Force
  }
  $copied += $entry
}

# .ps1 统一成 UTF-8 带 BOM（PS 5.1 的硬要求）
Get-ChildItem $staging -Recurse -File -Filter *.ps1 | ForEach-Object {
  $text = [System.IO.File]::ReadAllText($_.FullName, (New-Object System.Text.UTF8Encoding($false)))
  [System.IO.File]::WriteAllText($_.FullName, $text, (New-Object System.Text.UTF8Encoding($true)))
}

$zip = Join-Path $OutDir "$name-$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal

Write-Host "`n打包完成：$zip" -ForegroundColor Green
Write-Host ("  {0}（{1:N0} KB）" -f (Split-Path -Leaf $zip), ((Get-Item $zip).Length / 1KB))
Write-Host "  内容："
Get-ChildItem $staging -Recurse -File | ForEach-Object {
  Write-Host ("    {0,-44} {1,8:N0} B" -f $_.FullName.Substring($staging.Length + 1), $_.Length)
}
