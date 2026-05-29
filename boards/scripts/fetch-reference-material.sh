#!/usr/bin/env bash
#
# fetch-reference-material.sh — Stage 1.4 Reference Material Collection for the
# Dell Chromebook 11 (wolf) and Dell Chromebook 13 (lulu) HEADS port.
#
# ROADMAP: Stage 1.4 - Reference Material Collection
#
# This script AUTOMATES ACQUISITION ONLY. It downloads:
#   - The official ChromeOS recovery image(s) for wolf/lulu, discovered from
#     Google's published recovery.conf manifest, and verifies their checksums.
#   - Broadwell/Haswell CPU microcode source (acquisition pointer + optional
#     git fetch of Intel's public microcode data files).
#
# It NEVER fabricates blob content. Stock firmware (bios.bin) is extracted from
# the recovery image by a human following reports/stage-1.4-reference-material.md
# (extraction requires loop-mounting the rootfs, a privileged runtime step that
# is intentionally left out of this script).
#
# USAGE:
#   ./fetch-reference-material.sh [--board wolf|lulu|both] [--out DIR]
#                                 [--with-microcode] [--dry-run]
#
# Re-running is safe: already-downloaded, checksum-verified files are skipped.

set -euo pipefail

# ---- Defaults --------------------------------------------------------------
BOARD="both"
OUT_DIR="${OUT_DIR:-$PWD/reference-material}"
RECOVERY_CONF_URL="https://dl.google.com/dl/edgedl/chromeos/recovery/recovery.conf"
MICROCODE_REPO="https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files.git"
WITH_MICROCODE=0
DRY_RUN=0

# Board -> ChromeOS recovery image codename(s) used in recovery.conf.
WOLF_CODENAME="wolf"
LULU_CODENAME="lulu"

# ---- Logging helpers -------------------------------------------------------
log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

# ---- Argument parsing ------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)          BOARD="$2"; shift 2 ;;
    --out)            OUT_DIR="$2"; shift 2 ;;
    --with-microcode) WITH_MICROCODE=1; shift ;;
    --dry-run)        DRY_RUN=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) err "Unknown argument: $1"; exit 2 ;;
  esac
done

case "$BOARD" in
  wolf|lulu|both) ;;
  *) err "--board must be one of: wolf, lulu, both"; exit 2 ;;
esac

[ "$DRY_RUN" -eq 1 ] && warn "DRY-RUN MODE: downloads will be skipped."

for tool in curl grep awk sha1sum; do
  command -v "$tool" >/dev/null 2>&1 || { err "Required tool '$tool' not found."; exit 1; }
done

mkdir -p "$OUT_DIR"

# ---- recovery.conf parser --------------------------------------------------
# Google's recovery.conf is a series of blank-line-separated stanzas. Each
# stanza contains name=value lines including 'file=' (codename hint), 'url='
# and 'sha1='. We locate the stanza whose url/name matches the codename.
CONF_CACHE="$OUT_DIR/recovery.conf"

fetch_recovery_conf() {
  log "Fetching recovery manifest: $RECOVERY_CONF_URL"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "dry-run: skipping recovery.conf download"
    return 0
  fi
  curl -fsSL "$RECOVERY_CONF_URL" -o "$CONF_CACHE"
  ok "Saved manifest to $CONF_CACHE"
}

# Extract the url= and sha1= for a given codename from recovery.conf.
# Prints "<url>\t<sha1>" for each matching stanza.
lookup_image() {
  local codename="$1"
  [ -r "$CONF_CACHE" ] || { warn "recovery.conf not available; cannot look up $codename"; return 1; }
  awk -v RS='' -v code="$codename" '
    $0 ~ ("(^|[^a-z])" code "([^a-z]|$)") {
      url=""; sha=""
      n=split($0, lines, "\n")
      for (i=1; i<=n; i++) {
        if (lines[i] ~ /^url=/)  { sub(/^url=/,  "", lines[i]); url=lines[i] }
        if (lines[i] ~ /^sha1=/) { sub(/^sha1=/, "", lines[i]); sha=lines[i] }
      }
      if (url != "") print url "\t" sha
    }
  ' "$CONF_CACHE"
}

