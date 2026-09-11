# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

param(
  [Parameter(Mandatory = $true)]
  [string]$Destination,

  # Build the Vulkan whisper.cpp binary, which AMD and Intel cards use. There
  # is no official Windows build of it, so it is compiled here. Without the
  # Vulkan SDK the step is skipped with a warning; -RequireVulkan turns that
  # skip into an error, which is what release builds want.
  [switch]$SkipVulkan,
  [switch]$RequireVulkan
)

$ErrorActionPreference = "Stop"
$RuntimeCache = Join-Path $env:LOCALAPPDATA "LoreDubBuildCache"
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

# The CUDA build is downloaded by the application on demand, but Vulkan has no
# official Windows release at all, so it is built from the same tag.
function Build-VulkanWhisper {
  param([string]$Destination, [string]$Tag)

  $VulkanSdk = $env:VULKAN_SDK
  if (-not $VulkanSdk -or -not (Test-Path $VulkanSdk)) {
    $message = "Vulkan SDK not found (VULKAN_SDK is unset). " +
      "Skipping the Vulkan whisper build; AMD and Intel cards will fall back to the CPU."
    if ($RequireVulkan) { throw $message }
    Write-Warning $message
    return
  }

  $Source = Join-Path $RuntimeCache "whisper.cpp-$Tag"
  if (-not (Test-Path (Join-Path $Source "CMakeLists.txt"))) {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Source
    git clone --depth 1 --branch $Tag https://github.com/ggml-org/whisper.cpp $Source
    if ($LASTEXITCODE -ne 0) { throw "Failed to clone whisper.cpp $Tag" }
  }

  $Build = Join-Path $Source "build-vulkan"
  $Binary = Join-Path $Build "bin\Release\whisper-cli.exe"
  if (-not (Test-Path $Binary)) {
    cmake -S $Source -B $Build -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=ON `
      -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON
    if ($LASTEXITCODE -ne 0) { throw "Failed to configure the Vulkan whisper build" }
    cmake --build $Build --config Release --target whisper-cli
    if ($LASTEXITCODE -ne 0) { throw "Failed to build the Vulkan whisper binary" }
  }

  $Target = Join-Path $Destination "whisper-vulkan"
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item (Join-Path $Build "bin\Release\*.exe"), (Join-Path $Build "bin\Release\*.dll") `
    $Target -Force
}

if (-not $SkipVulkan) { Build-VulkanWhisper -Destination $Destination -Tag "v1.8.2" }

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

# sacremoses is what the Marian tokenizer normalizes punctuation with. It is
# optional, and without it transformers prints a recommendation on every start
# and leaves quotes and dashes as the text had them. Checked on its own so a
# cache filled by an earlier build gains it without downloading torch again.
if (-not (Test-Path (Join-Path $PythonCache "Lib\site-packages\sacremoses"))) {
  & (Join-Path $PythonCache "python.exe") -m pip install --no-cache-dir `
    --no-warn-script-location sacremoses==0.2.0
}
$PythonDestination = Join-Path $Destination "python"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $PythonDestination
Copy-Item $PythonCache $PythonDestination -Recurse
