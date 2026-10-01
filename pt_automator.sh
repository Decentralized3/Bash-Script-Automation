#!/bin/bash

# =========================================================================
# PT-AUTOMATOR v3.0 - THE FINAL WAR MACHINE
# Bug Bounty & Pentesting Automation Framework
# =========================================================================
# Description: This is a full-scale automated reconnaissance and active 
# vulnerability scanner for Web & Android targets.
# =========================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin

# ----------------- CONFIGURATIONS -----------------
# 1. Add your Discord or Slack webhook URL here to get live alerts!
WEBHOOK_URL=""
# 2. Paths
# Dynamically locate SecLists common.txt if it already exists on the system, otherwise fallback to download directory
if [ -f "/usr/share/nmap/nselib/data/passwords.lst" ]; then
    COMMON_WORDLIST="/usr/share/wordlists/dirb/common.txt" # if you have wordlists installed in standard parrot/kali dir
elif [ -f "/usr/share/wordlists/dirb/common.txt" ]; then
    COMMON_WORDLIST="/usr/share/wordlists/dirb/common.txt"
elif [ -f "/usr/share/wfuzz/wordlist/general/common.txt" ]; then
    COMMON_WORDLIST="/usr/share/wfuzz/wordlist/general/common.txt"
else
    WORDLIST_DIR="$HOME/wordlists"
    COMMON_WORDLIST="$WORDLIST_DIR/common.txt"
fi

# Clean exit on Ctrl+C
trap "echo -e '\n${RED}[!] Scan Interrupted by user. Exiting safely...${NC}'; exit 1" SIGINT

step_msg() { echo -e "\n${CYAN}${BOLD}[>>] $1${NC}"; }
success_msg() { echo -e "${GREEN}[OK] $1${NC}"; }
warn_msg() { echo -e "${YELLOW}[!] $1${NC}"; }
error_msg() { echo -e "${RED}[ERROR] $1${NC}"; }

