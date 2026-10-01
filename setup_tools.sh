#!/usr/bin/env bash
# =============================================================================
#  setup_tools.sh — Bug Bounty Tool Checker & Auto-Installer
#  Run this before recon.sh to ensure every tool is present
#  Usage: ./setup_tools.sh [--check-only] [--force] [--quiet]
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# COLORS & SYMBOLS
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

OK="  ${GREEN}✔${RESET}"
MISSING="  ${RED}✘${RESET}"
INSTALLING="  ${CYAN}↓${RESET}"
SKIPPED="  ${YELLOW}~${RESET}"
WARN="  ${YELLOW}⚠${RESET}"

# ──────────────────────────────────────────────────────────────────────────────
# FLAGS
# ──────────────────────────────────────────────────────────────────────────────
CHECK_ONLY=false
FORCE=false
QUIET=false

for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    --force)      FORCE=true ;;
    --quiet)      QUIET=true ;;
    --help|-h)
      echo "Usage: ./setup_tools.sh [--check-only] [--force] [--quiet]"
      echo ""
      echo "  --check-only   Only report what is missing, do not install"
      echo "  --force        Reinstall even if tool already exists"
      echo "  --quiet        Suppress per-tool output, show summary only"
      exit 0 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────────
# COUNTERS
# ──────────────────────────────────────────────────────────────────────────────
TOTAL=0; FOUND=0; INSTALLED=0; FAILED=0; SKIPPED_COUNT=0

