#define MyAppName "Mizuzaky System Inspector"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Mizuzaky"
#define MyAppURL "https://github.com/oiky8/mizuzaky-system-inspector"

[Setup]
AppId={{CF0A05EC-5D58-44AA-8F27-02DA926C77C2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\Mizuzaky System Inspector
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=MizuzakySystemInspector-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={sys}\WindowsPowerShell\v1.0\powershell.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "mizuzaky-system-inspector.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "error-catalog.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "locales.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -File ""{app}\mizuzaky-system-inspector.ps1"""; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -File ""{app}\mizuzaky-system-inspector.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -File ""{app}\mizuzaky-system-inspector.ps1"""; WorkingDir: "{app}"; Description: "Run Mizuzaky System Inspector now"; Flags: postinstall nowait skipifsilent runasoriginaluser unchecked
