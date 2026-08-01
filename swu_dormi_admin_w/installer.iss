[Setup]
AppName=샬롬하우스 관리 시스템
AppVersion=1.0.0
AppPublisher=SWU Dormi Admin
DefaultDirName={autopf}\ShalomHouseAdmin
DefaultGroupName=샬롬하우스 관리 시스템
OutputDir=installer
OutputBaseFilename=ShalomHouseAdmin_Setup_v1.0.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\swu_dormi_admin.exe
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\샬롬하우스 관리 시스템"; Filename: "{app}\swu_dormi_admin.exe"
Name: "{group}\{cm:UninstallProgram,샬롬하우스 관리 시스템}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\샬롬하우스 관리 시스템"; Filename: "{app}\swu_dormi_admin.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\swu_dormi_admin.exe"; Description: "{cm:LaunchProgram,샬롬하우스 관리 시스템}"; Flags: nowait postinstall skipifsilent
