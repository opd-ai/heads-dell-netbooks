# Unified HEADS Porting Guide: Dell Chromebook 11 (wolf) & Dell Chromebook 13 (lulu)

## Document Purpose

This guide consolidates both ports into a single optimized workflow that maximizes shared effort, parallelizes hardware work, and front-loads the irreversible decisions. Where the boards diverge, instructions are tagged **[wolf]** or **[lulu]**. Untagged steps apply to both.

---

## Target Hardware Identification (Read First)

Codename confusion is the most common cause of bricked Chromebooks during a HEADS port. Verify before procurement:

- **wolf** = Dell Chromebook 11 (model **P22T**, released 2014). Intel Haswell-ULT Celeron 2955U. SPI flash 8 MB.
  - **Not** the Dell Chromebook 11 **3120** (2015). The 3120 is Bay Trail (Celeron N2840) and uses a different codename (`candy` family). It is **out of scope** for this guide; do not buy a 3120 expecting it to work as wolf.
  - Verify the HWID at the ChromeOS recovery screen begins with `WOLF` before proceeding.
- **lulu** = Dell Chromebook 13 7310 (2015). Intel Broadwell-U (i3-5005U / i5-5200U / Celeron 3205U SKUs). SPI flash 8 MB.
  - Verify the HWID begins with `LULU`.

---

## Strategic Approach

The two ports share approximately 70% of the work: build environment, HEADS framework knowledge, TPM 1.2 integration, ath9k Wi-Fi validation, GPG/measured-boot flows, and recovery procedures. The optimized strategy is to **bring up wolf first** as the simpler, lower-risk reference, then **fork the working configuration to lulu** while adding FSP and ME-neutering work. This minimizes wasted effort if blockers surface early.

### Phased Strategy Overview

| Stage | Boards | Goal |
|---|---|---|
| 1. Foundation | Both | Procurement, environment, baseline knowledge |
| 2. Hardware prep | Both (parallel) | Backups, programmer setup, WP access |
| 3. wolf bring-up | wolf | First working HEADS ROM as reference |
| 4. lulu fork | lulu | Adapt wolf work + add FSP/ME pipeline |
| 5. Validation | Both | TPM, measured boot, blob audits |
| 6. Hardening | Both | Reliability, reproducibility, recovery |
| 7. Release | Both | Documentation, upstream submission |

---

## Stage 1: Foundation (Both Boards)

> **Status: deliverables generated.** Setup/acquisition scripts under
> `boards/scripts/` and execution handoffs under `reports/stage-1.*.md`.
> Items are marked complete once the corresponding script/handoff exists;
> humans execute the runtime steps (purchases, installs, builds, downloads)
> by following each handoff and record outcomes in `reports/stage-1.*-results.md`.

### 1.1 Knowledge Prerequisites
> Handoff: `reports/stage-1.1-knowledge-prerequisites.md` (human research/onboarding task).
- [x] Read HEADS architecture docs at `https://osresearch.net`
- [x] Read coreboot porting guide for Google boards
- [x] Review `boards/x230-flash/` as the canonical TPM 1.2 reference
- [x] Review existing `mrchromebox` coreboot scripts for wolf and lulu (reference only — not used in HEADS build)
- [x] Join HEADS community channels (Matrix `#heads:matrix.org`); announce intent to maintainers

### 1.2 Procurement Checklist
> Handoff: `reports/stage-1.2-procurement.md` (hardware purchase + HWID verification).

**Devices:**
- [x] **[wolf]** 1× Dell Chromebook 11 P22T (2014) — verify `WOLF` HWID prefix
- [x] **[wolf]** 1× backup unit (highly recommended)
- [x] **[lulu]** 1× Dell Chromebook 13 7310 — verify `LULU` HWID prefix; any RAM SKU acceptable (4–8 GB)
- [x] **[lulu]** 1× backup unit (highly recommended)

