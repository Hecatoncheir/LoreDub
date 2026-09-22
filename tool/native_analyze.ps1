# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# Runs MSVC's code analysis (/analyze) over the native library's sources,
# under the flags the build hook compiles them with and /WX, so a finding
# fails the run. The Windows SDK's own headers carry findings of their own,
# which are theirs: angle-bracket includes are external and not analysed.
#
#   powershell -ExecutionPolicy Bypass -File tool/native_analyze.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "Visual Studio's vswhere.exe was not found." }
$studio = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $studio) { throw "No Visual Studio with the C++ tools was found." }
$vcvars = Join-Path $studio "VC\Auxiliary\Build\vcvars64.bat"
# vcvars looks vswhere up on the path itself.
$env:PATH = "$(Split-Path $vswhere);$env:PATH"
$out = Join-Path $root "build\native_analyze"
New-Item -ItemType Directory -Force $out | Out-Null

# The stub is what builds off Windows, and is not what ships here.
$sources = (Get-ChildItem (Join-Path $root "native") -Filter "*.cpp" |
  Where-Object { $_.Name -ne "stub.cpp" } |
  ForEach-Object { "`"$($_.FullName)`"" }) -join " "
$flags = "/nologo /c /std:c++20 /EHsc /W4 /WX /permissive- /utf-8 /sdl /analyze " +
  "/external:anglebrackets /external:W0 /analyze:external- " +
  "/DNOMINMAX /DWIN32_LEAN_AND_MEAN /DUNICODE /D_UNICODE"
cmd /c "`"$vcvars`" >nul && cd /d `"$out`" && cl $flags /I `"$root\native`" $sources >nul"
if ($LASTEXITCODE -ne 0) {
  # Run again where the findings can be read.
  cmd /c "`"$vcvars`" >nul && cd /d `"$out`" && cl $flags /I `"$root\native`" $sources"
  Write-Host "Code analysis found something in native/."
  exit 1
}
Write-Host "native/: no findings under /analyze."
