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
Name: "{group}\LoreDub"; Filename: "{app}\lore_dub.exe"
Name: "{autodesktop}\LoreDub"; Filename: "{app}\lore_dub.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"

[Run]
Filename: "{app}\lore_dub.exe"; Description: "Запустить LoreDub"; Flags: nowait postinstall skipifsilent
