$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { & (Join-Path $PSScriptRoot 'setup.ps1') }
Push-Location $projectRoot
try {
    & $godot --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    & $godot --headless --path $projectRoot --script res://tests/run_tests.gd
    if ($LASTEXITCODE -ne 0) { throw 'Sim tests failed' }
    & $godot --headless --path $projectRoot -- --smoke
    if ($LASTEXITCODE -ne 0) { throw 'Scene smoke check failed' }
} finally { Pop-Location }
