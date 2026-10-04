#requires -Version 5.1

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

$appDirectory = Join-Path $env:LOCALAPPDATA 'LinhVatMayTinh'
$logPath = Join-Path $appDirectory 'assistant.log'
$catalogPath = Join-Path (Split-Path -Parent $PSCommandPath) 'error-catalog.json'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Linh Vat May Tinh.lnk'
$scriptPath = $PSCommandPath
$script:window = $null
$script:statusText = $null
$script:logText = $null
$script:startupButton = $null
$script:onlineSearchButton = $null
$script:onlineSearchQuery = $null
$script:knowledgeEntries = @()
$script:checkTimer = $null
$script:prioritySet = $false
$script:checkIntervalHours = 3
$script:busyRetryMinutes = 15
$script:busyCpuThreshold = 70
$script:minimumFreeMemoryMB = 1536

New-Item -ItemType Directory -Path $appDirectory -Force | Out-Null

try {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($catalog.version -ne 1 -or -not $catalog.entries) {
        throw 'The local error catalog has an unsupported format.'
    }
    $script:knowledgeEntries = @($catalog.entries)
}
catch {
    [void][System.Windows.MessageBox]::Show(
        ('Could not load the local error catalog: {0}' -f $_.Exception.Message),
        'Linh Vat May Tinh',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    exit 1
}

function Write-AssistantLog {
    param([Parameter(Mandatory)][string]$Message)

    $entry = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $entry -Encoding UTF8

    if ($script:logText) {
        $script:logText.Text = (Get-Content -LiteralPath $logPath -Tail 6 -ErrorAction Stop) -join [Environment]::NewLine
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

function Invoke-ScheduledHealthCheck {
    if (-not $script:prioritySet) {
        $script:statusText.Text = 'Checks paused: the mascot could not set its process priority to BelowNormal.'
        Write-AssistantLog 'Health check postponed because the mascot could not lower its process priority.'
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    try {
        $load = Get-SystemLoad
    }
    catch {
        $script:statusText.Text = 'Checks postponed: could not safely measure current system load.'
        Write-AssistantLog ('Health check postponed because system load could not be measured: {0}' -f $_.Exception.Message)
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    if ($load.CpuPercent -ge $script:busyCpuThreshold -or $load.FreeMemoryMB -lt $script:minimumFreeMemoryMB) {
        $script:statusText.Text = ('Machine busy (CPU {0}%, free memory {1} MB). Checks postponed for {2} minutes.' -f
            $load.CpuPercent, $load.FreeMemoryMB, $script:busyRetryMinutes)
        Write-AssistantLog ('Health check postponed: CPU {0}%, free memory {1} MB.' -f $load.CpuPercent, $load.FreeMemoryMB)
        $script:checkTimer.Interval = [TimeSpan]::FromMinutes($script:busyRetryMinutes)
        return
    }

    try {
        Invoke-HealthCheck
    }
    catch {
        $script:statusText.Text = 'Health check failed; see the local log for details.'
        Write-AssistantLog ('Health check failed: {0}' -f $_.Exception.Message)
    }
    finally {
        $script:checkTimer.Interval = [TimeSpan]::FromHours($script:checkIntervalHours)
    }
}

function Invoke-HealthCheck {
    $issues = New-Object System.Collections.Generic.List[string]
    $script:onlineSearchQuery = $null
    $script:onlineSearchButton.IsEnabled = $false

    try {
        $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
        foreach ($drive in $drives) {
            $freeGiB = [math]::Round($drive.FreeSpace / 1GB, 1)
            if ($freeGiB -lt 5) {
                $issues.Add(('{0} has only {1} GB free. No files were deleted.' -f $drive.DeviceID, $freeGiB))
            }
        }
    }
    catch {
        $issues.Add(('Disk check failed: {0}' -f $_.Exception.Message))
        Write-AssistantLog ('Disk check failed: {0}' -f $_.Exception.Message)
    }

    try {
        [void][System.Net.Dns]::GetHostAddresses('www.microsoft.com')
    }
    catch {
        Write-AssistantLog ('DNS lookup failed; trying a non-destructive DNS cache flush: {0}' -f $_.Exception.Message)
        try {
            $flush = Start-Process -FilePath "$env:SystemRoot\System32\ipconfig.exe" `
                -ArgumentList '/flushdns' -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($flush.ExitCode -ne 0) {
                throw ('ipconfig /flushdns exited with code {0}.' -f $flush.ExitCode)
            }
            [void][System.Net.Dns]::GetHostAddresses('www.microsoft.com')
            Write-AssistantLog 'DNS cache flush succeeded; name resolution is working again.'
        }
        catch {
            $issues.Add(('Network name lookup still fails after DNS cache repair: {0}' -f $_.Exception.Message))
            Write-AssistantLog ('DNS repair did not resolve the issue: {0}' -f $_.Exception.Message)
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
                            $issues.Add(('{0} event {1} ({2}): {3}' -f $eventRecord.LogName, $eventRecord.Id, $eventRecord.ProviderName, $entry.summary))
                        }
                        if (-not $script:onlineSearchQuery) {
                            $script:onlineSearchQuery = 'Windows event {0} {1} {2}' -f $eventRecord.LogName, $eventRecord.ProviderName, $eventRecord.Id
                        }
                    }
                    else {
                        $unknownEventCount++
                        if (-not $script:onlineSearchQuery) {
                            $script:onlineSearchQuery = 'Windows event {0} {1} {2}' -f $eventRecord.LogName, $eventRecord.ProviderName, $eventRecord.Id
                        }
                    }
                }
            }
            catch {
                $issues.Add(('Could not inspect the {0} event log: {1}' -f $logName, $_.Exception.Message))
                Write-AssistantLog ('Could not inspect the {0} event log: {1}' -f $logName, $_.Exception.Message)
            }
    }

    if ($knownEventCount -gt 5) {
            $issues.Add(('{0} additional known event type(s) were found; see the local log for the count.' -f ($knownEventCount - 5)))
    }
    if ($unknownEventCount -gt 0) {
            $issues.Add(('{0} recent error event type(s) are not in the local catalog. Only a generic event identifier can be searched online.' -f $unknownEventCount))
    }
    if ($script:onlineSearchQuery) {
            $script:onlineSearchButton.IsEnabled = $true
    }
    Write-AssistantLog ('Event log scan completed: {0} known and {1} uncatalogued recent error type(s).' -f $knownEventCount, $unknownEventCount)

    try {
            Test-NetworkConnection
    }
    catch {
        $issues.Add(('Internet connection test failed: {0}' -f $_.Exception.Message))
        Write-AssistantLog ('Internet connection test failed: {0}' -f $_.Exception.Message)
    }

    if ($issues.Count -eq 0) {
        $script:statusText.Text = 'All checks look good.'
        Write-AssistantLog 'Health check completed: no issues detected.'
    }
    else {
        $script:statusText.Text = $issues -join [Environment]::NewLine
        Write-AssistantLog ('Health check found {0} issue(s).' -f $issues.Count)
    }
}

function Update-StartupButton {
    if (Test-Path -LiteralPath $startupLink) {
        $script:startupButton.Content = 'Turn off startup'
    }
    else {
        $script:startupButton.Content = 'Start with Windows'
    }
}

function Toggle-Startup {
    try {
        if (Test-Path -LiteralPath $startupLink) {
            $answer = [System.Windows.MessageBox]::Show(
                'This removes only this app shortcut from your Startup folder. Continue?',
                'Confirm removal',
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
            $shortcut.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $scriptPath + '"'
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
            ('Could not update the startup setting: {0}' -f $_.Exception.Message),
            'Linh Vat May Tinh',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [void][System.Windows.MessageBox]::Show(
        'For safety, run this mascot as a standard (non-elevated) user. It does not need administrator rights.',
        'Linh Vat May Tinh',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Warning
    )
    exit 1
}

$window = New-Object System.Windows.Window
$window.Title = 'Linh Vat May Tinh'
$window.Width = 360
$window.SizeToContent = [System.Windows.SizeToContent]::Height
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
$window.ShowInTaskbar = $true
$window.Topmost = $false
$window.Background = [System.Windows.Media.Brushes]::White

$panel = New-Object System.Windows.Controls.StackPanel
$panel.Margin = New-Object System.Windows.Thickness(16)

$mascot = New-Object System.Windows.Controls.TextBlock
$mascot.Text = [char]::ConvertFromUtf32(0x1F916)
$mascot.FontSize = 38
$mascot.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
[void]$panel.Children.Add($mascot)

$heading = New-Object System.Windows.Controls.TextBlock
$heading.Text = 'Linh Vat May Tinh'
$heading.FontSize = 20
$heading.FontWeight = [System.Windows.FontWeights]::Bold
$heading.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$heading.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
[void]$panel.Children.Add($heading)

$script:statusText = New-Object System.Windows.Controls.TextBlock
$script:statusText.Text = 'Starting checks...'
$script:statusText.TextWrapping = [System.Windows.TextWrapping]::Wrap
$script:statusText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
[void]$panel.Children.Add($script:statusText)

$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$buttonPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

$scanButton = New-Object System.Windows.Controls.Button
$scanButton.Content = 'Check now'
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
$script:onlineSearchButton.Content = 'Search Microsoft docs'
$script:onlineSearchButton.IsEnabled = $false
$script:onlineSearchButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$script:onlineSearchButton.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
$script:onlineSearchButton.Add_Click({
    if ($script:onlineSearchQuery) {
        $uri = 'https://learn.microsoft.com/search/?terms={0}' -f [uri]::EscapeDataString($script:onlineSearchQuery)
        try {
            Start-Process -FilePath $uri -ErrorAction Stop
            Write-AssistantLog 'Opened Microsoft Learn search with only a generic Windows event identifier.'
        }
        catch {
            Write-AssistantLog ('Could not open Microsoft Learn: {0}' -f $_.Exception.Message)
            [void][System.Windows.MessageBox]::Show(
                ('Could not open Microsoft Learn: {0}' -f $_.Exception.Message),
                'Linh Vat May Tinh',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    }
})
[void]$buttonPanel.Children.Add($script:onlineSearchButton)

$exitButton = New-Object System.Windows.Controls.Button
$exitButton.Content = 'Exit'
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

$script:checkTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:checkTimer.Interval = [TimeSpan]::FromHours($script:checkIntervalHours)
$script:checkTimer.Add_Tick({ Invoke-ScheduledHealthCheck })
$script:checkTimer.Start()

$window.Add_Closed({ $script:checkTimer.Stop() })
$window.Add_ContentRendered({ Invoke-ScheduledHealthCheck })
[void]$window.ShowDialog()