# ──────────────────────────────────────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────────────────────────────────────
log()     { [[ "$QUIET" == false ]] && echo -e "$*" || true; }
info()    { log "${CYAN}[*]${RESET} $*"; }
success() { log "${GREEN}[+]${RESET} $*"; }
warn()    { log "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; }

section() {
  log ""
  log "${BOLD}${BLUE}──  $*  ──────────────────────────────────────────${RESET}"
}

# Check if a binary exists anywhere in PATH or common Go bin locations
is_installed() {
  local tool="$1"
  command -v "$tool" &>/dev/null \
    || [[ -x "$HOME/go/bin/$tool" ]] \
    || [[ -x "/usr/local/bin/$tool" ]] \
    || [[ -x "/usr/bin/$tool" ]]
}

# Run a command, capture output, return exit code
run_silent() { "$@" > /tmp/setup_out.txt 2>&1; }

# ──────────────────────────────────────────────────────────────────────────────
# INSTALL FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

install_go_pkg() {
  local pkg="$1"
  go install "$pkg" >> /tmp/setup_install.log 2>&1
}

install_apt() {
  local pkg="$1"
  sudo apt-get install -y "$pkg" >> /tmp/setup_install.log 2>&1
}

install_pip() {
  local pkg="$1"
  pip3 install "$pkg" --quiet >> /tmp/setup_install.log 2>&1
}

clone_and_install() {
  local repo="$1"
  local dir="$2"
  local post_cmd="${3:-}"
  git clone --depth=1 "$repo" "$dir" >> /tmp/setup_install.log 2>&1
  if [[ -n "$post_cmd" ]]; then
    (cd "$dir" && eval "$post_cmd") >> /tmp/setup_install.log 2>&1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# CORE: check one tool and optionally install it
# ──────────────────────────────────────────────────────────────────────────────
# check_tool <name> <category> <install_type> <install_arg> [<version_flag>]
#   install_type: go | apt | pip | git | manual
check_tool() {
  local name="$1"
  local category="$2"
  local install_type="$3"
  local install_arg="$4"
  local version_flag="${5:---version}"

  TOTAL=$(( TOTAL + 1 ))

  if is_installed "$name" && [[ "$FORCE" == false ]]; then
    FOUND=$(( FOUND + 1 ))
    local ver=""
    ver=$("$name" "$version_flag" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "")
    log "${OK} ${BOLD}${name}${RESET}${DIM}${ver:+  v$ver}${RESET}"
    return
  fi

  if [[ "$CHECK_ONLY" == true ]]; then
    SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}${name}${RESET}${DIM}  [not installed]${RESET}"
    return
  fi

  if [[ "$install_type" == "manual" ]]; then
    SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${SKIPPED} ${BOLD}${name}${RESET}${DIM}  [manual install required — see notes below]${RESET}"
    return
  fi

  log "${INSTALLING} ${BOLD}${name}${RESET}${DIM}  installing via ${install_type}...${RESET}"

  local ok=false
  case "$install_type" in
    go)  install_go_pkg "$install_arg"  && ok=true ;;
    apt) install_apt "$install_arg"     && ok=true ;;
    pip) install_pip "$install_arg"     && ok=true ;;
    git) 
      local repo dir post
      repo=$(echo "$install_arg" | cut -d'|' -f1)
      dir=$(echo  "$install_arg" | cut -d'|' -f2)
      post=$(echo "$install_arg" | cut -d'|' -f3)
      clone_and_install "$repo" "$dir" "$post" && ok=true ;;
  esac

  if $ok && is_installed "$name"; then
    INSTALLED=$(( INSTALLED + 1 ))
    log "    ${GREEN}→ installed successfully${RESET}"
  else
    FAILED=$(( FAILED + 1 ))
    log "    ${RED}→ FAILED — check /tmp/setup_install.log${RESET}"
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PREREQUISITE CHECKS
# ──────────────────────────────────────────────────────────────────────────────
check_prerequisites() {
  section "Prerequisites"

  local errors=0

  # Go
  if command -v go &>/dev/null; then
    local gover; gover=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | head -1)
    log "${OK} Go  ${DIM}($gover)${RESET}"
  else
    log "${MISSING} ${BOLD}Go${RESET} — required for most tools"
    log "     ${DIM}Install: https://go.dev/dl/${RESET}"
    errors=$(( errors + 1 ))
  fi

  # Python 3
  if command -v python3 &>/dev/null; then
    local pyver; pyver=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log "${OK} Python3  ${DIM}(v$pyver)${RESET}"
  else
    log "${MISSING} ${BOLD}Python3${RESET} — required for SecretFinder, Corsy, etc."
    errors=$(( errors + 1 ))
  fi

  # pip3
  if command -v pip3 &>/dev/null; then
    log "${OK} pip3"
  else
    log "${MISSING} ${BOLD}pip3${RESET}"
    errors=$(( errors + 1 ))
  fi

  # git
  if command -v git &>/dev/null; then
    log "${OK} git"
  else
    log "${MISSING} ${BOLD}git${RESET} — required for cloning tools"
    errors=$(( errors + 1 ))
  fi

  # curl
  if command -v curl &>/dev/null; then
    log "${OK} curl"
  else
    log "${MISSING} ${BOLD}curl${RESET}"
    errors=$(( errors + 1 ))
  fi

  # jq
  if command -v jq &>/dev/null; then
    log "${OK} jq"
  else
    log "${WARN} jq  ${DIM}(optional but recommended)${RESET}"
    [[ "$CHECK_ONLY" == false ]] && sudo apt-get install -y jq >> /tmp/setup_install.log 2>&1 && log "     ${GREEN}→ jq installed${RESET}" || true
  fi

  # Ensure ~/go/bin is in PATH
  if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    log "${WARN} ${DIM}\$HOME/go/bin not in PATH — adding to ~/.bashrc & ~/.zshrc${RESET}"
    echo 'export PATH="$PATH:$HOME/go/bin"' >> "$HOME/.bashrc"
    echo 'export PATH="$PATH:$HOME/go/bin"' >> "$HOME/.zshrc" 2>/dev/null || true
    export PATH="$PATH:$HOME/go/bin"
  fi

  if [[ "$errors" -gt 0 && "$CHECK_ONLY" == false ]]; then
    error "Fix $errors prerequisite(s) above before continuing."
    exit 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# TOOL DEFINITIONS
