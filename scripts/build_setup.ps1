# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

param(
  [string]$ReleaseTag = ""
)

$ErrorActionPreference = "Stop"
$CommitSuffix = if ($env:CI_COMMIT_SHORT_SHA) { $env:CI_COMMIT_SHORT_SHA } else { "local" }
$EffectiveTag = if ($ReleaseTag) {
  $ReleaseTag
} elseif ($env:CI_COMMIT_TAG) {
  $env:CI_COMMIT_TAG
} elseif ($env:GITHUB_REF_TYPE -eq "tag") {
  $env:GITHUB_REF_NAME
} else {
  ""
}
$PubspecVersion = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([^+\s]+)').Matches.Groups[1].Value
if (-not $PubspecVersion) {
  throw "Could not read the application version from pubspec.yaml."
}
$PackageVersion = if ($EffectiveTag) { $EffectiveTag.TrimStart("v") } else { "$PubspecVersion-$CommitSuffix" }
$BuildVersion = $PubspecVersion

flutter config --enable-windows-desktop
flutter pub get
dart run tool/ffigen.dart
flutter analyze --fatal-infos
flutter test
flutter build windows --release --build-name $BuildVersion

$ReleaseDirectory = "build\windows\x64\runner\Release"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare_windows_runtime.ps1 `
  -Destination (Join-Path $ReleaseDirectory "runtime")

$IsccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$Iscc = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Iscc) {
  throw "Inno Setup 6 is not installed on the GitLab runner."
}

New-Item -ItemType Directory -Force -Path dist | Out-Null
& $Iscc "/DAppVersion=$PackageVersion" "installer\lore_dub.iss"
