#!/usr/bin/env bash
# Recon_silent.sh
# Silent, thorough APK reconnaissance:
# - Unzip APK
# - Treat text and binary files differently (avoid grep "binary file matches")
# - Extract URLs, endpoints, API keys, secrets, JWTs, cloud buckets, private key markers
# - Produce deduplicated categorized output files
# Usage: ./Recon_silent.sh app.apk

set -euo pipefail
IFS=$'\n\t'

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <file.apk>"
  exit 1
fi

APK="$1"
if [ ! -f "$APK" ]; then
  echo "Error: APK not found: $APK"
  exit 2
fi

BASENAME=$(basename "$APK" .apk)
OUTDIR="${BASENAME}_recon"
APKD="${OUTDIR}/apk_unzipped"
mkdir -p "$OUTDIR"
rm -rf "$APKD"
mkdir -p "$APKD"

# Quiet header
printf "[+] Recon (silent) on: %s -> %s\n" "$APK" "$OUTDIR"

# Unzip quietly
unzip -q "$APK" -d "$APKD"

# Prepare temporary working lists
TMP_ALL="${OUTDIR}/.files_all.txt"
find "$APKD" -type f -print0 > "${OUTDIR}/.find_files0"
# convert to newline-separated safely
tr '\0' '\n' < "${OUTDIR}/.find_files0" > "$TMP_ALL"

# Output files
URLS="$OUTDIR/urls.txt"
API_ENDPOINTS="$OUTDIR/api_endpoints.txt"
KEYS="$OUTDIR/keys_secrets.txt"
FIREBASE="$OUTDIR/firebase_matches.txt"
CLOUD="$OUTDIR/cloud_storage.txt"
SMALI_REF="$OUTDIR/smali_references.txt"
ALL_STRINGS="$OUTDIR/strings_all_extracted.txt"
POTENTIAL_JWT="$OUTDIR/jwts.txt"
POTENTIAL_PRIVKEYS="$OUTDIR/private_keys_markers.txt"
SUMMARY="$OUTDIR/summary.txt"

# Clear outputs
> "$URLS" > "$API_ENDPOINTS" > "$KEYS" > "$FIREBASE" > "$CLOUD" > "$SMALI_REF" > "$ALL_STRINGS" > "$POTENTIAL_JWT" > "$POTENTIAL_PRIVKEYS" > "$SUMMARY"

# Patterns (conservative but broad)
RE_URL='https?://[A-Za-z0-9./?&=%:_-]*'
RE_API_ENDPOINT='/api/|/v[0-9]+/|/auth/|/login|/user|/config|/admin|/debug|/internal|/beta|/staging|/sandbox'
# Keys and tokens
RE_GOOGLE_API='AIza[0-9A-Za-z\-_]+'          # Google API key pattern
RE_FIREBASE='firebase(?:io)?|appspot|firebaseio.com|firebaseio'
RE_AWS_KEY='AKIA[0-9A-Z]{16}'               # AWS access key id
RE_AWS_SECRET='([A-Za-z0-9/+=]{40})'        # likely secret (very noisy -> later filter)
RE_STRIPE='(sk_live_|pk_live_|sk_test_|pk_test_)[0-9a-zA-Z]+'  # stripe-ish keys
RE_JWT='([A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_.+/=]*)' # possible JWT or JWT-like
RE_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
RE_CLIENTID='client_id|clientid|oauth_client_id|consumer_key'
RE_PRIVATE_KEY_MARKERS='-----BEGIN (RSA |EC |)PRIVATE KEY-----|-----BEGIN RSA PRIVATE KEY-----|-----BEGIN OPENSSH PRIVATE KEY-----|BEGIN PRIVATE KEY'

# Helper: process a text file with grep quietly
process_text_file() {
  local f="$1"
  # urls
  grep -Eo "$RE_URL" -- "$f" 2>/dev/null || true
  # endpoints
  grep -nE "$RE_API_ENDPOINT" -- "$f" 2>/dev/null || true
  # firebase matches
  grep -niE "$RE_FIREBASE" -- "$f" 2>/dev/null || true
  # google api keys and known key-like strings
  grep -noE "$RE_GOOGLE_API|client_secret|client_id|api_key|apikey|access_token|refresh_token|AUTHORIZATION|authorization|bearer" -- "$f" 2>/dev/null || true
  # aws key patterns
  grep -noE "$RE_AWS_KEY|$RE_STRIPE" -- "$f" 2>/dev/null || true
  # jwt-ish
  grep -Eo "$RE_JWT" -- "$f" 2>/dev/null || true
  # private key markers
  grep -nE "$RE_PRIVATE_KEY_MARKERS" -- "$f" 2>/dev/null || true
}

