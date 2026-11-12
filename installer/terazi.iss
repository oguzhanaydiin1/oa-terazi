; Terazi — Windows kurulum programı (Inno Setup 6). CI: ISCC /DAppVersion=0.1.0 installer\terazi.iss
; Yönetici izni istemez: kullanıcının kendi klasörüne kurulur.
; AppId sabit kalmalı: güncellemeler aynı kurulumun üzerine yazılır ve uygulama kendini bu kayıttan bulur.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppExe "terazi.exe"

[Setup]
; Windows dili Türkçe değilse kurulum İngilizce
ShowLanguageDialog=auto
LanguageDetectionMethod=uilanguage
AppId={{D99E23B6-9443-4E07-8548-3B2C66E92CFF}
AppName=Terazi
AppVersion={#AppVersion}
AppVerName=Terazi {#AppVersion}
AppPublisher=OA Labs
AppPublisherURL=https://oalabs.dev
AppSupportURL=https://oalabs.dev
DefaultDirName={localappdata}\Programs\Terazi
DefaultGroupName=Terazi
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Terazi-Kurulum
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName=Terazi
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Terazi"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\Terazi"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /im terazi.exe /f"; Flags: runhidden; RunOnceId: "TeraziKapat"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,Terazi}"; Flags: nowait postinstall skipifsilent
; Sessiz kurulum (OA Labs Center'ın güncellemesi): bitince yeni sürümü aç
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
