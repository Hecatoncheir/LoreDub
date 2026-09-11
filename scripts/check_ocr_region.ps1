# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# Checks the subtitle frame end to end on this machine, without a game and
# without any model: it opens the test window from ocr_test_window.ps1, runs
# the native OCR capture against it with a few frames, and compares what
# Windows OCR read with what each frame covers.
#
# Build the native library first (flutter build windows --debug). The test
# window takes the foreground while the check runs; leave it in front.

param(
  [string]$Library = (Join-Path $PSScriptRoot "..\build\windows\x64\runner\Debug\lore_dub_native.dll"),
  [int]$Seconds = 10,
  [switch]$Fullscreen,
  [switch]$KeepWindow
)

$ErrorActionPreference = "Stop"
$Library = (Resolve-Path $Library).Path
$Invariant = [Globalization.CultureInfo]::InvariantCulture

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LoreDubNative {
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern IntPtr LoadLibraryW(string path);
  [DllImport("user32.dll")]
  public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

  [DllImport("lore_dub_native.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern int ld_start(byte[] config);
  [DllImport("lore_dub_native.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern int ld_stop();
  [DllImport("lore_dub_native.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern int ld_poll_event_json(byte[] output, int capacity);
  [DllImport("lore_dub_native.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern IntPtr ld_error_message(int code);

  public static void BringToFront(IntPtr window) {
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
    SetForegroundWindow(window);
  }
}
'@

# The app runs per-monitor aware; without it a scaled display would hand the
# capture virtualized coordinates and the frame would land in the wrong place.
[LoreDubNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
if ([LoreDubNative]::LoadLibraryW($Library) -eq [IntPtr]::Zero) {
  throw "Cannot load $Library (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
}

$Window = & (Join-Path $PSScriptRoot "ocr_test_window.ps1") -PassThru -Fullscreen:$Fullscreen
$Deadline = (Get-Date).AddSeconds(15)
while ($Window.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $Deadline) {
  Start-Sleep -Milliseconds 200
  $Window.Refresh()
}
if ($Window.MainWindowHandle -eq [IntPtr]::Zero) { throw "The test window did not open." }

function Read-Events([int]$Seconds) {
  $buffer = New-Object byte[] 65536
  $events = @()
  $until = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $until) {
    $count = [LoreDubNative]::ld_poll_event_json($buffer, $buffer.Length)
    if ($count -gt 0) {
      $events += [Text.Encoding]::UTF8.GetString($buffer, 0, $count).TrimEnd([char]0) | ConvertFrom-Json
    } else {
      Start-Sleep -Milliseconds 80
    }
  }
  $events
}

function Test-Frame([string]$Name, [double[]]$Edges, [scriptblock]$Expect) {
  [LoreDubNative]::BringToFront($Window.MainWindowHandle)
  Start-Sleep -Milliseconds 400
  $inFront = [LoreDubNative]::GetForegroundWindow() -eq $Window.MainWindowHandle
  $config = [string]::Format($Invariant,
    '{{"processId":{0},"captureMode":"ocr","ocrRegionLeft":{1},"ocrRegionTop":{2},"ocrRegionRight":{3},"ocrRegionBottom":{4}}}',
    $Window.Id, $Edges[0], $Edges[1], $Edges[2], $Edges[3])
  $started = [LoreDubNative]::ld_start([Text.Encoding]::UTF8.GetBytes($config + [char]0))
  if ($started -ne 0) {
    $message = [Runtime.InteropServices.Marshal]::PtrToStringAnsi([LoreDubNative]::ld_error_message($started))
    throw "ld_start failed: $message"
  }
  $events = Read-Events $Seconds
  [LoreDubNative]::ld_stop() | Out-Null
  Read-Events 0 | Out-Null

  $texts = @($events | Where-Object { $_.type -eq "ocrText" } | ForEach-Object { $_.text })
  $errors = @($events | Where-Object { $_.type -eq "error" } | ForEach-Object { $_.message })
  $passed = $errors.Count -eq 0 -and (& $Expect $texts)
  $edgesText = ($Edges | ForEach-Object { $_.ToString("0.00", $Invariant) }) -join ", "
  Write-Host ""
  Write-Host ("{0} [{1}]  frame ({2})" -f $(if ($passed) { "PASS" } else { "FAIL" }), $Name, $edgesText) `
    -ForegroundColor $(if ($passed) { "Green" } else { "Red" })
  if (-not $inFront) { Write-Host "  the test window was not in front; click it and run again" -ForegroundColor Yellow }
  foreach ($text in $texts) { Write-Host "  read: $text" }
  if ($texts.Count -eq 0) { Write-Host "  read: nothing" }
  foreach ($message in $errors) { Write-Host "  error: $message" -ForegroundColor Red }
  $passed
}

$results = @()
try {
  # The dialogue line, and nothing of the objective above it.
  $results += Test-Frame "subtitles" @(0.0, 0.7, 1.0, 1.0) {
    param($texts) $texts.Count -gt 0 -and -not ($texts -match "Objective")
  }
  # The objective in the corner, and none of the dialogue below it.
  $results += Test-Frame "objective" @(0.0, 0.0, 0.6, 0.2) {
    param($texts) $texts.Count -gt 0 -and @($texts | Where-Object { $_ -notmatch "Objective" }).Count -eq 0
  }
  # Sky and hills only: a frame over no text must read nothing.
  $results += Test-Frame "empty" @(0.3, 0.3, 0.7, 0.6) {
    param($texts) $texts.Count -eq 0
  }
} finally {
  [LoreDubNative]::ld_stop() | Out-Null
  if (-not $KeepWindow -and -not $Window.HasExited) { $Window.Kill() }
}

Write-Host ""
if ($results -contains $false) {
  Write-Host "Some frames read the wrong text." -ForegroundColor Red
  exit 1
}
Write-Host "Every frame read only the text inside it." -ForegroundColor Green
