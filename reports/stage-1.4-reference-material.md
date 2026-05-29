---
title: "[Stage 1.4] Reference Material Collection"
type: validation
estimated_time: 3 hours
date_generated: 2026-05-29
---

## Task: What the human must do

Acquire the stock ChromeOS recovery images, extract the stock firmware
(`bios.bin`) for descriptor analysis, and pull the correct CPU microcode source.
The provided script automates the download/verify steps; the privileged
extraction (loop-mounting the recovery rootfs) is performed by the human.

BOARD: both | RISK: Low (read-only acquisition; no device is modified)

> NOTE: This step acquires real vendor blobs from official sources only. Never
> fabricate firmware or microcode content; always record SHA256 of every blob.

## Prerequisites
- [ ] Stage 1.3 complete (host tooling installed)
- [ ] Internet access to `dl.google.com` and `github.com`
- [ ] `curl`, `unzip`, root (for loop-mounting), and `cgpt`/`kpartx` available
- [ ] Script present: `boards/scripts/fetch-reference-material.sh`

## Procedure

### Step 1: Preview the acquisition (optional)
Do:
```bash
./boards/scripts/fetch-reference-material.sh --dry-run --board both
```
Expected: Prints the recovery.conf URL and the per-board lookups without
downloading.
Verify: No files appear under `reference-material/`.

### Step 2: Download and verify recovery images
Do:
```bash
./boards/scripts/fetch-reference-material.sh --board both --with-microcode
```
Expected: Downloads the wolf and lulu ChromeOS recovery images discovered in
Google's `recovery.conf`, verifies each against its published SHA1, and clones
the Intel microcode source.
Verify:
```bash
ls -lh reference-material/wolf reference-material/lulu
```
→ a `*.zip` recovery image is present for each board.
If fails: If a codename is not matched, open `reference-material/recovery.conf`
and search for `wolf`/`lulu` to confirm the current image URL, then re-run.

### Step 3: Extract the disk image
Do:
```bash
for board in wolf lulu; do
  cd "reference-material/${board}"
  unzip -o *.zip                    # yields chromiumos_image.bin (or *.bin)
done
```
Expected: A multi-GB `*.bin` ChromeOS disk image is extracted for each board.
Verify: `ls -lh reference-material/wolf/*.bin reference-material/lulu/*.bin`.
If fails: Confirm enough free disk (recovery images are large).

### Step 4: Extract stock firmware (bios.bin)
Do: Loop-mount the ROOT-A partition and run the shellball extractor.
```bash
for board in wolf lulu; do
  cd "reference-material/${board}"
  sudo kpartx -av chromiumos_image.bin         # maps partitions
  sudo mkdir -p /mnt/cros-root
  sudo mount -o ro /dev/mapper/loop*p3 /mnt/cros-root
  sudo /mnt/cros-root/usr/sbin/chromeos-firmwareupdate \
       --sb_extract "/tmp/${board}-fw"
  sudo umount /mnt/cros-root
  sudo kpartx -d chromiumos_image.bin
done
```
Expected: `/tmp/wolf-fw/bios.bin` and `/tmp/lulu-fw/bios.bin` are produced.
Verify: `ls -lh /tmp/wolf-fw/bios.bin /tmp/lulu-fw/bios.bin` → each roughly an 8 MB image.
If fails: If `--sb_extract` is unavailable, use `--mode=output` or copy the
shellball from `/usr/sbin/chromeos-firmwareupdate` and run `--unpack`.

### Step 5: Inspect the descriptor
Do:
```bash
ifdtool -d /tmp/wolf-fw/bios.bin
ifdtool -d /tmp/lulu-fw/bios.bin
```
Expected: A valid descriptor dump listing descriptor/ME/(GbE)/BIOS regions.
Verify: Region offsets/sizes are printed (record them for Stage 3.1/4.1).
If fails: Confirm `bios.bin` is the full 8 MB SPI image, not a partial region.

### Step 6: Pin and record microcode
Do: In `reference-material/microcode`, check out a specific upstream release
tag and locate the blobs:
- [wolf] Haswell-ULT `06-45-01`
- [lulu] Broadwell-U `06-3d-04`
```bash
cd reference-material/microcode
git checkout <pinned-release-tag>
sha256sum intel-ucode/06-45-01 intel-ucode/06-3d-04
```
Expected: The two microcode blobs exist; SHA256 recorded.
Verify: Hashes captured into build metadata.

### Step 7: Record all hashes
Do:
```bash
sha256sum /tmp/wolf-fw/bios.bin /tmp/lulu-fw/bios.bin reference-material/wolf/*.zip \
          reference-material/lulu/*.zip
```
Expected: SHA256 for every acquired artifact.
Verify: Hashes saved to `reports/stage-1.4-results.md`.

## Success Criteria
- [ ] Verified recovery image downloaded for wolf and for lulu
- [ ] Stock `bios.bin` extracted for both wolf and lulu
- [ ] `ifdtool -d` produces a valid descriptor dump with recorded region layout
- [ ] Microcode `06-45-01` (wolf) and `06-3d-04` (lulu) located from a pinned tag
- [ ] SHA256 recorded for every acquired blob

## Next Steps
1. Record image URLs, extraction notes, and all SHA256 in `reports/stage-1.4-results.md`
2. Mark ROADMAP.md Stage 1.4 items complete
3. Continue to Stage 2 (Hardware Preparation)

## Troubleshooting
**Problem:** recovery.conf has no `wolf`/`lulu` stanza →
**Fix:** Google occasionally renames stanzas; grep the manifest for the model
string and pass the exact codename, or download the image listed for the model
manually.
**Problem:** `chromeos-firmwareupdate --sb_extract` not supported →
**Fix:** Use `--unpack <dir>` on the shellball, then read `bios.bin` from the
unpacked directory.
**Problem:** Loop device permission errors →
**Fix:** Ensure you are root and that `kpartx`/`udev` mapped the partitions
(`ls /dev/mapper/loop*`).
