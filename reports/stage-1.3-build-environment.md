---
title: "[Stage 1.3] Build Environment"
type: validation
estimated_time: 2 hours (plus ~30–90 min for the validation build)
date_generated: 2026-05-29
---

## Task: What the human must do

Run the provided bootstrap script to install Docker and host tooling and clone
HEADS, then validate the toolchain with a reference build. The script performs
all installs/clone; the human runs the long reference build (the agent and the
script never execute builds).

BOARD: both | RISK: Low

## Prerequisites
- [ ] Debian 12 or Ubuntu 22.04 workstation
- [ ] `sudo`/root access for package installation
- [ ] >= 40 GB free disk space for build artifacts
- [ ] Internet access (to reach apt mirrors, PyPI, and GitHub)
- [ ] Script present: `boards/scripts/setup-build-env.sh`

## Procedure

### Step 1: Preview the bootstrap actions (optional but recommended)
Do: Run a dry-run to see exactly what will happen without making changes.
```bash
./boards/scripts/setup-build-env.sh --dry-run
```
Expected: Each step prints the command it would run, prefixed with `$`.
Verify: No package is installed yet — `command -v docker` still reflects prior state.
If fails: Ensure the script is executable (`chmod +x boards/scripts/setup-build-env.sh`).

### Step 2: Run the bootstrap
Do:
```bash
./boards/scripts/setup-build-env.sh
```
Expected: Installs `docker.io flashrom git build-essential curl unzip python3
python3-pip`, installs `me_cleaner`, enables Docker, adds you to the `docker`
group, and clones HEADS to `~/heads` (override with `--heads-dir DIR`).
Verify: Script ends with "Stage 1.3 build-environment bootstrap complete."
If fails: Re-read the failing apt/pip line; fix connectivity or package names
and re-run (the script is idempotent).

### Step 3: Apply docker group membership
Do:
```bash
newgrp docker   # or log out and back in
docker run --rm hello-world
```
Expected: Docker runs the container without `sudo`.
Verify: Output contains "Hello from Docker!".
If fails: Confirm `usermod -aG docker $USER` ran and that you re-logged in.

### Step 4: Validate the toolchain with the reference build
Do:
```bash
cd ~/heads
make BOARD=x230-flash
```
Expected: HEADS spawns its Docker build container and produces
`build/x230-flash/coreboot.rom`.
Verify:
```bash
ls -lh build/x230-flash/coreboot.rom
```
→ a ROM file of a few MB exists.
If fails: Capture the first error; most early failures are Docker permission or
disk-space issues already checked in Steps 2–3.

### Step 5: Confirm tooling versions
Do:
```bash
docker --version
flashrom --version
python3 -c "import me_cleaner; print('me_cleaner OK')"
```
Expected: Versions print and `me_cleaner OK` is shown.
Note: `ifdtool`/`cbfstool` are built inside the HEADS coreboot tree, not via
apt; they become available under the build tree after Step 4.

## Success Criteria
- [ ] Docker installed and usable without sudo (`docker run hello-world` works)
- [ ] `flashrom` and `me_cleaner` installed on the host
- [ ] HEADS cloned (default `~/heads`)
- [ ] `make BOARD=x230-flash` produces `build/x230-flash/coreboot.rom`
- [ ] >= 40 GB free disk confirmed by the script

## Next Steps
1. Record tool versions and the HEADS commit in `reports/stage-1.3-results.md`
2. Mark ROADMAP.md Stage 1.3 items complete
3. Continue to Stage 1.4 (Reference Material) — run
   `boards/scripts/fetch-reference-material.sh`; see
   `reports/stage-1.4-reference-material.md`

## Troubleshooting
**Problem:** `permission denied` talking to the Docker socket →
**Fix:** Run `newgrp docker` or log out/in so the `docker` group applies.
**Problem:** `pip3 install me_cleaner` blocked by PEP 668 (externally managed) →
**Fix:** The script falls back to `--break-system-packages`; alternatively
install in a virtualenv.
**Problem:** Reference build runs out of disk →
**Fix:** Free space or re-run with `--min-disk-gb` pointed at a larger volume
via `--heads-dir`.