download_and_verify() {
  local url="$1" sha1="$2" dest_dir="$3"
  local fname; fname="$(basename "${url%%\?*}")"
  local dest="$dest_dir/$fname"

  if [ -f "$dest" ] && [ -n "$sha1" ]; then
    if echo "$sha1  $dest" | sha1sum -c - >/dev/null 2>&1; then
      ok "Already present and verified: $fname"
      return 0
    fi
    warn "Existing $fname failed checksum; re-downloading."
  fi

  log "Downloading $fname"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "dry-run: would download $url -> $dest"
    return 0
  fi
  curl -fL --retry 3 "$url" -o "$dest"

  if [ -n "$sha1" ]; then
    if echo "$sha1  $dest" | sha1sum -c - >/dev/null 2>&1; then
      ok "Verified SHA1 for $fname"
    else
      err "SHA1 mismatch for $fname (expected $sha1). Removing corrupt download."
      rm -f "$dest"
      return 1
    fi
  else
    warn "No SHA1 published for $fname; record the hash manually after extraction."
  fi
}

fetch_board() {
  local board="$1" codename="$2"
  local dest_dir="$OUT_DIR/$board"
  local board_failed=0
  mkdir -p "$dest_dir"
  log "=== Reference material for $board (codename: $codename) ==="

  local matches; matches="$(lookup_image "$codename" || true)"
  if [ -z "$matches" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      warn "No recovery image preview available for '$codename' (recovery.conf not cached)."
      return 0
    fi
    err "No recovery image found for '$codename' in recovery.conf."
    err "Verify the codename mapping or recovery.conf contents before continuing."
    return 1
  fi

  while IFS="$(printf '\t')" read -r url sha1; do
    [ -z "$url" ] && continue
    if ! download_and_verify "$url" "$sha1" "$dest_dir"; then
      err "Download or verification failed for $url"
      board_failed=1
    fi
  done < <(printf '%s\n' "$matches")

  return "$board_failed"
}

# ---- Microcode acquisition -------------------------------------------------
fetch_microcode() {
  local mc_dir="$OUT_DIR/microcode"
  log "=== Intel microcode source ==="
  log "wolf needs Haswell-ULT 06-45-01; lulu needs Broadwell-U 06-3d-04."
  if [ "$WITH_MICROCODE" -eq 0 ]; then
    warn "Skipping microcode fetch (pass --with-microcode to enable)."
    warn "Source: $MICROCODE_REPO (pin a release tag and record its SHA256)."
    return 0
  fi
  command -v git >/dev/null 2>&1 || { err "git required for --with-microcode"; return 1; }
  if [ -d "$mc_dir/.git" ]; then
    ok "Microcode repo already cloned at $mc_dir (not auto-updating)."
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "dry-run: would clone $MICROCODE_REPO -> $mc_dir"
    return 0
  fi
  git clone "$MICROCODE_REPO" "$mc_dir"
  ok "Microcode source cloned. Pin a release tag before using in a build."
}

# ---- Main ------------------------------------------------------------------
fetch_recovery_conf

case "$BOARD" in
  wolf) fetch_board wolf "$WOLF_CODENAME" || exit 1 ;;
  lulu) fetch_board lulu "$LULU_CODENAME" || exit 1 ;;
  both)
    fetch_board wolf "$WOLF_CODENAME" || exit 1
    fetch_board lulu "$LULU_CODENAME" || exit 1
    ;;
esac

fetch_microcode

cat <<EOF

Acquisition step complete. Downloads (if any) are under: $OUT_DIR

Manual follow-up (privileged runtime — see reports/stage-1.4-reference-material.md):
  1. Unzip each recovery image (.zip -> chromiumos_image.bin).
  2. Loop-mount partition 3 (ROOT-A) and locate
       /usr/sbin/chromeos-firmwareupdate
  3. Run 'chromeos-firmwareupdate --sb_extract <dir>' to obtain bios.bin.
  4. Inspect with 'ifdtool -d bios.bin' and record region offsets.
  5. Record SHA256 of every extracted/pinned blob in build metadata.
EOF
