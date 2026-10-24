#ifndef AppVersion
  #error AppVersion must be supplied by package_windows_release.ps1
#endif
#ifndef StageDir
  #error StageDir must be supplied by package_windows_release.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by package_windows_release.ps1
#endif
#ifndef AppIdValue
  #define AppIdValue "io.github.zueshans.ojfloat"
#endif
#ifndef OutputName
  #define OutputName "OJ-Float-v" + AppVersion + "-windows-x64-setup"
#endif
#ifndef AppGroupName
  #define AppGroupName "OJ Float"
#endif

[Setup]
AppId={#AppIdValue}
AppName=OJ Float
AppVersion={#AppVersion}
AppVerName=OJ Float {#AppVersion}
AppPublisher=ZuesHans
AppPublisherURL=https://github.com/ZuesHans/oj-desktop-widget
AppSupportURL=https://github.com/ZuesHans/oj-desktop-widget/issues
AppUpdatesURL=https://github.com/ZuesHans/oj-desktop-widget/releases
DefaultDirName={localappdata}\Programs\OJ Float
DefaultGroupName={#AppGroupName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\..\assets\app_icon.ico
UninstallDisplayIcon={app}\oj_float.exe
UninstallDisplayName=OJ Float
LicenseFile=..\..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
CloseApplicationsFilter=oj_float.exe,oj_problem_companion.exe
AppMutex=Local\OJFloat.SingleInstance
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
DisableProgramGroupPage=yes
VersionInfoCompany=ZuesHans
VersionInfoDescription=OJ Float installer
VersionInfoVersion={#AppVersion}

[Tasks]
Name: desktopicon; Description: "Create desktop shortcuts"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OJ Float"; Filename: "{app}\oj_float.exe"; WorkingDir: "{app}"
Name: "{group}\OJ Problem Companion"; Filename: "{app}\oj_problem_companion.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall OJ Float"; Filename: "{uninstallexe}"
Name: "{userdesktop}\OJ Float"; Filename: "{app}\oj_float.exe"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userdesktop}\OJ Problem Companion"; Filename: "{app}\oj_problem_companion.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\oj_float.exe"; Description: "Open OJ Float"; Flags: nowait postinstall skipifsilent

; User data lives in RoamingAppData. No uninstall action removes it.
