# Copyright 2026 Kenny Root
# SPDX-License-Identifier: Apache-2.0
$ErrorActionPreference = 'Stop'
$requiredFlutterVersion = '3.47.9'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $versionInfo = flutter --version --machine
    if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK could not be inspected.' }
    if (($versionInfo | ConvertFrom-Json).frameworkVersion -ne $requiredFlutterVersion) {
        throw "Use Flutter $requiredFlutterVersion for its Windows Korean IME cursor fix."
    }
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'Build cleanup failed.' }
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    $bundle = Join-Path (Get-Location) 'build\windows\x64\runner\Release'
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $visualStudio) { throw 'MSVC installation was not found.' }
    $runtimeVersion = (Get-Content (Join-Path $visualStudio 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt') -Raw).Trim()
    $runtime = Join-Path $visualStudio "VC\Redist\MSVC\$runtimeVersion\x64\Microsoft.VC143.CRT"
    foreach ($library in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        Copy-Item -LiteralPath (Join-Path $runtime $library) -Destination $bundle
    }
    Copy-Item -LiteralPath 'windows\runner\resources\app_icon.ico' -Destination (Join-Path $bundle 'Tilde.ico')
    New-Item -ItemType Directory -Path artifacts -Force | Out-Null
    Compress-Archive -Path "$bundle\*" -DestinationPath 'artifacts\Tilde-Windows.zip' -Force
    Write-Output 'Built artifacts\Tilde-Windows.zip. Extract the whole archive and run Tilde.exe.'
} finally {
    Pop-Location
}
