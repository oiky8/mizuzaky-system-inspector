#requires -Version 5.1

param(
    [switch]$ConfigureEmail,
    [ValidateSet('en', 'vi', 'zh-CN', 'zh-TW', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'ru', 'ar', 'hi', 'id', 'th')]
    [string]$Language
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('MizuzakyFileChangeMonitor' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32.SafeHandles;

public sealed class MizuzakyFileChangeMonitor : IDisposable
{
    private const int MaximumQueuedPaths = 2048;
    private readonly ConcurrentQueue<string> paths = new ConcurrentQueue<string>();
    private readonly ConcurrentDictionary<string, byte> queued =
        new ConcurrentDictionary<string, byte>(StringComparer.OrdinalIgnoreCase);
    private readonly List<FileSystemWatcher> watchers = new List<FileSystemWatcher>();
    private int pendingCount;
    private int overflowed;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    public int RootCount { get { return watchers.Count; } }

    public void AddRoot(string path)
    {
        FileSystemWatcher watcher = new FileSystemWatcher(path);
        try
        {
            watcher.IncludeSubdirectories = true;
            watcher.NotifyFilter = NotifyFilters.FileName |
                NotifyFilters.LastWrite | NotifyFilters.Size | NotifyFilters.CreationTime;
            watcher.InternalBufferSize = 16384;
            watcher.Created += OnFileCreated;
            watcher.Changed += OnFileChanged;
            watcher.Renamed += OnFileRenamed;
            watcher.Error += OnWatcherError;
            watcher.EnableRaisingEvents = true;
            watchers.Add(watcher);
        }
        catch
        {
            watcher.Dispose();
            throw;
        }
    }

    public bool TryDequeue(out string path)
    {
        if (!paths.TryDequeue(out path))
            return false;

        byte ignored;
        queued.TryRemove(path, out ignored);
        Interlocked.Decrement(ref pendingCount);
        return true;
    }

    public bool ConsumeOverflow()
    {
        return Interlocked.Exchange(ref overflowed, 0) != 0;
    }

    private void OnFileCreated(object sender, FileSystemEventArgs args)
    {
        if (File.Exists(args.FullPath) && IsReviewablePath(args.FullPath))
            Enqueue(args.FullPath);
    }

    private void OnFileChanged(object sender, FileSystemEventArgs args)
    {
        if (!IsReviewablePath(args.FullPath))
            return;

        string extension = Path.GetExtension(args.FullPath).ToLowerInvariant();
        if (IsSourceFile(extension))
        {
            Enqueue(args.FullPath);
            return;
        }

        int errorCode;
        if (HasInternetZoneStream(args.FullPath, out errorCode))
            Enqueue(args.FullPath);
        else if (errorCode != 2 && errorCode != 3 && errorCode != 32)
            Interlocked.Exchange(ref overflowed, 1);
    }

    private static bool HasInternetZoneStream(string path, out int errorCode)
    {
        using (SafeFileHandle handle = CreateFile(
            path + ":Zone.Identifier",
            0x80000000,
            0x00000001 | 0x00000002 | 0x00000004,
            IntPtr.Zero,
            3,
            0x00000080,
            IntPtr.Zero))
        {
            errorCode = handle.IsInvalid ? Marshal.GetLastWin32Error() : 0;
            return !handle.IsInvalid;
        }
    }

    private static bool IsSourceFile(string extension)
    {
        return extension == ".ps1" || extension == ".psm1" || extension == ".psd1" ||
            extension == ".bat" || extension == ".cmd" || extension == ".vbs" ||
            extension == ".js" || extension == ".mjs" || extension == ".cjs" ||
            extension == ".ts" || extension == ".tsx" || extension == ".jsx" ||
            extension == ".py" || extension == ".rb" || extension == ".pl" ||
            extension == ".php" || extension == ".java" || extension == ".kt" ||
            extension == ".go" || extension == ".rs" || extension == ".c" ||
            extension == ".h" || extension == ".cc" || extension == ".cpp" ||
            extension == ".hpp" || extension == ".cs" || extension == ".fs" ||
            extension == ".sh" || extension == ".lua" || extension == ".r" ||
            extension == ".swift" || extension == ".sql" || extension == ".html" ||
            extension == ".hta" || extension == ".yml" || extension == ".yaml" ||
            extension == ".json" || extension == ".toml";
    }

    private static bool IsReviewablePath(string path)
    {
        string[] ignoredDirectories = {
            ".git", "node_modules", "vendor", "bin", "obj", ".venv",
            "venv", "__pycache__", "dist", "build", ".next"
        };
        foreach (string segment in path.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar))
        {
            foreach (string ignored in ignoredDirectories)
            {
                if (String.Equals(segment, ignored, StringComparison.OrdinalIgnoreCase))
                    return false;
            }
        }

        string extension = Path.GetExtension(path).ToLowerInvariant();
        return IsSourceFile(extension) || extension == ".exe" || extension == ".dll" ||
            extension == ".msi" || extension == ".scr" || extension == ".com" ||
            extension == ".zip";
    }

    private void OnFileRenamed(object sender, RenamedEventArgs args)
    {
        if (File.Exists(args.FullPath) && IsReviewablePath(args.FullPath))
            Enqueue(args.FullPath);
    }

    private void OnWatcherError(object sender, ErrorEventArgs args)
    {
        Interlocked.Exchange(ref overflowed, 1);
    }

    public void Enqueue(string path)
    {
        if (!queued.TryAdd(path, 0))
            return;

        if (Interlocked.Increment(ref pendingCount) > MaximumQueuedPaths)
        {
            Interlocked.Decrement(ref pendingCount);
            byte ignored;
            queued.TryRemove(path, out ignored);
            Interlocked.Exchange(ref overflowed, 1);
            return;
        }

        paths.Enqueue(path);
    }

    public void Dispose()
    {
        foreach (FileSystemWatcher watcher in watchers)
            watcher.Dispose();
        watchers.Clear();
    }
}
'@
}

