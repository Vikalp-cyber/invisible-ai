; Flowdesk — Windows installer (Inno Setup 6)
;
; Prerequisites:
;   1. flutter build windows --release
;   2. Inno Setup 6: https://jrsoftware.org/isinfo.php
;
; Build locally:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\invisible_ai_assistant.iss /DMyAppVersion=1.0.1
;
; Or run:  .\scripts\create_installer.ps1
;
; Output: dist\invisible_ai_assistant_setup_<version>.exe

#define MyAppName "Flowdesk"
#define MyAppExeName "invisible_ai_assistant.exe"
#define MyAppPublisher "LuminoAI"
#define MyAppURL "https://github.com/LuminoAi/invisible-ai"

#ifndef MyAppVersion
#define MyAppVersion "1.0.1"
#endif

; Fixed AppId — do not change after first public release (enables in-place upgrades).
#define MyAppId "{{2A4B2D5C-946E-4A6F-9B94-29A76A8D58D1}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

DisableDirPage=auto
UsePreviousAppDir=yes
UsePreviousTasks=yes
UsePreviousLanguage=yes

UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\assets\app_icon.ico

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=..\dist
OutputBaseFilename=invisible_ai_assistant_setup_{#MyAppVersion}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

SetupLogging=yes
CloseApplications=yes
RestartApplications=yes

VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoTextVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter Windows release output (exe, DLLs, data/, flutter_assets/, etc.)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "*.pdb,*.lib,*.exp,*.ilk,*.iobj,*.ipdb,*.obj"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
