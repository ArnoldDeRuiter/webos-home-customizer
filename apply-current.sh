#!/bin/sh
# Re-applies whichever preset is recorded in state/current_preset.txt.
# Run by the app itself (immediate apply) and by the webosbrew init.d boot
# hook (so it survives reboots -- the overlay mount below lives in /tmp,
# which is wiped every boot, so this script has to re-run every time).
set -e

APP_DIR=/media/developer/apps/usr/palm/applications/com.arnolderuiter.homecustomizer
STATE_FILE="$APP_DIR/state/current_preset.txt"
ASSETS_DIR=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
UPPER_DIR=/tmp/homecustomizer-overlay-upper
WORK_DIR=/tmp/homecustomizer-overlay-work

[ -f "$STATE_FILE" ] || exit 0
PRESET="$(cat "$STATE_FILE")"
SRC="$APP_DIR/assets/presets/$PRESET"
[ -d "$SRC" ] || exit 0

# Overlay the real assets dir with just the handful of files the preset
# actually changes, instead of copying the whole assets tree into /tmp on
# every apply before bind-mounting the copy over the original. Unmodified
# files are served straight from the real assets dir (lowerdir) with no
# copying at all -- measured ~6.75x faster on real hardware for the
# equivalent change in the personal (non-packaged) version of this script.
umount "$ASSETS_DIR" 2>/dev/null || true
rm -rf "$UPPER_DIR" "$WORK_DIR"
mkdir -p "$UPPER_DIR/images/hd" "$UPPER_DIR/images/2k" "$UPPER_DIR/images/4k" "$UPPER_DIR/i18n" "$WORK_DIR"

cp "$SRC/home.xml" "$UPPER_DIR/home.xml"
cp "$SRC/images/hd/bg_banner_img.png" "$UPPER_DIR/images/hd/bg_banner_img.png"
cp "$SRC/images/2k/bg_banner_img.png" "$UPPER_DIR/images/2k/bg_banner_img.png"
cp "$SRC/images/4k/bg_banner_img.png" "$UPPER_DIR/images/4k/bg_banner_img.png"

# i18n in the real assets dir is a symlink, not a plain directory -- a real
# directory placed in upperdir shadows it by name regardless of type, same
# as the old approach's rm+replace, so this doesn't need special handling.
cp -R "$SRC/i18n/." "$UPPER_DIR/i18n/"

mount -t overlay overlay -o lowerdir="$ASSETS_DIR",upperdir="$UPPER_DIR",workdir="$WORK_DIR" "$ASSETS_DIR"
pkill -f com.webos.app.home || true
