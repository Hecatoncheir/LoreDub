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
. (Join-Path $PSScriptRoot "invoke_native.ps1")
$RuntimeCache = Join-Path $env:LOCALAPPDATA "LoreDubBuildCache"
New-Item -ItemType Directory -Force -Path $RuntimeCache, $Destination | Out-Null

# Remove-Item -ErrorAction SilentlyContinue was how a folder that is not there
# was passed over, and it passed over one that could not be removed as well. A
# worker still running out of the destination holds its python.exe: the folder
# stayed, gutted of everything else, Copy-Item put the new runtime inside it as
# python\python-3.11.9, and the script reported nothing.
function Remove-Tree {
  param([string]$Path)
  if (Test-Path $Path) { Remove-Item -Recurse -Force $Path }
}

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
  Remove-Tree $WhisperExtract
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
    Remove-Tree $Source
    Invoke-Native {
      git clone --depth 1 --branch $Tag https://github.com/ggml-org/whisper.cpp $Source
    }
  }

  $Build = Join-Path $Source "build-vulkan"
  $Binary = Join-Path $Build "bin\Release\whisper-cli.exe"
  if (-not (Test-Path $Binary)) {
    Invoke-Native {
      cmake -S $Source -B $Build -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=ON `
        -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON
    }
    Invoke-Native { cmake --build $Build --config Release --target whisper-cli }
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
$Python = Join-Path $PythonCache "python.exe"

# What the bundled interpreter is filled with. torch stands apart because it
# comes from an index of its own, the processor-only build.
$TorchIndex = "https://download.pytorch.org/whl/cpu"
$TorchPackage = "torch==2.7.1"
$Packages = @(
  "numpy==2.2.6",
  "transformers==4.53.3",
  "sentencepiece==0.2.0",
  # sacremoses is what the Marian tokenizer normalizes punctuation with. It is
  # optional, and without it transformers prints a recommendation on every
  # start and leaves quotes and dashes as the text had them.
  "sacremoses==0.2.0",
  # CTranslate2 runs the translator: the same Marian weights in int8, read in
  # about half the time transformers took for them. transformers stays for the
  # tokenizer alone.
  "ctranslate2==4.8.2",
  # Vosk-TTS, the Russian voice under Apache 2.0, runs on onnxruntime's
  # processor build. 1.20 read a line in 754 ms against 1.30's 846 on the
  # same machine, and opens the model as fast once the worker turns memory
  # reuse off (vosk_voice.py).
  "onnxruntime==1.20.1",
  "vosk-tts==0.3.61",
  # The English voice, Kokoro, is read through the same onnxruntime and needs
  # no package of its own: `kokoro_voice.py` opens the model and the voices.
  # What it does need is phonemes, and every other wrapper of that model
  # takes them from espeak-ng, which is GPLv3 and cannot travel inside an MIT
  # application. misaki is Apache 2.0 and reads the words it holds. It is
  # installed without its `[en]` extra on purpose: that extra is what pulls
  # espeakng-loader and phonemizer-fork, the GPL half, and the two packages
  # of it we do want are named here instead.
  "misaki==0.9.4",
  "num2words==0.5.14",
  "spacy==3.8.16",
  # misaki tags the words with this pipeline, and downloads it itself when it
  # is missing -- a network call in the middle of a dubbing session.
  "https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"
)

# Installed without its dependencies, because only its letter-to-sound
# weights are used: `english_g2p.py` reads `checkpoint20.npz` out of the
# package and never imports it. Importing it would pull NLTK in and ask for
# two corpora, downloading them from the network on a machine that is meant
# to dub a game offline.
$WeightsOnly = @("g2p-en==2.1.0")

# The cache is vouched for by a marker written after the last install, and by
# nothing else. It used to be the torch folder, which is the first thing pip
# makes: a run that lost transformers or ctranslate2 to the network left a
# cache the next run took for whole, and the installer carried an interpreter
# the worker could not start on. The marker holds what it vouches for, so a
# cache filled before a package was added here, or before a pin moved, is
# rebuilt too -- which is what sacremoses and ctranslate2 used to be checked
# folder by folder for. The price is torch downloaded again on that day.
$PythonComplete = Join-Path $PythonCache ".complete"
$PythonWanted = @($TorchIndex, $TorchPackage) + $Packages + $WeightsOnly
$PythonKept = if (Test-Path $PythonComplete) { @(Get-Content $PythonComplete) } else { @() }
if (($PythonKept -join "`n") -ne ($PythonWanted -join "`n")) {
  Remove-Tree $PythonCache
  Expand-Archive -Path $PythonZip -DestinationPath $PythonCache
  $Pth = Join-Path $PythonCache "python311._pth"
  (Get-Content $Pth) -replace '#import site', 'import site' | Set-Content -Encoding ascii $Pth
  Add-Content -Encoding ascii $Pth "Lib\site-packages"
  $GetPip = Get-Download "https://bootstrap.pypa.io/get-pip.py" "get-pip.py"
  Invoke-Native { & $Python $GetPip --no-warn-script-location }
  Invoke-Native {
    & $Python -m pip install --no-cache-dir --no-warn-script-location `
      --index-url $TorchIndex $TorchPackage
  }
  Invoke-Native {
    & $Python -m pip install --no-cache-dir --no-warn-script-location @Packages
  }
  Invoke-Native {
    & $Python -m pip install --no-cache-dir --no-warn-script-location --no-deps @WeightsOnly
  }
  Set-Content -Encoding ascii $PythonComplete $PythonWanted
}

$PythonDestination = Join-Path $Destination "python"
Remove-Tree $PythonDestination
Copy-Item $PythonCache $PythonDestination -Recurse
# The marker speaks for the cache. The installer packs everything under the
# destination, and a player's disk is no place for it.
Remove-Item (Join-Path $PythonDestination ".complete")
