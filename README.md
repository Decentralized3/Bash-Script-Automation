# Bash Script Automation

A collection of Bash-based automation scripts for security reconnaissance, infrastructure analysis, web app testing, and Android APK inspection.

This repository contains two focused tools:

- `infra_automator.sh` — infrastructure reconnaissance and network scanning
- `pt_automator.sh` — broader pentesting automation for web targets and Android APKs

Important: These scripts are intended for authorized security testing, bug bounty research, and educational learning in environments where you have explicit permission to test. Do not use them against systems you do not own or are not authorized to assess.

## Repository Structure

```text
Bash-Script-Automation/
├── infra_automator.sh
├── pt_automator.sh
├── reports/
└── README.md
```

The `reports/` directory is created automatically when the scripts run and stores scan output, logs, and generated markdown summaries.

## 1) infra_automator.sh

### Purpose

`infra_automator.sh` is a lightweight infrastructure reconnaissance utility designed for:

- DNS and WHOIS reconnaissance
- IP and subnet scanning
- service enumeration
- SMB, RPC, and SSL inspection
- report generation in a local `reports/` folder

### Features

- Dependency checking for tools such as `nmap`, `whois`, `dig`, `dnsrecon`, `enum4linux`, and `sslscan`
- DNS footprinting using WHOIS, `dig`, and optional `dnsrecon`
- full-port Nmap scanning using `-p-`
- service/version detection with `-sV -sC`
- vulnerability script scanning via `nmap --script vuln`
- SMB, SSL, and RPC deep dives
- simple interactive text menu

### Example usage

```bash
chmod +x infra_automator.sh
./infra_automator.sh
```

Then choose from the menu:

1. Run dependency check
2. Network footprinting and DNS
3. Nmap full assault
4. Protocol deep dive
5. Exit

### What it does internally

The script creates a timestamped directory such as:

```text
reports/infra_example.com_20260101_120000
```

and saves files like:

- `whois.txt`
- `dig_any.txt`
- `zone_transfer_attempt.txt`
- `dnsrecon.txt`
- `nmap_all_ports.txt`
- `nmap_services.txt`
- `nmap_vulns.txt`
- `smb_enum.txt`
- `ssl_tls_scan.txt`
- `rpc_info.txt`

### Best use case

This script is useful for reconnaissance against a target you are authorized to assess, particularly when you want a quick command-line workflow to gather infrastructure intelligence and map exposed services.

## 2) pt_automator.sh

### Purpose

`pt_automator.sh` is a more comprehensive pentesting automation framework for:

- web reconnaissance
- subdomain discovery
- live host detection
- URL fuzzing
- XSS and SQL injection targeting heuristics
- historical endpoint discovery
- Android APK reverse engineering
- secret extraction from JavaScript and APK content

### Features

- installs required tools and Go-based security tools
- discovers subdomains using `subfinder`, `assetfinder`, and `crt.sh`
- checks for potential subdomain takeovers
- resolves active hosts with `httpx`
- performs directory fuzzing with `ffuf`
- crawls endpoints with `katana`
- queries historical URLs via `waybackurls`
- runs `dalfox` for XSS checks
- runs `sqlmap` against identified parameter-bearing URLs
- scans using `nmap`
- extracts JS secrets from downloaded JavaScript files
- runs `nuclei` against discovered targets
- analyzes APK files with `apktool`, `jadx`, and regex-based secret detection
- creates markdown summary reports in `reports/`

### Example usage

```bash
chmod +x pt_automator.sh
./pt_automator.sh
```

Menu options:

1. Bootstrap installer: install dependencies and wordlists
2. Web app autopilot
3. Android APK autopilot
4. Exit

### Web scanning flow

When choosing the web target option, the script asks for a domain such as:

```bash
example.com
```

It then runs a sequence that includes:

- subdomain discovery
- takeover checks
- live host validation
- directory/API fuzzing
- crawling and endpoint collection
- parameter extraction
- XSS and SQLi-focused probes
- port scanning
- JavaScript secret extraction
- Nuclei-based vulnerability scanning
- final markdown report generation

Example output path:

```text
reports/web_example.com_20260101_120000/FINAL_REPORT.md
```

### Android scanning flow

When choosing the APK option, the script asks for the APK path, then performs:

- APK unpacking using `apktool`
- Java decompilation using `jadx`
- regex-based secret extraction for common API key patterns
- detection of exported components and deep links
- summary report generation

Example output path:

```text
reports/android_appname.apk_20260101_120000/FINAL_REPORT.md
```

## Script Workflow Overview

### infra_automator.sh workflow

```text
dependencies check -> DNS WHOIS -> dig -> dnsrecon -> nmap port scan -> service scan -> vuln scan -> SMB/RPC/SSL checks -> report generation
```

### pt_automator.sh workflow

```text
install tools -> discover subdomains -> validate live hosts -> fuzz endpoints -> crawl app -> inspect parameters -> XSS/SQLi heuristics -> port scan -> secret extraction -> Nuclei checks -> final report
```

## Tools Used

These scripts rely on external security tools, including:

- `nmap`
- `whois`
- `dig`
- `dnsrecon`
- `enum4linux`
- `sslscan`
- `rpcinfo`
- `subfinder`
- `assetfinder`
- `httpx`
- `ffuf`
- `katana`
- `waybackurls`
- `dalfox`
- `sqlmap`
- `apktool`
- `jadx`
- `nuclei`
- `curl`
- `wget`
- `jq`

Some of these tools are installed automatically by the script or by package managers such as `apt` and Go package installation commands.

## Security and Legal Notes

- Only run these scripts against systems or domains you own or have explicit authorization to test.
- Ensure you comply with local laws, contractual obligations, and organizational security policies.
- Some actions such as network scanning, vulnerability probing, and reverse engineering can trigger alarms or be considered intrusive if used improperly.
- Use the scripts in a controlled environment and keep generated reports private.

## Recommended Usage

For authorized testing, a typical order is:

1. Run `infra_automator.sh` for network footprinting and service discovery
2. Run `pt_automator.sh` for deeper web and APK testing
3. Review generated reports in `reports/`
4. Validate findings manually before escalating or reporting them

## Notes for Contributors

If you want to extend this repository:

- keep the scripts shell-compatible and portable
- avoid hardcoded personal values
- add clear logging and output directories
- maintain safe default behavior and explicit authorization reminders
- keep reports organized per target and timestamp

## License

This project does not currently declare a license in the repository. If you plan to redistribute or share it, confirm the legal permissions before doing so.

## Summary

This repository combines two Bash automation workflows:

- `infra_automator.sh` focuses on infrastructure reconnaissance and network-level enumeration.
- `pt_automator.sh` focuses on deeper web application and Android APK security testing.

Together, they provide a practical command-line toolkit for authorized security assessment, reconnaissance, and reporting.

If you want, I can also generate a more polished version of the README with screenshots, installation commands, and a sample report section, or I can rewrite the scripts to be safer and cleaner for production use.
