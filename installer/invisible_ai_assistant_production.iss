; =========================================================
; Invisible AI Assistant - Production Inno Setup Script
; =========================================================

#define MyAppName "Invisible AI Assistant"
#define MyAppExeName "invisible_ai_assistant.exe"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Invisible AI"
#define MyAppURL "https://github.com/Vikalp-cyber/invisible-ai"
#define MyAppId "{{E5913033-D79E-4F93-A8A3-33F260E090D5}"

; IMPORTANT:
; Keep these paths aligned with your local workspace/build output.
#define BuildRoot "C:\Users\avipa\invisible_ai_assistant\build\windows\x64\runner\Release"
#define OutputRoot "C:\Users\avipa\Downloads"
#define SetupIcon "C:\Users\avipa\invisible_ai_assistant\windows\runner\resources\app_icon.ico"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir={#OutputRoot}
OutputBaseFilename=invisible_ai_setup_{#MyAppVersion}
SetupIconFile={#SetupIcon}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

UsePreviousAppDir=yes
UsePreviousTasks=yes
UsePreviousLanguage=yes
SetupLogging=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start {#MyAppName} when Windows starts"; Flags: unchecked

[Files]
; Package full Flutter release runtime in one rule.
; NOTE: Excludes must be on the same line as Source.
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "*.pdb,*.lib,*.exp,*.ilk,*.iobj,*.ipdb,*.obj"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "InvisibleAIAssistant"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: startupicon; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

