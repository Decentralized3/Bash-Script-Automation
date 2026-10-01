#!/bin/bash

# =========================================================================
# BugBountyX v1.0 - Smart Automated Bug Bounty Hunter
# =========================================================================
# Description: Automates recon, filters for high-value targets, runs vuln
# scans (parallel), and produces a SINGLE ranked bounty report.
# =========================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin

step_msg() { echo -e "\n${CYAN}${BOLD}[>>] $1${NC}"; }
success_msg() { echo -e "${GREEN}[OK] $1${NC}"; }
warn_msg() { echo -e "${YELLOW}[!] $1${NC}"; }
error_msg() { echo -e "${RED}[ERROR] $1${NC}"; }

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
# THE ENGINE
# =======================================================
run_scan() {
    TARGET=$1
    DIR="reports/bugbountyx_${TARGET}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"
    
    REPORT="${DIR}/BOUNTY_REPORT.md"
    
    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > BUGBOUNTYX ENGAGED: $TARGET ${NC}"
    echo -e "${YELLOW}${BOLD}   > OUTPUT DIR: $DIR ${NC}"
    echo -e "${BLUE}====================================================${NC}"

    # Initialize Report
    echo "# BugBountyX Ranked Report: $TARGET" > "$REPORT"
    echo "**Date:** $(date)" >> "$REPORT"
    echo "---" >> "$REPORT"

    # ---- PHASE 1: RECON ----
    step_msg "PHASE 1/4: Omnidirectional Recon (Subdomains & Endpoints)"
    
    # Subdomains
    subfinder -d "$TARGET" -all -silent > "$DIR/subs_temp1.txt" &
    assetfinder -subs-only "$TARGET" > "$DIR/subs_temp2.txt" &
    if command -v amass &> /dev/null; then
        amass enum -passive -d "$TARGET" -silent > "$DIR/subs_temp3.txt" &
    fi
    curl -s "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > "$DIR/subs_temp4.txt" &
    wait

    cat "$DIR"/subs_temp*.txt 2>/dev/null | sort -u | grep -i "$TARGET" > "$DIR/subdomains.txt"
    rm -f "$DIR"/subs_temp*.txt
    
    # Live Hosts
    cat "$DIR/subdomains.txt" | httpx -silent -ports 80,443 -title -tech-detect -status-code -o "$DIR/live_hosts_detailed.txt" & spinner $!
    cat "$DIR/live_hosts_detailed.txt" | grep -v "404" | awk '{print $1}' > "$DIR/live_hosts.txt"
    
    # Endpoints
    cat "$DIR/live_hosts.txt" | gau --subs "$TARGET" 2>/dev/null > "$DIR/all_endpoints.txt" & spinner $!
    
    success_msg "Recon complete. Subdomains: $(wc -l < "$DIR/subdomains.txt") | Live: $(wc -l < "$DIR/live_hosts.txt") | Endpoints: $(wc -l < "$DIR/all_endpoints.txt")"

    # ---- PHASE 2: SMART FILTERING ----
    step_msg "PHASE 2/4: Smart Filtering & Prioritization"
    
    grep "=" "$DIR/all_endpoints.txt" | sort -u > "$DIR/all_params.txt"
    grep -E "\?(id|file|url|redirect|path)=" "$DIR/all_params.txt" > "$DIR/critical_params.txt"
    grep -E "\?(q|search|query)=" "$DIR/all_params.txt" > "$DIR/high_params.txt"
    
    success_msg "Filtered parameters. Critical (SSRF/LFI): $(wc -l < "$DIR/critical_params.txt") | High (XSS): $(wc -l < "$DIR/high_params.txt")"

    # ---- PHASE 3: VULN SCANNING (PARALLEL) ----
    step_msg "PHASE 3/4: Multi-Threaded Vulnerability Scanning"
    
    echo " -> Firing Subjack (Takeovers)..."
    subjack -w "$DIR/subdomains.txt" -t 50 -timeout 30 -o "$DIR/takeovers.txt" -ssl -v &

    echo " -> Firing Dalfox (XSS) at High-Priority Params..."
    if [ -s "$DIR/high_params.txt" ]; then
        dalfox pipe --silence --timeout 10 -o "$DIR/dalfox_xss.txt" < "$DIR/high_params.txt" &
    fi

    echo " -> Firing SQLMap (SQLi) at Critical-Priority Params..."
    if [ -s "$DIR/critical_params.txt" ]; then
        head -n 20 "$DIR/critical_params.txt" > "$DIR/sqlmap_targets.txt"
        sqlmap -m "$DIR/sqlmap_targets.txt" --batch --random-agent --level=2 --risk=2 --smart > "$DIR/sqlmap_results.txt" &
    fi

    echo " -> Firing Nuclei (CVEs, Exposures, Misconfigs) against Live Hosts..."
    nuclei -l "$DIR/live_hosts.txt" -t cves/ -t exposed-panels/ -t misconfiguration/ -t vulnerabilities/ -silent -o "$DIR/nuclei_results.txt" &

    # Wait for all vuln scans to hit
    spinner $!
    wait
    success_msg "Vulnerability scanning complete."

    # ---- PHASE 4: REPORT GENERATION ----
    step_msg "PHASE 4/4: Compiling Consolidated Bounty Report"

    echo "## 🔴 CRITICAL FINDINGS (\$1000+ Potential)" >> "$REPORT"
    echo "*(SQLi, RCE, SSRF, Critical CVEs)*" >> "$REPORT"
    echo "\`\`\`text" >> "$REPORT"
    if [ -s "$DIR/nuclei_results.txt" ] && grep -i "critical" "$DIR/nuclei_results.txt" > /dev/null; then
        grep -i "critical" "$DIR/nuclei_results.txt" >> "$REPORT"
    fi
    if [ -s "$DIR/sqlmap_results.txt" ] && grep -i "is vulnerable" "$DIR/sqlmap_results.txt" > /dev/null; then
        echo "--> SQLi Candidates Found! Check $DIR/sqlmap_results.txt for details." >> "$REPORT"
    fi
    echo "\`\`\`" >> "$REPORT"

    echo -e "\n## 🟠 HIGH FINDINGS (\$500+ Potential)" >> "$REPORT"
    echo "*(High CVEs, Subdomain Takeovers, XSS)*" >> "$REPORT"
    echo "\`\`\`text" >> "$REPORT"
    if [ -s "$DIR/nuclei_results.txt" ] && grep -i "high" "$DIR/nuclei_results.txt" > /dev/null; then
        grep -i "high" "$DIR/nuclei_results.txt" >> "$REPORT"
    fi
    if [ -s "$DIR/takeovers.txt" ]; then
        cat "$DIR/takeovers.txt" >> "$REPORT"
    fi
    if [ -s "$DIR/dalfox_xss.txt" ]; then
        cat "$DIR/dalfox_xss.txt" >> "$REPORT"
    fi
    echo "\`\`\`" >> "$REPORT"

    echo -e "\n## 🟡 MEDIUM/LOW FINDINGS (Recon & Padding)" >> "$REPORT"
    echo "\`\`\`text" >> "$REPORT"
    if [ -s "$DIR/nuclei_results.txt" ] && grep -iE "medium|low|info" "$DIR/nuclei_results.txt" > /dev/null; then
        grep -iE "medium|low|info" "$DIR/nuclei_results.txt" >> "$REPORT"
    fi
    echo "\`\`\`" >> "$REPORT"

    echo -e "\n## 🎯 TOP TARGETS FOR MANUAL FOCUS" >> "$REPORT"
    echo "*(Hosts running juicy tech or with lots of parameters)*" >> "$REPORT"
    echo "\`\`\`text" >> "$REPORT"
    grep -iE "admin|login|dashboard|api|upload" "$DIR/live_hosts_detailed.txt" | head -n 10 >> "$REPORT"
    echo "\`\`\`" >> "$REPORT"

    echo -e "\n---" >> "$REPORT"
    echo "**Execution Stats:**" >> "$REPORT"
    echo "- Subdomains: $(wc -l < "$DIR/subdomains.txt")" >> "$REPORT"
    echo "- Live Hosts: $(wc -l < "$DIR/live_hosts.txt")" >> "$REPORT"
    echo "- Endpoints: $(wc -l < "$DIR/all_endpoints.txt")" >> "$REPORT"

    success_msg "Report Generated: $REPORT"
    echo -e "\n${GREEN}${BOLD}Hunt Complete. Focus your energy on the CRITICAL section first!${NC}"
}

# =======================================================
# MENU
# =======================================================
print_banner() {
    echo -e "\n${RED}${BOLD}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}     BUGBOUNTYX v1.0 - SMART BOUNTY HUNTER           ${NC}"
    echo -e "${RED}${BOLD}====================================================${NC}"
}

mkdir -p reports
print_banner
if [ -z "$1" ]; then
    read -p ">> Enter Target Domain (e.g. example.com): " TARGET
else
    TARGET="$1"
fi

if [ -n "$TARGET" ]; then
    run_scan "$TARGET"
else
    error_msg "No target provided."
fi