# Process all files: detect mime via 'file -b --mime-type'
while IFS= read -r file; do
  # skip if empty
  [ -z "$file" ] && continue
  # use file to determine mime
  mime="$(file -b --mime-type -- "$file" 2>/dev/null || echo "application/octet-stream")"
  case "$mime" in
    text/*|application/xml|application/json)
      # text-like - grep directly
      # collect strings for historical reference
      process_text_file "$file" >> "$ALL_STRINGS"
      # specific files to copy directly (google config, manifest)
      case "$file" in
         */google-services.json) cp -f -- "$file" "$OUTDIR/google-services.json" 2>/dev/null || true ;;
         */AndroidManifest.xml) cp -f -- "$file" "$OUTDIR/AndroidManifest.xml" 2>/dev/null || true ;;
      esac
      # extract endpoints lines separately
      grep -niE "$RE_API_ENDPOINT" -- "$file" 2>/dev/null >> "$API_ENDPOINTS" || true
      grep -niE "$RE_FIREBASE" -- "$file" 2>/dev/null >> "$FIREBASE" || true
      ;;
    *)
      # binary or unknown: use strings to extract readable substrings
      # only keep strings >=6 chars to reduce noise
      strings -n 6 -- "$file" 2>/dev/null >> "$ALL_STRINGS"
      ;;
  esac
done < "$TMP_ALL"

# Now run categorization on the aggregated strings file
# Deduplicate and sort for consistent output
sort -u "$ALL_STRINGS" -o "$ALL_STRINGS"

# Extract URLs
grep -Eo "$RE_URL" "$ALL_STRINGS" | sort -u > "$URLS" || true

# Extract endpoints (context lines)
grep -niE "$RE_API_ENDPOINT" "$ALL_STRINGS" | sort -u > "$API_ENDPOINTS" || true

# Firebase matches
grep -niE "$RE_FIREBASE" "$ALL_STRINGS" | sort -u > "$FIREBASE" || true

# Cloud storage patterns
grep -niE 's3\.amazonaws\.com|storage\.googleapis\.com|blob\.core\.windows\.net|digitaloceanspaces.com|static\.hosting' "$ALL_STRINGS" | sort -u > "$CLOUD" || true

# Google API keys
grep -Eo "$RE_GOOGLE_API" "$ALL_STRINGS" | sort -u >> "$KEYS" || true

# AWS keys
grep -Eo "$RE_AWS_KEY" "$ALL_STRINGS" | sort -u >> "$KEYS" || true

# Stripe-ish keys
grep -Eo "$RE_STRIPE" "$ALL_STRINGS" | sort -u >> "$KEYS" || true

# Generic suspicious keywords (context)
grep -niE 'api_key|apikey|client_secret|client_secret|client_id|token|access_token|refresh_token|authorization|bearer|secret|private_key|password' "$ALL_STRINGS" | sort -u >> "$KEYS" || true

# JWT-like strings detection (heuristic: three dot-separated base64url-ish parts)
# Filter short values by length >= 20 to reduce false positives
grep -Eo '[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}' "$ALL_STRINGS" | awk 'length($0)>=20' | sort -u > "$POTENTIAL_JWT" || true

# Private key markers
grep -nE "$RE_PRIVATE_KEY_MARKERS" "$ALL_STRINGS" | sort -u > "$POTENTIAL_PRIVKEYS" || true

# Smali references (if present)
if [ -d "${APKD}/smali" ]; then
  grep -RniE 'http|https|token|secret|key|endpoint|auth|api_key|client_id|client_secret' -- "${APKD}/smali" > "$SMALI_REF" 2>/dev/null || true
fi

# Cloud storage list - (also check buckets inside urls)
grep -Eo '([A-Za-z0-9.-]+)\.(?:s3\.amazonaws\.com|storage\.googleapis\.com|appspot\.com|firebaseio.com|cloudfront.net)' "$ALL_STRINGS" | sort -u > "$CLOUD" || true

# Final dedupe for keys file
sort -u "$KEYS" -o "$KEYS" || true

# Produce short summary
{
  echo "Recon summary for: $APK"
  echo "Output dir: $OUTDIR"
  echo ""
  echo "Counts:"
  echo "  All distinct extracted strings: $(wc -l < "$ALL_STRINGS" | tr -d ' ')"
  echo "  URLs: $(wc -l < "$URLS" | tr -d ' ')"
  echo "  API-like endpoints: $(wc -l < "$API_ENDPOINTS" | tr -d ' ')"
  echo "  Firebase references: $(wc -l < "$FIREBASE" | tr -d ' ')"
  echo "  Cloud-related matches: $(wc -l < "$CLOUD" | tr -d ' ')"
  echo "  Candidate keys/tokens (raw matches): $(wc -l < "$KEYS" | tr -d ' ')"
  echo "  Potential JWT-like strings: $(wc -l < "$POTENTIAL_JWT" | tr -d ' ')"
  echo "  Private key markers found: $(wc -l < "$POTENTIAL_PRIVKEYS" | tr -d ' ')"
  echo ""
  echo "Recommendations:"
  echo " - Inspect $OUTDIR/google-services.json and $OUTDIR/AndroidManifest.xml if present."
  echo " - Manually review $KEYS and $POTENTIAL_JWT for false positives before testing."
  echo " - Test firebase/hosting/storage URLs (but only if in-scope)."
  echo " - If you want, run jq on google-services.json for structured values."
} > "$SUMMARY"

# Print only the summary to the terminal
cat "$SUMMARY"

# End
exit 0
