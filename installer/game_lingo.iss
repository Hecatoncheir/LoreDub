; Copyright (c) 2026 GameLingo contributors.
; SPDX-License-Identifier: MIT

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{07C07368-8B79-4C57-9F15-AE119E7F405B}
AppName=GameLingo
AppVersion={#AppVersion}
AppPublisher=GameLingo contributors
DefaultDirName={localappdata}\Programs\GameLingo
DefaultGroupName=GameLingo
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=GameLingo-{#AppVersion}-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\game_lingo.exe
LicenseFile=..\LICENSE
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\GameLingo"; Filename: "{app}\game_lingo.exe"
Name: "{autodesktop}\GameLingo"; Filename: "{app}\game_lingo.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"

[Run]
Filename: "{app}\game_lingo.exe"; Description: "Запустить GameLingo"; Flags: nowait postinstall skipifsilent
