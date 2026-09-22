# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# The steps of .github/workflows/windows.yml, in its order, on this machine.
#
# While GitHub refuses to start the workflow, this is what stands between a
# push and main: run it before pushing, and the ratchets, the goldens, the
# coverage and the native tests are checked as the runner would have. Every
# program goes through Invoke-Native, so the first step that fails ends the
# run with its exit code instead of letting the next one pass for it.
#
#   powershell -ExecutionPolicy Bypass -File tool/verify.ps1
#   powershell -ExecutionPolicy Bypass -File tool/verify.ps1 -SkipBuild
#
# -Base is what the complexity ratchet compares against, origin/main as the
# workflow's push does; -SkipBuild leaves out the release build, which is
# the slowest step and the one a change to Dart alone rarely breaks. A step
# added to the workflow is a step added here.

param(
  [string]$Base = "origin/main",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\scripts\invoke_native.ps1")
Set-Location (Join-Path $PSScriptRoot "..")

# The versions the workflow pins; a ratchet counted by another version of
# its tool is not the ratchet CI holds.
$RuffVersion = "0.16.8"
$NumpyVersion = "2.2.6"
$ComplexityVersion = "0.2.4"
$LinterVersion = "4.4.0"
$BlocToolsVersion = "0.1.0-dev.24"

$Started = Get-Date
$Steps = 0

function Step {
  param(
    [Parameter(Mandatory = $true)] [string]$Name,
    [Parameter(Mandatory = $true)] [scriptblock]$Command
  )
  $script:Steps++
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Invoke-Native $Command
}

Step "pub get" { flutter pub get }
Step "format" { dart format --output=none --set-exit-if-changed lib test tool hook }
Step "ffigen" { dart run tool/ffigen.dart }
Step "gen-l10n" { flutter gen-l10n }
Step "generated code is committed as generated" { git diff --exit-code -- lib/src/native lib/l10n }
Step "analyze" { flutter analyze --fatal-infos }
Step "test" { flutter test --coverage }
Step "coverage of the data layer and the domain does not fall" { dart run tool/coverage.dart }
Step "the worker's pieces" {
  # Without numpy the sound tests are skipped rather than failed, which is
  # how they went unrun; the pin is the runtime's.
  Invoke-Native { python -m pip install --quiet "numpy==$NumpyVersion" }
  python -m unittest discover -s test/runtime -v
}
Step "ruff" {
  # A no-op when the pinned version is already there.
  Invoke-Native { python -m pip install --quiet "ruff==$RuffVersion" }
  python -m ruff check assets/runtime test/runtime scripts
}
Step "native tests" { powershell -ExecutionPolicy Bypass -File tool/native_tests.ps1 }
Step "native code analysis" { powershell -ExecutionPolicy Bypass -File tool/native_analyze.ps1 }
Step "screenshots still match the interface" { flutter test test/screenshots.dart }
Step "cognitive complexity does not grow" {
  Invoke-Native { dart pub global activate cognitive_complexity $ComplexityVersion }
  dart pub global run cognitive_complexity --git-diff=$Base --fail-on-increase --fail-threshold 15 lib
}
Step "cognitive complexity stays under the ceiling" {
  dart pub global run cognitive_complexity --fail-threshold 15 lib
}
Step "widget structure and hand-written styles do not grow" {
  Invoke-Native { dart pub global activate dart_code_linter $LinterVersion }
  Invoke-Native { dart pub global run dart_code_linter:metrics analyze lib --reporter=json --json-path=build/metrics.json --no-fatal-warnings }
  dart run tool/ratchet.dart --metrics build/metrics.json
}
Step "bloc lint" {
  Invoke-Native { dart pub global activate bloc_tools $BlocToolsVersion }
  dart pub global run bloc_tools:bloc lint lib
}
if (-not $SkipBuild) {
  Step "release build" { flutter build windows --release }
}

$Minutes = [math]::Round(((Get-Date) - $Started).TotalMinutes, 1)
Write-Host ""
Write-Host "All $Steps steps passed in $Minutes min." -ForegroundColor Green
