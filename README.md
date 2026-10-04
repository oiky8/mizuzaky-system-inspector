# Mizuzaky System Inspector

A lightweight Windows desktop mascot for periodic, load-aware system health checks and conservative diagnostics.

> **Prototype:** This project uses a small set of deterministic checks. It is not an AI agent and cannot diagnose or safely repair every Windows problem.

## Features

- Checks local disk space, DNS resolution, and Internet connectivity.
- Reviews recent error events from the Windows **System** and **Application** logs against [`error-catalog.json`](./error-catalog.json).
- Selects Vietnamese UI when the Windows UI language is Vietnamese; otherwise uses English as the fallback. UI strings are kept in [`locales.json`](./locales.json) for future translations.
- Detects Python, Node.js (JavaScript/TypeScript), Java, .NET (including C#), Go, and Rust executables available on `PATH`. It reports matching recent Windows application-crash events without running runtimes, scanning projects, or reading source code.
- Runs an initial check at startup, then checks every three hours.
- Defers checks for 15 minutes when CPU usage is at least 70% or free memory is below 1.5 GB.
- Sets only its own process priority to `BelowNormal`; it does not close or reprioritize other applications.
- Can run one allowlisted low-risk repair: refresh the local DNS cache after DNS fails while a direct IP connection is available. It uses the documented Windows `ipconfig` command, verifies the result, and includes the Microsoft source in the report.
- Reports issues by email when SMTP is configured. Reports contain concise findings, not full Windows event messages; unchanged findings are not emailed repeatedly.
- Opens a Microsoft Learn search only when the user clicks the search button. It sends a generic event identifier, not event log contents.
- Writes a local log to `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

The error catalog is an editable starter set, not a comprehensive knowledge base. Runtime detection is limited to tools available on `PATH` and crash events Windows records; it is not a compiler, debugger, or project scanner. UI localization currently supports Vietnamese and English fallback; other Windows display languages use English. Internet search results are never downloaded or executed as repairs. Unknown, risky, or cross-component issues are reported for owner review.

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

Enter your SMTP submission server, port (usually 587), sender, recipient, and SMTP username/app password. Use an app password when your provider requires one. The password is stored with Windows DPAPI protection for the current Windows user under `%LOCALAPPDATA%\MizuzakySystemInspector`; it is not stored in the repository. Do not paste credentials into source files or commit them. A test message can be sent during setup.

Email reports require the computer to be online and the SMTP provider to permit authenticated SMTP. They are sent only when findings exist and change. If email is not configured or sending fails, the app reports that locally and keeps its local log.

## Safety and limitations

- No user files are automatically deleted. The sole automatic repair is the documented DNS-cache refresh described above.
- The app does not edit the registry, alter security settings, install or uninstall software, change other processes, or restart Windows.
- Low disk space and most system, driver, security, hardware, and application errors are reported, not automatically repaired.
- Event scanning is limited to up to 100 recent events per log and only considers errors from the last 24 hours.
- Run as a standard user. The app refuses to start elevated.

See the [Vietnamese guide](./README.vi.md) for hướng dẫn bằng tiếng Việt.
