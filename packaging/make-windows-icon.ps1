#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$sourceSvg = Join-Path $scriptDir 'icons\illuminate.svg'
$targetIcon = Join-Path $scriptDir 'icons\AppIcon.ico'
$workDir = Join-Path $env:LOCALAPPDATA ('illuminate-windows-icon-' + $PID)
$buildDir = Join-Path $workDir 'build'
$previousPlatform = $env:QT_QPA_PLATFORM
$previousPluginPath = $env:QT_PLUGIN_PATH
$previousPath = $env:PATH

try {
    $cmakeArgs = @('-S', (Join-Path $scriptDir 'icongen'), '-B', $buildDir)
    if ($env:QT_DIR) {
        $cmakeArgs += @('-DCMAKE_PREFIX_PATH=' + $env:QT_DIR)
    }
    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }

    & cmake --build $buildDir --config Release
    if ($LASTEXITCODE -ne 0) { throw 'Icon generator build failed.' }

    $generator = Join-Path $buildDir 'Release\icongen.exe'
    if (-not (Test-Path -LiteralPath $generator)) {
        $generator = Join-Path $buildDir 'icongen.exe'
    }
    if (-not (Test-Path -LiteralPath $generator)) {
        throw "Icon generator executable was not produced under $buildDir."
    }

    $env:QT_QPA_PLATFORM = 'offscreen'
    if ($env:QT_DIR) {
        $env:PATH = (Join-Path $env:QT_DIR 'bin') + ';' + $env:PATH
        $env:QT_PLUGIN_PATH = Join-Path $env:QT_DIR 'plugins'
    }
    & $generator --windows $sourceSvg $targetIcon
    if ($LASTEXITCODE -ne 0) { throw 'Windows icon generation failed.' }
    Write-Host "Wrote $targetIcon"
}
finally {
    if ($null -eq $previousPlatform) {
        Remove-Item Env:QT_QPA_PLATFORM -ErrorAction SilentlyContinue
    } else {
        $env:QT_QPA_PLATFORM = $previousPlatform
    }
    if ($null -eq $previousPluginPath) {
        Remove-Item Env:QT_PLUGIN_PATH -ErrorAction SilentlyContinue
    } else {
        $env:QT_PLUGIN_PATH = $previousPluginPath
    }
    $env:PATH = $previousPath
    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir -Recurse -Force
    }
}
