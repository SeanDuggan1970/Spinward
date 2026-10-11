$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { & (Join-Path $PSScriptRoot 'setup.ps1') }

# Godot keeps running after a GDScript error and can still exit 0, so treat any
# script error in the output as a failure too.
function Invoke-Godot([string]$label, [string[]]$godotArgs) {
    $output = & $godot @godotArgs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $output | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR|checks,|SMOKE_OK|DOCK_TRIAL|FAIL' } | ForEach-Object { Write-Host $_ }
    if ($code -ne 0 -or ($output -match 'SCRIPT ERROR')) { throw "$label failed" }
}

Push-Location $projectRoot
try {
    Invoke-Godot 'Godot import' @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit')
    Invoke-Godot 'Sim tests' @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_tests.gd')
    Invoke-Godot 'Site departures' @('--headless', '--path', $projectRoot, '--script', 'res://tests/site_departures.gd')
    Invoke-Godot 'Scene smoke check' @('--headless', '--path', $projectRoot, '--', '--smoke')
    Invoke-Godot 'Docking trial' @('--headless', '--path', $projectRoot, '--', '--dock-trial')
} finally { Pop-Location }
