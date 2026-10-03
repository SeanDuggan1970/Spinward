param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    & (Join-Path $PSScriptRoot 'setup.ps1')
}
if ($Editor) {
    & $godotPath --path $projectRoot --editor
} else {
    & $godotPath --path $projectRoot
}
