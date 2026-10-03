$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
$engineDirectory = Join-Path $toolRoot 'godot'
$binaryName = 'Godot_v4.7.2-stable_win64.exe'
if (Test-Path -LiteralPath (Join-Path $engineDirectory $binaryName)) { return }
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
$release = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable'
$archiveName = 'Godot_v4.7.2-stable_win64.exe.zip'
$archive = Join-Path $toolRoot 'godot.zip'
$sums = Join-Path $toolRoot 'godot-SHA512-SUMS.txt'
Write-Host 'Downloading the portable Godot 4.7.2 editor from its official release...'
Invoke-WebRequest "$release/$archiveName" -OutFile $archive -UseBasicParsing
Invoke-WebRequest "$release/SHA512-SUMS.txt" -OutFile $sums -UseBasicParsing
$line = Get-Content -LiteralPath $sums | Where-Object { $_ -match ('\s' + [regex]::Escape($archiveName) + '$') }
if (@($line).Count -ne 1) { throw 'Could not identify the official archive checksum.' }
$expected = ($line -split '\s+')[0].ToLowerInvariant()
$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash.ToLowerInvariant()
if ($expected -ne $actual) { throw 'Godot download checksum failed. Archive was not extracted.' }
Expand-Archive -LiteralPath $archive -DestinationPath $engineDirectory -Force
Write-Host 'Godot is ready.'
