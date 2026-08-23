#!/bin/sh
# Re-applies whichever preset is recorded in state/current_preset.txt.
# Run by the app itself (immediate apply) and by the webosbrew init.d boot
# hook (so it survives reboots -- the bind mount below lives in /tmp, which
# is wiped every boot, so this script has to re-run every time).
set -e

APP_DIR=/media/developer/apps/usr/palm/applications/com.arnolderuiter.homecustomizer
STATE_FILE="$APP_DIR/state/current_preset.txt"
ASSETS_DIR=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

[ -f "$STATE_FILE" ] || exit 0
PRESET="$(cat "$STATE_FILE")"
SRC="$APP_DIR/assets/presets/$PRESET"
[ -d "$SRC" ] || exit 0

umount "$ASSETS_DIR" 2>/dev/null || true
rm -rf /tmp/homecustomizer-merged
mkdir /tmp/homecustomizer-merged
cp -R --no-dereference "$ASSETS_DIR"/. /tmp/homecustomizer-merged/

cp "$SRC/home.xml" /tmp/homecustomizer-merged/home.xml
cp "$SRC/images/hd/bg_banner_img.png" /tmp/homecustomizer-merged/images/hd/bg_banner_img.png
cp "$SRC/images/2k/bg_banner_img.png" /tmp/homecustomizer-merged/images/2k/bg_banner_img.png
cp "$SRC/images/4k/bg_banner_img.png" /tmp/homecustomizer-merged/images/4k/bg_banner_img.png

rm -f /tmp/homecustomizer-merged/i18n
cp -R "$SRC/i18n" /tmp/homecustomizer-merged/i18n

mount --bind /tmp/homecustomizer-merged "$ASSETS_DIR"
pkill -f com.webos.app.home || true
