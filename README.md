# Bash Script Automation - Complete Security Toolkit

A comprehensive collection of Bash-based automation scripts for security reconnaissance, infrastructure analysis, web application testing, and Android APK inspection.

**Purpose:** Streamline bug bounty workflows, penetration testing, and authorized security assessments through automated reconnaissance and vulnerability discovery.

> **⚠️ Legal Notice:** These scripts are intended for authorized security testing, bug bounty research, and educational learning only. Do not use against systems you do not own or are not authorized to assess. Users are solely responsible for compliance with local laws and organizational policies.

---

## 📁 Repository Structure

```
Bash-Script-Automation/
├── setup_tools.sh          # Tool installer & dependency checker
├── recon.sh                # Main bug bounty recon automation
├── infra_automator.sh      # Infrastructure & network reconnaissance
├── pt_automator.sh         # Full pentesting automation (web + APK)
├── bugbountyx.sh           # Smart bug bounty hunter
├── Recon.sh                # Generic APK/app content recon
├── APKRecon.sh             # Specialized Android APK analysis
├── reports/                # Auto-generated output directory
└── README.md
```

---

## 🚀 Quick Start Guide

### Step 1: Install Dependencies
```bash
chmod +x setup_tools.sh
./setup_tools.sh
```
This installs all required tools: subfinder, httpx, nuclei, ffuf, apktool, jadx, and more.

### Step 2: Run Reconnaissance
```bash
chmod +x recon.sh
./recon.sh -d example.com
```

### Step 3: Review Reports
```bash
cat reports/web_example.com_*/FINAL_REPORT.md
```

---

## 📋 Script Descriptions

### 1️⃣ **setup_tools.sh** — Tool Installer & Checker

**Purpose:** Ensures all dependencies are installed and configured.

**Features:**
- ✅ Checks for Go, Python3, git, curl, jq
- 📦 Installs 30+ security tools via apt, pip, and Go
- 🔧 Configures paths and wordlists
- 📊 Displays summary of installation status

**Usage:**
```bash
./setup_tools.sh              # Auto-install missing tools
./setup_tools.sh --check-only # Only check what's missing
./setup_tools.sh --force      # Reinstall all tools
./setup_tools.sh --quiet      # Suppress output
```

**Installs:**
- **Subdomain Enumeration:** subfinder, assetfinder, amass, findomain
- **Live Host Probing:** httpx, httprobe, naabu, aquatone
- **DNS & Infrastructure:** dnsx, massdns, asnmap, whois
- **Endpoint Discovery:** gau, waybackurls, katana, hakrawler, subjs
- **Vulnerability Scanning:** nuclei, dalfox, ffuf, arjun, sqlmap
- **Subdomain Takeover:** subzy, subjack
- **Python Tools:** SecretFinder, Corsy, LinkFinder
- **Wordlists:** SecLists (~1GB), Nuclei templates, gf patterns, DNS resolvers

---

### 2️⃣ **recon.sh** — Main Bug Bounty Automation

**Purpose:** Complete web reconnaissance and vulnerability discovery workflow.

**Features:**
- 🔍 7-phase automated workflow
- 📊 Structured output with markdown reports
- 🎯 Supports passive and active scanning modes
- 🔔 Discord webhook notifications
- ⚡ Configurable threading and rate limiting

**Phases:**
1. **Subdomain Enumeration** — subfinder, assetfinder, amass, crt.sh, Wayback
2. **Live Host Probing** — httpx fingerprinting + technology detection
3. **DNS & Infrastructure** — dnsx, whois, ASN mapping, Shodan
4. **Endpoint & JS Recon** — gau, waybackurls, katana, hakrawler, SecretFinder
5. **Vulnerability Scanning** — nuclei, dalfox (XSS), directory fuzzing
6. **Subdomain Takeover** — subzy, subjack, nuclei takeover templates
7. **Report Generation** — Markdown summary with all findings

**Usage:**
```bash
./recon.sh -d example.com                                    # Full recon
./recon.sh -d example.com --quick                           # Fast tools only
./recon.sh -d example.com --passive                         # No active scanning
./recon.sh -d example.com -w https://discord.com/api/...    # With webhook
./recon.sh -d example.com --skip-vuln --skip-screens        # Skip slow phases
```

**Output Structure:**
```
results/example.com/
├── subdomains/          (all.txt, subfinder.txt, crtsh.txt, wayback_subs.txt)
├── live/                (live_urls.txt, httpx.json)
├── dns/                 (resolved.txt, cnames.txt, whois.txt)
├── endpoints/           (all.txt, gau.txt, katana.txt, wayback.txt)
├── js/                  (jsfiles.txt, secrets.txt)
├── vulns/               (nuclei.txt, xss_params.txt, nuclei.json)
├── screenshots/         (aquatone screenshots)
└── reports/             (FINAL_REPORT.md)
```

