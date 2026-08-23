#!/bin/sh
# Builds a webOS/opkg-style .ipk from this source tree, by hand (ar + tar),
# since ares-cli (LG's official packaging tool) isn't assumed to be installed.
# ipk format: an `ar` archive containing debian-binary, control.tar.gz, data.tar.gz
# -- same shape as a .deb, which is what opkg (the on-device package tool) expects.
set -e

cd "$(dirname "$0")"

APP_ID="com.arnolderuiter.homecustomizer"
VERSION="$(python3 -c "import json;print(json.load(open('appinfo.json'))['version'])")"
INSTALL_ROOT="media/developer/apps/usr/palm/applications/$APP_ID"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- data.tar.gz: the actual app files, laid out at their real target path ---
DATA_DIR="$WORK/data/$INSTALL_ROOT"
mkdir -p "$DATA_DIR"
cp -R appinfo.json index.html icon.png css js apply-current.sh assets "$DATA_DIR/"
chmod +x "$DATA_DIR/apply-current.sh"

# packageinfo.json is separate from appinfo.json and lives at a different
# path entirely -- required by the on-device installer (appinstalld), or
# install fails with "Cannot find packageinfo.json". Confirmed by inspecting
# already-installed homebrew apps on a real TV, not from docs alone.
PKG_DIR="$WORK/data/media/developer/apps/usr/palm/packages/$APP_ID"
mkdir -p "$PKG_DIR"
cat > "$PKG_DIR/packageinfo.json" <<EOF
{
  "id": "$APP_ID",
  "version": "$VERSION",
  "app": "$APP_ID"
}
EOF

( cd "$WORK/data" && tar --owner=0 --group=0 -czf "$WORK/data.tar.gz" . )

# --- control.tar.gz: opkg package metadata ---
mkdir -p "$WORK/control"
cat > "$WORK/control/control" <<EOF
Package: $APP_ID
Version: $VERSION
Architecture: all
Maintainer: ArnoldDeRuiter
Description: Pick a home-screen layout/wallpaper preset for rooted webOS 10 TVs and apply it via a bind-mount overlay (see README for how it works). Reversible, nothing on the signed system partition is touched.
Section: misc
Priority: optional
EOF
( cd "$WORK/control" && tar --owner=0 --group=0 -czf "$WORK/control.tar.gz" control )

# --- assemble the ipk (ar archive, debian-binary first) ---
echo "2.0" > "$WORK/debian-binary"
OUT="${APP_ID}_${VERSION}_all.ipk"
rm -f "$OUT"
( cd "$WORK" && ar -crf "$OUT" debian-binary control.tar.gz data.tar.gz )
mv "$WORK/$OUT" "./$OUT"

sha256sum "$OUT"
echo "Built: $(pwd)/$OUT"
