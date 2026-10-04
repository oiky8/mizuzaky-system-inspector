# Mizuzaky System Inspector

A lightweight Windows desktop mascot for periodic, load-aware system health checks and conservative diagnostics.

> **Prototype:** This project uses a small set of deterministic checks. It is not an AI agent and cannot diagnose or safely repair every Windows problem.

## Features

- Checks local disk space, DNS resolution, and Internet connectivity.
- Reviews recent error events from the Windows **System** and **Application** logs against [`error-catalog.json`](./error-catalog.json).
- Runs an initial check at startup, then checks every three hours.
- Defers checks for 15 minutes when CPU usage is at least 70% or free memory is below 1.5 GB.
- Sets only its own process priority to `BelowNormal`; it does not close or reprioritize other applications.
- Attempts a DNS cache flush if DNS resolution fails. This is the only automatic repair in this prototype.
- Opens a Microsoft Learn search only when the user clicks the search button. It sends a generic event identifier, not event log contents.
- Writes a local log to `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

The error catalog is an editable starter set, not a comprehensive knowledge base. Online results are never downloaded or executed as repairs.

## Requirements

- Windows with Windows PowerShell 5.1 and WPF.
- A standard, non-administrator user account.
- Keep `mizuzaky-system-inspector.ps1` and `error-catalog.json` in the same folder.

## Run

Open PowerShell in the project folder and run:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1"
```

Use **Start with Windows** in the app to add or remove its shortcut from the current user's Startup folder. The app starts after that user signs in; it does not run before sign-in.

## Safety and limitations

- No files are automatically deleted.
- The app does not edit the registry, alter security settings, install or uninstall software, change other processes, or restart Windows.
- Low disk space and most system, driver, security, hardware, and application errors are reported, not automatically repaired.
- Event scanning is limited to up to 100 recent events per log and only considers errors from the last 24 hours.
- Run as a standard user. The app refuses to start elevated.

See the [Vietnamese guide](./README.vi.md) for hướng dẫn bằng tiếng Việt.
