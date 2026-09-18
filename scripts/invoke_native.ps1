# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# Dot-sourced by the build scripts; it runs nothing on its own.
#
# $ErrorActionPreference = "Stop" stops a script on a failing cmdlet and says
# nothing about a program: flutter, pip or ISCC can exit with an error and the
# next line runs all the same -- always in Windows PowerShell 5.1, and in
# PowerShell 7 unless $PSNativeCommandUseErrorActionPreference is switched on.
# A CI step sees the exit code of the last command only, so a tag whose tests
# had failed was still built into an installer and published. Every program
# these scripts start therefore goes through here:
#
#   Invoke-Native { flutter test }
#
# Leave the program's stderr where it is inside the block. Under 5.1 with
# "Stop", a 2>&1 turns the first line written there into a terminating error,
# and git and pip both report their progress on stderr.
function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )

  # A program that is not found is PowerShell's own error rather than an exit
  # code, and only "Stop" makes it end the script instead of the one line.
  $ErrorActionPreference = "Stop"
  # Whatever ran before must not answer for this command: a block that starts
  # no program would otherwise be judged by the last one that did.
  $global:LASTEXITCODE = 0
  & $Command
  if ($LASTEXITCODE -ne 0) {
    # As it was written, on one line: the continuation marks and the
    # indentation of a wrapped command are no use in a build log.
    $Text = ($Command.ToString() -replace '`\r?\n', ' ' -replace '\s+', ' ').Trim()
    throw "Command failed with exit code ${LASTEXITCODE}: $Text"
  }
}
