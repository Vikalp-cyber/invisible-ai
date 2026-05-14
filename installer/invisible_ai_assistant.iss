; Flowdesk — production installer
;
; Version is supplied at compile time (required for release builds):
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\invisible_ai_assistant.iss /DMyAppVersion=1.2.3
;
; GitHub Actions: strip a leading "v" from the tag and pass the same /D switch.

#define MyAppName "Flowdesk"
#define MyAppExeName "invisible_ai_assistant.exe"
#define MyAppPublisher "Flowdesk"
#define MyAppURL "https://github.com/LuminoAi/invisible-ai"

; Default for local compiles only — release builds must pass /DMyAppVersion=x.y.z
#ifndef MyAppVersion
#define MyAppVersion "0.0.0-dev"
#endif

; Fixed forever: Windows uses this with uninstall entries and in-place upgrades.
; Do not change after the first public release.
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

; First install: show directory. Upgrades: reuse prior path (same AppId) without manual uninstall.
DisableDirPage=auto
UsePreviousAppDir=yes
UsePreviousTasks=yes
UsePreviousLanguage=yes

UninstallDisplayIcon={app}\{#MyAppExeName}

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Output relative to this .iss (installer\ → repo root\dist\)
OutputDir=..\dist
OutputBaseFilename=invisible_ai_assistant_setup_{#MyAppVersion}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

SetupLogging=yes

; Close running instances during upgrade, then restart them when possible (Restart Manager).
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
; Full Flutter Windows release payload (exe, DLLs, data/, flutter_assets/, etc.)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "*.pdb,*.lib,*.exp,*.ilk,*.iobj,*.ipdb,*.obj"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
