#!/bin/bash

# =========================================================================
# INFRA-AUTOMATOR v1.0 - NETWORK & IP WARFARE
# Infrastructure Reconnaissance & Vulnerability Scanning CLI
# =========================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

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
# DEPENDENCY CHECKER
# =======================================================
check_dependencies() {
    echo -e "\n${YELLOW}[>] Checking Network Dependencies...${NC}"
    for tool in nmap whois dig dnsrecon enum4linux sslscan; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}[!] $tool is missing. Please run:\n    sudo apt-get install $tool dnsutils sslscan enum4linux -y${NC}"
        else
            echo -e "${GREEN}[V] $tool is installed.${NC}"
        fi
    done
    sleep 2
}

# =======================================================
# 1. DNS & WHOIS FOOTPRINTING
# =======================================================
dns_footprint() {
    TARGET=$1
    DIR="reports/infra_${TARGET}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"

    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > DNS & FOOTPRINTING: $TARGET ${NC}"
    echo -e "${BLUE}====================================================${NC}"

    step_msg "STEP 1/3: Whois & Routing Information"
    whois "$TARGET" > "$DIR/whois.txt" & spinner $!
    success_msg "Whois lookup complete."

    step_msg "STEP 2/3: Basic DNS Records (A, MX, TXT, NS)"
    dig ANY "$TARGET" +short > "$DIR/dig_any.txt"
    dig AXFR "$TARGET" > "$DIR/zone_transfer_attempt.txt"
    success_msg "DNS records gathered."

    step_msg "STEP 3/3: Advanced DNS Recon (dnsrecon)"
    if command -v dnsrecon &> /dev/null; then
        dnsrecon -d "$TARGET" -t std -a > "$DIR/dnsrecon.txt" & spinner $!
        success_msg "DNSRecon complete."
    else
        warn_msg "dnsrecon not found, skipping."
    fi

    echo -e "\n${GREEN}[+] Footprinting done. Data saved in $DIR${NC}"
}

# =======================================================
# 2. THE GOD-MODE NMAP SCAN
# =======================================================
nmap_god_mode() {
    IP=$1
    DIR="reports/ip_${IP}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"

    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > FULL IP VULN SCAN: $IP ${NC}"
    echo -e "${BLUE}====================================================${NC}"

    step_msg "STEP 1/3: All Ports Fast Scan"
    echo "Scanning all 65535 ports to find open services..."
    nmap -p- -T4 --min-rate=1000 -Pn "$IP" -oN "$DIR/nmap_all_ports.txt" & spinner $!
    
    # Extract open ports
    OPEN_PORTS=$(grep ^[0-9] "$DIR/nmap_all_ports.txt" | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
    
    if [ -z "$OPEN_PORTS" ]; then
        error_msg "No open ports found on $IP!"
        return
    fi
    success_msg "Open ports found: $OPEN_PORTS"

    step_msg "STEP 2/3: Deep Target Service Enumeration (-sV -sC)"
    echo "Pinpointing service versions and running default scripts on open ports..."
    nmap -p "$OPEN_PORTS" -sV -sC -T4 -Pn "$IP" -oN "$DIR/nmap_services.txt" & spinner $!
    success_msg "Service mapping complete."

    step_msg "STEP 3/3: NSE Vulnerability Engine (--script vuln)"
    echo "Running Nmap Vuln engine against found services..."
    nmap -p "$OPEN_PORTS" -sV --script vuln -Pn -T4 "$IP" -oN "$DIR/nmap_vulns.txt" & spinner $!
    success_msg "Vulnerability scanning complete."

    echo -e "\n${GREEN}[+] Nmap God Mode finished. Reports in $DIR${NC}"
}

# =======================================================
# 3. INFRASTRUCTURE DEEP DIVES (SMB, SSL, RPC)
# =======================================================
infra_deep_dive() {
    IP=$1
    DIR="reports/infra_deep_${IP}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIR"

    echo -e "\n${BLUE}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}   > PROTOCOL DEEP DIVE: $IP ${NC}"
    echo -e "${BLUE}====================================================${NC}"

    step_msg "STEP 1/3: SMB / NetBIOS Enumeration (enum4linux)"
    if command -v enum4linux &> /dev/null; then
        enum4linux -a "$IP" > "$DIR/smb_enum.txt" & spinner $!
        success_msg "enum4linux complete."
    else
        warn_msg "enum4linux not found!"
    fi

    step_msg "STEP 2/3: SSL/TLS Vulnerability Scan (sslscan)"
    if command -v sslscan &> /dev/null; then
        sslscan "$IP" > "$DIR/ssl_tls_scan.txt" & spinner $!
        success_msg "SSL vulnerabilities logged."
    else
        warn_msg "sslscan not found!"
    fi

    step_msg "STEP 3/3: RPC Bind Mapper (rpcinfo)"
    rpcinfo -p "$IP" > "$DIR/rpc_info.txt" 2>/dev/null
    success_msg "RPC dump complete."

    echo -e "\n${GREEN}[+] Deep Dive complete. Data saved in $DIR${NC}"
}

# =======================================================
# MAIN MENU
# =======================================================
print_banner() {
    echo -e "\n${RED}${BOLD}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}       INFRA-AUTOMATOR v1.0 - NETWORK WARFARE        ${NC}"
    echo -e "${RED}${BOLD}====================================================${NC}"
}

menu() {
    while true; do
        print_banner
        echo " 1) Run Dependency Check"
        echo " 2) Network Footprinting & DNS (Whois, Dig, Zone Transfers)"
        echo " 3) Nmap Full Assault (All 65k Ports -> Service Map -> Vuln Engine)"
        echo " 4) Protocol Deep Dive (SMB, RPC, SSL/TLS Vulnerabilities)"
        echo " 5) Exit Console"
        echo "----------------------------------------------------"
        read -p ">> Select Tactic: " choice
        
        case $choice in
            1) check_dependencies ;;
            2)
                read -p "Enter Target Domain/IP: " target
                if [ -n "$target" ]; then dns_footprint "$target"; else error_msg "Invalid target."; fi
                ;;
            3)
                read -p "Enter Target IP/Subnet (e.g. 192.168.1.1): " target
                if [ -n "$target" ]; then nmap_god_mode "$target"; else error_msg "Invalid target."; fi
                ;;
            4)
                read -p "Enter Target IP: " target
                if [ -n "$target" ]; then infra_deep_dive "$target"; else error_msg "Invalid target."; fi
                ;;
            5)
                echo -e "${GREEN}Process Terminated. Good luck!${NC}"
                exit 0
                ;;
            *)
                error_msg "Protocol missing. Select 1-5."
                ;;
        esac
    done
}

mkdir -p "reports"
menu