$appDirectory = Join-Path $env:LOCALAPPDATA 'MizuzakySystemInspector'
$logPath = Join-Path $appDirectory 'assistant.log'
$emailConfigPath = Join-Path $appDirectory 'email-config.json'
$emailCredentialPath = Join-Path $appDirectory 'email-credential.xml'
$lastReportPath = Join-Path $appDirectory 'last-report.dat'
$catalogPath = Join-Path (Split-Path -Parent $PSCommandPath) 'error-catalog.json'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Mizuzaky System Inspector.lnk'
$scriptPath = $PSCommandPath
$script:window = $null
$script:notificationIcon = $null
$script:statusText = $null
$script:logText = $null
$script:startupButton = $null
$script:onlineSearchButton = $null
$script:onlineSearchQuery = $null
$script:fileReviewSearchQuery = $null
$script:knowledgeEntries = @()
$script:checkTimer = $null
$script:fileReviewTimer = $null
$script:fileMonitor = $null
$script:fileReviewObservations = @{}
$script:fileReviewInspectedSignatures = @{}
$script:fileReviewLastLoadCheck = [DateTime]::MinValue
$script:fileReviewLoadBusy = $true
$script:fileReviewFindingCount = 0
$script:fileReviewUnreportedCount = 0
$script:fileMonitorRoots = 0
$script:fileMonitoringUnavailable = $false
$script:fileMonitoringCoverageIncomplete = $false
$script:prioritySet = $false
$script:checkIntervalHours = 3
$script:busyRetryMinutes = 15
$script:busyCpuThreshold = 70
$script:minimumFreeMemoryMB = 1536
$script:emailReportMinimumInterval = [TimeSpan]::FromHours(1)
$script:emailReportRepeatInterval = [TimeSpan]::FromHours(24)
$script:reportStateEntropy = [Text.Encoding]::UTF8.GetBytes('MizuzakySystemInspector.ReportState.v1')
if ($Language) {
    $script:language = $Language
}
else {
    $uiCulture = [Globalization.CultureInfo]::CurrentUICulture
    if ($uiCulture.Name -match '^zh-(TW|HK|MO|Hant)') {
        $script:language = 'zh-TW'
    }
    elseif ($uiCulture.TwoLetterISOLanguageName -eq 'zh') {
        $script:language = 'zh-CN'
    }
    else {
        $script:language = $uiCulture.TwoLetterISOLanguageName
    }
}
$localePath = Join-Path (Split-Path -Parent $PSCommandPath) 'locales.json'
try {
    $script:uiText = Get-Content -LiteralPath $localePath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if (-not $script:uiText.en) {
        throw 'The locale catalog must include English.'
    }
    if (-not $script:uiText.PSObject.Properties[$script:language]) {
        $script:language = 'en'
    }
}
catch {
    [System.Windows.MessageBox]::Show(
        ('Could not load the locale catalog: {0}' -f $_.Exception.Message),
        'Mizuzaky System Inspector',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    exit 1
}
$script:programmingRuntimes = @(
    [pscustomobject]@{ Name = 'Python'; Commands = @('python.exe', 'py.exe'); Processes = @('python.exe', 'pythonw.exe') },
    [pscustomobject]@{ Name = 'Node.js'; Commands = @('node.exe'); Processes = @('node.exe') },
    [pscustomobject]@{ Name = 'Java'; Commands = @('java.exe'); Processes = @('java.exe', 'javaw.exe') },
    [pscustomobject]@{ Name = '.NET'; Commands = @('dotnet.exe'); Processes = @('dotnet.exe') },
    [pscustomobject]@{ Name = 'Go'; Commands = @('go.exe'); Processes = @('go.exe') },
    [pscustomobject]@{ Name = 'Rust'; Commands = @('rustc.exe', 'cargo.exe'); Processes = @('rustc.exe', 'cargo.exe') },
    [pscustomobject]@{ Name = 'PHP'; Commands = @('php.exe'); Processes = @('php.exe') },
    [pscustomobject]@{ Name = 'Ruby'; Commands = @('ruby.exe'); Processes = @('ruby.exe') },
    [pscustomobject]@{ Name = 'Perl'; Commands = @('perl.exe'); Processes = @('perl.exe') },
    [pscustomobject]@{ Name = 'Lua'; Commands = @('lua.exe', 'luajit.exe'); Processes = @('lua.exe', 'luajit.exe') },
    [pscustomobject]@{ Name = 'R'; Commands = @('R.exe'); Processes = @('R.exe', 'Rscript.exe') },
    [pscustomobject]@{ Name = 'Swift'; Commands = @('swift.exe'); Processes = @('swift.exe') },
    [pscustomobject]@{ Name = 'C/C++ toolchain'; Commands = @('clang.exe', 'gcc.exe', 'cl.exe'); Processes = @('clang.exe', 'gcc.exe', 'cl.exe') }
)
$script:detectedRuntimes = @()

New-Item -ItemType Directory -Path $appDirectory -Force | Out-Null

function Set-PrivatePathAcl {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][bool]$IsDirectory
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('Refusing to use a reparse point for protected application data: {0}' -f $Path)
    }

    if ($IsDirectory) {
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    }
    else {
        $acl = New-Object System.Security.AccessControl.FileSecurity
        $inheritance = [System.Security.AccessControl.InheritanceFlags]::None
    }

    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($script:currentUserSid)
    foreach ($sid in @($script:currentUserSid, [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.AddAccessRule($rule)
    }

    $existingAcl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $existingOwnerSid = ([System.Security.Principal.NTAccount]::new($existingAcl.Owner)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    )
    $existingRules = @($existingAcl.Access)
    $expectedRules = @($acl.Access)
    $alreadyPrivate = $existingAcl.AreAccessRulesProtected -and
        $existingOwnerSid.Value -eq $script:currentUserSid.Value -and
        $existingRules.Count -eq $expectedRules.Count

    if ($alreadyPrivate) {
        foreach ($expectedRule in $expectedRules) {
            $expectedSid = $expectedRule.IdentityReference.Translate(
                [System.Security.Principal.SecurityIdentifier]
            ).Value
            $matchingRules = @($existingRules | Where-Object {
                -not $_.IsInherited -and
                $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $expectedSid -and
                $_.FileSystemRights -eq $expectedRule.FileSystemRights -and
                $_.InheritanceFlags -eq $expectedRule.InheritanceFlags -and
                $_.PropagationFlags -eq $expectedRule.PropagationFlags -and
                $_.AccessControlType -eq $expectedRule.AccessControlType
            })
            if ($matchingRules.Count -ne 1) {
                $alreadyPrivate = $false
                break
            }
        }
    }

    if ($alreadyPrivate) {
        return
    }

    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Assert-PrivatePathAcl {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('Refusing to use a reparse point for protected application data: {0}' -f $Path)
    }
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $ownerSid = ([System.Security.Principal.NTAccount]::new($acl.Owner)).Translate([System.Security.Principal.SecurityIdentifier])
    if ($ownerSid.Value -ne $script:currentUserSid.Value -or -not $acl.AreAccessRulesProtected) {
        throw ('Protected application data has an unexpected owner or inherited permissions: {0}' -f $Path)
    }

    $allowedSids = @($script:currentUserSid.Value, 'S-1-5-18')
    foreach ($rule in $acl.Access) {
        $ruleSid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        if ($rule.IsInherited -or $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or $ruleSid -notin $allowedSids) {
            throw ('Protected application data has an unexpected access rule: {0}' -f $Path)
        }
    }
}

function Protect-PrivateFile {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Set-PrivatePathAcl -Path $Path -IsDirectory $false
        Assert-PrivatePathAcl -Path $Path
    }
}

$script:currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
Set-PrivatePathAcl -Path $appDirectory -IsDirectory $true
Assert-PrivatePathAcl -Path $appDirectory
$legacyReportPath = Join-Path $appDirectory 'last-report.json'
if (Test-Path -LiteralPath $legacyReportPath) {
    Protect-PrivateFile -Path $legacyReportPath
    Remove-Item -LiteralPath $legacyReportPath -Force -ErrorAction Stop
}

function Get-Text {
    param([Parameter(Mandatory)][string]$Key)
    return $script:uiText.$($script:language).$Key
}

function Get-InstalledProgrammingRuntimes {
    $detected = New-Object System.Collections.Generic.List[object]
    foreach ($runtime in $script:programmingRuntimes) {
        $foundCommand = $null
        foreach ($commandName in $runtime.Commands) {
            $foundCommand = Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($foundCommand) {
                break
            }
        }
        if ($foundCommand) {
            $detected.Add([pscustomobject]@{
                Name = $runtime.Name
                Processes = $runtime.Processes
            })
        }
    }
    return @($detected.ToArray())
}