---

### 3️⃣ **infra_automator.sh** — Infrastructure Reconnaissance

**Purpose:** Network-level reconnaissance and infrastructure mapping.

**Features:**
- 🌐 DNS footprinting (WHOIS, dig, dnsrecon, zone transfers)
- 🔌 Full port scanning (nmap all 65535 ports)
- 🔎 Service version detection
- 🛡️ Protocol deep-dives (SMB, RPC, SSL/TLS)
- 📋 Interactive menu system

**Workflow:**
```
Dependencies Check → DNS WHOIS → Zone Transfer Attempts → 
Nmap All Ports → Service Detection → Vulnerability Scanning → 
SMB/RPC/SSL Analysis → Report Generation
```

**Usage:**
```bash
./infra_automator.sh
# Then choose from menu:
# 1) Run Dependency Check
# 2) Network Footprinting & DNS
# 3) Nmap Full Assault (all 65535 ports)
# 4) Protocol Deep Dive (SMB, RPC, SSL)
# 5) Exit Console
```

**Output:**
```
reports/infra_example.com_TIMESTAMP/
├── whois.txt
├── dig_any.txt
├── zone_transfer_attempt.txt
├── dnsrecon.txt
├── nmap_all_ports.txt
├── nmap_services.txt
├── nmap_vulns.txt
├── smb_enum.txt
├── ssl_tls_scan.txt
└── rpc_info.txt
```

---

### 4️⃣ **pt_automator.sh** — Full Pentesting Automation

**Purpose:** Comprehensive pentesting framework for web + Android targets.

**Features:**
- 🎯 8-step automated web exploitation
- 📱 Android APK reverse engineering
- 🔗 Subdomain discovery + takeover checks
- 🌐 Fuzzing, crawling, parameter extraction
- 🚀 Parallel vulnerability scanning (Nuclei, Dalfox, SQLMap)
- 📊 Raw findings markdown reports

**Web Scanning Pipeline:**
1. Subdomain enumeration (subfinder, assetfinder, crt.sh)
2. Subdomain takeover checks (subjack)
3. Live host resolution (httpx)
4. Directory & API fuzzing (ffuf)
5. Deep web crawling (katana)
6. Wayback Machine endpoint discovery
7. XSS/SQLi-focused parameter testing
8. Port scanning + JavaScript secret extraction
9. Nuclei vulnerability scanning
10. Report generation with findings categorized by severity

**Android Scanning Pipeline:**
1. APK unpacking (apktool)
2. Java decompilation (jadx)
3. Regex-based secret extraction (API keys, JWTs, credentials)
4. Exported components & deep links mapping
5. Summary report generation

**Usage:**
```bash
./pt_automator.sh
# Menu options:
# 1) Bootstrap: Install Dependencies & Wordlists
# 2) Web App Autopilot (Full web scanning)
# 3) Android APK Autopilot (APK reverse engineering)
# 4) Exit Console
```

**Output:**
```
reports/web_example.com_TIMESTAMP/FINAL_REPORT.md        # Web findings
reports/android_app.apk_TIMESTAMP/FINAL_REPORT.md         # APK findings
```

---

### 5️⃣ **bugbountyx.sh** — Smart Bug Bounty Hunter

**Purpose:** Streamlined bug bounty workflow with intelligent prioritization.

**Features:**
- 🎯 4-phase optimized workflow
- 💰 Severity-based prioritization (Critical → Medium/Low)
- ⚡ Parallel vulnerability scanning
- 🔍 Smart parameter filtering (SSRF/LFI vs XSS)
- 📊 Single ranked bounty report

**Phases:**
1. **Omnidirectional Recon** — Subdomains, live hosts, endpoints
2. **Smart Filtering** — Separate critical (SSRF/LFI) from high (XSS) parameters
3. **Multi-Threaded Scanning** — Subjack, Dalfox, SQLMap, Nuclei in parallel
4. **Report Generation** — Findings ranked by potential bounty value

**Usage:**
```bash
./bugbountyx.sh example.com
# or
./bugbountyx.sh
# then enter domain when prompted
```

**Report Sections:**
- 🔴 **CRITICAL FINDINGS** ($1000+ potential) — SQLi, RCE, SSRF, CVEs
- 🟠 **HIGH FINDINGS** ($500+ potential) — CVEs, takeovers, XSS
- 🟡 **MEDIUM/LOW FINDINGS** — Info disclosures, misconfigs
- 🎯 **TOP TARGETS** — Admin, login, API endpoints for manual testing

---

### 6️⃣ **Recon.sh** — Generic Content Reconnaissance

