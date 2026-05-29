#!/usr/bin/env bash
#
# setup-build-env.sh — Stage 1.3 Build Environment bootstrap for the
# Dell Chromebook 11 (wolf) and Dell Chromebook 13 (lulu) HEADS port.
#
# ROADMAP: Stage 1.3 - Build Environment
#
# This script prepares a Debian 12 / Ubuntu 22.04 workstation for HEADS
# development. It installs Docker and the SPI/host tooling, clones the
# upstream HEADS tree, and verifies that enough disk space is available.
#
# SAFETY:
#   - This script only installs packages and clones a public repository.
#   - It NEVER flashes hardware, modifies firmware, or runs a HEADS build.
#   - The toolchain-validation build (`make BOARD=x230-flash`) is a long,
#     resource-heavy operation and is intentionally left for a human to run
#     (see reports/stage-1.3-build-environment.md). This script only prints
#     the exact command to use.
#
# USAGE:
#   ./setup-build-env.sh [--heads-dir DIR] [--min-disk-gb N] [--dry-run]
#
# Re-running is safe: every step is idempotent.

set -euo pipefail

# ---- Defaults --------------------------------------------------------------
HEADS_DIR="${HEADS_DIR:-$HOME/heads}"
HEADS_REPO="https://github.com/linuxboot/heads.git"
MIN_DISK_GB="${MIN_DISK_GB:-40}"
DRY_RUN=0

# ---- Logging helpers -------------------------------------------------------
log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

run() {
  # Echo every command; only execute when not in dry-run mode.
  printf '    $ %s\n' "$*"
  if [ "$DRY_RUN" -eq 0 ]; then
    "$@"
  fi
}

# ---- Argument parsing ------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --heads-dir)    HEADS_DIR="$2"; shift 2 ;;
    --min-disk-gb)  MIN_DISK_GB="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) err "Unknown argument: $1"; exit 2 ;;
  esac
done

[ "$DRY_RUN" -eq 1 ] && warn "DRY-RUN MODE: no changes will be made."

# ---- sudo helper -----------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    err "This script needs root for package installation. Install sudo or run as root."
    exit 1
  fi
fi

# ---- 1. OS sanity check ----------------------------------------------------
log "Checking host operating system"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${VERSION_ID:-}" in
    debian:12*|ubuntu:22.04*)
      ok "Supported host detected: ${PRETTY_NAME:-$ID $VERSION_ID}" ;;
    debian:*|ubuntu:*)
      warn "Untested ${ID} ${VERSION_ID}; the ROADMAP targets Debian 12 / Ubuntu 22.04. Continuing." ;;
    *)
      warn "Non-Debian-family host (${ID:-unknown}); apt-based steps may fail." ;;
  esac
else
  warn "/etc/os-release missing; cannot identify the host distribution."
fi

if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get not found. This bootstrap script only supports Debian/Ubuntu hosts."
  exit 1
fi

# ---- 2. Disk space check ---------------------------------------------------
log "Verifying at least ${MIN_DISK_GB} GB free for build artifacts"
PARENT_DIR="$(dirname "$HEADS_DIR")"
DISK_CHECK_DIR="$PARENT_DIR"
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$PARENT_DIR"
elif [ ! -d "$PARENT_DIR" ]; then
  while [ -n "$DISK_CHECK_DIR" ] && [ ! -d "$DISK_CHECK_DIR" ] && [ "$DISK_CHECK_DIR" != "/" ]; do
    DISK_CHECK_DIR="$(dirname "$DISK_CHECK_DIR")"
  done
  warn "dry-run: $PARENT_DIR does not exist; checking free space at $DISK_CHECK_DIR instead."
fi
AVAIL_GB="$(df -BG --output=avail "$DISK_CHECK_DIR" | tail -1 | tr -dc '0-9')"
if [ "${AVAIL_GB:-0}" -lt "$MIN_DISK_GB" ]; then
  err "Only ${AVAIL_GB} GB free at ${DISK_CHECK_DIR}; HEADS needs >= ${MIN_DISK_GB} GB."
  exit 1
fi
ok "${AVAIL_GB} GB free at ${DISK_CHECK_DIR}"

# ---- 3. Package installation ----------------------------------------------
# docker.io      : HEADS uses Docker for reproducible builds.
# flashrom       : reads/writes SPI flash (used in Stage 2+).
# git, build-essential, curl, unzip : build prerequisites and helpers.
# python3, python3-pip : me_cleaner runtime.
#
# Note: ifdtool and cbfstool are NOT distro packages. They are built from the
# coreboot `util/` tree, which the HEADS Docker build produces automatically.
# This script installs me_cleaner separately below.
APT_PACKAGES=(docker.io flashrom git build-essential curl unzip python3 python3-pip)

log "Installing host packages: ${APT_PACKAGES[*]}"
run $SUDO apt-get update
run $SUDO apt-get install -y "${APT_PACKAGES[@]}"
ok "Host packages installed"

# ---- 4. me_cleaner ---------------------------------------------------------
# me_cleaner is required for the lulu ME-neutralization pipeline (Stage 4).
# It is distributed via PyPI / GitHub rather than apt.
log "Installing me_cleaner (Stage 4 dependency)"
if command -v me_cleaner >/dev/null 2>&1 || command -v me_cleaner.py >/dev/null 2>&1; then
  ok "me_cleaner already present"
else
  run $SUDO pip3 install --break-system-packages me_cleaner || \
    run $SUDO pip3 install me_cleaner
  ok "me_cleaner installed"
fi

# ---- 5. Docker service + group --------------------------------------------
log "Enabling Docker service"
if command -v systemctl >/dev/null 2>&1; then
  run $SUDO systemctl enable --now docker || warn "Could not enable docker via systemctl."
fi
if ! id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
  warn "Adding $USER to the 'docker' group; log out/in (or 'newgrp docker') to take effect."
  run $SUDO usermod -aG docker "$USER" || warn "Could not add $USER to docker group."
fi

# ---- 6. Clone HEADS --------------------------------------------------------
log "Cloning HEADS into ${HEADS_DIR}"
if [ -d "$HEADS_DIR/.git" ]; then
  ok "HEADS already cloned at ${HEADS_DIR}; leaving as-is (no auto-pull)."
else
  run git clone "$HEADS_REPO" "$HEADS_DIR"
  ok "HEADS cloned"
fi

# ---- 7. Summary + next steps ----------------------------------------------
ok "Stage 1.3 build-environment bootstrap complete."
cat <<EOF

Next steps (performed by a human — NOT by this script):

  1. Apply the new docker group membership:
       newgrp docker        # or log out and back in

  2. Validate the toolchain with the reference board build:
       cd "${HEADS_DIR}"
       make BOARD=x230-flash
     Expected: build completes and produces build/x230-flash/coreboot.rom

  3. Confirm tooling versions:
       docker --version
       flashrom --version
       python3 -c "import me_cleaner" 2>/dev/null && echo "me_cleaner OK"

See reports/stage-1.3-build-environment.md for the full validation handoff.
EOF