**Wi-Fi:**
- [x] **[wolf]** Confirm onboard Atheros AR9462 (mini-PCIe / soldered variant depending on revision) — no swap if already ath9k; if Marvell-based variant is encountered, replace with mini-PCIe AR5B22 (AR9462)
- [x] **[lulu]** lulu uses **M.2 2230 key A/E**. Replacement options (validate the specific model in ChromeOS first):
  - Atheros/QCA QCNFA222 (AR9462 in M.2 2230) — uncommon but exists as OEM Lenovo/HP pulls
  - Any verified ath9k M.2 2230 card known to enumerate on Broadwell Chromebooks
  - Note: stock card is Intel Dual Band Wireless-AC 7260/7265 and **must** be replaced for blob-free operation

**Tools:**
- [x] CH341A USB programmer (or Raspberry Pi with SPI)
- [x] Pomona 5250 SOIC-8 test clip (avoid clone clips — they cause flaky reads)
- [x] 3.3V regulator mod for CH341A (the stock 5V will damage the flash chip over time)
- [x] 1.8V level shifter (not strictly needed for these boards, but useful for future ports)
- [x] Precision screwdriver set (Phillips #00, Torx T5)
- [x] Plastic spudgers and pry tools
- [x] Anti-static mat and wrist strap
- [x] HOTP USB security key with OpenPGP smartcard (Nitrokey Pro 2 or Librem Key) — needed in Stage 5

### 1.3 Build Environment
> Script: `boards/scripts/setup-build-env.sh` · Handoff: `reports/stage-1.3-build-environment.md`
- [x] Linux workstation (Debian 12 or Ubuntu 22.04 recommended)
- [x] Install Docker: `apt install docker.io` (HEADS uses Docker for reproducible builds)
- [x] Clone HEADS: `git clone https://github.com/linuxboot/heads.git`
- [x] Run `make BOARD=x230-flash` once to validate toolchain works
- [x] Allocate ≥40 GB disk space for build artifacts
- [x] Install host tools: `flashrom`, `ifdtool`, `cbfstool`, `me_cleaner`

### 1.4 Reference Material Collection
> Script: `boards/scripts/fetch-reference-material.sh` · Handoff: `reports/stage-1.4-reference-material.md`
- [x] Download stock recovery images for both boards from Google's recovery image server
- [x] Extract recovery images to obtain stock RW firmware (`bios.bin`) for analysis with `ifdtool -d`
- [x] Pull mainline coreboot tree; verify `google/wolf` and `google/lulu` build out-of-tree against recent commits
- [x] Download latest microcode from Intel:
  - **[wolf]** Haswell-ULT family `06-45-01` (Celeron 2955U)
  - **[lulu]** Broadwell-U family `06-3d-04` (i3/i5 5xxxU and Celeron 3205U)

---

## Stage 2: Hardware Preparation (Parallel — Both Boards)

Perform these steps for each device. Working on both in parallel saves time since they share procedures.

### 2.1 Disassembly & Discovery
- [ ] Photograph each step of disassembly for reassembly reference
- [ ] **[wolf]** Remove bottom cover (Phillips screws, plus several hidden under rubber feet)
- [ ] **[lulu]** Remove bottom cover (multiple Torx T5 screws + clips)
- [ ] Locate SPI flash chip; verify package (SOIC-8) and part number
- [ ] **[wolf]** Confirm 8 MB Winbond W25Q64 (or compatible 25-series 8 MB part)
- [ ] **[lulu]** Confirm 8 MB Winbond W25Q64 (or compatible 25-series 8 MB part)
- [ ] Locate write-protect screw (refer to mrchromebox.tech for photos)
- [ ] **[wolf]** WP screw on motherboard near SPI flash (under keyboard or accessible from bottom depending on revision)
- [ ] **[lulu]** WP screw on motherboard near RAM, marked on PCB silkscreen
- [ ] Document all screw locations and types

### 2.2 Firmware Backup (Critical — Do Not Skip)
- [ ] Disconnect battery before connecting SPI clip
- [ ] Connect SOIC-8 clip with correct pin-1 orientation
- [ ] Read full SPI flash → `stock_<board>_read1.rom`
- [ ] Read full SPI flash again → `stock_<board>_read2.rom`
- [ ] Verify: `sha256sum stock_<board>_read*.rom` — both must match
- [ ] If they don't match, re-seat clip and re-read until 3 consecutive reads agree
- [ ] Run `ifdtool -d stock_<board>_read1.rom` to confirm a valid descriptor and inspect actual region layout (do **not** assume regions; record what is present)
- [ ] Copy verified backup to USB stick + cloud storage + offline drive
- [ ] Test restore: flash `stock_<board>_read1.rom` back, boot ChromeOS, verify normal operation
- [ ] **Do not proceed to any modification stage until restore is proven**

### 2.3 ChromeOS Baseline Verification (Sanity Check)
- [ ] Enable developer mode (Esc + Refresh + Power → Ctrl+D)
- [ ] In crosh shell, verify TPM: `tpm_version` (expect Infineon SLB 96xx, family 1.2)
- [ ] Verify Wi-Fi works at this baseline
- [ ] **[lulu]** Swap Intel 7260/7265 → Atheros M.2 card; reboot; verify Wi-Fi enumerates and connects in ChromeOS before any firmware modification
- [ ] Document ChromeOS firmware version (`chrome://system` → `firmware_version`) for reference

### 2.4 Write Protect Removal
- [ ] Remove WP screw from each board
- [ ] Store WP screws in labeled containers (you will reinstall later)
- [ ] Verify WP defeated: `flashrom -p ch341a_spi --wp-status` should report disabled
- [ ] Reassemble enough to power on for next stages

---

## Stage 3: wolf Bring-up (Reference Build)

The wolf port comes first because Haswell Chromebooks have a minimal ME footprint and no FSP requirement in coreboot, validating the HEADS build pipeline before adding Broadwell complexity.

### 3.1 Inspect the Stock Descriptor (Do Not Skip)
- [ ] Run `ifdtool -d stock_wolf_read1.rom`. Haswell Chromebooks **do** include an ME region in the descriptor; Google ships a minimal ME image but the region is not absent.
- [ ] Record the exact region offsets and sizes for descriptor, ME, GbE (if any), and BIOS — these drive the HEADS / coreboot IFD layout.
- [ ] Extract regions: `ifdtool -x stock_wolf_read1.rom` produces `flashregion_*.bin` files.

### 3.2 HEADS Board Configuration
- [ ] Create directory `boards/wolf/`
- [ ] Copy `boards/x230-flash/x230-flash.config` → `boards/wolf/wolf.config`
- [ ] Edit the HEADS board config (HEADS-side variables only):
  - [ ] Set `CONFIG_TARGET_ARCH=x86`
  - [ ] Set `CONFIG_COREBOOT=y`, `CONFIG_COREBOOT_VERSION=<pinned-tag>`
  - [ ] Set `CONFIG_COREBOOT_CONFIG_FILE=config/coreboot-wolf.config`
  - [ ] Set `CONFIG_LINUX_CONFIG=config/linux-wolf.config`
  - [ ] Set `CONFIG_TPM=y` (HEADS will select the TPM 1.2 path automatically since this is a pre-Skylake board)
- [ ] Create the coreboot defconfig fragment `config/coreboot-wolf.config` with the coreboot-side symbols:
  - [ ] `CONFIG_VENDOR_GOOGLE=y`
  - [ ] `CONFIG_BOARD_GOOGLE_WOLF=y`
  - [ ] `CONFIG_PAYLOAD_LINUX=y`
  - [ ] `CONFIG_INCLUDE_MICROCODE=y` with `06-45-01` blob path
  - [ ] IFD layout matching the stock descriptor (ME region preserved with stock minimal ME by default)
- [ ] Pin coreboot revision in `modules/coreboot` (`CONFIG_COREBOOT_VERSION`) to a known-good commit supporting wolf

### 3.3 Linux Kernel Configuration (Blob-Free)
- [ ] Copy x230 kernel config as base into `config/linux-wolf.config`
- [ ] Required drivers: `i915` (Haswell), `ath9k`, `tpm_tis`, `xhci_hcd`, `ehci_hcd`, `ahci`, `i2c_hid`, `snd_hda_intel`
- [ ] Hard-disable: `CONFIG_EXTRA_FIRMWARE=""`, all `iwlwifi`, all `mwlwifi`, GuC/HuC paths
- [ ] Disable: `CONFIG_FW_LOADER_USER_HELPER`, `CONFIG_FW_LOADER_COMPRESS` (force no firmware)
- [ ] Add framebuffer console support for early HEADS GUI (`CONFIG_FB_EFI` not applicable; use `CONFIG_FRAMEBUFFER_CONSOLE` over the coreboot linear FB)
- [ ] Build kernel; verify size fits within HEADS CBFS budget

### 3.4 First Build
- [ ] Run `make BOARD=wolf` in HEADS top-level (HEADS will spawn the Docker build container)
- [ ] Address build errors iteratively (most will be coreboot config mismatches)
- [ ] Verify final ROM size ≤ 8 MB
- [ ] Compute SHA256 of resulting ROM; record it

### 3.5 Blob Audit Pre-Flash
- [ ] `find build/wolf/ -name '*.fw' -o -name '*.bin' -o -name '*.ucode'` — review every match
- [ ] Confirm only legitimate microcode, the stock minimal ME (in its descriptor region), and CPU bootblock are present
- [ ] No iwlwifi, mwlwifi, ath10k, GuC, HuC, audio DSP firmware in CBFS or initrd
- [ ] `cbfstool build/wolf/coreboot.rom print` to confirm CBFS contents
- [ ] Document audit results

### 3.6 First Flash
- [ ] Disconnect battery, attach SOIC-8 clip
- [ ] Flash: `flashrom -p ch341a_spi -w build/wolf/coreboot.rom`
- [ ] Verify with read-back: `flashrom -p ch341a_spi -v build/wolf/coreboot.rom`
- [ ] Reconnect battery, power on
- [ ] If no POST: re-flash backup; debug; do not panic

### 3.7 Bring-up Validation
- [ ] HEADS GUI renders on internal display
- [ ] Keyboard input works
- [ ] Trackpad responsive
- [ ] All USB ports detect devices
- [ ] HDMI output functional
- [ ] Internal SSD detected
- [ ] Wi-Fi loads `ath9k` cleanly
- [ ] **Critical:** `dmesg | grep -i firmware` shows zero firmware load attempts (microcode-early load is acceptable and not flagged here)
- [ ] TPM 1.2 detected: `/dev/tpm0` exists, `tpm_version` reports family 1.2

---

## Stage 4: lulu Fork & FSP/ME Pipeline

Once wolf is working, fork the configuration and add lulu-specific complexity: Broadwell FSP, ME neutralization, and an M.2 Wi-Fi swap that has already been proven in Stage 2.3.

### 4.1 Inspect the Stock Descriptor
- [ ] Run `ifdtool -d stock_lulu_read1.rom` and record region offsets
- [ ] Extract regions: `ifdtool -x stock_lulu_read1.rom`
- [ ] Identify `flashregion_2_intel_me.bin` (Broadwell ME 10.x)

### 4.2 ME Neutralization
- [ ] Run: `me_cleaner.py -S -t -r -O me_cleaned.bin flashregion_2_intel_me.bin`
  - `-S` sets the HAP / AltMeDisable bit
  - `-t` truncates the ME image
  - `-r` relocates the FTPR partition
- [ ] Verify cleaned ME ~90 KB; ROMP and BUP partitions retained
- [ ] Sanity check the cleaned image: `me_cleaner.py -c me_cleaned.bin` (`-c` runs structural checks without modifying)
- [ ] Verify HAP bit set in the **descriptor** after assembling the full ROM by running `ifdtool -d <final-rom>` and inspecting the `HAP` / `AltMeDisable` field
- [ ] Place cleaned ME at `blobs/lulu/me.bin` in the HEADS tree

### 4.3 FSP Blob Acquisition
- [ ] Obtain Broadwell FSP from Intel's `BroadwellFspBinPkg` (release tag pinned)
- [ ] Place at `blobs/lulu/fsp.bin`
- [ ] Document FSP version and SHA256 in `boards/lulu/README.md`

### 4.4 Microcode Update
- [ ] Pull Broadwell microcode `06-3d-04` from `intel-microcode` package (pin a specific upstream revision)
- [ ] Place in coreboot's microcode CBFS path
- [ ] Document microcode revision used

### 4.5 HEADS Board Configuration
- [ ] Create `boards/lulu/` from a copy of `wolf/`
- [ ] Edit the HEADS board config:
  - [ ] Set `CONFIG_COREBOOT_CONFIG_FILE=config/coreboot-lulu.config`
  - [ ] Set `CONFIG_LINUX_CONFIG=config/linux-lulu.config`
- [ ] Create coreboot defconfig fragment `config/coreboot-lulu.config`:
  - [ ] `CONFIG_VENDOR_GOOGLE=y`
  - [ ] `CONFIG_BOARD_GOOGLE_LULU=y`
  - [ ] `CONFIG_FSP_USE_REPO=n`
  - [ ] `CONFIG_FSP_FILE="/path/to/blobs/lulu/fsp.bin"`
  - [ ] `CONFIG_HAVE_ME_BIN=y`, `CONFIG_ME_BIN_PATH="blobs/lulu/me.bin"`
  - [ ] `CONFIG_HAVE_IFD_BIN=y`, `CONFIG_IFD_BIN_PATH="blobs/lulu/descriptor.bin"` (use a descriptor with HAP set)
  - [ ] `CONFIG_INCLUDE_MICROCODE=y` referencing `06-3d-04` blob
  - [ ] IFD layout includes ME region (now neutered)

### 4.6 Linux Kernel for lulu
- [ ] Fork wolf kernel config to `config/linux-lulu.config`
- [ ] Add Broadwell-specific quirks (none usually needed for `i915`)
- [ ] Verify same blob-free constraints maintained (no `iwlwifi`, no GuC/HuC, no audio DSP firmware)
- [ ] Add backlit keyboard and laptop-platform drivers (`dell_laptop`, `dell_wmi`)

### 4.7 Build & Flash
- [ ] `make BOARD=lulu`
- [ ] Repeat blob audit (Stage 3.5)
- [ ] External flash via SPI clip
- [ ] Verify POST + HEADS GUI

### 4.8 ME-Specific Validation
- [ ] Boot into HEADS recovery shell
- [ ] Run `intelmetool -m` — confirm ME is unresponsive (HECI does not respond to MEI commands)
- [ ] Verify HECI device behavior: `lspci -nn | grep -i mei` should show device present but `mei_me` driver should fail to communicate
- [ ] Re-run `ifdtool -d` on a re-read of the live flash and confirm HAP bit remains set
- [ ] Check power consumption baseline (idle wattmeter reading) — neutered ME often reduces idle draw

### 4.9 lulu Bring-up Validation
- [ ] All Stage 3.7 checks repeated for lulu
- [ ] Atheros Wi-Fi (post-swap) loads cleanly with `ath9k`
- [ ] Backlit keyboard functional
- [ ] 1080p IPS display correct resolution (lulu has FHD on most SKUs; verify EDID handling)
- [ ] **Critical:** zero non-microcode userspace firmware loads in `dmesg`

---

## Stage 5: TPM & Measured Boot (Both Boards)

### 5.1 TPM Ownership
- [ ] Take TPM ownership via HEADS GUI
- [ ] Set strong owner password; record in offline password manager
- [ ] Verify PCR values stable across reboots: record PCRs 0–7

### 5.2 HOTP Attestation
- [ ] Initialize HOTP USB key (Nitrokey Pro 2 / Librem Key) using HEADS' `hotp-verification` flow
- [ ] Pair with HEADS via GUI workflow (this writes shared HOTP secret to TPM NVRAM)
- [ ] Test attestation success on clean boot (key shows green LED)
- [ ] **Tamper test:** modify a CBFS file (e.g., re-add a banner string), re-flash, boot — key must show red
- [ ] Restore good ROM, confirm green again

### 5.3 GPG Key Provisioning (Smartcard-Based)

HEADS' standard `/boot` integrity flow uses an **OpenPGP smartcard** (the same Nitrokey/Librem Key device). Signing happens on the target with the smartcard inserted, not on a separate airgapped machine.

- [ ] Generate user GPG key on an **airgapped** machine (best practice — do not generate on the chromebook)
- [ ] Move the GPG **subkeys** onto the OpenPGP smartcard (`keytocard` in `gpg --edit-key`)
- [ ] Keep the offline master key backup on encrypted offline media; destroy or vault the on-disk private key copy
- [ ] Export the public key to a USB stick
- [ ] Import the public key into HEADS via the GUI (this stores it in the ROM's CBFS, requiring a re-flash on first import)
- [ ] On the target, with smartcard inserted, use HEADS' "Update `/boot` checksums and sign" menu entry to sign the kernel + initrd + grub config
- [ ] Verify HEADS validates signatures on subsequent boots and proceeds to kexec

---

## Stage 6: OS Installation (Both Boards)

### 6.1 Distribution Selection
- [ ] Use Debian "main"-only install (no `non-free`, no `non-free-firmware`)
- [ ] Alternative: Devuan, Trisquel, Parabola, Guix
- [ ] **[wolf]** 4 GB RAM (non-upgradeable, soldered) — XFCE or LXQt recommended
- [ ] **[lulu]** Up to 8 GB RAM allows GNOME/KDE if desired (RAM is also soldered on lulu)

### 6.2 Install Procedure
- [ ] Boot Debian netinstall from USB via HEADS recovery
- [ ] Install to internal SSD (M.2 SATA on lulu, eMMC on wolf — note: wolf's storage is soldered eMMC on most SKUs)
- [ ] Post-install: `dmesg | grep -i firmware` must show zero non-microcode firmware loads
- [ ] Verify Wi-Fi (`ath9k`), graphics (`i915`), audio (`snd_hda_intel`) all functional
- [ ] Configure `/boot` GPG signing workflow with smartcard

### 6.3 Boot Flow Verification
- [ ] Cold boot: HEADS attestation → `/boot` signature check → kexec → Linux → login
- [ ] Reboot 5 times; verify consistent behavior
- [ ] Verify TOTP/HOTP green status persists
- [ ] Verify Linux runs without proprietary blobs in userspace (CPU microcode excepted)

---

## Stage 7: Hardening & Validation (Both Boards)

### 7.1 Stability Testing
- [ ] 100+ reboot cycle test (script in HEADS recovery)
- [ ] 24-hour idle stability test
- [ ] Suspend/resume cycle (if HEADS supports it for the board — Haswell/Broadwell S3 paths can be flaky under coreboot; record actual behavior)
- [ ] Battery-only operation across full discharge

### 7.2 Recovery Path Testing
- [ ] Practice USB recovery boot from HEADS
- [ ] Simulate partial brick (corrupt one CBFS file via `cbfstool`); recover via HEADS recovery shell
- [ ] Simulate full brick; recover via external SPI flash
- [ ] Document recovery time and steps for each scenario

### 7.3 Reproducibility
- [ ] Build ROM on second independent machine
- [ ] Compare SHA256 of resulting ROMs — they must match exactly
- [ ] If mismatch: identify non-deterministic build inputs (timestamps, build paths, locale) and pin them
- [ ] Record reproducible-build instructions in board README

### 7.4 Re-secure Hardware
- [ ] Reinstall WP screw on each device
- [ ] Verify internal flashrom blocked: `flashrom --wp-status` reports enabled with WP range covering BIOS region
- [ ] Confirm HEADS GUI flash operations are now restricted to writable regions only

---

## Stage 8: Documentation & Release

### 8.1 Per-Board Documentation
- [ ] Write `boards/wolf/README.md`:
  - Hardware overview and HWID confirmation
  - Disambiguation note: wolf is the 2014 P22T, **not** the 2015 3120
  - SPI flash location with photos
  - WP screw location with photos
  - Build instructions (Docker invocation, pinned coreboot tag, pinned microcode revision)
  - Flashing procedure
  - Recovery procedure
  - Known issues
- [ ] Write `boards/lulu/README.md` (same structure plus):
  - Wi-Fi swap procedure with photos
  - ME neutralization parameters and resulting size
  - FSP version, source, and SHA256
  - Microcode revision and SHA256
  - Descriptor HAP-bit verification command output

### 8.2 Release Artifacts
- [ ] Tag release in your fork
- [ ] Publish ROM SHA256 hashes
- [ ] Publish reproducible build instructions (Docker image digest, host requirements)
- [ ] Publish detached GPG signatures of release ROMs

### 8.3 Upstream Submission
- [ ] Submit PR to `linuxboot/heads` for wolf board
- [ ] Submit PR for lulu board after wolf is merged or accepted
- [ ] Respond to maintainer review feedback
- [ ] Maintain board against future HEADS releases (security patches, kernel updates)

---

## Risk Register & Mitigations

| Risk | Boards | Likelihood | Mitigation |
|---|---|---|---|
| Wrong device purchased (3120 instead of P22T) | wolf | Medium | Verify HWID prefix `WOLF` before purchase; reject 3120 listings |
| Brick during flash | Both | Medium | Verified backups, external programmer, backup unit |
| Coreboot wolf/lulu support stale in mainline | Both | Low-Med | Pin known-good commit; backport fixes if needed |
| ME neutralization breaks boot | lulu | Medium | Test `me_cleaner` flags incrementally; keep stock backup |
| Wi-Fi swap incompatibility | lulu | Low-Med | Test card in ChromeOS first (Stage 2.3); have a second ath9k card on hand |
| FSP version drift | lulu | Low | Pin FSP blob hash in repo |
| Microcode regression | Both | Low | Track Intel advisories; pin tested revision |
| Reproducibility failure | Both | Medium | Use Docker build; pin all toolchain versions and image digest |
| S3 suspend/resume unstable | Both | Med-High | Document and disable suspend if necessary; use suspend-to-disk as fallback |
| Smartcard provisioning errors | Both | Low | Practice `keytocard` flow on a test key first |
| Upstream rejection | Both | Low | Maintain as fork if needed |

---

## Optimized Effort Summary

Estimates assume one engineer with prior coreboot/HEADS experience. First-time HEADS porters should plan toward the upper range; first-time hardware flashers should add another 20–30 hours of debugging contingency.

| Stage | Effort (hours) | Cumulative |
|---|---|---|
| 1. Foundation | 8–14 | 14 |
| 2. Hardware prep (parallel) | 8–14 | 28 |
| 3. wolf bring-up | 30–50 | 78 |
| 4. lulu fork & FSP/ME | 25–45 | 123 |
| 5. TPM & measured boot | 8–14 | 137 |
| 6. OS installation | 4–8 | 145 |
| 7. Hardening | 12–20 | 165 |
| 8. Documentation & release | 10–15 | 180 |
| **Total** | **105–180 hours** | |

The wolf-first strategy means that if the project is abandoned at any stage after wolf bring-up, you still ship a complete HEADS port with minimal blobs (only the stock minimal ME and CPU microcode) — the most valuable single artifact. lulu becomes incremental work atop a proven foundation rather than a parallel risk.

---

## Definition of Done

A port is considered complete when all of the following are true for each board:

- [ ] Reproducible HEADS ROM builds from clean checkout (SHA256 match across two machines)
- [ ] First-flash and recovery procedures documented with photos
- [ ] TPM 1.2 measured boot with HOTP attestation working end-to-end
- [ ] OpenPGP-smartcard-signed `/boot` workflow operational
- [ ] Linux distribution boots with zero userspace firmware loads (excluding CPU microcode and, for lulu, the neutered ME / Broadwell FSP which are not userspace)
- [ ] 100+ reboot stability test passed
- [ ] WP screw reinstalled, internal flash protection verified
- [ ] README, recovery guide, and Wi-Fi swap (lulu) documentation published
- [ ] Upstream PR submitted to `linuxboot/heads`
