# Copyright (c) 2026 GameLingo contributors.
# SPDX-License-Identifier: MIT

param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)

$ErrorActionPreference = "Stop"
$RuntimeCache = Join-Path $env:LOCALAPPDATA "GameLingoBuildCache"
New-Item -ItemType Directory -Force -Path $RuntimeCache, $Destination | Out-Null

function Get-Download {
  param([string]$Url, [string]$FileName, [string]$Sha256 = "")
  $Target = Join-Path $RuntimeCache $FileName
  if (-not (Test-Path $Target)) {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$Target.part"
    Move-Item -Force "$Target.part" $Target
  }
  if ($Sha256) {
    $Actual = (Get-FileHash -Algorithm SHA256 $Target).Hash.ToLowerInvariant()
    if ($Actual -ne $Sha256) { throw "SHA-256 mismatch for $FileName" }
  }
  return $Target
}

$WhisperZip = Get-Download `
  "https://github.com/ggml-org/whisper.cpp/releases/download/v1.8.2/whisper-bin-x64.zip" `
  "whisper-bin-x64-v1.8.2.zip" `
  "b1514ebc099765e39fa37eb780b92a140a94c86bb0b3b3d98226b38825979732"
$WhisperExtract = Join-Path $RuntimeCache "whisper-v1.8.2"
if (-not (Test-Path (Join-Path $WhisperExtract "whisper-cli.exe"))) {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $WhisperExtract
  Expand-Archive -Path $WhisperZip -DestinationPath $WhisperExtract
  $WhisperCli = Get-ChildItem $WhisperExtract -Recurse -Filter whisper-cli.exe | Select-Object -First 1
  if (-not $WhisperCli) { throw "whisper-cli.exe is missing from the official archive" }
  Copy-Item (Join-Path $WhisperCli.Directory.FullName "*") $WhisperExtract -Force
}
$WhisperDestination = Join-Path $Destination "whisper"
New-Item -ItemType Directory -Force -Path $WhisperDestination | Out-Null
Copy-Item (Join-Path $WhisperExtract "*.exe"), (Join-Path $WhisperExtract "*.dll") `
  $WhisperDestination -Force

$PythonZip = Get-Download `
  "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" `
  "python-3.11.9-embed-amd64.zip"
$PythonCache = Join-Path $RuntimeCache "python-3.11.9"
if (-not (Test-Path (Join-Path $PythonCache "Lib\site-packages\torch"))) {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $PythonCache
  Expand-Archive -Path $PythonZip -DestinationPath $PythonCache
  $Pth = Join-Path $PythonCache "python311._pth"
  (Get-Content $Pth) -replace '#import site', 'import site' | Set-Content -Encoding ascii $Pth
  Add-Content -Encoding ascii $Pth "Lib\site-packages"
  $GetPip = Get-Download "https://bootstrap.pypa.io/get-pip.py" "get-pip.py"
  & (Join-Path $PythonCache "python.exe") $GetPip --no-warn-script-location
  & (Join-Path $PythonCache "python.exe") -m pip install --no-cache-dir `
    --index-url https://download.pytorch.org/whl/cpu torch==2.7.1
  & (Join-Path $PythonCache "python.exe") -m pip install --no-cache-dir `
    numpy==2.2.6 transformers==4.53.3 sentencepiece==0.2.0
}
$PythonDestination = Join-Path $Destination "python"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $PythonDestination
Copy-Item $PythonCache $PythonDestination -Recurse
