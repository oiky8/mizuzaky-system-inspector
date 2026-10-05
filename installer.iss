#define MyAppName "mizuzaky-system-inspector"
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
DefaultDirName={localappdata}\Programs\mizuzaky-system-inspector
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=mizuzaky-system-inspector-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={sys}\WindowsPowerShell\v1.0\powershell.exe
LanguageDetectionMethod=uilanguage
ShowLanguageDialog=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "vietnamese"; MessagesFile: "compiler:Default.isl,installer-languages\Vietnamese.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Default.isl,installer-languages\ChineseSimplified.isl"
Name: "chinesetraditional"; MessagesFile: "compiler:Default.isl,installer-languages\ChineseTraditional.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "indonesian"; MessagesFile: "compiler:Default.isl,installer-languages\Indonesian.isl"
Name: "thai"; MessagesFile: "compiler:Languages\Thai.isl"
Name: "hindi"; MessagesFile: "compiler:Default.isl,installer-languages\Hindi.isl"

[CustomMessages]
english.CreateDesktopShortcut=Create a desktop shortcut
english.AdditionalShortcuts=Additional shortcuts:
english.RunNow=Run mizuzaky-system-inspector now
vietnamese.CreateDesktopShortcut=Tạo lối tắt trên màn hình nền
vietnamese.AdditionalShortcuts=Lối tắt bổ sung:
vietnamese.RunNow=Chạy mizuzaky-system-inspector ngay
chinesesimplified.CreateDesktopShortcut=创建桌面快捷方式
chinesesimplified.AdditionalShortcuts=其他快捷方式：
chinesesimplified.RunNow=立即运行 mizuzaky-system-inspector
chinesetraditional.CreateDesktopShortcut=建立桌面捷徑
chinesetraditional.AdditionalShortcuts=其他捷徑：
chinesetraditional.RunNow=立即執行 mizuzaky-system-inspector
spanish.CreateDesktopShortcut=Crear un acceso directo en el escritorio
spanish.AdditionalShortcuts=Accesos directos adicionales:
spanish.RunNow=Ejecutar mizuzaky-system-inspector ahora
french.CreateDesktopShortcut=Créer un raccourci sur le bureau
french.AdditionalShortcuts=Raccourcis supplémentaires :
french.RunNow=Exécuter mizuzaky-system-inspector maintenant
german.CreateDesktopShortcut=Desktopverknüpfung erstellen
german.AdditionalShortcuts=Zusätzliche Verknüpfungen:
german.RunNow=mizuzaky-system-inspector jetzt starten
japanese.CreateDesktopShortcut=デスクトップにショートカットを作成する
japanese.AdditionalShortcuts=追加のショートカット:
japanese.RunNow=mizuzaky-system-inspector を今すぐ実行
korean.CreateDesktopShortcut=바탕 화면 바로 가기 만들기
korean.AdditionalShortcuts=추가 바로 가기:
korean.RunNow=mizuzaky-system-inspector 지금 실행
portuguese.CreateDesktopShortcut=Criar um atalho no ambiente de trabalho
portuguese.AdditionalShortcuts=Atalhos adicionais:
portuguese.RunNow=Executar mizuzaky-system-inspector agora
brazilianportuguese.CreateDesktopShortcut=Criar um atalho na área de trabalho
brazilianportuguese.AdditionalShortcuts=Atalhos adicionais:
brazilianportuguese.RunNow=Executar mizuzaky-system-inspector agora
russian.CreateDesktopShortcut=Создать ярлык на рабочем столе
russian.AdditionalShortcuts=Дополнительные ярлыки:
russian.RunNow=Запустить mizuzaky-system-inspector сейчас
arabic.CreateDesktopShortcut=إنشاء اختصار على سطح المكتب
arabic.AdditionalShortcuts=اختصارات إضافية:
arabic.RunNow=تشغيل mizuzaky-system-inspector الآن
indonesian.CreateDesktopShortcut=Buat pintasan desktop
indonesian.AdditionalShortcuts=Pintasan tambahan:
indonesian.RunNow=Jalankan mizuzaky-system-inspector sekarang
thai.CreateDesktopShortcut=สร้างทางลัดบนเดสก์ท็อป
thai.AdditionalShortcuts=ทางลัดเพิ่มเติม:
thai.RunNow=เรียกใช้ mizuzaky-system-inspector ทันที
hindi.CreateDesktopShortcut=डेस्कटॉप शॉर्टकट बनाएँ
hindi.AdditionalShortcuts=अतिरिक्त शॉर्टकट:
hindi.RunNow=mizuzaky-system-inspector अभी चलाएँ

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopShortcut}"; GroupDescription: "{cm:AdditionalShortcuts}"

[Files]
Source: "mizuzaky-system-inspector.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "error-catalog.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "locales.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "assets\mascot-healthy.png"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "assets\mascot-issue.png"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "assets\mascot-repaired.png"; DestDir: "{app}\assets"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -WindowStyle Hidden -STA -File ""{app}\mizuzaky-system-inspector.ps1"" -Language {code:GetAppUiLanguage}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -WindowStyle Hidden -STA -File ""{app}\mizuzaky-system-inspector.ps1"" -Language {code:GetAppUiLanguage}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -WindowStyle Hidden -STA -File ""{app}\mizuzaky-system-inspector.ps1"" -Language {code:GetAppUiLanguage}"; WorkingDir: "{app}"; Description: "{cm:RunNow}"; Flags: postinstall nowait skipifsilent runasoriginaluser unchecked

[Code]
function GetAppUiLanguage(Param: String): String;
begin
  if ActiveLanguage = 'vietnamese' then
    Result := 'vi'
  else if ActiveLanguage = 'chinesesimplified' then
    Result := 'zh-CN'
  else if ActiveLanguage = 'chinesetraditional' then
    Result := 'zh-TW'
  else if ActiveLanguage = 'spanish' then
    Result := 'es'
  else if ActiveLanguage = 'french' then
    Result := 'fr'
  else if ActiveLanguage = 'german' then
    Result := 'de'
  else if ActiveLanguage = 'japanese' then
    Result := 'ja'
  else if ActiveLanguage = 'korean' then
    Result := 'ko'
  else if (ActiveLanguage = 'portuguese') or (ActiveLanguage = 'brazilianportuguese') then
    Result := 'pt'
  else if ActiveLanguage = 'russian' then
    Result := 'ru'
  else if ActiveLanguage = 'arabic' then
    Result := 'ar'
  else if ActiveLanguage = 'hindi' then
    Result := 'hi'
  else if ActiveLanguage = 'indonesian' then
    Result := 'id'
  else if ActiveLanguage = 'thai' then
    Result := 'th'
  else
    Result := 'en';
end;