function Normalize-SmtpHost {
    param([Parameter(Mandatory)][string]$HostName)

    $hostValue = $HostName.Trim().TrimEnd('.')
    if ($hostValue.Length -gt 253 -or $hostValue -match '[\s/@:]') {
        throw 'Use a public DNS hostname for the SMTP server, not an IP address or local name.'
    }

    $ipAddress = $null
    if ([Net.IPAddress]::TryParse($hostValue, [ref]$ipAddress)) {
        throw 'SMTP IP addresses are not accepted; use the provider hostname so TLS can validate its identity.'
    }

    try {
        $asciiHost = ([Globalization.IdnMapping]::new()).GetAscii($hostValue).ToLowerInvariant()
    }
    catch {
        throw 'The SMTP server name is not a valid internationalized DNS hostname.'
    }

    if ($asciiHost.Length -gt 253 -or $asciiHost -notmatch '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' -or
        $asciiHost -match '\.(local|localhost|internal|test|invalid|example|home|corp|lan|intranet|private|onion)$|\.home\.arpa$') {
        throw 'Use a fully qualified public DNS hostname for the SMTP server.'
    }
    return $asciiHost
}

function Get-ValidatedEmailAddress {
    param([Parameter(Mandatory)][string]$Address)

    if ($Address.Length -gt 254 -or $Address -match '[\r\n]') {
        throw 'Enter a valid email address.'
    }
    try {
        $mailAddress = New-Object System.Net.Mail.MailAddress($Address.Trim())
    }
    catch {
        throw 'Enter a valid email address.'
    }
    if ($mailAddress.Address -ine $Address.Trim()) {
        throw 'Enter only an email address, without a display name.'
    }
    return $mailAddress.Address
}

function Read-EmailConfiguration {
    $hasConfig = Test-Path -LiteralPath $emailConfigPath
    $hasCredential = Test-Path -LiteralPath $emailCredentialPath
    if (-not $hasConfig -and -not $hasCredential) {
        return $null
    }
    if (-not $hasConfig -or -not $hasCredential) {
        throw 'Email configuration is incomplete.'
    }

    try {
        Assert-PrivatePathAcl -Path $appDirectory
        Assert-PrivatePathAcl -Path $emailConfigPath
        Assert-PrivatePathAcl -Path $emailCredentialPath
        if ((Get-Item -LiteralPath $emailConfigPath).Length -gt 16384 -or (Get-Item -LiteralPath $emailCredentialPath).Length -gt 65536) {
            throw 'Email configuration files exceed their permitted size.'
        }
        $config = Get-Content -LiteralPath $emailConfigPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $config.host -or -not $config.port -or -not $config.from -or -not $config.to) {
            throw 'Email configuration is incomplete.'
        }
        $smtpHost = Normalize-SmtpHost -HostName ([string]$config.host)
        if ([int]$config.port -ne 587) {
            throw 'Only authenticated SMTP submission with STARTTLS on port 587 is supported.'
        }
        $sender = Get-ValidatedEmailAddress -Address ([string]$config.from)
        $recipient = Get-ValidatedEmailAddress -Address ([string]$config.to)
        $credential = Import-Clixml -LiteralPath $emailCredentialPath -ErrorAction Stop
        if ($credential -isnot [System.Management.Automation.PSCredential] -or
            [string]::IsNullOrWhiteSpace($credential.UserName) -or
            $credential.GetNetworkCredential().Password.Length -lt 1) {
            throw 'The saved SMTP credential is invalid.'
        }

        return [pscustomobject]@{
            Host = $smtpHost
            Port = 587
            From = $sender
            To = $recipient
            Credential = $credential
        }
    }
    catch {
        Write-Error ('Could not load email configuration: {0}' -f $_.Exception.Message)
    }
}

function Send-EmailMessage {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body
    )

    if ($Configuration.Port -ne 587 -or (Normalize-SmtpHost -HostName $Configuration.Host) -ne $Configuration.Host) {
        throw 'Refusing to send email without a validated SMTP STARTTLS destination on port 587.'
    }
    $client = New-Object System.Net.Mail.SmtpClient($Configuration.Host, $Configuration.Port)
    $message = New-Object System.Net.Mail.MailMessage($Configuration.From, $Configuration.To, $Subject, $Body)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $client.EnableSsl = $true
        $client.UseDefaultCredentials = $false
        $client.Credentials = $Configuration.Credential.GetNetworkCredential()
        $client.Timeout = 10000
        $client.Send($message)
    }
    finally {
        $message.Dispose()
        $client.Dispose()
    }
}

