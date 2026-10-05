# Mizuzaky System Inspector

A lightweight Windows desktop mascot for periodic, load-aware system health checks and conservative diagnostics.

> **Prototype:** This project uses a small set of deterministic checks. It is not an AI agent and cannot diagnose or safely repair every Windows problem.

## Read this page in your language

**Automatic:** [Open the README in my browser's language](https://oiky8.github.io/mizuzaky-system-inspector/) · English GitHub README

**English** · [Tiếng Việt](https://translate.google.com/translate?sl=auto&tl=vi&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [简体中文](https://translate.google.com/translate?sl=auto&tl=zh-CN&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [繁體中文](https://translate.google.com/translate?sl=auto&tl=zh-TW&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Español](https://translate.google.com/translate?sl=auto&tl=es&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Français](https://translate.google.com/translate?sl=auto&tl=fr&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Deutsch](https://translate.google.com/translate?sl=auto&tl=de&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [日本語](https://translate.google.com/translate?sl=auto&tl=ja&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [한국어](https://translate.google.com/translate?sl=auto&tl=ko&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Português](https://translate.google.com/translate?sl=auto&tl=pt&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Русский](https://translate.google.com/translate?sl=auto&tl=ru&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [العربية](https://translate.google.com/translate?sl=auto&tl=ar&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [हिन्दी](https://translate.google.com/translate?sl=auto&tl=hi&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Bahasa Indonesia](https://translate.google.com/translate?sl=auto&tl=id&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [ไทย](https://translate.google.com/translate?sl=auto&tl=th&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector)

GitHub displays README files as static Markdown and cannot automatically select a translation from your browser language. To enable the automatic link, open **Settings → Pages** and set **Deploy from a branch** to branch `main`, folder `/docs`. Then visit `https://oiky8.github.io/mizuzaky-system-inspector/`. The redirect uses your browser's preferred language; Google Translate receives the public repository URL and your selected language. You can also choose a language link above or use your browser's built-in **Translate page** feature.

## Features

- Checks local disk space, DNS resolution, and Internet connectivity.
- Reviews recent error events from the Windows **System** and **Application** logs against [`error-catalog.json`](./error-catalog.json).
- Selects Vietnamese, Simplified or Traditional Chinese, Spanish, French, German, Japanese, Korean, Portuguese, Russian, Arabic, Hindi, Indonesian, or Thai from the Windows UI language; other languages fall back to English. Arabic uses right-to-left layout. UI strings are kept in [`locales.json`](./locales.json) for future translations.
- Detects common toolchains available on `PATH`: Python, Node.js (JavaScript/TypeScript), Java, .NET (including C#), Go, Rust, PHP, Ruby, Perl, Lua, R, Swift, and C/C++. It reports matching recent Windows application-crash events without running runtimes.
- Watches changes only under the current user's `Downloads`, `Desktop`, and `Documents` folders on local NTFS. It queues supported source files, executable types, and ZIP archives, skipping dependency/build/cache folders such as `.git`, `node_modules`, `vendor`, `bin`, and `obj`. Files marked by Windows as downloaded from the Internet are checked for that origin; supported executable files also have their Authenticode signature status checked. Changed source files inside Git working trees under those folders are inspected for a short allowlist of risky code patterns. Small source files in marked ZIP downloads are inspected without extracting them. Only heuristic matches are reported; no file is changed, executed, quarantined, or uploaded.
- Runs an initial check at startup, then checks every three hours.
- Defers checks for 15 minutes when CPU usage is at least 70% or free memory is below 1.5 GB.
- Sets only its own process priority to `BelowNormal`; it does not close or reprioritize other applications.
- Can run one allowlisted low-risk repair: refresh the local DNS cache after DNS fails while a direct IP connection is available. It uses the documented Windows `ipconfig` command, verifies the result, and includes the Microsoft source in the report.
- Reports issues by email when SMTP is configured. Reports contain concise findings, not full Windows event messages; unchanged findings are not emailed repeatedly.
- Opens a web search only when the user clicks the search button. Search terms are generic issue categories or Windows event identifiers; they never contain source code, file paths, or raw event messages. The search provider still receives the query and normal connection metadata. Results are untrusted advice: review sources carefully and never run downloaded scripts or commands just because a page recommends them.
- Writes a local log to `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

The error catalog is an editable starter set, not a comprehensive knowledge base. File review is a lightweight static heuristic, not antivirus, a full security audit, or proof that a file is safe; Windows Defender or another reputable antivirus is still required. A valid Authenticode signature does not prove software is safe, and unsigned software is not automatically malicious. Monitoring starts when the app starts and covers only the current user's `Downloads`, `Desktop`, and `Documents` folders on local NTFS. Files elsewhere—including Git repositories outside those folders—network/removable/non-NTFS volumes, files already present at startup, and downloads that Windows does not mark with Internet Zone information are not covered. Git source is reviewed only when a file change is observed while the app is running; notification overflow or high system load can delay or miss reviews. Source files over 256 KB, executable signature checks over 100 MB, and ZIP archives over 50 MB are skipped; ZIP inspection is limited to 50 small source entries. Network-retrieval and dynamic-execution APIs are reported as separate weak indicators; their presence alone does not establish malicious behavior. No source text is included in email; email reports remain count-only. Programming-language runtime detection is limited to the listed toolchains and crash events Windows records. Internet searches open only after the user clicks and contain generic categories/event identifiers, not source or local paths. Search advice is untrusted and is never downloaded or executed as a repair. Unknown, risky, or cross-component issues are reported for owner review.

## Requirements

- Windows with Windows PowerShell 5.1 and WPF.
- A standard, non-administrator user account.
- Keep `mizuzaky-system-inspector.ps1`, `error-catalog.json`, and `locales.json` in the same folder.

## Run

Open PowerShell in the project folder and run:

```powershell
powershell.exe -NoProfile -STA -File ".\mizuzaky-system-inspector.ps1"
```

Use **Start with Windows** in the app to add or remove its shortcut from the current user's Startup folder. The app starts after that user signs in; it does not run before sign-in.

The app does not bypass PowerShell's execution policy. If your policy blocks the script, use an approved signed copy or ask your administrator; do not weaken a managed policy.

### Installer

The Windows installer is built with Inno Setup 6. Install Inno Setup, then compile `installer.iss` with Inno Setup Compiler (`ISCC.exe`). The installer executable is written to `dist\MizuzakySystemInspector-Setup.exe`.

The installer is per-user and does not require administrator privileges. It automatically selects its interface language from the Windows display language, with English as the fallback. Its translations cover the same languages as the app except Hindi; on Hindi Windows, the installer uses English and the app uses Hindi. It creates a desktop shortcut by default; clear the translated **Create a desktop shortcut** option during setup if you do not want one. Double-click the shortcut to open the app. On the final page, choose the translated **Run Mizuzaky System Inspector now** option to launch the app immediately, or leave it unchecked to finish without starting the app. Uninstalling removes the installed program and shortcuts but preserves the user's local settings and reports.

Vietnamese, Simplified Chinese, Traditional Chinese, and Indonesian installer message files are sourced from [Inno Setup's language translations](https://github.com/jrsoftware/issrc/tree/a942f923d84b7a227b49af1721a1dc4492831ec0/Files/Languages). The upstream translation files retain their original contributor attribution.

## Email reports

To configure email, run the script interactively in PowerShell:

```powershell
powershell.exe -NoProfile -STA -File ".\mizuzaky-system-inspector.ps1" -ConfigureEmail
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

Use the language links above or your browser's **Translate page** feature for other languages.
