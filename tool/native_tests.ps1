# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# Builds and runs the native library's own tests: plain executables that fail
# on the first check that does not hold. They cover what can be tried without
# a game, a sound device or a window -- the JSON crossing the boundary, where
# a phrase of the game's speech begins and ends, which reading of the screen
# is trusted, and the frame it is read through.
#
#   powershell -ExecutionPolicy Bypass -File tool/native_tests.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "Visual Studio's vswhere.exe was not found." }
$studio = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $studio) { throw "No Visual Studio with the C++ tools was found." }
$vcvars = Join-Path $studio "VC\Auxiliary\Build\vcvars64.bat"
# vcvars looks vswhere up on the path itself.
$env:PATH = "$(Split-Path $vswhere);$env:PATH"
$out = Join-Path $root "build\native_tests"
New-Item -ItemType Directory -Force $out | Out-Null

$failed = $false
foreach ($test in Get-ChildItem (Join-Path $root "native\tests") -Filter "*_test.cpp") {
  $exe = Join-Path $out ($test.BaseName + ".exe")
  # vcvars sets the compiler's environment for one cmd, which the build and
  # the run share. /utf-8: the tests hold Cyrillic, as the configs do.
  cmd /c "`"$vcvars`" >nul && cl /nologo /std:c++20 /EHsc /W4 /WX /utf-8 /I `"$root\native`" `"$($test.FullName)`" /Fe:`"$exe`" /Fo:`"$out\\`" >nul && `"$exe`""
  if ($LASTEXITCODE -ne 0) {
    Write-Host "$($test.BaseName) failed"
    $failed = $true
  }
}
if ($failed) { exit 1 }
