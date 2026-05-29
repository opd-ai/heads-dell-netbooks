---
title: "[Stage 1.2] Procurement"
type: hardware
estimated_time: 4 hours (plus shipping lead time)
date_generated: 2026-05-29
---

## Task: What the human must do

Acquire and verify the devices, Wi-Fi cards, and flashing tools needed for the
wolf/lulu HEADS port. The single highest-risk procurement error is buying the
wrong device (a Dell Chromebook 11 **3120** is NOT wolf).

BOARD: both | RISK: Medium (wrong-device purchase can waste money / brick later)

## Prerequisites
- [ ] Stage 1.1 complete (you understand board identification)
- [ ] Budget for at least one device per board, plus optional backup units
- [ ] Ability to read the ChromeOS recovery-screen HWID before buying when possible

## Procedure

### Step 1: Acquire and verify the wolf device
Do: Source a **Dell Chromebook 11 P22T (2014)**. Before/at purchase, confirm
the recovery-screen HWID begins with `WOLF`.
Expected: HWID prefix `WOLF`; Intel Haswell-ULT Celeron 2955U; 8 MB SPI flash.
Verify: ChromeOS recovery screen (Esc+Refresh+Power) shows a `WOLF...` HWID.
If fails: REJECT the unit. A 3120 (2015, Bay Trail N2840, `candy` family) is
out of scope and can hard-brick if flashed with wolf images.

### Step 2: Acquire and verify the lulu device
Do: Source a **Dell Chromebook 13 7310 (2015)**. Any RAM SKU (4–8 GB) is fine.
Expected: HWID prefix `LULU`; Intel Broadwell-U (i3-5005U / i5-5200U / Celeron
3205U); 8 MB SPI flash.
Verify: Recovery screen shows a `LULU...` HWID.
If fails: REJECT the unit.

### Step 3: Acquire backup units (recommended)
Do: Where budget allows, buy one spare of each board.
Expected: Identical HWID prefixes to the primaries.
Verify: Same `WOLF` / `LULU` HWID checks as above.

### Step 4: Acquire ath9k Wi-Fi replacements
Do:
- [wolf] Confirm onboard Atheros AR9462; if a Marvell variant is present, obtain
  a mini-PCIe AR5B22 (AR9462).
- [lulu] Stock is Intel 7260/7265 and MUST be replaced for blob-free operation.
  Obtain an ath9k **M.2 2230 key A/E** card (e.g. QCNFA222 / AR9462 in M.2 2230,
  or another verified ath9k M.2 2230 card).
Expected: Cards on hand that are known to enumerate on Haswell/Broadwell.
Verify: Card model confirmed against the ath9k-supported list before install.
If fails: Order a second known-good ath9k card as backup (Stage 2.3 tests it).

### Step 5: Acquire flashing tools
Do: Obtain the SPI flashing kit:
- CH341A USB programmer (or Raspberry Pi with SPI)
- Pomona 5250 SOIC-8 test clip (avoid clone clips — flaky reads)
- 3.3V regulator mod for the CH341A (stock 5V damages the flash over time)
- 1.8V level shifter (not required here, useful for future ports)
- Precision screwdrivers (Phillips #00, Torx T5)
- Plastic spudgers/pry tools
- Anti-static mat and wrist strap
Expected: Complete kit on hand.
Verify: Physically check each item against this list.

### Step 6: Acquire the HOTP/OpenPGP security key
Do: Obtain a Nitrokey Pro 2 or Librem Key (needed in Stage 5).
Expected: Device on hand with OpenPGP smartcard support.
Verify: Vendor confirms OpenPGP + HOTP support.

## Success Criteria
- [ ] wolf device verified with `WOLF` HWID (and confirmed NOT a 3120)
- [ ] lulu device verified with `LULU` HWID
- [ ] ath9k replacement card(s) on hand for required board(s)
- [ ] Complete SPI flashing kit on hand (programmer, 3.3V mod, Pomona clip, ESD gear)
- [ ] HOTP/OpenPGP security key on hand

## Next Steps
1. Record models, HWIDs, and serials in `reports/stage-1.2-results.md`
2. Mark ROADMAP.md Stage 1.2 items complete
3. Continue to Stage 1.3 (Build Environment) — run
   `boards/scripts/setup-build-env.sh`; see `reports/stage-1.3-build-environment.md`

## Troubleshooting
**Problem:** Listing photos show "Dell Chromebook 11" but model is ambiguous →
**Fix:** Require the seller to confirm model `P22T` (2014); reject `3120`/2015.
**Problem:** CH341A reads are flaky → **Fix:** Apply the 3.3V regulator mod and
replace any clone SOIC-8 clip with a genuine Pomona 5250.
**Problem:** Cannot verify HWID before purchase → **Fix:** Buy from a returnable
source and verify the `WOLF`/`LULU` HWID on arrival before any other work.