function Configure-Email {
    $hostName = Read-Host (Get-Text 'EmailSetupHost')
    if ([string]::IsNullOrWhiteSpace($hostName)) {
        throw 'SMTP server name cannot be empty.'
    }
    $hostName = Normalize-SmtpHost -HostName $hostName
    $portInput = Read-Host (Get-Text 'EmailSetupPort')
    $port = 0
    if (-not [int]::TryParse($portInput, [ref]$port) -or $port -ne 587) {
        throw 'For security, only SMTP submission with STARTTLS on port 587 is supported.'
    }

    $sender = Get-ValidatedEmailAddress -Address (Read-Host (Get-Text 'EmailSetupSender'))
    $recipient = Get-ValidatedEmailAddress -Address (Read-Host (Get-Text 'EmailSetupRecipient'))
    $credential = Get-Credential -Message 'Enter the SMTP username and app password. It is encrypted for this Windows user.'
    if (-not $credential) {
        throw 'Email setup was cancelled because no SMTP credential was provided.'
    }

    $config = [pscustomobject]@{
        host = $hostName.Trim()
        port = $port
        from = $sender.Trim()
        to = $recipient.Trim()
    }
    $config | ConvertTo-Json | Set-Content -LiteralPath $emailConfigPath -Encoding UTF8
    Protect-PrivateFile -Path $emailConfigPath
    $credential | Export-Clixml -LiteralPath $emailCredentialPath -Force
    Protect-PrivateFile -Path $emailCredentialPath
    Write-Output ('Email settings saved under {0}. The credential is protected for this Windows user.' -f $appDirectory)

    $answer = Read-Host (Get-Text 'EmailTestPrompt')
    if ($answer -match '^(y|yes)$') {
        $configuration = Read-EmailConfiguration
        Send-EmailMessage -Configuration $configuration `
            -Subject (Get-Text 'EmailReportTitle') `
            -Body ((Get-Text 'EmailReportTitle') + [Environment]::NewLine + ((Get-Text 'ReportTime') -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')))
        Write-Output 'Test email sent successfully.'
    }
}

if ($ConfigureEmail) {
    try {
        Configure-Email
        exit 0
    }
    catch {
        Write-Error ('Email setup failed: {0}' -f $_.Exception.Message)
        exit 1
    }
}

try {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($catalog.version -ne 1 -or -not $catalog.entries -or -not $catalog.safeRepairs) {
        throw 'The local error catalog has an unsupported format.'
    }
    $script:knowledgeEntries = @($catalog.entries)
    $script:safeRepairs = @($catalog.safeRepairs)
}
catch {
    [void][System.Windows.MessageBox]::Show(
        ('Could not load the local error catalog: {0}' -f $_.Exception.Message),
        'Mizuzaky System Inspector',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    exit 1
}

function Write-AssistantLog {
    param([Parameter(Mandatory)][string]$Message)

    $entry = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $entry -Encoding UTF8
    Protect-PrivateFile -Path $logPath

    if ($script:logText) {
        $script:logText.Text = (Get-Content -LiteralPath $logPath -Tail 6 -ErrorAction Stop) -join [Environment]::NewLine
    }
}

function Get-GitRepositoryRoot {
    param([Parameter(Mandatory)][string]$Path)

    $directory = New-Object System.IO.DirectoryInfo([System.IO.Path]::GetDirectoryName($Path))
    while ($directory) {
        if (Test-Path -LiteralPath (Join-Path $directory.FullName '.git')) {
            return $directory.FullName
        }
        $directory = $directory.Parent
    }
    return $null
}

function Get-CodeRiskFindings {
    param([Parameter(Mandatory)][string]$Content)

    $findings = New-Object System.Collections.Generic.List[string]
    $networkPattern = '(?i)DownloadString|Invoke-WebRequest|Invoke-RestMethod|WebClient|requests\.(get|post)|urlopen|fetch\s*\(|curl\s|wget\s'
    $executionPattern = '(?i)Invoke-Expression|\bIEX\b|\beval\s*\(|\bexec\s*\(|Start-Process|subprocess\.(run|Popen|call)|child_process\.(exec|spawn)'
    $hasNetworkRetrieval = $Content -match $networkPattern
    $hasDynamicExecution = $Content -match $executionPattern
    if ($hasNetworkRetrieval) {
        $findings.Add('network-or-download-api-present')
    }
    if ($hasDynamicExecution) {
        $findings.Add('dynamic-execution-api-present')
    }
    if ($hasNetworkRetrieval -and $hasDynamicExecution) {
        $findings.Add('network-plus-dynamic-execution')
    }
    if ($Content -match '(?i)-EncodedCommand|FromBase64String|base64\.b64decode|Buffer\.from.{0,40}base64') {
        $findings.Add('encoded-or-obfuscated-command')
    }
    if ($Content -match '(?i)DisableRealtimeMonitoring|Add-MpPreference.{0,100}Exclusion|Set-MpPreference.{0,100}Disable') {
        $findings.Add('security-control-tampering')
    }
    return @($findings.ToArray())
}

function Read-LimitedStreamText {
    param(
        [Parameter(Mandatory)][System.IO.Stream]$Stream,
        [Parameter(Mandatory)][int]$MaximumCharacters
    )

    $reader = New-Object System.IO.StreamReader($Stream, [Text.Encoding]::UTF8, $true, 4096, $true)
    try {
        $buffer = New-Object 'char[]' $MaximumCharacters
        $length = $reader.Read($buffer, 0, $buffer.Length)
        return [string]::new($buffer, 0, $length)
    }
    finally {
        $reader.Dispose()
    }
}

function Get-ZipCodeRiskFindings {
    param([Parameter(Mandatory)][string]$Path)

    $findings = New-Object System.Collections.Generic.List[string]
    $codeExtensions = @(
        '.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.vbs', '.js', '.mjs', '.cjs', '.ts',
        '.tsx', '.jsx', '.py', '.rb', '.pl', '.php', '.java', '.kt', '.go', '.rs', '.c',
        '.h', '.cc', '.cpp', '.hpp', '.cs', '.fs', '.sh', '.lua', '.r', '.swift', '.sql',
        '.html', '.hta', '.yml', '.yaml', '.json', '.toml'
    )
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $inspectedEntries = 0
        $inspectedBytes = 0
        foreach ($entry in $archive.Entries) {
            if ($inspectedEntries -ge 50 -or $inspectedBytes -ge 5242880) {
                break
            }
            if ($entry.FullName -match '(^|/)\.git(/|$)|(^|/)node_modules(/|$)' -or
                [System.IO.Path]::GetExtension($entry.FullName).ToLowerInvariant() -notin $codeExtensions -or
                $entry.Length -gt 262144) {
                continue
            }

            $entryStream = $entry.Open()
            try {
                $content = Read-LimitedStreamText -Stream $entryStream -MaximumCharacters 262144
            }
            finally {
                $entryStream.Dispose()
            }
            $inspectedEntries++
            $inspectedBytes += $entry.Length
            foreach ($finding in (Get-CodeRiskFindings -Content $content)) {
                if (-not $findings.Contains($finding)) {
                    $findings.Add($finding)
                }
            }
        }
    }
    finally {
        $archive.Dispose()
    }
    return @($findings.ToArray())
}

function Get-MonitoredFileFindings {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        return
    }

    $zoneStream = $null
    try {
        $zoneStream = Get-Item -LiteralPath $Path -Stream 'Zone.Identifier' -ErrorAction Stop
    }
    catch {
        if ($_.FullyQualifiedErrorId -notlike 'AlternateDataStreamNotFound,*') {
            throw
        }
    }
    $downloadedFromInternet = $false
    if ($zoneStream) {
        $zoneText = Get-Content -LiteralPath $Path -Stream 'Zone.Identifier' -Raw -ErrorAction Stop
        $downloadedFromInternet = $zoneText -match '(?m)^ZoneId=(3|4)\s*$'
    }

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $isCodeFile = $extension -in @(
        '.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.vbs', '.js', '.mjs', '.cjs', '.ts',
        '.tsx', '.jsx', '.py', '.rb', '.pl', '.php', '.java', '.kt', '.go', '.rs', '.c',
        '.h', '.cc', '.cpp', '.hpp', '.cs', '.fs', '.sh', '.lua', '.r', '.swift', '.sql',
        '.html', '.hta', '.yml', '.yaml', '.json', '.toml'
    )
    $repositoryRoot = $null
    if ($isCodeFile -and $Path -notmatch '(?i)(^|[\\/])\.git([\\/]|$)') {
        $repositoryRoot = Get-GitRepositoryRoot -Path $Path
    }
    if (-not $downloadedFromInternet -and -not $repositoryRoot) {
        return
    }

    $findings = New-Object System.Collections.Generic.List[string]
    if ($downloadedFromInternet -and $extension -eq '.zip' -and $item.Length -le 52428800) {
        foreach ($finding in (Get-ZipCodeRiskFindings -Path $Path)) {
            $findings.Add($finding)
        }
    }
    elseif ($isCodeFile -and $item.Length -le 262144) {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $content = Read-LimitedStreamText -Stream $stream -MaximumCharacters 262144
        }
        finally {
            $stream.Dispose()
        }
        foreach ($finding in (Get-CodeRiskFindings -Content $content)) {
            $findings.Add($finding)
        }
    }
    elseif ($downloadedFromInternet -and $item.Length -le 104857600 -and
        $extension -in @('.exe', '.dll', '.msi', '.scr', '.com')) {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($signature.Status -in @('HashMismatch', 'NotTrusted', 'UnknownError')) {
            $findings.Add('invalid-or-untrusted-authenticode-signature')
        }
    }

    return [pscustomobject]@{
        IsInternetDownload = $downloadedFromInternet
        RepositoryRoot = $repositoryRoot
        Findings = @($findings.ToArray())
    }
}

