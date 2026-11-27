#Requires -Version 5.1
<#
Usage:
    build.ps1                # configure (if needed) + build
    build.ps1 --run          # build + launch detached (no logs)
    build.ps1 --dev          # build Debug + run with live logs in terminal
    build.ps1 --clean        # wipe build dir AND app data
    build.ps1 --clean --keep-data  # wipe build dir only, keep app data
    build.ps1 --package      # Release build + .zip in dist/
#>

$DoClean    = $false
$DoKeepData = $false
$DoRun      = $false
$DoDev      = $false
$DoPackage  = $false

foreach ($arg in $args) {
    switch -CaseSensitive ($arg) {
        '--clean'     { $DoClean = $true }
        '--keep-data' { $DoKeepData = $true }
        '--run'       { $DoRun = $true }
        '--dev'       { $DoDev = $true }
        '--package'   { $DoPackage = $true }
        default {
            Write-Host "Unknown argument: $arg"
            Write-Host 'Usage: build.ps1 [--clean [--keep-data]] [--run | --dev] [--package]'
            exit 1
        }
    }
}

if ($DoPackage -and $DoDev) {
    Write-Host '✗ --package builds Release; it can''t be combined with --dev.'
    exit 1
}
if ($DoKeepData -and -not $DoClean) {
    Write-Host 'Note: --keep-data has no effect without --clean.'
}
if ($DoRun -and $DoDev) {
    Write-Host 'Note: --dev already runs the app in the foreground with live logs; ignoring --run.'
    $DoRun = $false
}

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$BuildDir  = Join-Path $ScriptDir 'build'
$AppLabel  = 'illuminate'
$AppImage  = 'illuminate.exe'

# ── helpers ──────────────────────────────────────────────────────────────────

function Fail([string]$Message) {
    Write-Host "✗ $Message"
    exit 1
}

function Assert-NativeSuccess([string]$What) {
    if ($LASTEXITCODE -ne 0) { Fail "$What failed (exit code $LASTEXITCODE)." }
}

function Remove-Tree([string]$Path) {
    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path -LiteralPath $Path)) { return }
    $err = $null
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        return
    } catch { $err = $_ }
    try {
        Remove-Item -LiteralPath "\\?\$Path" -Recurse -Force -ErrorAction Stop
        return
    } catch { $err = $_ }
    Fail "Could not remove $Path ($($err.Exception.Message))"
}

