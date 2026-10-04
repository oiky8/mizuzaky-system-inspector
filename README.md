# Mizuzaky System Inspector

A lightweight Windows desktop mascot for periodic, load-aware system health checks and conservative diagnostics.

> **Prototype:** This project uses a small set of deterministic checks. It is not an AI agent and cannot diagnose or safely repair every Windows problem.

## Features

- Checks local disk space, DNS resolution, and Internet connectivity.
- Reviews recent error events from the Windows **System** and **Application** logs against [`error-catalog.json`](./error-catalog.json).
- Selects Vietnamese, Simplified or Traditional Chinese, Spanish, French, German, Japanese, Korean, Portuguese, Russian, Arabic, Hindi, Indonesian, or Thai from the Windows UI language; other languages fall back to English. Arabic uses right-to-left layout. UI strings are kept in [`locales.json`](./locales.json) for future translations.
- Detects common toolchains available on `PATH`: Python, Node.js (JavaScript/TypeScript), Java, .NET (including C#), Go, Rust, PHP, Ruby, Perl, Lua, R, Swift, and C/C++. It reports matching recent Windows application-crash events without running runtimes.
- Watches file changes on local NTFS volumes while the app is running. Files marked by Windows as downloaded from the Internet are checked for that origin; supported executable files also have their Authenticode signature status checked. Changed source files inside Git working trees are inspected for a short allowlist of risky code patterns. Small source files in marked ZIP downloads are inspected without extracting them. Only heuristic matches are reported; no file is changed, executed, quarantined, or uploaded.
- Runs an initial check at startup, then checks every three hours.
- Defers checks for 15 minutes when CPU usage is at least 70% or free memory is below 1.5 GB.
- Sets only its own process priority to `BelowNormal`; it does not close or reprioritize other applications.
- Can run one allowlisted low-risk repair: refresh the local DNS cache after DNS fails while a direct IP connection is available. It uses the documented Windows `ipconfig` command, verifies the result, and includes the Microsoft source in the report.
- Reports issues by email when SMTP is configured. Reports contain concise findings, not full Windows event messages; unchanged findings are not emailed repeatedly.
- Opens a Microsoft Learn search only when the user clicks the search button. It sends a generic event identifier, not event log contents.
- Writes a local log to `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

The error catalog is an editable starter set, not a comprehensive knowledge base. File review is a lightweight static heuristic, not antivirus, a full security audit, or proof that a file is safe; Windows Defender or another reputable antivirus is still required. A valid Authenticode signature does not prove software is safe, and unsigned software is not automatically malicious. Monitoring starts when the app starts and is limited to local NTFS volumes. It does not cover network/removable/non-NTFS volumes, files already present at startup, or downloads that Windows does not mark with Internet Zone information. Git source is reviewed only when a file change is observed while the app is running; notification overflow or high system load can delay or miss reviews. Source files over 256 KB, executable signature checks over 100 MB, and ZIP archives over 50 MB are skipped; ZIP inspection is limited to 50 small source entries. No source text is included in email; email reports remain count-only. Programming-language runtime detection is limited to the listed toolchains and crash events Windows records. Internet search results are never downloaded or executed as repairs. Unknown, risky, or cross-component issues are reported for owner review.

## Requirements

- Windows with Windows PowerShell 5.1 and WPF.
- A standard, non-administrator user account.
- Keep `mizuzaky-system-inspector.ps1`, `error-catalog.json`, and `locales.json` in the same folder.

## Run

Open PowerShell in the project folder and run:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1"
```

Use **Start with Windows** in the app to add or remove its shortcut from the current user's Startup folder. The app starts after that user signs in; it does not run before sign-in.

## Email reports

To configure email, run the script interactively in PowerShell:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1" -ConfigureEmail
```

Enter your provider's public SMTP hostname, port `587`, sender, recipient, and SMTP username/app password. The app rejects IP addresses, local-only hostnames, non-587 ports, and address display-name syntax. It uses authenticated SMTP with STARTTLS, requires TLS 1.2, and relies on Windows/.NET's normal server-certificate chain and hostname validation; invalid or self-signed certificates fail closed. Providers that do not offer STARTTLS on port 587 are not supported.

The SMTP password is stored using Windows DPAPI for the current user. The app also protects its data directory, email settings, credential file, local log, and anti-repeat state with explicit current-user/SYSTEM ACLs and rejects reparse-point config files. Report anti-repeat state is DPAPI-protected, reports are limited to one per hour, and identical summaries are not repeated for 24 hours. The report body contains only a timestamp and issue count: it does not include a computer name, recipient address, raw event text, file paths, or source code. The normal mail headers still identify the configured sender and recipient. The report count follows the selected Windows UI language.

These controls protect data from other local accounts and insecure transport. They cannot protect secrets from malware already running as the same Windows user, a compromised mail provider, or a recipient mailbox. Email requires an online PC and a provider that supports authenticated STARTTLS on port 587. If configuration validation or certificate verification fails, the app refuses to send and reports the failure locally.

## Safety and limitations

- No user files are automatically deleted. The sole automatic repair is the documented DNS-cache refresh described above.
- File monitoring reads only local file metadata and supported source text for static heuristics. It never runs, deletes, or quarantines files and does not upload source code. Heuristic results can have false positives and false negatives.
- The app does not edit the registry, alter security settings, install or uninstall software, change other processes, or restart Windows.
- Low disk space and most system, driver, security, hardware, and application errors are reported, not automatically repaired.
- Event scanning is limited to up to 100 recent events per log and only considers errors from the last 24 hours.
- Run as a standard user. The app refuses to start elevated.

See the [Vietnamese guide](./README.vi.md) for hướng dẫn bằng tiếng Việt.
