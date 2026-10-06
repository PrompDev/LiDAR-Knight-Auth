; LiDAR-Knight Auth: one-click Windows installer (Inno Setup 6).
;
; This is the fork's OWN installer. It never reuses Ente's AppId, so it can't replace or uninstall a real Ente Auth.
; AppId below must NEVER change after the first release: Windows uses it to find this app for upgrades and uninstall.
;
; Per-user install (no administrator prompt): %LOCALAPPDATA%\Programs\LiDAR-Knight Auth, Start-menu and desktop
; shortcuts, and "Launch" on the last page. The only click is Finish. Unsigned: SmartScreen shows "More info → Run anyway".
;
; Build (after `flutter build windows --release` in mobile/apps/auth):
;   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" /DMyAppVersion=4.4.31 /DVcRedist="<VS>\VC\Redist\MSVC\<ver>\x64\Microsoft.VC143.CRT" LiDAR-Knight-Auth.iss
; Output: mobile/apps/auth/build/installer/LiDAR-Knight-Auth-Setup.exe

#define MyAppName "LiDAR-Knight Auth"
#ifndef MyAppVersion
  #define MyAppVersion "4.4.32"
#endif
#define MyAppPublisher "PrompDev"
#define MyAppURL "https://github.com/PrompDev/LiDAR-Knight-Auth"
#define MyAppExeName "auth.exe"
#ifndef SourceDir
  #define SourceDir "..\..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{9D2BB997-46D5-494B-B352-3AA386B9994D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright=LiDAR-Knight Auth contributors. A modified fork of Ente Auth, (c) Ente Technologies, Inc. AGPL-3.0.
VersionInfoDescription={#MyAppName} installer (fork of Ente Auth)
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\..\build\installer
OutputBaseFilename=LiDAR-Knight-Auth-Setup
SetupIconFile=..\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
; 4.4.31: the LiDAR Knight emblem replaces the generic box icon top right (Inno picks the size for the screen scaling).
WizardSmallImageFile=art\lk-emblem-small-55x55.bmp,art\lk-emblem-small-64x68.bmp,art\lk-emblem-small-83x80.bmp,art\lk-emblem-small-92x97.bmp,art\lk-emblem-small-110x106.bmp,art\lk-emblem-small-119x123.bmp,art\lk-emblem-small-138x140.bmp
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#ifdef VcRedist
; Visual C++ runtime, deployed app-locally (Microsoft's redistributable files) so the app runs on PCs without it.
Source: "{#VcRedist}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRedist}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRedist}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
#endif
Source: "..\..\..\..\..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE-AGPL-3.0.txt"; Flags: ignoreversion
; 4.4.31: the LiDAR Knight banner on the "Ready to Install" page (DeAndre). Setup-only files, never installed.
Source: "art\lk-banner-1x.bmp"; Flags: dontcopy
Source: "art\lk-banner-1.5x.bmp"; Flags: dontcopy
Source: "art\lk-banner-2x.bmp"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// 4.4.31 (DeAndre): the LiDAR Knight banner fills the empty box on the "Ready to Install" page. The art for 100 %, 150 %
// or 200 % scaling is chosen by the wizard's own scale, shown at its native width (narrowed only if the page is narrower),
// keeping its 3:1 shape, centred where the (empty) ready memo was.
procedure InitializeWizard;
var
  Banner: TBitmapImage;
  Name: String;
  W, H: Integer;
begin
  if ScaleX(100) >= 175 then Name := 'lk-banner-2x.bmp'
  else if ScaleX(100) >= 125 then Name := 'lk-banner-1.5x.bmp'
  else Name := 'lk-banner-1x.bmp';
  ExtractTemporaryFile(Name);
  Banner := TBitmapImage.Create(WizardForm);
  Banner.Parent := WizardForm.ReadyPage;
  Banner.Bitmap.LoadFromFile(ExpandConstant('{tmp}\' + Name));
  W := Banner.Bitmap.Width;
  if W > WizardForm.ReadyMemo.Width then W := WizardForm.ReadyMemo.Width;
  H := W * Banner.Bitmap.Height div Banner.Bitmap.Width;
  Banner.Stretch := True;
  Banner.SetBounds(WizardForm.ReadyMemo.Left + (WizardForm.ReadyMemo.Width - W) div 2, WizardForm.ReadyMemo.Top, W, H);
  WizardForm.ReadyMemo.Visible := False;
end;