function Normalize-Path([string]$Path) {
    if (-not $Path) { return '' }
    return ($Path.Trim().TrimEnd([char]'\', [char]'/') -replace '\\', '/')
}

function To-CMakePath([string]$Path) {
    if (-not $Path) { return '' }
    return ($Path -replace '\\', '/')
}

function Get-CacheValue([string]$File, [string]$Key) {
    if (-not (Test-Path -LiteralPath $File)) { return '' }
    $raw = [System.IO.File]::ReadAllText($File)
    $m = [regex]::Match($raw, '(?m)^' + [regex]::Escape($Key) + '(?::[^=\r\n]*)?=(.*)$')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value.Trim()
}


function Get-VersionParts([string]$Text) {
    $m = [regex]::Match("$Text", '\d+(\.\d+)+')
    if (-not $m.Success) { return @() }
    return @($m.Value -split '\.' | ForEach-Object { [int]$_ })
}

function Test-VersionGe([string]$A, [string]$B) {
    $va = Get-VersionParts $A
    $vb = Get-VersionParts $B
    if ($vb.Count -eq 0) { return $true }
    if ($va.Count -eq 0) { return $false }
    $n = [Math]::Max($va.Count, $vb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $ai = if ($i -lt $va.Count) { $va[$i] } else { 0 }
        $bi = if ($i -lt $vb.Count) { $vb[$i] } else { 0 }
        if ($ai -gt $bi) { return $true }
        if ($ai -lt $bi) { return $false }
    }
    return $true
}

function Find-Bash {
    if ($env:ILLUMINATE_BASH) { return $env:ILLUMINATE_BASH }
    $candidates = @()
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe') }
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) { $candidates += (Join-Path $pf86 'Git\bin\bash.exe') }
    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.CommandType -eq 'Application') { $candidates += $cmd.Source }
    foreach ($p in $candidates) {
        if ($p -and $p -notmatch 'WindowsApps' -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return ''
}

# ── locate toolchain, Qt and CEF ─────────────────────────────────────────────

# Root of a Visual Studio installation that ships the C++ tools.
function Find-VsInstallation {
    $vswhere = $null
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) { $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe' }
    if ($vswhere -and (Test-Path -LiteralPath $vswhere)) {
        $found = & $vswhere -all -products * `
                    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
                    -property installationPath 2>$null
        foreach ($cand in @($found)) {
            $cand = "$cand".Trim()
            if ($cand -and (Test-Path -LiteralPath (Join-Path $cand 'VC\Auxiliary\Build\vcvars64.bat'))) {
                return $cand
            }
        }
    }
    # vswhere's recorded state can go stale (e.g. after the install directory
    # is moved), so also scan the usual locations directly.
    $roots = @()
    if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022') }
    if ($pf86) { $roots += (Join-Path $pf86 'Microsoft Visual Studio\2022') }
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($edition in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath (Join-Path $edition.FullName 'VC\Auxiliary\Build\vcvars64.bat')) {
                return $edition.FullName
            }
        }
    }
    foreach ($edition in @(Get-ChildItem -LiteralPath $HOME -Directory -ErrorAction SilentlyContinue)) {
        if (Test-Path -LiteralPath (Join-Path $edition.FullName 'VC\Auxiliary\Build\vcvars64.bat')) {
            return $edition.FullName
        }
    }
    return ''
}

function Find-Qt {
    if ($env:QT_DIR) { return $env:QT_DIR }

    foreach ($qmakeName in 'qmake6', 'qmake') {
        $cmd = Get-Command $qmakeName -ErrorAction SilentlyContinue
        if (-not $cmd -or $cmd.CommandType -ne 'Application') { continue }
        $prefix = (& $cmd.Source -query QT_INSTALL_PREFIX 2>$null | Select-Object -First 1)
        if (-not $prefix) { continue }
        $prefix = "$prefix".Trim()
        if ($qmakeName -eq 'qmake6') { return $prefix }
        # a stray qmake from somewhere else must not be trusted
        if ($prefix -match '(?i)qt' -or
                (Test-Path -LiteralPath (Join-Path $prefix 'lib\cmake\Qt6\Qt6Config.cmake'))) {
            return $prefix
        }
    }

    # Only msvc kits are usable: the CEF binaries are MSVC-built, so a mingw
    # kit could not link against them.
    $best = ''
    foreach ($root in @((Join-Path $HOME 'Qt'), 'C:\Qt', 'D:\Qt', 'C:\Program Files\Qt')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($verDir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            foreach ($kit in @(Get-ChildItem -LiteralPath $verDir.FullName -Directory -Filter 'msvc*' -ErrorAction SilentlyContinue)) {
                if (-not (Test-Path -LiteralPath (Join-Path $kit.FullName 'lib\cmake\Qt6\Qt6Config.cmake'))) { continue }
                if ($best -eq '' -or (Test-VersionGe $kit.FullName $best)) { $best = $kit.FullName }
            }
        }
    }
    return $best
}

function Find-Cef {
    $envRoot = $env:CEF_ROOT
    if ($envRoot -and (Test-Path -LiteralPath $envRoot -PathType Container)) { return $envRoot }

    $cacheCef = Get-CacheValue (Join-Path $BuildDir 'CMakeCache.txt') 'CEF_ROOT'
    if ($cacheCef -and (Test-Path -LiteralPath $cacheCef -PathType Container)) { return $cacheCef }

    $cefHome = Join-Path $HOME 'cef'
    $candidates = @()
    if (Test-Path -LiteralPath $cefHome) {
        $candidates += @(Get-ChildItem -LiteralPath $cefHome -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $candidates += $cefHome
        $candidates += (Join-Path $cefHome 'latest')
    }
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'cef') }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath (Join-Path $candidate 'include'))) { continue }
        $release = Join-Path $candidate 'Release'
        if (-not (Test-Path -LiteralPath $release -PathType Container)) { continue }
        if (@(Get-ChildItem -LiteralPath $release -Filter 'libcef*' -ErrorAction SilentlyContinue).Count -gt 0) {
            return $candidate
        }
    }

    if ($env:CEF_PREFIX -and (Test-Path -LiteralPath $env:CEF_PREFIX -PathType Container)) { return $env:CEF_PREFIX }
    return ''
}

# Try to locate CEF through cmake's find_package mechanism.
function Find-CefViaPrefix {
    $candidates = @()
    if ($env:CEF_ROOT) { $candidates += $env:CEF_ROOT }
    $candidates += (Join-Path $HOME 'cef')
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'cef') }

    foreach ($prefix in $candidates) {
        if (-not $prefix -or -not (Test-Path -LiteralPath $prefix -PathType Container)) { continue }
        $lib = Join-Path $prefix 'lib'
        if (-not (Test-Path -LiteralPath $lib -PathType Container)) { continue }
        if (@(Get-ChildItem -LiteralPath $lib -Filter 'cef_config.cmake*' -ErrorAction SilentlyContinue).Count -gt 0) { return $prefix }
        $cmakeDir = Join-Path $lib 'cmake'
        if ((Test-Path -LiteralPath $cmakeDir -PathType Container) -and
                @(Get-ChildItem -LiteralPath $cmakeDir -Filter 'cef*' -ErrorAction SilentlyContinue).Count -gt 0) {
            return $prefix
        }
    }
    return ''
}

# install-cef.sh already knows how to fetch CEF on Windows; it only needs a
# POSIX shell to run in.
function Install-Cef {
    $script = Join-Path $ScriptDir 'install-cef.sh'
    if (-not (Test-Path -LiteralPath $script)) { return '' }
    $bash = Find-Bash
    if (-not $bash) { return '' }
    Write-Host "> CEF not found. Running installer ($script)..."
    # Out-Host (not the default stream) so the installer's output is printed
    # instead of being swallowed as this function's return value.
    & $bash $script | Out-Host
    if ($LASTEXITCODE -ne 0) { return '' }
    return (Find-Cef)
}

function Initialize-MsvcEnvironment([string]$VsInstall) {
    $vcvars = Join-Path $VsInstall 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { return $false }
    $envDump = cmd.exe /c "`"$vcvars`" >nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($line in @($envDump)) {
        if ($line -match '^([^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
    return $true
}

function Find-Ninja {
    $cmd = Get-Command ninja -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $vsNinja = $null
    $vsInstall = Find-VsInstallation
    if ($vsInstall) {
        $vsNinja = Join-Path $vsInstall 'Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe'
    }
    if ($vsNinja -and (Test-Path -LiteralPath $vsNinja)) { return $vsNinja }
    return ''
}

# ── dependency check ─────────────────────────────────────────────────────────

$Missing  = @()
$QtPrefix = ''
$CefRoot  = ''
$VsInstall = Find-VsInstallation
$NinjaPath = Find-Ninja

if (-not $VsInstall) { $Missing += 'C++ compiler' }
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { $Missing += 'cmake' }
if (-not $NinjaPath) { $Missing += 'Ninja' }

$QtPrefix = Find-Qt
if (-not $QtPrefix) { $Missing += 'Qt 6' }

$CefRoot = Find-Cef
if (-not $CefRoot) { $CefRoot = Find-CefViaPrefix }
if (-not $CefRoot) { $CefRoot = Install-Cef }
if (-not $CefRoot) { $Missing += 'CEF (Chromium Embedded Framework)' }

if ($Missing.Count -gt 0) {
    Write-Host '✗ Missing build dependencies:'
    foreach ($m in $Missing) { Write-Host "    • $m" }
    Write-Host ''
    Write-Host '  This script builds and packages the app; it doesn''t set up your'
    Write-Host '  toolchain. Install the above yourself, then re-run:'
    Write-Host '    • Visual Studio 2022 with the C++ workload (Build Tools is'
    Write-Host '      enough) - https://visualstudio.microsoft.com/downloads/'
    Write-Host '    • cmake (https://cmake.org/download/) if not installed'
    Write-Host '    • Ninja - winget install Ninja-build.Ninja (or choco install ninja)'
    Write-Host '    • Qt 6 for MSVC, e.g. C:/Qt/6.8.3/msvc2022_64 - set QT_DIR'
    Write-Host '      if it lives somewhere nonstandard'
    Write-Host '    • CEF for Windows - set CEF_ROOT to the extracted path or'
    Write-Host '      install via: ./install-cef.sh'
    if ($QtPrefix) { Write-Host "  (Qt was found at $QtPrefix - ensure CEF_ROOT is also set.)" }
    Write-Host '  Qt installed somewhere nonstandard? Point QT_DIR at its prefix.'
    exit 1
}

$env:CEF_ROOT = To-CMakePath $CefRoot
# let the app and windeployqt resolve Qt when run from the build tree
$env:PATH = (Join-Path $QtPrefix 'bin') + [System.IO.Path]::PathSeparator + $env:PATH

$BuildType = 'Release'
if ($DoDev) { $BuildType = 'Debug' }

# Multi-config generators (Ninja Multi-Config) place binaries in
# build/<Config>/ instead of build/.
$AppBinary = Join-Path $BuildDir (Join-Path $BuildType $AppImage)

if ($DoClean -and (Test-Path -LiteralPath $BuildDir)) {
    Write-Host '> Removing build directory...'
    Remove-Tree $BuildDir
}

Write-Host "> Using Qt at: $QtPrefix"
Write-Host "> Using CEF at: $CefRoot"

# ── configure ────────────────────────────────────────────────────────────────

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    if (-not (Initialize-MsvcEnvironment $VsInstall)) {
        Fail 'Ninja is installed, but the MSVC x64 environment could not be initialized. Open a VS Developer PowerShell or repair Visual Studio Build Tools.'
    }
}
$env:PATH = (Split-Path -Parent $NinjaPath) + [System.IO.Path]::PathSeparator + $env:PATH
$Generator = 'Ninja Multi-Config'
$CacheFile = Join-Path $BuildDir 'CMakeCache.txt'

if (Test-Path -LiteralPath $CacheFile) {
    $cachedGenerator = Get-CacheValue $CacheFile 'CMAKE_GENERATOR:INTERNAL'
    if ($cachedGenerator -and $cachedGenerator -ne $Generator) {
        Write-Host "> Build was configured with generator '$cachedGenerator';"
        Write-Host "  switching to '$Generator' - wiping build dir..."
        Remove-Tree $BuildDir
    }
}

$NeedConfigure = $false
if (-not (Test-Path -LiteralPath $CacheFile)) {
    $NeedConfigure = $true
} elseif ((Normalize-Path (Get-CacheValue $CacheFile 'CMAKE_PREFIX_PATH')) -ne (Normalize-Path $QtPrefix)) {
    $NeedConfigure = $true
} elseif ((Normalize-Path (Get-CacheValue $CacheFile 'CEF_ROOT')) -ne (Normalize-Path $CefRoot)) {
    $NeedConfigure = $true
} else {
    $cmakeLists = Join-Path $ScriptDir 'CMakeLists.txt'
    $cmakeModule = Join-Path $ScriptDir 'cmake\IlluminateModule.cmake'
    $cacheTime = (Get-Item -LiteralPath $CacheFile).LastWriteTimeUtc
    if (((Get-Item -LiteralPath $cmakeLists).LastWriteTimeUtc -gt $cacheTime) -or
        ((Test-Path -LiteralPath $cmakeModule) -and ((Get-Item -LiteralPath $cmakeModule).LastWriteTimeUtc -gt $cacheTime))) {
        Write-Host '> CMake configuration changed since last configure; reconfiguring...'
        $NeedConfigure = $true
    }
}

if ($NeedConfigure) {
    Write-Host "> Configuring ($BuildType, $Generator)..."
    $cmakeArgs = @(
        '-S', $ScriptDir,
        '-B', $BuildDir,
        '-G', $Generator,
        "-DCMAKE_PREFIX_PATH=$(To-CMakePath $QtPrefix)",
        "-DCEF_ROOT=$(To-CMakePath $CefRoot)",
        '-DUSE_SANDBOX=OFF',
        '-DBUILD_TESTING=OFF'
    )
    $cmakeArgs += @('-DCMAKE_C_COMPILER=cl', '-DCMAKE_CXX_COMPILER=cl')
    & cmake @cmakeArgs
    Assert-NativeSuccess 'cmake configure'

    # cmake leaves CMakeCache.txt alone when no value changes, so without a
    # fresh timestamp the "CMakeLists.txt is newer" test above would fire on
    # every single run.
    if (Test-Path -LiteralPath $CacheFile) {
        [System.IO.File]::SetLastWriteTimeUtc($CacheFile, [DateTime]::UtcNow)
    }
}

# ── stop the previous run ────────────────────────────────────────────────────

$running = @(Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($AppImage)) -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host "> Quitting running $AppLabel..."
    # one image name covers the browser process and all CEF subprocesses
    $running | Stop-Process -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 50; $i++) {
        if (-not @(Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($AppImage)) -ErrorAction SilentlyContinue).Count) { break }
        Start-Sleep -Milliseconds 100
    }
    if (@(Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($AppImage)) -ErrorAction SilentlyContinue).Count) {
        Write-Host '  Still running after 5s; could not kill it.'
    }
}

