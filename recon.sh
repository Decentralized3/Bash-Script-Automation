#!/usr/bin/env bash
# =============================================================================
#  recon.sh — Bug Bounty Automation Script
#  Usage:  ./recon.sh -d example.com [options]
#  Author: Generated for your workflow
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# COLORS
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

# ──────────────────────────────────────────────────────────────────────────────
# CONFIG — edit these to match your setup
# ──────────────────────────────────────────────────────────────────────────────
WORDLIST_DIR="$HOME/wordlists"
RESOLVERS="$HOME/resolvers.txt"
NUCLEI_TEMPLATES="$HOME/nuclei-templates"
DISCORD_WEBHOOK=""          # paste your webhook URL here or export DISCORD_WEBHOOK=
THREADS=50
RATE_LIMIT=150              # requests/sec for aggressive tools — lower on rate-limited programs

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────────────────────────────────────
banner() {
  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║        Bug Bounty Automation — recon.sh      ║"
  echo "╚══════════════════════════════════════════════╝${RESET}"
}

log()     { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[+]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; }
phase()   { echo -e "\n${BOLD}${BLUE}━━━  $*  ━━━${RESET}"; }

# Send a Discord notification (silent if webhook not set)
notify() {
  local msg="$1"
  [[ -z "${DISCORD_WEBHOOK:-}" ]] && return
  curl -s -H "Content-Type: application/json" \
    -d "{\"content\": \"🔍 **recon.sh** | ${msg}\"}" \
    "$DISCORD_WEBHOOK" > /dev/null
}

# Check if a tool exists, warn if missing (don't abort)
need() {
  local tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    warn "Tool not found: ${BOLD}${tool}${RESET} — skipping related step"
    return 1
  fi
  return 0
}

# Count lines in a file safely
count() { [[ -f "$1" ]] && wc -l < "$1" | tr -d ' ' || echo 0; }

# ──────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ──────────────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ./recon.sh -d <domain> [flags]

${BOLD}Flags:${RESET}
  -d  domain       Target domain (required)
  -o  output_dir   Output directory (default: ./results/<domain>)
  -w  webhook      Discord webhook URL
  -t  threads      Threads (default: 50)
  --passive        Passive recon only (no active scanning)
  --skip-vuln      Skip vulnerability scanning phase
  --skip-screens   Skip aquatone screenshots
  --quick          Run only fast tools (subfinder, httpx, nuclei)
  -h               Show this help

${BOLD}Examples:${RESET}
  ./recon.sh -d example.com
  ./recon.sh -d example.com --quick
  ./recon.sh -d example.com -w https://discord.com/api/webhooks/...
EOF
  exit 0
}

TARGET=""
OUTPUT_DIR=""
PASSIVE=false
SKIP_VULN=false
SKIP_SCREENS=false
QUICK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) TARGET="$2"; shift 2 ;;
    -o) OUTPUT_DIR="$2"; shift 2 ;;
    -w) DISCORD_WEBHOOK="$2"; shift 2 ;;
    -t) THREADS="$2"; shift 2 ;;
    --passive)    PASSIVE=true; shift ;;
    --skip-vuln)  SKIP_VULN=true; shift ;;
    --skip-screens) SKIP_SCREENS=true; shift ;;
    --quick)      QUICK=true; shift ;;
    -h|--help)    usage ;;
    *) error "Unknown flag: $1"; usage ;;
  esac
done

[[ -z "$TARGET" ]] && { error "Domain is required. Use -d example.com"; usage; }

# Strip http/https if user pastes a URL
TARGET="${TARGET#http://}"; TARGET="${TARGET#https://}"; TARGET="${TARGET%%/*}"

OUTPUT_DIR="${OUTPUT_DIR:-./results/$TARGET}"
START_TIME=$(date +%s)