function Start-LocalFileMonitoring {
    $script:fileMonitor = New-Object MizuzakyFileChangeMonitor
    $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
    $knownFolders = @(
        (Join-Path $env:USERPROFILE 'Downloads')
        [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
        [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($folder in $knownFolders) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            $script:fileMonitoringCoverageIncomplete = $true
            Write-AssistantLog ('User folder is not available for file monitoring: {0}' -f $folder)
            continue
        }
        $volumeRoot = [IO.Path]::GetPathRoot($folder)
        $volume = $drives | Where-Object { $_.DeviceID -eq $volumeRoot.TrimEnd('\') } | Select-Object -First 1
        if (-not $volume -or $volume.FileSystem -ne 'NTFS') {
            $script:fileMonitoringCoverageIncomplete = $true
            Write-AssistantLog ('Skipping file monitoring for non-local-NTFS folder: {0}' -f $folder)
            continue
        }
        try {
            $script:fileMonitor.AddRoot($folder)
            Write-AssistantLog ('Local NTFS file-change monitoring started for user folder {0}.' -f $folder)
        }
        catch {
            $script:fileMonitoringCoverageIncomplete = $true
            Write-AssistantLog ('Could not monitor user folder {0}: {1}' -f $folder, $_.Exception.Message)
        }
    }

    $script:fileMonitorRoots = $script:fileMonitor.RootCount
    if ($script:fileMonitorRoots -eq 0) {
        $script:fileMonitoringUnavailable = $true
        $script:statusText.Text = Get-Text 'FileWatchUnavailable'
        Write-AssistantLog 'No local NTFS user folder could be monitored for file changes.'
        return
    }

    Write-AssistantLog ('Monitoring {0} user folders on local NTFS volumes. Other folders are not monitored; no file contents are uploaded or executed.' -f $script:fileMonitorRoots)
    $script:fileReviewTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:fileReviewTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:fileReviewTimer.Add_Tick({ Invoke-PendingFileReview })
    $script:fileReviewTimer.Start()
}

function Invoke-PendingFileReview {
    if (-not $script:fileMonitor) {
        return
    }

    if ($script:fileMonitor.ConsumeOverflow()) {
        $script:fileMonitoringCoverageIncomplete = $true
        $script:statusText.Text = Get-Text 'FileWatchCoverageWarning'
        Write-AssistantLog 'File monitoring reported a notification or queue overflow; some changes may have been missed.'
    }

    if (([DateTime]::Now - $script:fileReviewLastLoadCheck) -ge [TimeSpan]::FromSeconds(15)) {
        $script:fileReviewLastLoadCheck = [DateTime]::Now
        try {
            $load = Get-SystemLoad
            $script:fileReviewLoadBusy = $load.CpuPercent -ge $script:busyCpuThreshold -or
                $load.FreeMemoryMB -lt $script:minimumFreeMemoryMB
        }
        catch {
            $script:fileReviewLoadBusy = $true
            Write-AssistantLog ('File review paused because system load could not be measured: {0}' -f $_.Exception.Message)
        }
    }
    if ($script:fileReviewLoadBusy) {
        return
    }

    for ($index = 0; $index -lt 2; $index++) {
        $path = $null
        if (-not $script:fileMonitor.TryDequeue([ref]$path)) {
            break
        }
        try {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                [void]$script:fileReviewObservations.Remove($path)
                continue
            }
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            $signature = '{0}|{1}' -f $item.Length, $item.LastWriteTimeUtc.Ticks
            if (-not $script:fileReviewObservations.ContainsKey($path) -or
                $script:fileReviewObservations[$path].Signature -ne $signature) {
                $attempts = 1
                if ($script:fileReviewObservations.ContainsKey($path)) {
                    $attempts = $script:fileReviewObservations[$path].Attempts + 1
                }
                if ($attempts -ge 6) {
                    [void]$script:fileReviewObservations.Remove($path)
                    Write-AssistantLog ('File review skipped a file that kept changing: {0}' -f $path)
                    $script:fileMonitoringCoverageIncomplete = $true
                    $script:statusText.Text = Get-Text 'FileWatchCoverageWarning'
                    continue
                }
                $script:fileReviewObservations[$path] = @{
                    Signature = $signature
                    Attempts = $attempts
                    ObservedAt = [DateTime]::Now
                }
                $script:fileMonitor.Enqueue($path)
                continue
            }
            if (([DateTime]::Now - $script:fileReviewObservations[$path].ObservedAt) -lt [TimeSpan]::FromSeconds(2)) {
                $script:fileMonitor.Enqueue($path)
                continue
            }
            [void]$script:fileReviewObservations.Remove($path)
            if ($script:fileReviewInspectedSignatures.ContainsKey($path) -and
                $script:fileReviewInspectedSignatures[$path] -eq $signature) {
                continue
            }

            $review = Get-MonitoredFileFindings -Path $path
            if (-not $review) {
                continue
            }
            if ($script:fileReviewInspectedSignatures.Count -ge 4096) {
                $script:fileReviewInspectedSignatures.Clear()
            }
            $script:fileReviewInspectedSignatures[$path] = $signature
            if ($review.Findings.Count -gt 0) {
                $script:fileReviewFindingCount++
                $script:fileReviewUnreportedCount++
                $findingSummary = $review.Findings -join ', '
                Write-AssistantLog ('Static review heuristic flagged {0}: {1}' -f $path, $findingSummary)
                $script:statusText.Text = (Get-Text 'FileReviewFlagged') -f $script:fileReviewFindingCount
                $searchTopics = foreach ($finding in $review.Findings) {
                    switch ($finding) {
                        'network-or-download-api-present' { 'PowerShell script network download API safe security review' }
                        'dynamic-execution-api-present' { 'PowerShell script dynamic code execution eval exec security risks' }
                        'network-plus-dynamic-execution' { 'safely review script downloading and executing code' }
                        'encoded-or-obfuscated-command' { 'Windows encoded PowerShell command security review' }
                        'security-control-tampering' { 'Microsoft Defender settings changed script security review' }
                        'invalid-or-untrusted-authenticode-signature' { 'Windows Authenticode signature untrusted verify publisher safely' }
                    }
                }
                if ($searchTopics) {
                    $script:fileReviewSearchQuery = (@($searchTopics | Select-Object -Unique) -join ' ')
                    $script:onlineSearchQuery = $script:fileReviewSearchQuery
                    $script:onlineSearchButton.IsEnabled = $true
                }
            }
        }
        catch {
            [void]$script:fileReviewObservations.Remove($path)
            Write-AssistantLog ('Could not review monitored file {0}: {1}' -f $path, $_.Exception.Message)
        }
    }
}

function Read-ProtectedReportState {
    if (-not (Test-Path -LiteralPath $lastReportPath)) {
        return $null
    }

    Assert-PrivatePathAcl -Path $lastReportPath
    if ((Get-Item -LiteralPath $lastReportPath).Length -gt 8192) {
        throw 'The protected email report state exceeds its permitted size.'
    }

    $protectedBytes = [Convert]::FromBase64String((Get-Content -LiteralPath $lastReportPath -Raw -Encoding ASCII -ErrorAction Stop).Trim())
    $plainBytes = $null
    try {
        $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
            $protectedBytes,
            $script:reportStateEntropy,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        $state = [Text.Encoding]::UTF8.GetString($plainBytes) | ConvertFrom-Json -ErrorAction Stop
        $sentAt = [DateTimeOffset]::MinValue
        if ($state.fingerprint -notmatch '^[A-Fa-f0-9]{64}$' -or
            -not [DateTimeOffset]::TryParse([string]$state.sentAt, [ref]$sentAt)) {
            throw 'Protected email report state is invalid.'
        }
        return [pscustomobject]@{
            Fingerprint = [string]$state.fingerprint
            SentAt = $sentAt
        }
    }
    finally {
        if ($plainBytes) {
            [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        }
        [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
    }
}

function Write-ProtectedReportState {
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [Parameter(Mandatory)][DateTimeOffset]$SentAt
    )

    if (Test-Path -LiteralPath $lastReportPath) {
        Assert-PrivatePathAcl -Path $lastReportPath
    }
    $plainBytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject @{
        fingerprint = $Fingerprint
        sentAt = $SentAt.ToString('o')
    }))
    $protectedBytes = $null
    try {
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $script:reportStateEntropy,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        [Convert]::ToBase64String($protectedBytes) | Set-Content -LiteralPath $lastReportPath -Encoding ASCII -NoNewline
        Protect-PrivateFile -Path $lastReportPath
    }
    finally {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        if ($protectedBytes) {
            [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
        }
    }
}

function Send-HealthReport {
    param([Parameter(Mandatory)][string[]]$Issues)

    if ($Issues.Count -eq 0) {
        return
    }

    $reportText = @(
        (Get-Text 'ReportFindings')
        ((Get-Text 'ReportCount') -f $Issues.Count)
    ) -join [Environment]::NewLine
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fingerprint = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($reportText))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }

    try {
        $lastReport = Read-ProtectedReportState
    }
    catch {
        Write-AssistantLog ('Email report blocked because its protected anti-repeat state could not be verified: {0}' -f $_.Exception.Message)
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'EmailStateUntrusted')
        return
    }
    if ($lastReport) {
        $age = [DateTimeOffset]::Now - $lastReport.SentAt
        if ($age -lt $script:emailReportMinimumInterval) {
            Write-AssistantLog 'Email report deferred by the minimum-interval limit.'
            return
        }
        if ($lastReport.Fingerprint -eq $fingerprint -and $age -lt $script:emailReportRepeatInterval) {
            Write-AssistantLog 'Email report skipped because the same privacy-safe summary was sent recently.'
            return
        }
    }

    try {
        $configuration = Read-EmailConfiguration
    }
    catch {
        Write-AssistantLog ('Email report could not load its local configuration: {0}' -f $_.Exception.Message)
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'EmailConfigError')
        return
    }
    if (-not $configuration) {
        Write-AssistantLog 'Email report not sent: configure an SMTP account with -ConfigureEmail.'
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'EmailMissing')
        return
    }

    $body = @(
        (Get-Text 'EmailReportTitle')
        ((Get-Text 'ReportTime') -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
        ''
        $reportText
        ''
        (Get-Text 'EmailReportPrivacy')
    ) -join [Environment]::NewLine

    try {
        Send-EmailMessage -Configuration $configuration `
            -Subject (Get-Text 'EmailReportTitle') `
            -Body $body
    }
    catch {
        Write-AssistantLog ('Email report failed: {0}' -f $_.Exception.Message)
        $script:statusText.Text += [Environment]::NewLine + ((Get-Text 'EmailFailed') -f $_.Exception.Message)
        return
    }

    try {
        Write-ProtectedReportState -Fingerprint $fingerprint -SentAt ([DateTimeOffset]::Now)
        Write-AssistantLog 'Privacy-minimized email health report sent successfully.'
    }
    catch {
        Write-AssistantLog ('Email was sent, but protected anti-repeat state could not be saved; a duplicate report may be sent later: {0}' -f $_.Exception.Message)
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'EmailStateWriteFailed')
    }
}