**Purpose:** Static analysis of any APK or app archive for sensitive data.

**Features:**
- 📦 Unzips and processes all files (text + binary)
- 🔐 Extracts URLs, API endpoints, secrets, JWTs, private keys
- 🌐 Firebase, cloud storage, and credential detection
- 🎯 MIME-type aware processing (avoids binary noise)
- 📋 Categorized output files

**Detections:**
- URLs (https://...)
- API endpoints (/api/, /v1/, /auth/, etc.)
- API keys (Google, AWS, Stripe)
- Firebase references
- Cloud storage buckets
- JWT-like tokens
- Private key markers
- Secrets keywords

**Usage:**
```bash
./Recon.sh app.apk
```

**Output:**
```
app_recon/
├── urls.txt
├── api_endpoints.txt
├── keys_secrets.txt
├── firebase_matches.txt
├── cloud_storage.txt
├── jwts.txt
├── private_keys_markers.txt
├── smali_references.txt
├── strings_all_extracted.txt
└── summary.txt
```

---

### 7️⃣ **APKRecon.sh** — Android APK Deep Analysis

**Purpose:** Specialized reconnaissance for Android applications.

**Features:**
- 📱 APK unpacking and manifest extraction
- 🔧 Smali bytecode analysis
- 🔑 Hardcoded secrets detection
- 🔗 Exported components mapping
- 🌐 Deep link discovery
- 🔓 Permission analysis

**Detections:**
- Google API keys
- AWS credentials (AKIA keys)
- Firebase endpoints
- JWT tokens
- Private keys
- Cloud service references
- Exported Android components
- Deep link schemes

**Usage:**
```bash
./APKRecon.sh com.example.app.apk
```

**Output:**
```
com.example.app_recon/
├── apk_unzipped/          (full APK extraction)
├── urls.txt               (extracted URLs)
├── api_endpoints.txt      (API routes)
├── critical_secrets.txt   (API keys, JWTs, tokens)
├── firebase_matches.txt   (Firebase references)
├── deeplinks.txt          (deep link schemes)
├── exported_components.txt (exported activities/services)
└── summary.txt            (analysis summary)
```

---

## 🛠️ Tools Ecosystem

### Subdomain Enumeration (6 tools)
- **subfinder** — Multi-source passive enumeration (ProjectDiscovery)
- **assetfinder** — Certificate transparency & common sources
- **amass** — OWASP comprehensive network mapping
- **findomain** — Fast alternative with good coverage
- **crt.sh** — Certificate transparency queries
- **Wayback Machine** — Historical subdomain extraction

### Live Host Probing (4 tools)
- **httpx** — Probe & fingerprint with tech detection
- **httprobe** — Simple HTTP probe verification
- **naabu** — Fast port scanner (top 1000 ports)
- **aquatone** — Screenshot capture & visualization

### DNS & Infrastructure (5 tools)
- **dnsx** — DNS resolution + CNAME extraction
- **massdns** — Subdomain resolution at scale
- **asnmap** — ASN range mapping
- **whois** — WHOIS lookups
- **Shodan** — Shodan API queries

### Endpoint Discovery (6 tools)
- **gau** — Wayback + CommonCrawl + OTX URLs
- **waybackurls** — Wayback Machine endpoints
- **katana** — Active web crawling (depth control)
- **hakrawler** — Recursive crawling
- **subjs** — JavaScript file discovery
- **gf** — Grep patterns for parameters

### Vulnerability Scanning (5 tools)
- **nuclei** — Template-based vulnerability scanner
- **dalfox** — XSS detection & verification
- **ffuf** — Directory & parameter fuzzing
- **arjun** — Hidden parameter discovery
- **sqlmap** — SQL injection detection

### Subdomain Takeover (2 tools)
- **subzy** — Fast takeover detection
- **subjack** — Cross-platform takeover scanner

### Reverse Engineering (3 tools)
- **apktool** — APK unpacking & repackaging
- **jadx** — Java decompiler for APKs
- **strings** — Extract readable strings from binaries

### Python Utilities (3 tools)
- **SecretFinder** — JavaScript secret extraction
- **Corsy** — CORS misconfiguration scanning
- **LinkFinder** — JavaScript endpoint discovery

---

## 📊 Recommended Workflow

### For Bug Bounty Hunters:
```
1. ./setup_tools.sh           # One-time setup
2. ./bugbountyx.sh example.com # Fast prioritized scan
3. Review CRITICAL findings    # Focus on high bounty items
4. Manual validation           # Confirm & exploit
```

### For Penetration Testers:
```
1. ./setup_tools.sh              # One-time setup
2. ./infra_automator.sh          # Network reconnaissance
3. ./recon.sh -d target.com      # Deep web assessment
4. ./pt_automator.sh             # Full exploitation automation
5. Review reports in ./reports/  # Consolidated findings
```

### For Security Researchers:
```
1. ./setup_tools.sh              # Tool installation
2. ./Recon.sh app.apk            # Generic content analysis
3. ./APKRecon.sh app.apk         # Specialized APK analysis
4. Manual code review            # Deep-dive into findings
```

---

## ⚙️ Configuration & Customization

### Environment Variables
```bash
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."  # Real-time notifications
export SHODAN_API_KEY="your_key_here"                          # Shodan queries
export WORDLIST_DIR="$HOME/wordlists"                          # Custom wordlist path
export NUCLEI_TEMPLATES="$HOME/nuclei-templates"               # Template path
```

### Script-Specific Options
```bash
./recon.sh -d example.com -o ./custom_output/  # Custom output dir
./recon.sh -d example.com -t 100               # Custom threads
./recon.sh -d example.com --passive            # Passive mode only
./recon.sh -d example.com --quick              # Fast tools only
```

---

## 📈 Output & Reports

### Report Locations
```
./reports/
├── web_example.com_20260101_120000/
│   ├── FINAL_REPORT.md
│   ├── subdomains/
│   ├── live/
│   ├── endpoints/
│   ├── vulns/
│   └── js/
├── infra_192.168.1.1_20260101_120000/
│   ├── nmap_all_ports.txt
│   ├── nmap_services.txt
│   ├── nmap_vulns.txt
│   └── ...
└── android_app.apk_20260101_120000/
    ├── FINAL_REPORT.md
    └── ...
```

### Report Contents
- **Findings Summary** — Counts by category
- **Critical Vulnerabilities** — High-priority issues
- **Endpoints & Parameters** — Attack surface mapping
- **Technology Stack** — Fingerprinted technologies
- **Subdomains & IPs** — Infrastructure mapping
- **Secrets & Keys** — Extracted credentials (sanitized for review)

---

## 🔒 Security & Legal Disclaimers

**Authorization Required:**
- Only use these scripts against systems you own or have explicit written permission to test
- Unauthorized access to computer systems is illegal in most jurisdictions

**Compliance:**
- Comply with local laws (CFAA in US, CMA 2000 in UK, etc.)
- Follow organizational security policies and bug bounty program rules
- Respect rate limits and avoid DoS-level activity
- Keep findings confidential until disclosure window

**Responsible Disclosure:**
- Report critical findings through official bug bounty channels
- Allow vendors reasonable time to patch (30-90 days typical)
- Document all steps for reproducibility

---

## 📝 Examples

### Scan Public Company (Authorized)
```bash
./recon.sh -d company.com -w "$DISCORD_WEBHOOK"
# Wait for completion
cat reports/web_company.com_*/FINAL_REPORT.md
```

### Analyze Android App (Authorized)
```bash
./APKRecon.sh ~/Downloads/app.apk
cat app_recon/critical_secrets.txt
```

### Quick Infrastructure Assessment
```bash
./infra_automator.sh
# Choose option 3 for full Nmap assault
# Results in reports/infra_*/ directory
```

---

## 🤝 Contributing

To extend this repository:
- Keep scripts POSIX-compatible where possible
- Avoid hardcoded paths; use environment variables
- Add comprehensive logging and error handling
- Maintain organized output directory structures
- Update this README for new features
- Include usage examples for new scripts

---

## 📄 License

This project does not currently declare a license. Before redistributing or sharing these tools, confirm legal permissions and ensure compliance with open-source licenses of included tools.

---

## 📞 Support & Troubleshooting

**Common Issues:**

1. **Tools not found after install:**
   ```bash
   export PATH="$PATH:$HOME/go/bin"
   echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
   ```

2. **Permission denied on scripts:**
   ```bash
   chmod +x *.sh
   ```

3. **Too many requests (rate limiting):**
   - Reduce `THREADS` and `RATE_LIMIT` variables
   - Add delays between scans

4. **Out of memory:**
   - Use `--quick` mode
   - Reduce thread count with `-t`

---

## 🎯 Summary

This toolkit combines **8 specialized Bash automation scripts** providing:

- **Complete Web Reconnaissance** (recon.sh)
- **Infrastructure Mapping** (infra_automator.sh)
- **Full Pentesting Automation** (pt_automator.sh)
- **Bug Bounty Optimization** (bugbountyx.sh)
- **Android Analysis** (APKRecon.sh, Recon.sh)
- **Dependency Management** (setup_tools.sh)

**Together, they streamline authorized security assessments from reconnaissance through exploitation.**

---

**Last Updated:** October 2026  
**Maintained by:** Decentralized3  
**GitHub:** https://github.com/Decentralized3/Bash-Script-Automation
