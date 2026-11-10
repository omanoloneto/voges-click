#!/usr/bin/env bash
set -euo pipefail

version="${1:?version, such as 1.0.0}"
bundle="${2:?build/linux/x64/release/bundle folder}"
output="${3:?output .deb file}"

here="$(cd "$(dirname "$0")" && pwd)"
app_id=com.omanoloneto.voges_click
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
chmod 755 "$root"

mkdir -p "$root/DEBIAN" "$root/usr/lib/voges-click" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"
cp -r "$bundle/." "$root/usr/lib/voges-click/"
ln -s ../lib/voges-click/voges_click "$root/usr/bin/voges-click"
install -m 644 "$here/$app_id.desktop" "$root/usr/share/applications/"
convert "$here/../../assets/icon/icon_rounded.png" -resize 256x256 \
  "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

# zenity (or kdialog) provides the open and save dialogs for file_picker
cat > "$root/DEBIAN/control" <<CONTROL
Package: voges-click
Version: $version
Section: graphics
Priority: optional
Architecture: amd64
Depends: libgtk-3-0t64 | libgtk-3-0, zenity | kdialog
Maintainer: omanoloneto <mano.afonso93@gmail.com>
Homepage: https://omanoloneto.pro/voges/click/
Description: image editor with layers
 Voges Click edits pictures in layers with brush, eraser, fill,
 gradient, shapes, text, selections, crop and adjustments, opens PSD,
 PNG, JPEG, BMP, GIF, WebP, TIFF, ICO and TGA files and saves PSD with
 the layers, PNG, JPEG and BMP.
CONTROL

dpkg-deb --build --root-owner-group "$root" "$output"