# ──────────────────────────────────────────────────────────────────────────────
# DIRECTORY STRUCTURE
# ──────────────────────────────────────────────────────────────────────────────
setup_dirs() {
  mkdir -p "$OUTPUT_DIR"/{subdomains,live,dns,endpoints,js,vulns,screenshots,recon,reports}
  log "Output directory: ${BOLD}$OUTPUT_DIR${RESET}"
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 1 — SUBDOMAIN ENUMERATION
# ──────────────────────────────────────────────────────────────────────────────
phase_subdomains() {
  phase "Phase 1 — Subdomain Enumeration"
  local outdir="$OUTPUT_DIR/subdomains"

  # subfinder (fast, multi-source passive)
  if need subfinder; then
    log "Running subfinder..."
    subfinder -d "$TARGET" -all -silent -o "$outdir/subfinder.txt" 2>/dev/null
    success "subfinder: $(count "$outdir/subfinder.txt") subdomains"
  fi

  # amass passive (thorough but slower — skip in --quick mode)
  if [[ "$QUICK" == false ]] && need amass; then
    log "Running amass (passive)..."
    amass enum -passive -d "$TARGET" -o "$outdir/amass.txt" 2>/dev/null || true
    success "amass: $(count "$outdir/amass.txt") subdomains"
  fi

  # assetfinder
  if need assetfinder; then
    log "Running assetfinder..."
    assetfinder --subs-only "$TARGET" > "$outdir/assetfinder.txt" 2>/dev/null
    success "assetfinder: $(count "$outdir/assetfinder.txt") subdomains"
  fi

  # findomain
  if need findomain; then
    log "Running findomain..."
    findomain -t "$TARGET" -u "$outdir/findomain.txt" -q 2>/dev/null || true
    success "findomain: $(count "$outdir/findomain.txt") subdomains"
  fi

  # crt.sh (certificate transparency)
  log "Querying crt.sh..."
  curl -s "https://crt.sh/?q=%25.$TARGET&output=json" 2>/dev/null \
    | grep -oP '"name_value":"\K[^"]+' \
    | sed 's/\*\.//g' \
    | sort -u > "$outdir/crtsh.txt" || true
  success "crt.sh: $(count "$outdir/crtsh.txt") entries"

  # Wayback Machine subdomain extraction
  log "Extracting from Wayback Machine..."
  curl -s "https://web.archive.org/cdx/search/cdx?url=*.$TARGET&output=json&fl=original&collapse=urlkey" 2>/dev/null \
    | grep -oP 'https?://\K[^/]+' \
    | grep -i "\.$TARGET$" \
    | sort -u > "$outdir/wayback_subs.txt" || true
  success "Wayback subs: $(count "$outdir/wayback_subs.txt") entries"

  # Merge and deduplicate everything
  cat "$outdir"/*.txt 2>/dev/null \
    | sed 's/\*\.//g' \
    | grep -E "\.$TARGET$|^$TARGET$" \
    | grep -vE ' |^#' \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u > "$outdir/all.txt"

  local total
  total=$(count "$outdir/all.txt")
  success "Total unique subdomains: ${BOLD}${total}${RESET}"
  notify "[$TARGET] Subdomain enumeration done — $total unique subs found"
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 2 — LIVE HOST PROBING
# ──────────────────────────────────────────────────────────────────────────────
phase_live_hosts() {
  phase "Phase 2 — Live Host Probing"
  local outdir="$OUTPUT_DIR/live"
  local subs="$OUTPUT_DIR/subdomains/all.txt"

  [[ ! -f "$subs" || $(count "$subs") -eq 0 ]] && { warn "No subdomains found, skipping."; return; }

  # httpx — probe + fingerprint in one shot
  if need httpx; then
    log "Running httpx (probing + tech detection)..."
    httpx -l "$subs" \
      -silent \
      -status-code \
      -title \
      -tech-detect \
      -follow-redirects \
      -threads "$THREADS" \
      -rate-limit "$RATE_LIMIT" \
      -o "$outdir/httpx_full.txt" \
      -json -o "$outdir/httpx.json" 2>/dev/null || true

    # Extract just the live URLs for other tools
    grep -oP 'https?://[^\s"]+' "$outdir/httpx_full.txt" 2>/dev/null \
      | sort -u > "$outdir/live_urls.txt" || true

    success "httpx: $(count "$outdir/live_urls.txt") live hosts"
  fi

  # Port scan with naabu (skip in quick/passive mode)
  if [[ "$QUICK" == false && "$PASSIVE" == false ]] && need naabu; then
    log "Running naabu port scan (top 1000 ports)..."
    naabu -l "$subs" -top-ports 1000 -silent -o "$outdir/ports.txt" -rate 1000 2>/dev/null || true
    success "naabu: $(count "$outdir/ports.txt") open ports"
  fi

  # Screenshots with aquatone
  if [[ "$SKIP_SCREENS" == false && "$QUICK" == false ]] && need aquatone; then
    log "Taking screenshots with aquatone..."
    cat "$outdir/live_urls.txt" \
      | aquatone -out "$OUTPUT_DIR/screenshots" -threads 5 -timeout 10000 2>/dev/null || true
    success "Screenshots saved to screenshots/"
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 3 — DNS & INFRASTRUCTURE RECON
# ──────────────────────────────────────────────────────────────────────────────
phase_dns() {
  phase "Phase 3 — DNS & Infrastructure"
  local outdir="$OUTPUT_DIR/dns"
  local subs="$OUTPUT_DIR/subdomains/all.txt"

  # dnsx — resolve + grab CNAMEs (subdomain takeover indicators)
  if need dnsx; then
    log "Running dnsx (resolve + CNAME)..."
    dnsx -l "$subs" -a -cname -silent -o "$outdir/resolved.txt" 2>/dev/null || true
    success "dnsx: $(count "$outdir/resolved.txt") resolved"

    # Pull CNAME records specifically for takeover analysis
    dnsx -l "$subs" -cname -silent 2>/dev/null \
      | grep -i "CNAME" > "$outdir/cnames.txt" || true
    success "CNAMEs found: $(count "$outdir/cnames.txt")"
  fi

  # ASN / IP range recon
  if need asnmap; then
    log "Running asnmap..."
    asnmap -d "$TARGET" -silent > "$OUTPUT_DIR/recon/asn.txt" 2>/dev/null || true
  fi

  # Whois
  log "Running whois..."
  whois "$TARGET" > "$OUTPUT_DIR/recon/whois.txt" 2>/dev/null || true

  # Shodan (requires API key in env SHODAN_API_KEY)
  if need shodan && [[ -n "${SHODAN_API_KEY:-}" ]]; then
    log "Querying Shodan..."
    shodan domain "$TARGET" > "$OUTPUT_DIR/recon/shodan.txt" 2>/dev/null || true
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 4 — ENDPOINT & JS RECON
# ──────────────────────────────────────────────────────────────────────────────
phase_endpoints() {
  phase "Phase 4 — Endpoint & JS Recon"
  local epdir="$OUTPUT_DIR/endpoints"
  local jsdir="$OUTPUT_DIR/js"
  local live="$OUTPUT_DIR/live/live_urls.txt"

  [[ ! -f "$live" || $(count "$live") -eq 0 ]] && { warn "No live hosts, skipping endpoints."; return; }

  # gau — historical URLs (Wayback + CommonCrawl + OTX)
  if need gau; then
    log "Running gau (Wayback + CommonCrawl)..."
    gau "$TARGET" \
      --threads 10 \
      --blacklist png,jpg,gif,svg,woff,ttf,eot,ico,pdf \
      --o "$epdir/gau.txt" 2>/dev/null || true
    success "gau: $(count "$epdir/gau.txt") URLs"
  fi

  # waybackurls
  if need waybackurls; then
    log "Running waybackurls..."
    echo "$TARGET" | waybackurls > "$epdir/wayback.txt" 2>/dev/null || true
    success "waybackurls: $(count "$epdir/wayback.txt") URLs"
  fi

  # katana — active crawl
  if [[ "$PASSIVE" == false ]] && need katana; then
    log "Running katana (active crawl, depth 3)..."
    katana -list "$live" \
      -d 3 \
      -jc \
      -silent \
      -o "$epdir/katana.txt" 2>/dev/null || true
    success "katana: $(count "$epdir/katana.txt") URLs"
  fi

  # hakrawler
  if [[ "$PASSIVE" == false ]] && need hakrawler; then
    log "Running hakrawler..."
    cat "$live" | hakrawler -d 2 -subs 2>/dev/null \
      | tee -a "$epdir/hakrawler.txt" > /dev/null || true
    success "hakrawler: $(count "$epdir/hakrawler.txt") URLs"
  fi

  # Merge all endpoints
  cat "$epdir"/*.txt 2>/dev/null | sort -u > "$epdir/all.txt"
  success "Total unique endpoints: $(count "$epdir/all.txt")"

  # ── JS file extraction ──────────────────────────────────────────────────────
  log "Extracting JS files..."
  cat "$epdir/all.txt" | grep -E "\.js(\?|$)" | sort -u > "$jsdir/jsfiles.txt"

  if need subjs; then
    cat "$live" | subjs 2>/dev/null >> "$jsdir/jsfiles.txt" || true
  fi
  sort -u -o "$jsdir/jsfiles.txt" "$jsdir/jsfiles.txt"
  success "JS files found: $(count "$jsdir/jsfiles.txt")"

  # Download JS files and scan for secrets
  if need SecretFinder || [[ -f "$HOME/SecretFinder/SecretFinder.py" ]]; then
    log "Scanning JS for secrets/API keys..."
    while IFS= read -r jsurl; do
      python3 "$HOME/SecretFinder/SecretFinder.py" \
        -i "$jsurl" -o cli 2>/dev/null >> "$jsdir/secrets.txt" || true
    done < "$jsdir/jsfiles.txt"
    local secrets
    secrets=$(grep -cE "api|key|token|secret|password" "$jsdir/secrets.txt" 2>/dev/null || echo 0)
    [[ "$secrets" -gt 0 ]] && {
      success "Potential secrets found: $secrets"
      notify "[$TARGET] ⚠️ $secrets potential secrets in JS files!"
    }
  fi

  # gf — grep patterns for vuln-interesting params
  if need gf; then
    log "Running gf patterns..."
    local patterns=(xss sqli ssrf redirect lfi rce idor ssti)
    for pat in "${patterns[@]}"; do
      cat "$epdir/all.txt" | gf "$pat" 2>/dev/null > "$OUTPUT_DIR/vulns/${pat}_params.txt" || true
      local n; n=$(count "$OUTPUT_DIR/vulns/${pat}_params.txt")
      [[ "$n" -gt 0 ]] && success "gf $pat: $n URLs"
    done
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 5 — VULNERABILITY SCANNING
# ──────────────────────────────────────────────────────────────────────────────
phase_vulns() {
  [[ "$SKIP_VULN" == true ]] && { warn "Vulnerability scanning skipped (--skip-vuln)"; return; }
  phase "Phase 5 — Vulnerability Scanning"
  local live="$OUTPUT_DIR/live/live_urls.txt"
  local vdir="$OUTPUT_DIR/vulns"

  [[ ! -f "$live" ]] && { warn "No live hosts found."; return; }

  # nuclei — the core scanner
  if need nuclei; then
    log "Running nuclei (critical + high + medium)..."
    nuclei \
      -l "$live" \
      -t "$NUCLEI_TEMPLATES" \
      -severity critical,high,medium \
      -silent \
      -rate-limit "$RATE_LIMIT" \
      -o "$vdir/nuclei.txt" \
      -json-export "$vdir/nuclei.json" 2>/dev/null || true

    local n; n=$(count "$vdir/nuclei.txt")
    success "nuclei: $n findings"

    # Alert on critical/high
    local crits; crits=$(grep -c '"severity":"critical"' "$vdir/nuclei.json" 2>/dev/null || echo 0)
    [[ "$crits" -gt 0 ]] && notify "[$TARGET] 🚨 $crits CRITICAL nuclei findings!"
  fi

  # dalfox — XSS
  if need dalfox && [[ -f "$vdir/xss_params.txt" ]] && [[ $(count "$vdir/xss_params.txt") -gt 0 ]]; then
    log "Running dalfox (XSS)..."
    cat "$vdir/xss_params.txt" \
      | dalfox pipe \
        --skip-bav \
        --no-spinner \
        -o "$vdir/xss_confirmed.txt" 2>/dev/null || true
    success "dalfox: $(count "$vdir/xss_confirmed.txt") XSS found"
  fi

  # CORS misconfiguration
  if [[ -f "$HOME/Corsy/corsy.py" ]]; then
    log "Checking CORS misconfigurations..."
    python3 "$HOME/Corsy/corsy.py" \
      -i "$live" -t 10 \
      -o "$vdir/cors.json" 2>/dev/null || true
  fi

  # Hidden parameters with arjun (slow, skip in quick mode)
  if [[ "$QUICK" == false ]] && need arjun; then
    log "Running arjun (hidden params)..."
    arjun \
      -i "$OUTPUT_DIR/endpoints/katana.txt" \
      --stable \
      -oT "$vdir/params.txt" 2>/dev/null || true
    success "arjun: $(count "$vdir/params.txt") hidden params"
  fi

  # Directory fuzzing with ffuf
  if [[ "$PASSIVE" == false ]] && need ffuf; then
    local wordlist="${WORDLIST_DIR}/raft-medium-directories.txt"
    if [[ -f "$wordlist" ]]; then
      log "Running ffuf (directory fuzzing) on top 5 hosts..."
      head -5 "$live" | while IFS= read -r url; do
        local host; host=$(echo "$url" | sed 's|https\?://||;s|/.*||')
        ffuf -u "$url/FUZZ" \
          -w "$wordlist" \
          -mc 200,201,204,301,302,307,401,403 \
          -silent \
          -rate "$RATE_LIMIT" \
          -o "$vdir/ffuf_${host}.json" \
          -of json 2>/dev/null || true
      done
    else
      warn "ffuf wordlist not found at $wordlist — skipping"
    fi
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 6 — SUBDOMAIN TAKEOVER
# ──────────────────────────────────────────────────────────────────────────────
phase_takeover() {
  phase "Phase 6 — Subdomain Takeover"
  local subs="$OUTPUT_DIR/subdomains/all.txt"
  local vdir="$OUTPUT_DIR/vulns"

  [[ ! -f "$subs" || $(count "$subs") -eq 0 ]] && { warn "No subdomains to check."; return; }

  # subzy (fast, modern)
  if need subzy; then
    log "Running subzy..."
    subzy run \
      --targets "$subs" \
      --output "$vdir/subzy.txt" \
      --hide-fails 2>/dev/null || true
    local n; n=$(count "$vdir/subzy.txt")
    success "subzy: $n potential takeovers"
    [[ "$n" -gt 0 ]] && notify "[$TARGET] 🎯 $n potential subdomain takeovers!"
  fi

  # subjack (cross-reference)
  if [[ "$QUICK" == false ]] && need subjack; then
    log "Running subjack..."
    subjack \
      -w "$subs" \
      -t 100 \
      -timeout 30 \
      -ssl \
      -o "$vdir/subjack.txt" 2>/dev/null || true
    success "subjack done"
  fi

  # nuclei takeover templates
  if need nuclei; then
    log "Running nuclei takeover templates..."
    nuclei \
      -l "$subs" \
      -t "$NUCLEI_TEMPLATES/takeovers/" \
      -silent \
      -o "$vdir/nuclei_takeover.txt" 2>/dev/null || true
    success "nuclei takeovers: $(count "$vdir/nuclei_takeover.txt") findings"
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PHASE 7 — REPORT GENERATION
# ──────────────────────────────────────────────────────────────────────────────
phase_report() {
  phase "Phase 7 — Report Generation"
  local report="$OUTPUT_DIR/reports/report_$(date +%Y%m%d_%H%M%S).md"
  local END_TIME; END_TIME=$(date +%s)
  local DURATION=$(( END_TIME - START_TIME ))
  local DURATION_FMT; DURATION_FMT=$(printf '%02d:%02d:%02d' $((DURATION/3600)) $(( (DURATION%3600)/60 )) $((DURATION%60)))

  cat > "$report" <<REPORT
# Bug Bounty Recon Report

**Target:** \`${TARGET}\`
**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Duration:** ${DURATION_FMT}

---

## Summary

| Category | Count |
|---|---|
| Subdomains discovered | $(count "$OUTPUT_DIR/subdomains/all.txt") |
| Live hosts | $(count "$OUTPUT_DIR/live/live_urls.txt") |
| Endpoints collected | $(count "$OUTPUT_DIR/endpoints/all.txt") |
| JS files | $(count "$OUTPUT_DIR/js/jsfiles.txt") |
| Nuclei findings | $(count "$OUTPUT_DIR/vulns/nuclei.txt") |
| Potential takeovers | $(count "$OUTPUT_DIR/vulns/subzy.txt") |

---

## Nuclei Findings

\`\`\`
$(cat "$OUTPUT_DIR/vulns/nuclei.txt" 2>/dev/null | head -50 || echo "None")
\`\`\`

## Potential Subdomain Takeovers

\`\`\`
$(cat "$OUTPUT_DIR/vulns/subzy.txt" 2>/dev/null || echo "None")
\`\`\`

## Confirmed XSS (dalfox)

\`\`\`
$(cat "$OUTPUT_DIR/vulns/xss_confirmed.txt" 2>/dev/null || echo "None")
\`\`\`

## Potential Secrets in JS

\`\`\`
$(head -30 "$OUTPUT_DIR/js/secrets.txt" 2>/dev/null || echo "None")
\`\`\`

---

*Generated by recon.sh*
REPORT

  success "Report saved: $report"
  notify "[$TARGET] ✅ Recon complete in ${DURATION_FMT} — report saved"
}

# ──────────────────────────────────────────────────────────────────────────────
# TOOL INSTALLER (helper — run with --install)
# ──────────────────────────────────────────────────────────────────────────────
install_tools() {
  echo -e "${BOLD}Installing Go-based tools...${RESET}"
  local go_tools=(
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
    "github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
    "github.com/tomnomnom/assetfinder@latest"
    "github.com/tomnomnom/waybackurls@latest"
    "github.com/tomnomnom/httprobe@latest"
    "github.com/tomnomnom/gf@latest"
    "github.com/tomnomnom/subjs@latest"
    "github.com/hakluke/hakrawler@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
    "github.com/PentestPad/subzy@latest"
    "github.com/hahwul/dalfox/v2@latest"
    "github.com/ffuf/ffuf/v2@latest"
    "github.com/s0md3v/arjun@latest"
  )
  for pkg in "${go_tools[@]}"; do
    local name; name=$(basename "${pkg%%@*}")
    echo -n "  Installing $name... "
    go install "$pkg" 2>/dev/null && echo "✓" || echo "✗ (failed)"
  done

  echo -e "\n${BOLD}Updating nuclei templates...${RESET}"
  nuclei -update-templates 2>/dev/null || true

  echo -e "\n${BOLD}Installing wordlists (SecLists)...${RESET}"
  if [[ ! -d "$WORDLIST_DIR" ]]; then
    git clone --depth=1 https://github.com/danielmiessler/SecLists "$WORDLIST_DIR" 2>/dev/null || true
  else
    echo "  SecLists already at $WORDLIST_DIR"
  fi

  echo -e "\n${GREEN}Done! Run ./recon.sh -d <domain> to start.${RESET}"
  exit 0
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────
[[ "${1:-}" == "--install" ]] && install_tools

banner
log "Target: ${BOLD}${TARGET}${RESET}"
log "Output: ${BOLD}${OUTPUT_DIR}${RESET}"
[[ "$PASSIVE" == true ]]    && warn "Passive mode — active scanning disabled"
[[ "$QUICK" == true ]]      && warn "Quick mode — running fast tools only"
[[ "$SKIP_VULN" == true ]]  && warn "Vulnerability scanning disabled"
echo ""

setup_dirs
notify "[$TARGET] 🚀 Recon started"

phase_subdomains
phase_live_hosts
phase_dns
phase_endpoints
phase_vulns
phase_takeover
phase_report

echo ""
success "${BOLD}Recon complete for $TARGET${RESET}"
echo -e "  Results:  ${CYAN}$OUTPUT_DIR${RESET}"
echo -e "  Duration: ${CYAN}$(printf '%02d:%02d:%02d' $(( ($(date +%s)-START_TIME)/3600 )) $(( (($(date +%s)-START_TIME)%3600)/60 )) $(( ($(date +%s)-START_TIME)%60 )))${RESET}"