# ──────────────────────────────────────────────────────────────────────────────
check_all_tools() {

  # ── Subdomain Enumeration ───────────────────────────────────────────────────
  section "Subdomain Enumeration"
  check_tool subfinder    "recon" go  "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  check_tool assetfinder  "recon" go  "github.com/tomnomnom/assetfinder@latest"
  check_tool findomain    "recon" apt "findomain"
  check_tool amass        "recon" go  "github.com/owasp-amass/amass/v4/...@master"

  # ── Live Host Probing ───────────────────────────────────────────────────────
  section "Live Host Probing"
  check_tool httpx        "probing" go  "github.com/projectdiscovery/httpx/cmd/httpx@latest"
  check_tool httprobe     "probing" go  "github.com/tomnomnom/httprobe@latest"
  check_tool naabu        "probing" go  "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
  check_tool aquatone     "probing" go  "github.com/michenriksen/aquatone@latest"

  # ── DNS & Infrastructure ────────────────────────────────────────────────────
  section "DNS & Infrastructure"
  check_tool dnsx         "dns" go  "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
  check_tool massdns      "dns" apt "massdns"
  check_tool asnmap       "dns" go  "github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
  check_tool whois        "dns" apt "whois"
  check_tool shodan       "dns" pip "shodan"

  # ── Endpoint & JS Recon ─────────────────────────────────────────────────────
  section "Endpoint & JS Recon"
  check_tool gau          "endpoints" go  "github.com/lc/gau/v2/cmd/gau@latest"
  check_tool waybackurls  "endpoints" go  "github.com/tomnomnom/waybackurls@latest"
  check_tool katana       "endpoints" go  "github.com/projectdiscovery/katana/cmd/katana@latest"
  check_tool hakrawler    "endpoints" go  "github.com/hakluke/hakrawler@latest"
  check_tool subjs        "endpoints" go  "github.com/lc/subjs@latest"
  check_tool gf           "endpoints" go  "github.com/tomnomnom/gf@latest"

  # ── Vulnerability Scanning ──────────────────────────────────────────────────
  section "Vulnerability Scanning"
  check_tool nuclei       "vulns" go  "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  check_tool dalfox       "vulns" go  "github.com/hahwul/dalfox/v2@latest"
  check_tool ffuf         "vulns" go  "github.com/ffuf/ffuf/v2@latest"
  check_tool arjun        "vulns" pip "arjun"
  check_tool sqlmap       "vulns" apt "sqlmap"

  # ── Subdomain Takeover ──────────────────────────────────────────────────────
  section "Subdomain Takeover"
  check_tool subzy        "takeover" go  "github.com/PentestPad/subzy@latest"
  check_tool subjack      "takeover" go  "github.com/haccer/subjack@latest"

  # ── Python-based Tools (git clones) ─────────────────────────────────────────
  section "Python Tools (git-based)"

  # SecretFinder
  if [[ -f "$HOME/SecretFinder/SecretFinder.py" ]] && [[ "$FORCE" == false ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}SecretFinder${RESET}${DIM}  (~/.SecretFinder)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}SecretFinder${RESET}${DIM}  [not installed]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}SecretFinder${RESET}${DIM}  cloning...${RESET}"
    if clone_and_install \
        "https://github.com/m4ll0k/SecretFinder.git" \
        "$HOME/SecretFinder" \
        "pip3 install -r requirements.txt -q"; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ installed at ~/SecretFinder${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # Corsy (CORS scanner)
  if [[ -f "$HOME/Corsy/corsy.py" ]] && [[ "$FORCE" == false ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}Corsy${RESET}${DIM}  (~/.Corsy)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}Corsy${RESET}${DIM}  [not installed]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}Corsy${RESET}${DIM}  cloning...${RESET}"
    if clone_and_install \
        "https://github.com/s0md3v/Corsy.git" \
        "$HOME/Corsy" \
        "pip3 install -r requirements.txt -q 2>/dev/null || true"; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ installed at ~/Corsy${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # LinkFinder
  if [[ -f "$HOME/LinkFinder/linkfinder.py" ]] && [[ "$FORCE" == false ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}LinkFinder${RESET}${DIM}  (~/.LinkFinder)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}LinkFinder${RESET}${DIM}  [not installed]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}LinkFinder${RESET}${DIM}  cloning...${RESET}"
    if clone_and_install \
        "https://github.com/GerbenJavado/LinkFinder.git" \
        "$HOME/LinkFinder" \
        "pip3 install -r requirements.txt -q && python3 setup.py install 2>/dev/null || true"; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ installed at ~/LinkFinder${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # ── Wordlists ───────────────────────────────────────────────────────────────
  section "Wordlists"
  local wl_dir="$HOME/wordlists"

  if [[ -d "$wl_dir" ]] && [[ $(ls -A "$wl_dir" 2>/dev/null | wc -l) -gt 10 ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}SecLists${RESET}${DIM}  ($wl_dir)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}SecLists${RESET}${DIM}  [not found at $wl_dir]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}SecLists${RESET}${DIM}  cloning (this is large, ~1GB)...${RESET}"
    if git clone --depth=1 https://github.com/danielmiessler/SecLists "$wl_dir" >> /tmp/setup_install.log 2>&1; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ SecLists cloned to $wl_dir${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # ── Nuclei Templates ────────────────────────────────────────────────────────
  section "Nuclei Templates"
  local nt_dir="$HOME/nuclei-templates"

  if [[ -d "$nt_dir" ]] && [[ "$FORCE" == false ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}nuclei-templates${RESET}${DIM}  ($nt_dir)${RESET}"
    if [[ "$CHECK_ONLY" == false ]]; then
      log "    ${DIM}updating templates...${RESET}"
      nuclei -update-templates >> /tmp/setup_install.log 2>&1 || true
      log "    ${GREEN}→ templates updated${RESET}"
    fi
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}nuclei-templates${RESET}${DIM}  [not found]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}nuclei-templates${RESET}${DIM}  downloading...${RESET}"
    if nuclei -update-templates >> /tmp/setup_install.log 2>&1; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ templates downloaded${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # ── gf Patterns ─────────────────────────────────────────────────────────────
  section "gf Patterns"
  local gf_dir="$HOME/.gf"

  if [[ -d "$gf_dir" ]] && [[ $(ls "$gf_dir"/*.json 2>/dev/null | wc -l) -gt 5 ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}gf patterns${RESET}${DIM}  ($(ls "$gf_dir"/*.json 2>/dev/null | wc -l) patterns)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}gf patterns${RESET}${DIM}  [~/.gf not populated]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}gf patterns${RESET}${DIM}  cloning 1337r00t patterns...${RESET}"
    mkdir -p "$gf_dir"
    if git clone --depth=1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns >> /tmp/setup_install.log 2>&1; then
      cp /tmp/gf-patterns/*.json "$gf_dir/" 2>/dev/null || true
      rm -rf /tmp/gf-patterns
      # also grab tomnomnom's example patterns
      local gf_src
      gf_src=$(find "$HOME/go/pkg/mod" -name "*.json" -path "*/tomnomnom/gf*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
      [[ -n "$gf_src" ]] && cp "$gf_src"/*.json "$gf_dir/" 2>/dev/null || true
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ $(ls "$gf_dir"/*.json 2>/dev/null | wc -l) patterns installed to ~/.gf${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi

  # ── DNS Resolvers list ───────────────────────────────────────────────────────
  section "DNS Resolvers"
  local resolvers="$HOME/resolvers.txt"

  if [[ -f "$resolvers" ]] && [[ $(wc -l < "$resolvers") -gt 10 ]]; then
    TOTAL=$(( TOTAL + 1 )); FOUND=$(( FOUND + 1 ))
    log "${OK} ${BOLD}resolvers.txt${RESET}${DIM}  ($(wc -l < "$resolvers") resolvers)${RESET}"
  elif [[ "$CHECK_ONLY" == true ]]; then
    TOTAL=$(( TOTAL + 1 )); SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
    log "${MISSING} ${BOLD}resolvers.txt${RESET}${DIM}  [not found at $resolvers]${RESET}"
  else
    TOTAL=$(( TOTAL + 1 ))
    log "${INSTALLING} ${BOLD}resolvers.txt${RESET}${DIM}  downloading fresh list...${RESET}"
    if curl -s "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" \
        -o "$resolvers" >> /tmp/setup_install.log 2>&1; then
      INSTALLED=$(( INSTALLED + 1 ))
      log "    ${GREEN}→ $(wc -l < "$resolvers") resolvers saved to $resolvers${RESET}"
    else
      FAILED=$(( FAILED + 1 ))
      log "    ${RED}→ FAILED${RESET}"
    fi
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────
print_summary() {
  local total_missing=$(( TOTAL - FOUND - INSTALLED ))
  [[ "$total_missing" -lt 0 ]] && total_missing=0

  echo ""
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  Setup Summary${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  printf "  ${GREEN}✔ Already installed:${RESET}  %d\n"  "$FOUND"
  [[ "$CHECK_ONLY" == false ]] && \
  printf "  ${CYAN}↓ Newly installed:${RESET}    %d\n"  "$INSTALLED"
  [[ "$FAILED" -gt 0 ]] && \
  printf "  ${RED}✘ Failed:${RESET}             %d\n"  "$FAILED"
  [[ "$SKIPPED_COUNT" -gt 0 ]] && \
  printf "  ${YELLOW}~ Skipped / manual:${RESET}   %d\n" "$SKIPPED_COUNT"
  printf "  ${DIM}─ Total checked:${RESET}      %d\n"  "$TOTAL"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  if [[ "$FAILED" -gt 0 ]]; then
    warn "Some tools failed to install."
    warn "Check the log: ${BOLD}cat /tmp/setup_install.log${RESET}"
  fi

  if [[ "$CHECK_ONLY" == true && "$SKIPPED_COUNT" -gt 0 ]]; then
    echo ""
    warn "$SKIPPED_COUNT tool(s) missing. Run without --check-only to install them."
    return 1
  fi

  if [[ "$FAILED" -eq 0 ]]; then
    echo ""
    success "${BOLD}All tools are ready. You can now run recon.sh.${RESET}"
    echo ""
    echo -e "  ${DIM}Next step:${RESET}  ${CYAN}./recon.sh -d example.com${RESET}"
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# MANUAL INSTALL NOTES
# ──────────────────────────────────────────────────────────────────────────────
print_manual_notes() {
  [[ "$SKIPPED_COUNT" -eq 0 ]] && return
  echo ""
  echo -e "${BOLD}Manual installation notes:${RESET}"
  echo -e "  ${YELLOW}findomain${RESET}    — https://github.com/Findomain/Findomain/releases"
  echo -e "  ${YELLOW}massdns${RESET}      — sudo apt install massdns  (or build from source)"
  echo -e "  ${YELLOW}aquatone${RESET}     — https://github.com/michenriksen/aquatone/releases"
  echo -e "  ${YELLOW}Shodan CLI${RESET}   — pip3 install shodan  then  shodan init <YOUR_API_KEY>"
  echo ""
  echo -e "  ${DIM}Set your Shodan API key: export SHODAN_API_KEY=your_key_here${RESET}"
  echo -e "  ${DIM}Add it to ~/.bashrc to persist it across sessions.${RESET}"
}

# ──────────────────────────────────────────────────────────────────────────────
# BANNER
# ──────────────────────────────────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗"
  echo -e "║    Bug Bounty Tool Checker & Auto-Installer      ║"
  echo -e "╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  if [[ "$CHECK_ONLY" == true ]]; then
    echo -e "  ${YELLOW}Mode: CHECK ONLY — nothing will be installed${RESET}"
  elif [[ "$FORCE" == true ]]; then
    echo -e "  ${YELLOW}Mode: FORCE REINSTALL — reinstalling all tools${RESET}"
  else
    echo -e "  ${CYAN}Mode: AUTO-INSTALL — missing tools will be installed${RESET}"
  fi
  echo -e "  ${DIM}Log: /tmp/setup_install.log${RESET}"
  echo ""
}

# ──────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ──────────────────────────────────────────────────────────────────────────────
banner
> /tmp/setup_install.log  # clear log

check_prerequisites
check_all_tools
print_summary
print_manual_notes