function Test-NetworkConnection {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect('1.1.1.1', 443, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(2500, $false)) {
            throw 'Connection test timed out.'
        }
        $client.EndConnect($pending)
    }
    finally {
        $client.Close()
    }
}

function Get-SystemLoad {
    $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
        Measure-Object -Property LoadPercentage -Average
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    if ($null -eq $processors.Average -or $null -eq $operatingSystem.FreePhysicalMemory) {
        throw 'Windows did not report CPU or available memory usage.'
    }

    [pscustomobject]@{
        CpuPercent = [math]::Round($processors.Average)
        FreeMemoryMB = [math]::Round($operatingSystem.FreePhysicalMemory / 1024)
    }
}

function Show-HealthNotification {
    param(
        [Parameter(Mandatory)][string]$Message,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    if (-not $script:notificationIcon -or -not $script:notificationIcon.Visible) {
        return
    }

    try {
        $script:notificationIcon.ShowBalloonTip(5000, (Get-Text 'AppTitle'), $Message, $Icon)
        Write-AssistantLog 'Displayed a Windows notification-area health-check summary.'
    }
    catch {
        Write-AssistantLog ('Could not display a Windows notification: {0}' -f $_.Exception.Message)
    }
}

function Invoke-ScheduledHealthCheck {
    if (-not $script:prioritySet) {
        $script:statusText.Text = Get-Text 'PriorityPaused'
        Write-AssistantLog 'Health check postponed because the mascot could not lower its process priority.'
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    try {
        $load = Get-SystemLoad
    }
    catch {
        $script:statusText.Text = Get-Text 'LoadUnavailable'
        Write-AssistantLog ('Health check postponed because system load could not be measured: {0}' -f $_.Exception.Message)
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    if ($load.CpuPercent -ge $script:busyCpuThreshold -or $load.FreeMemoryMB -lt $script:minimumFreeMemoryMB) {
        $script:statusText.Text = ((Get-Text 'MachineBusy') -f
            $load.CpuPercent, $load.FreeMemoryMB, $script:busyRetryMinutes)
        Write-AssistantLog ('Health check postponed: CPU {0}%, free memory {1} MB.' -f $load.CpuPercent, $load.FreeMemoryMB)
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    try {
        Invoke-HealthCheck
    }
    catch {
        $script:statusText.Text = Get-Text 'CheckFailed'
        Write-AssistantLog ('Health check failed: {0}' -f $_.Exception.Message)
        Show-HealthNotification -Message (Get-Text 'NotificationFailed') -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
        Send-HealthReport -Issues @('Health check failed; details are recorded in the local log.')
    }
    finally {
        $script:checkTimer.Interval = [TimeSpan]::FromHours($script:checkIntervalHours)
    }
}

function Invoke-HealthCheck {
    $issues = New-Object System.Collections.Generic.List[string]
    $script:onlineSearchQuery = $null
    $script:onlineSearchButton.IsEnabled = $false
    $script:detectedRuntimes = Get-InstalledProgrammingRuntimes
    $reportedRuntimeEvents = @{}

    try {
        $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
        foreach ($drive in $drives) {
            $freeGiB = [math]::Round($drive.FreeSpace / 1GB, 1)
            if ($freeGiB -lt 5) {
                $issues.Add(((Get-Text 'DiskLow') -f $drive.DeviceID, $freeGiB))
                if (-not $script:onlineSearchQuery) {
                    $script:onlineSearchQuery = 'Windows low disk space safe troubleshooting'
                }
            }
        }
    }
    catch {
        $issues.Add(((Get-Text 'DiskFailed') -f $_.Exception.Message))
        Write-AssistantLog ('Disk check failed: {0}' -f $_.Exception.Message)
    }

    try {
        [void][System.Net.Dns]::GetHostAddresses('www.microsoft.com')
    }
    catch {
        $dnsError = $_.Exception.Message
        if (-not $script:onlineSearchQuery) {
            $script:onlineSearchQuery = 'Windows DNS name resolution troubleshooting'
        }
        $dnsRepair = $script:safeRepairs | Where-Object { $_.id -eq 'flush-dns-cache' } | Select-Object -First 1
        Write-AssistantLog ('DNS lookup failed: {0}' -f $dnsError)
        try {
            if (-not $dnsRepair -or $dnsRepair.action -ne 'FlushDnsCache' -or -not $dnsRepair.sourceUrl.StartsWith('https://learn.microsoft.com/', [StringComparison]::OrdinalIgnoreCase)) {
                throw 'No approved Microsoft-sourced repair is configured for this issue.'
            }

            Test-NetworkConnection
            $flush = Start-Process -FilePath "$env:SystemRoot\System32\ipconfig.exe" `
                -ArgumentList '/flushdns' -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($flush.ExitCode -ne 0) {
                throw ('ipconfig /flushdns exited with code {0}.' -f $flush.ExitCode)
            }
            [void][System.Net.Dns]::GetHostAddresses('www.microsoft.com')
            $issues.Add(((Get-Text 'DnsRepairSucceeded') -f $dnsRepair.sourceUrl))
            Write-AssistantLog ('DNS cache refresh succeeded. Source: {0}' -f $dnsRepair.sourceUrl)
        }
        catch {
            $issues.Add(((Get-Text 'DnsLookupFailed') -f $dnsError))
            $issues.Add(((Get-Text 'DnsRepairFailed') -f $_.Exception.Message, $(if ($dnsRepair) { $dnsRepair.sourceUrl } else { 'No verified source is configured.' })))
            Write-AssistantLog ('DNS repair was skipped or did not resolve the issue: {0}' -f $_.Exception.Message)
        }
    }

    $seenEvents = @{}
    $knownEventCount = 0
    $unknownEventCount = 0
    foreach ($logName in @('System', 'Application')) {
            try {
                $recentEvents = @(Get-WinEvent -LogName $logName -MaxEvents 100 -ErrorAction Stop |
                    Where-Object { $_.Level -eq 2 -and $_.TimeCreated -ge (Get-Date).AddHours(-24) })
                foreach ($eventRecord in $recentEvents) {
                    if ($logName -eq 'Application' -and $eventRecord.Id -in @(1000, 1001) -and $script:detectedRuntimes.Count -gt 0) {
                        try {
                            $eventMessage = $eventRecord.Message
                            foreach ($runtime in $script:detectedRuntimes) {
                                $matchedProcess = $runtime.Processes |
                                    Where-Object { $eventMessage -match ('(?i)(?<![\w.-]){0}(?![\w.-])' -f [regex]::Escape($_)) } |
                                    Select-Object -First 1
                                if ($matchedProcess) {
                                    $runtimeEventKey = '{0}|{1}|{2}' -f $runtime.Name, $eventRecord.Id, $eventRecord.TimeCreated.Ticks
                                    if (-not $reportedRuntimeEvents.ContainsKey($runtimeEventKey)) {
                                        $reportedRuntimeEvents[$runtimeEventKey] = $true
                                        $issues.Add(((Get-Text 'RuntimeCrash') -f $runtime.Name, $eventRecord.Id, $eventRecord.TimeCreated.ToString('yyyy-MM-dd HH:mm')))
                                    }
                                }
                            }
                        }
                        catch {
                            Write-AssistantLog ('Could not inspect event {0} for a programming-runtime crash: {1}' -f $eventRecord.Id, $_.Exception.Message)
                        }
                    }

                    $key = '{0}|{1}|{2}' -f $eventRecord.LogName, $eventRecord.ProviderName, $eventRecord.Id
                    if ($seenEvents.ContainsKey($key)) {
                        continue
                    }
                    $seenEvents[$key] = $true

                    $entry = $script:knowledgeEntries |
                        Where-Object { $_.log -eq $eventRecord.LogName -and $_.provider -eq $eventRecord.ProviderName -and [int]$_.eventId -eq $eventRecord.Id } |
                        Select-Object -First 1

                    if ($entry) {
                        $knownEventCount++
                        if ($knownEventCount -le 5) {
                            $summarySuffix = $script:language.Replace('-', '')
                            $summaryProperty = 'summary{0}' -f $summarySuffix
                            $summary = $entry.$summaryProperty
                            if (-not $summary) {
                                $summary = $entry.summary
                            }
                            $issues.Add(((Get-Text 'EventKnown') -f $eventRecord.Id, $eventRecord.ProviderName, $eventRecord.LogName, $summary))
                        }
                        $script:onlineSearchQuery = 'Windows event {0} {1} {2}' -f $eventRecord.LogName, $eventRecord.ProviderName, $eventRecord.Id
                    }
                    else {
                        $unknownEventCount++
                        $script:onlineSearchQuery = 'Windows event {0} {1} {2}' -f $eventRecord.LogName, $eventRecord.ProviderName, $eventRecord.Id
                    }
                }
            }
            catch {
                $issues.Add(((Get-Text 'EventLogFailed') -f $logName, $_.Exception.Message))
                Write-AssistantLog ('Could not inspect the {0} event log: {1}' -f $logName, $_.Exception.Message)
            }
    }

    if ($knownEventCount -gt 5) {
            $issues.Add(((Get-Text 'EventExtraKnown') -f ($knownEventCount - 5)))
    }
    if ($unknownEventCount -gt 0) {
            $issues.Add(((Get-Text 'EventUnknown') -f $unknownEventCount))
    }
    if ($script:onlineSearchQuery) {
            $script:onlineSearchButton.IsEnabled = $true
    }
    Write-AssistantLog ('Event log scan completed: {0} known and {1} uncatalogued recent error type(s).' -f $knownEventCount, $unknownEventCount)

    try {
            Test-NetworkConnection
    }
    catch {
        $issues.Add(((Get-Text 'NetworkFailed') -f $_.Exception.Message))
        if (-not $script:onlineSearchQuery) {
            $script:onlineSearchQuery = 'Windows internet connection network troubleshooting'
        }
        Write-AssistantLog ('Internet connection test failed: {0}' -f $_.Exception.Message)
    }

    if ($script:fileReviewUnreportedCount -gt 0) {
        $issues.Add(((Get-Text 'FileReviewFlagged') -f $script:fileReviewUnreportedCount))
        $script:fileReviewUnreportedCount = 0
        if (-not $script:onlineSearchQuery -and $script:fileReviewSearchQuery) {
            $script:onlineSearchQuery = $script:fileReviewSearchQuery
        }
    }

    if ($issues.Count -eq 0) {
        $script:statusText.Text = Get-Text 'AllGood'
        Write-AssistantLog 'Health check completed: no issues detected.'
    }
    else {
        $script:statusText.Text = ((Get-Text 'IssuesFound') -f $issues.Count) + [Environment]::NewLine + ($issues -join [Environment]::NewLine)
        Write-AssistantLog ('Health check found {0} issue(s).' -f $issues.Count)
    }

    if ($script:detectedRuntimes.Count -gt 0) {
        $runtimeNames = ($script:detectedRuntimes | ForEach-Object { $_.Name }) -join ', '
        $script:statusText.Text += [Environment]::NewLine + ((Get-Text 'RuntimeHeading') -f $runtimeNames)
        Write-AssistantLog ('Detected programming runtimes: {0}' -f $runtimeNames)
    }
    else {
        Write-AssistantLog 'No supported programming runtimes were detected on PATH.'
    }

    if ($script:fileMonitoringUnavailable) {
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'FileWatchUnavailable')
    }
    elseif ($script:fileMonitoringCoverageIncomplete) {
        $script:statusText.Text += [Environment]::NewLine + (Get-Text 'FileWatchCoverageWarning')
    }

    if ($script:onlineSearchQuery) {
        $script:onlineSearchButton.IsEnabled = $true
    }

    Send-HealthReport -Issues @($issues.ToArray())
    if ($issues.Count -eq 0) {
        Show-HealthNotification -Message (Get-Text 'NotificationAllGood')
    }
    else {
        Show-HealthNotification `
            -Message ((Get-Text 'NotificationIssues') -f $issues.Count) `
            -Icon ([System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

function Update-StartupButton {
    if (Test-Path -LiteralPath $startupLink) {
        $script:startupButton.Content = Get-Text 'StartupOff'
    }
    else {
        $script:startupButton.Content = Get-Text 'StartupOn'
    }
}

function Toggle-Startup {
    try {
        if (Test-Path -LiteralPath $startupLink) {
            $answer = [System.Windows.MessageBox]::Show(
                (Get-Text 'ConfirmStartupRemoval'),
                (Get-Text 'StartupRemovalTitle'),
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )
            if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
                return
            }

            Remove-Item -LiteralPath $startupLink -ErrorAction Stop
            Write-AssistantLog 'Removed this app shortcut from the current user Startup folder.'
        }
        else {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($startupLink)
            $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $shortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -File "' + $scriptPath + '" -Language "' + $script:language + '"'
            $shortcut.WorkingDirectory = Split-Path -Parent $scriptPath
            $shortcut.Description = 'Windows health mascot'
            $shortcut.Save()
            Write-AssistantLog 'Added this app shortcut to the current user Startup folder.'
        }

        Update-StartupButton
    }
    catch {
        Write-AssistantLog ('Startup setting failed: {0}' -f $_.Exception.Message)
        [void][System.Windows.MessageBox]::Show(
            ((Get-Text 'StartupFailed') -f $_.Exception.Message),
            (Get-Text 'AppTitle'),
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [void][System.Windows.MessageBox]::Show(
        (Get-Text 'ElevatedWarning'),
        (Get-Text 'AppTitle'),
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Warning
    )
    exit 1
}

$window = New-Object System.Windows.Window
$window.Title = Get-Text 'AppTitle'
$window.Width = 360
$window.SizeToContent = [System.Windows.SizeToContent]::Height
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
$window.ShowInTaskbar = $true
$window.Topmost = $false
$window.Background = [System.Windows.Media.Brushes]::White
$window.FlowDirection = if ($script:language -eq 'ar') {
    [System.Windows.FlowDirection]::RightToLeft
}
else {
    [System.Windows.FlowDirection]::LeftToRight
}

$script:notificationIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notificationIcon.Icon = [System.Drawing.SystemIcons]::Information
$script:notificationIcon.Text = Get-Text 'AppTitle'
$script:notificationIcon.Visible = $true
$script:notificationIcon.Add_BalloonTipShown({
    Write-AssistantLog 'Windows displayed a health-check notification.'
})
$script:notificationIcon.Add_BalloonTipClicked({
    $script:window.Show()
    $script:window.Activate()
})
$script:notificationIcon.Add_DoubleClick({
    $script:window.Show()
    $script:window.Activate()
})

$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = New-Object System.Windows.Thickness(16)

$mascot = New-Object System.Windows.Controls.TextBlock
$mascot.Text = [char]::ConvertFromUtf32(0x1F916)
$mascot.FontSize = 38
$mascot.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
[void]$panel.Children.Add($mascot)

$heading = New-Object System.Windows.Controls.TextBlock
$heading.Text = Get-Text 'AppTitle'
$heading.FontSize = 20
$heading.FontWeight = [System.Windows.FontWeights]::Bold
$heading.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$heading.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
[void]$panel.Children.Add($heading)

$script:statusText = New-Object System.Windows.Controls.TextBlock
$script:statusText.Text = Get-Text 'Starting'
$script:statusText.TextWrapping = [System.Windows.TextWrapping]::Wrap
$script:statusText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
[void]$panel.Children.Add($script:statusText)

$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$buttonPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

$scanButton = New-Object System.Windows.Controls.Button
$scanButton.Content = Get-Text 'CheckNow'
$scanButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$scanButton.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
$scanButton.Add_Click({ Invoke-ScheduledHealthCheck })
[void]$buttonPanel.Children.Add($scanButton)

$script:startupButton = New-Object System.Windows.Controls.Button
$script:startupButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$script:startupButton.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
$script:startupButton.Add_Click({ Toggle-Startup })
[void]$buttonPanel.Children.Add($script:startupButton)

$script:onlineSearchButton = New-Object System.Windows.Controls.Button
$script:onlineSearchButton.Content = Get-Text 'SearchDocs'
$script:onlineSearchButton.IsEnabled = $false
$script:onlineSearchButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$script:onlineSearchButton.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
$script:onlineSearchButton.Add_Click({
    if ($script:onlineSearchQuery) {
        $uri = 'https://www.google.com/search?q={0}' -f [uri]::EscapeDataString($script:onlineSearchQuery)
        try {
            Start-Process -FilePath $uri -ErrorAction Stop
            Write-AssistantLog 'Opened a web search with a generic error category; no source text, file path, or event message was included.'
        }
        catch {
            Write-AssistantLog ('Could not open the web search: {0}' -f $_.Exception.Message)
            [void][System.Windows.MessageBox]::Show(
                ('Could not open the web search: {0}' -f $_.Exception.Message),
                (Get-Text 'AppTitle'),
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }
})
[void]$buttonPanel.Children.Add($script:onlineSearchButton)

$exitButton = New-Object System.Windows.Controls.Button
$exitButton.Content = Get-Text 'Exit'
$exitButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$exitButton.Add_Click({ $script:window.Close() })
[void]$buttonPanel.Children.Add($exitButton)
[void]$panel.Children.Add($buttonPanel)

$script:logText = New-Object System.Windows.Controls.TextBox
$script:logText.IsReadOnly = $true
$script:logText.TextWrapping = [System.Windows.TextWrapping]::Wrap
$script:logText.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
$script:logText.Height = 90
$script:logText.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
$script:logText.Visibility = [System.Windows.Visibility]::Collapsed
[void]$panel.Children.Add($script:logText)

$window.Content = $panel
$workArea = [System.Windows.SystemParameters]::WorkArea
$window.Left = $workArea.Right - $window.Width - 24
$window.Top = $workArea.Bottom - 390

Update-StartupButton
$script:window = $window
Write-AssistantLog 'Mascot started for the current Windows user.'

$process = [System.Diagnostics.Process]::GetCurrentProcess()
try {
    $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
    $script:prioritySet = $true
    Write-AssistantLog 'Mascot process priority set to BelowNormal.'
}
catch {
    Write-AssistantLog ('Could not lower mascot process priority: {0}' -f $_.Exception.Message)
}
finally {
    $process.Dispose()
}

try {
    Start-LocalFileMonitoring
}
catch {
    $script:fileMonitoringUnavailable = $true
    $script:statusText.Text = Get-Text 'FileWatchUnavailable'
    Write-AssistantLog ('Could not start local file monitoring: {0}' -f $_.Exception.Message)
}

$script:checkTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:checkTimer.Interval = [TimeSpan]::FromHours($script:checkIntervalHours)
$script:checkTimer.Add_Tick({ Invoke-ScheduledHealthCheck })
$script:checkTimer.Start()

$window.Add_Closed({
    $script:checkTimer.Stop()
    if ($script:fileReviewTimer) {
        $script:fileReviewTimer.Stop()
    }
    if ($script:fileMonitor) {
        $script:fileMonitor.Dispose()
    }
    if ($script:notificationIcon) {
        $script:notificationIcon.Visible = $false
        $script:notificationIcon.Dispose()
    }
})
$window.Add_ContentRendered({ Invoke-ScheduledHealthCheck })
[void]$window.ShowDialog()
