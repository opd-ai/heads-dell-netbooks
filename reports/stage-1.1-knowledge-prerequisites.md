---
title: "[Stage 1.1] Knowledge Prerequisites"
type: validation
estimated_time: 6 hours
date_generated: 2026-05-29
---

## Task: What the human must do

Build the baseline HEADS/coreboot knowledge and establish community contact
required before any wolf/lulu porting work begins. This is a research and
onboarding task — no hardware or builds are involved.

BOARD: both | RISK: Low

## Prerequisites
- [ ] Workstation with a web browser and internet access
- [ ] A Matrix account (for `#heads:matrix.org`)
- [ ] Git installed (to clone reference trees for reading)

## Procedure

### Step 1: Read HEADS architecture documentation
Do: Open `https://osresearch.net` and read the HEADS architecture, threat
model, and measured-boot sections.
Expected: You can explain what HEADS measures (firmware, kernel, initrd) and
how HOTP/TOTP attestation and the OpenPGP `/boot` signing flow work.
Verify: You can answer — "Why does HEADS re-flash when importing a GPG public
key?" (Because the key is stored in the ROM's CBFS.)
If fails: Re-read the measured-boot and `/boot` signing sections.

### Step 2: Read the coreboot porting guide for Google boards
Do: Read coreboot's documentation on porting/maintaining Google ChromeOS
boards, focusing on the `google/wolf` (Haswell) and `google/lulu` (Broadwell)
targets and the IFD/ME/FSP concepts.
Expected: You understand the difference between Haswell (no FSP, minimal ME)
and Broadwell (FSP required, ME 10.x) bring-up.
Verify: You can state why wolf is the lower-risk reference build.

### Step 3: Review the canonical TPM 1.2 reference board
Do: Read `boards/x230-flash/x230-flash.config` in a local HEADS checkout (see
Stage 1.3). This is the canonical TPM 1.2 reference these ports copy from.
Verify: `grep -i tpm boards/x230-flash/x230-flash.config` → shows the TPM
configuration symbols that wolf/lulu will reuse.
If fails: Confirm the HEADS clone from Stage 1.3 completed.

### Step 4: Review mrchromebox coreboot scripts (reference only)
Do: Read the mrchromebox coreboot scripts/notes for wolf and lulu for hardware
pointers (WP screw location, SPI layout). These are reference only and are NOT
used in the HEADS build.
Expected: You know where the WP screw and SPI flash sit on each board.
Verify: You can point to the WP screw location for both boards.

### Step 5: Join the HEADS community and announce intent
Do: Join Matrix `#heads:matrix.org`; post a short message announcing intent to
port wolf and lulu and asking whether anyone has prior art.
Expected: Message posted; you are watching the channel for replies.
Verify: Your message is visible in the channel scrollback.

## Success Criteria
- [ ] Can explain HEADS measured-boot and `/boot` signing at a high level
- [ ] Can articulate the wolf-first (Haswell) vs lulu (Broadwell) risk rationale
- [ ] Located the x230-flash TPM 1.2 reference config in a local checkout
- [ ] Identified WP-screw and SPI-flash locations for both boards
- [ ] Joined `#heads:matrix.org` and announced intent

## Next Steps
1. Document findings/links in `reports/stage-1.1-results.md`
2. Mark ROADMAP.md Stage 1.1 items complete
3. Continue to Stage 1.2 (Procurement) — see `reports/stage-1.2-procurement.md`

## Troubleshooting
**Problem:** `osresearch.net` unreachable → **Fix:** Use the HEADS GitHub wiki
(`github.com/linuxboot/heads/wiki`) as a mirror of the architecture docs.
**Problem:** Cannot find wolf/lulu in the coreboot tree → **Fix:** They live
under `src/mainboard/google/` as Haswell/Broadwell variant boards; pin a recent
commit per Stage 3.2/4.5.
