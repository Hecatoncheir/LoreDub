; Copyright (c) 2026 LoreDub contributors.
; SPDX-License-Identifier: MIT

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{07C07368-8B79-4C57-9F15-AE119E7F405B}
AppName=LoreDub
AppVersion={#AppVersion}
AppPublisher=LoreDub contributors
DefaultDirName={localappdata}\Programs\LoreDub
DefaultGroupName=LoreDub
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=LoreDub-{#AppVersion}-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\lore_dub.exe
LicenseFile=..\LICENSE
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; AppUserModelID is what Windows matches a desktop application's toasts
; against. Without a Start Menu shortcut carrying it, the update notification
; is accepted and filed in the notification centre but never shown.
Name: "{group}\LoreDub"; Filename: "{app}\lore_dub.exe"; AppUserModelID: "com.loredub.LoreDub"
Name: "{autodesktop}\LoreDub"; Filename: "{app}\lore_dub.exe"; Tasks: desktopicon; AppUserModelID: "com.loredub.LoreDub"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"

[Run]
Filename: "{app}\lore_dub.exe"; Description: "Запустить LoreDub"; Flags: nowait postinstall skipifsilent
; The application updates itself by closing and running this setup silently
; with /RELAUNCH; nothing else would open the new version afterwards.
Filename: "{app}\lore_dub.exe"; Flags: nowait; Check: RelaunchRequested

[Code]
function RelaunchRequested: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '/RELAUNCH') = 0 then
      Result := True;
end;