notify() {
    local message="$1"
    if [ -n "$WEBHOOK_URL" ]; then
        # Simple JSON payload for Discord/Slack standard webhook
        curl -s -H "Content-Type: application/json" -d "{\"content\": \"🚨 **[PT-AUTOMATOR]** $message\"}" "$WEBHOOK_URL" >/dev/null
    fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# =======================================================
# INSTALLATION & ENVIRONMENT MODULE
# =======================================================
install_tools() {
    echo -e "\n${YELLOW}[>] Updating System & Bootstrapping the Arsenal...${NC}"
    
    # 1. Apt standard tools
    for tool in nmap apktool sqlmap jq curl wget ffuf default-jre unzip zip; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${YELLOW}[*] Installing $tool (Requires Sudo)...${NC}"
            sudo apt-get update -y && sudo apt-get install -y $tool
        fi
    done

    # 2. Golang
    if ! command -v go &> /dev/null; then
        warn_msg "Go missing. Installing Golang..."
        sudo apt-get install -y golang
    fi

    # 3. Go-based Security Tools
    declare -A go_tools
    go_tools[subfinder]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    go_tools[httpx]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    go_tools[nuclei]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    go_tools[assetfinder]="github.com/tomnomnom/assetfinder@latest"
    go_tools[waybackurls]="github.com/tomnomnom/waybackurls@latest"
    go_tools[dalfox]="github.com/hahwul/dalfox/v2@latest"
    go_tools[subjack]="github.com/haccer/subjack@latest"
    go_tools[katana]="github.com/projectdiscovery/katana/cmd/katana@latest"

    for tool in "${!go_tools[@]}"; do
        if ! command -v $tool &> /dev/null && [ ! -f "$HOME/go/bin/$tool" ]; then
            echo -e "${CYAN}[*] Installing $tool...${NC}"
            go install ${go_tools[$tool]}
        fi
    done

    # 4. Jadx (For Android Java Decompilation)
    if ! command -v jadx &> /dev/null; then
        echo -e "${CYAN}[*] Installing Jadx for Android analysis...${NC}"
        wget -q -O jadx.zip "https://github.com/skylot/jadx/releases/download/v1.4.7/jadx-1.4.7.zip"
        sudo unzip -q jadx.zip -d /opt/jadx
        sudo ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx
        rm jadx.zip
    fi

    # 5. Wordlists (SecLists Common)
    if [ ! -f "$COMMON_WORDLIST" ]; then
        echo -e "${CYAN}[*] Downloading common fuzzing wordlist (SecLists)...${NC}"
        mkdir -p "$WORDLIST_DIR"
        wget -q "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" -O "$COMMON_WORDLIST"
    fi

    success_msg "All tools and lists are ready for war."
    sleep 2
}

# =======================================================
# WEB: THE TOTAL ANNIHILATION MODE
# =======================================================
web_scan() {
    RAW_INPUT=$1
    # Strip protocols and trailing slashes so users can input http://example.com/ safely
    TARGET=$(echo "$RAW_INPUT" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    
    DIR="reports/web_${TARGET}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"
    
    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > WEB WAR MACHINE ENGAGED: $TARGET ${NC}"
    echo -e "${YELLOW}${BOLD}   > OUTPUT DIR: $DIR ${NC}"
    echo -e "${BLUE}====================================================${NC}"
    notify "Started Full Web Scan on $TARGET"

    # ---- 1: RECON ----
    step_msg "STEP 1/8: Omni-Directory Subdomain Enum (subfinder + assetfinder + crt.sh)"
    subfinder -d "$TARGET" -all -silent > "$DIR/subs_temp1.txt" &
    assetfinder -subs-only "$TARGET" > "$DIR/subs_temp2.txt" &
    curl -s "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > "$DIR/subs_temp3.txt" &
    wait
    
    cat "$DIR"/subs_temp*.txt | sort -u | grep -i "$TARGET" > "$DIR/subdomains.txt"
    rm "$DIR"/subs_temp*.txt
    success_msg "Discovered $(wc -l < "$DIR/subdomains.txt") unique subdomains."

    # ---- 2: SUBDOMAIN TAKEOVERS ----
    step_msg "STEP 2/8: Subdomain Takeover Check (subjack)"
    subjack -w "$DIR/subdomains.txt" -t 100 -timeout 30 -o "$DIR/takeovers.txt" -ssl -v & spinner $!
    if [ -s "$DIR/takeovers.txt" ]; then
        warn_msg "POTENTIAL TAKEOVER FOUND!"
        notify "Subdomain Takeover potential on $TARGET! Check takeovers.txt"
    else
        success_msg "No screaming takeovers detected."
    fi

    # ---- 3: LIVE HOSTS ----
    step_msg "STEP 3/8: Resolving Live Targets (httpx)"
    cat "$DIR/subdomains.txt" | httpx -silent -ports 80,443 -title -tech-detect -status-code -o "$DIR/live_hosts_detailed.txt" & spinner $!
    cat "$DIR/live_hosts_detailed.txt" | awk '{print $1}' > "$DIR/live_hosts.txt"
    success_msg "Resolved $(wc -l < "$DIR/live_hosts.txt") active endpoints."

    # ---- 4: DIRECTORY & API FUZZING ----
    step_msg "STEP 4/8: Content & API Fuzzing (ffuf)"
    ffuf -c -w "$COMMON_WORDLIST" -u "https://$TARGET/FUZZ" -t 80 -e .php,.html,.txt,.git,.env,.bak -mc 200,301,302,403,500 -o "$DIR/fuzzing_report.json" -s & spinner $!
    success_msg "Fuzzing complete -> output in fuzzing_report.json"

    # ---- 4.5: ACTIVE CRAWLING (KATANA) ----
    step_msg "STEP 4.5/8: Deep Web Crawling (KatanaSpider)"
    katana -list "$DIR/live_hosts.txt" -d 3 -jc -silent -o "$DIR/katana_crawl.txt" & spinner $!
    success_msg "Crawled $( [ -f "$DIR/katana_crawl.txt" ] && wc -l < "$DIR/katana_crawl.txt" || echo 0 ) active JS/HTML endpoints."

    # ---- 5: HISTORICAL DATA & EXPLOITS ----
    step_msg "STEP 5/8: Deep Parameter Hunting & Exploitation (Wayback + Crawl -> XSS/SQLi)"
    cat "$DIR/live_hosts.txt" | waybackurls | sort -u > "$DIR/wayback_all.txt" & spinner $!
    cat "$DIR/katana_crawl.txt" "$DIR/wayback_all.txt" 2>/dev/null | sort -u > "$DIR/all_endpoints.txt"
    grep "=" "$DIR/all_endpoints.txt" | sort -u > "$DIR/all_params.txt"
    
    echo " -> Firing Dalfox (XSS) at combined parameters..."
    dalfox pipe --silence --timeout 10 -o "$DIR/dalfox_xss.txt" < "$DIR/all_params.txt" & spinner $!
    
    echo " -> Firing SQLMap (Heuristic) at deep parameters..."
    head -n 30 "$DIR/all_params.txt" > "$DIR/sqlmap_targets.txt"
    if [ -s "$DIR/sqlmap_targets.txt" ]; then
        sqlmap -m "$DIR/sqlmap_targets.txt" --batch --random-agent --level=3 --risk=2 --smart --tamper=space2comment -q > "$DIR/sqlmap_results.txt" 2>&1 & spinner $!
    fi
    success_msg "Exploit sequence complete."

    # ---- 6: NMAP ----
    step_msg "STEP 6/8: Tactical Port Scanning (Nmap)"
    awk -F/ '{print $3}' "$DIR/live_hosts.txt" | cut -d: -f1 | cut -d" " -f1 | sort -u > "$DIR/nmap_targets.txt"
    nmap -T4 -iL "$DIR/nmap_targets.txt" -oN "$DIR/nmap_scan.txt" --open & spinner $!
    success_msg "Network perimeter mapped."

    # ---- 7: JS SECRETS ----
    step_msg "STEP 7/8: JavaScript Espionage (Regex Hunters)"
    grep -i "\.js" "$DIR/all_endpoints.txt" | sort -u > "$DIR/js_links.txt"
    mkdir -p "$DIR/js_downloads"
    head -n 200 "$DIR/js_links.txt" | while read url; do wget -q --timeout=5 -P "$DIR/js_downloads/" "$url"; done
    grep -Erio "AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|bearer [-a-zA-Z0-9._~+/]+=" "$DIR/js_downloads" > "$DIR/js_secrets.txt"
    if [ -s "$DIR/js_secrets.txt" ]; then notify "API Keys found in JS on $TARGET"; fi
    success_msg "JS extraction complete."

    # ---- 8: NUCLEI ----
    step_msg "STEP 8/8: Nuclei Deep Vuln DAST Matrix"
    nuclei -l "$DIR/live_hosts.txt" -t cves/ -t exposed-panels/ -t misconfiguration/ -t vulnerabilities/ -t default-logins/ -t takeovers/ -silent -o "$DIR/nuclei_results.txt" & spinner $!
    
    # ---- 9: REPORT ----
    echo -e "\n${CYAN}[*] Generating Deep Data Markdown Report...${NC}"
    echo "# PT-Automator Raw Data Web Report: $TARGET" > "$DIR/FINAL_REPORT.md"
    echo "**Date:** $(date)" >> "$DIR/FINAL_REPORT.md"
    echo "## Execution Summary" >> "$DIR/FINAL_REPORT.md"
    echo "- **Subdomains Discovered:** $( [ -f "$DIR/subdomains.txt" ] && wc -l < "$DIR/subdomains.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- **Live Hosts:** $( [ -f "$DIR/live_hosts.txt" ] && wc -l < "$DIR/live_hosts.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- **Raw Endpoints (Wayback+Katana):** $( [ -f "$DIR/all_endpoints.txt" ] && wc -l < "$DIR/all_endpoints.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- **Injectable Parameters:** $( [ -f "$DIR/all_params.txt" ] && wc -l < "$DIR/all_params.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- **XSS Hits (Dalfox):** $( [ -f "$DIR/dalfox_xss.txt" ] && wc -l < "$DIR/dalfox_xss.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- **CVEs & Panel Hits (Nuclei):** $( [ -f "$DIR/nuclei_results.txt" ] && wc -l < "$DIR/nuclei_results.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    
    echo -e "\n## Raw Vulnerability Findings" >> "$DIR/FINAL_REPORT.md"
    
    echo "### 1. Nuclei Critical/Info Hits" >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"
    [ -f "$DIR/nuclei_results.txt" ] && cat "$DIR/nuclei_results.txt" | head -n 30 >> "$DIR/FINAL_REPORT.md" || echo "No Nuclei hits found." >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"

    echo "### 2. Dalfox XSS Payloads Found" >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"
    [ -f "$DIR/dalfox_xss.txt" ] && cat "$DIR/dalfox_xss.txt" >> "$DIR/FINAL_REPORT.md" || echo "No XSS found." >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"

    echo "### 3. Subdomain Takeover Hooks" >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"
    [ -f "$DIR/takeovers.txt" ] && cat "$DIR/takeovers.txt" >> "$DIR/FINAL_REPORT.md" || echo "No Subdomain takeovers." >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"

    echo "### 4. JavaScript Hardcoded Secrets" >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"
    [ -f "$DIR/js_secrets.txt" ] && head -n 20 "$DIR/js_secrets.txt" >> "$DIR/FINAL_REPORT.md" || echo "No JS secrets extracted." >> "$DIR/FINAL_REPORT.md"
    echo "\`\`\`" >> "$DIR/FINAL_REPORT.md"

    notify "Web Scan Finished for $TARGET. Report ready."
    echo -e "\n${GREEN}${BOLD}[+] WAR MACHINE SHUTDOWN. Check -> $DIR/FINAL_REPORT.md (Now includes raw findings!) ${NC}"
}

# =======================================================
# ANDROID: THE DEEP EXCAVATION MODE
# =======================================================
android_scan() {
    APK=$1
    if [ ! -f "$APK" ]; then error_msg "APK file does not exist: $APK"; return; fi
    APK_NAME=$(basename "$APK")
    DIR="reports/android_${APK_NAME}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"
    
    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > ANDROID WAR MACHINE ENGAGED: $APK_NAME ${NC}"
    echo -e "${YELLOW}${BOLD}   > OUTPUT DIR: $DIR ${NC}"
    echo -e "${BLUE}====================================================${NC}"
    notify "Started Android Scan on $APK_NAME"
    
    # ---- 1: APKTOOL ----
    step_msg "STEP 1/4: Unpacking Manifest & Resources (Apktool)"
    apktool d "$APK" -o "$DIR/unpacked_resources" -f >/dev/null 2>&1 & spinner $!
    success_msg "Resources extracted."
    
    # ---- 2: JADX DECOMPILE ----
    step_msg "STEP 2/4: Reverse Engineering Source to Java (Jadx)"
    if command -v jadx &>/dev/null; then
        jadx -d "$DIR/source_java" "$APK" >/dev/null 2>&1 & spinner $!
        success_msg "Java Source code decompiled."
    else
        warn_msg "Jadx missing. Skipping deep Java analysis (Run option 1 to install)."
    fi

    # ---- 3: DEEP SECRET HUNT ----
    step_msg "STEP 3/4: Deep Hardcoded Secret Extraction (Regex)"
    # Searching through both resources AND java source
    grep -Erio "AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|https://[a-zA-Z0-9.-]+\.firebaseio\.com" "$DIR" > "$DIR/critical_secrets.txt"
    if [ -s "$DIR/critical_secrets.txt" ]; then 
        warn_msg "Keys found! Check critical_secrets.txt!"
        notify "Android secrets found in $APK_NAME"
    else
        success_msg "Clean. No standard secrets found."
    fi
    
    # ---- 4: ATTACK SURFACE ----
    step_msg "STEP 4/4: Mapping Android Attack Surface (Deep Link & Intents)"
    if [ -f "$DIR/unpacked_resources/AndroidManifest.xml" ]; then
        grep -A 2 -i "android:exported=\"true\"" "$DIR/unpacked_resources/AndroidManifest.xml" > "$DIR/exported_components.txt"
        grep -i "android:scheme=" "$DIR/unpacked_resources/AndroidManifest.xml" > "$DIR/deeplinks.txt"
        success_msg "Exported Components & Deeplinks mapped."
    fi

    # Report
    echo -e "\n${CYAN}[*] Generating Android Summary Report...${NC}"
    echo "# PT-Automator Android Report: $APK_NAME" > "$DIR/FINAL_REPORT.md"
    echo "- Hardcoded Secrets: $( [ -f "$DIR/critical_secrets.txt" ] && wc -l < "$DIR/critical_secrets.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- Exported Components: $( [ -f "$DIR/exported_components.txt" ] && wc -l < "$DIR/exported_components.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"
    echo "- Deep Links: $( [ -f "$DIR/deeplinks.txt" ] && wc -l < "$DIR/deeplinks.txt" || echo 0 )" >> "$DIR/FINAL_REPORT.md"

    notify "Android Scan Finished for $APK_NAME."
    echo -e "\n${GREEN}${BOLD}[+] REVERSE ENGINEERING COMPLETE. Check -> $DIR/FINAL_REPORT.md ${NC}"
}

# =======================================================
# MAIN MENU LOOP
# =======================================================
print_banner() {
    echo -e "\n${RED}${BOLD}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}     PT-AUTOMATOR v3.0 - THE FINAL WAR MACHINE      ${NC}"
    echo -e "${RED}${BOLD}====================================================${NC}"
}

menu() {
    while true; do
        print_banner
        echo " 1) Bootstrapper: Install Dependencies & Wordlists"
        echo " 2) Web App Autopilot (Fuzzing, XSS, SQLi, Takeover, Nuclei)"
        echo " 3) Android APK Autopilot (Java Decompile, Regex, Deeplinks)"
        echo " 4) Exit Console"
        echo "----------------------------------------------------"
        read -p ">> Select Protocol: " choice
        
        case $choice in
            1) install_tools ;;
            2)
                read -p "Enter Target Domain (e.g. example.com): " domain
                if [ -n "$domain" ]; then web_scan "$domain"; else error_msg "Invalid target."; fi
                ;;
            3)
                read -p "Enter Target APK Path (/home/user/app.apk): " apk_path
                if [ -n "$apk_path" ]; then android_scan "$apk_path"; else error_msg "Invalid path."; fi
                ;;
            4)
                echo -e "${GREEN}Process Terminated. Happy Hacking!${NC}"
                exit 0
                ;;
            *)
                error_msg "Protocol missing. Press 1, 2, 3 or 4."
                ;;
        esac
    done
}

mkdir -p "reports"
menu