if ($DoClean) {
    if ($DoKeepData) {
        Write-Host '> Keeping app data (--keep-data).'
    } else {
        Write-Host '> Removing app data...'
        # QStandardPaths puts config/data under %APPDATA% and caches under
        # %LOCALAPPDATA%, both rooted in a illuminate org directory.
        foreach ($base in @($env:APPDATA, $env:LOCALAPPDATA)) {
            if ($base) { Remove-Tree (Join-Path $base $AppLabel) }
        }
    }
}

# ── build ────────────────────────────────────────────────────────────────────

Write-Host '> Building...'
# Build the app target and its dependencies only. The default ALL_BUILD target
# also compiles every test executable, which is unnecessary for a normal app
# build and particularly costly with MSVC.
& cmake --build $BuildDir --target illuminate --config $BuildType --parallel ([Environment]::ProcessorCount)
Assert-NativeSuccess 'build'

if (-not (Test-Path -LiteralPath $AppBinary)) {
    Fail "Build finished but binary not found at expected path: $AppBinary"
}
Write-Host '✓ Build succeeded.'
Write-Host "  Binary: $AppBinary"

# ── package ──────────────────────────────────────────────────────────────────

if ($DoPackage) {
    $version = ''
    $m = [regex]::Match([System.IO.File]::ReadAllText((Join-Path $ScriptDir 'CMakeLists.txt')),
                        'project\(illuminate\s+VERSION\s+([0-9.]+)')
    if ($m.Success) { $version = $m.Groups[1].Value }
    if (-not $version) {
        Write-Host '⚠ Could not read a version from CMakeLists.txt; using 0.0.0 for the package name.'
        $version = '0.0.0'
    }

    $distDir  = Join-Path $ScriptDir 'dist'
    $stageDir = Join-Path $distDir 'stage'
    Remove-Tree $stageDir
    if (-not (Test-Path -LiteralPath $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

    Write-Host '> Installing into staging tree (windeployqt + CEF)...'
    & cmake --install $BuildDir --config $BuildType --prefix $stageDir
    Assert-NativeSuccess 'cmake --install'

    if (-not (Test-Path -LiteralPath (Join-Path $stageDir 'bin\illuminate.exe'))) {
        Fail "Staged tree looks incomplete: $stageDir\bin\illuminate.exe is missing."
    }

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
    $pkgPath = Join-Path $distDir "illuminate-$version-windows-$arch.zip"
    if (Test-Path -LiteralPath $pkgPath) { Remove-Item -LiteralPath $pkgPath -Force }

    try {
        Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $pkgPath -Force -ErrorAction Stop
    } catch {
        Write-Host '  Compress-Archive could not read the staged tree; falling back to tar...'
        if (Test-Path -LiteralPath $pkgPath) { Remove-Item -LiteralPath $pkgPath -Force }
        & tar.exe -a -cf $pkgPath -C $stageDir .
        Assert-NativeSuccess 'tar'
    }

    Remove-Tree $stageDir
    Write-Host "✓ Package: $pkgPath"
    Write-Host '  Extract anywhere and run illuminate.exe - Qt and CEF are bundled.'
}

# ── run (detached) ───────────────────────────────────────────────────────────

if ($DoRun -and -not $DoDev) {
    Write-Host "> Launching $AppLabel (detached)..."
    $proc = Start-Process -FilePath $AppBinary -PassThru
    Write-Host "  PID: $($proc.Id)"
}

# ── dev (foreground, live logs) ──────────────────────────────────────────────

if ($DoDev) {
    if (-not (Test-Path -LiteralPath $AppBinary)) {
        Fail "Binary not found at expected path: $AppBinary"
    }

    $logRoot = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $env:APPDATA }
    $logFile = Join-Path $logRoot "$AppLabel\$AppLabel\logs\browser.log"
    Write-Host "  Log file: $logFile"
    Write-Host '  Press Ctrl+C to stop the app.'

    try {
        # The app is a GUI-subsystem binary that mirrors every log line to
        # stderr; the pipes PowerShell attaches here are what carry those
        # lines into this terminal. It writes browser.log itself.
        & $AppBinary 2>&1 | ForEach-Object {
            $text = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ }
            foreach ($line in ($text -split "`r`n|`n")) {
                if ($line.Length) { Write-Host $line }
            }
        }
    } finally {
        Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($AppImage)) -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
}
