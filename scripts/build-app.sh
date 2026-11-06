#!/usr/bin/env bash
# Build Taipea.app: a tiny launcher that opens the Taipea window through Hammerspoon.
# Usage: scripts/build-app.sh [destination.app] [icon.icns]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${1:-$HOME/Applications/Taipea.app}"
icon="${2:-$here/../assets/Taipea.icns}"
version="${TAIPEA_VERSION:-0.2.9}"

if ! command -v osacompile >/dev/null 2>&1; then
  echo "osacompile not found: Taipea.app can only be built on macOS." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Start Hammerspoon if needed (give it time to load Taipea), then open the window.
# (osacompile prints a harmless "replacing existing signature" note; show its output only on failure)
if ! osa_out="$(osacompile -o "$tmp/Taipea.app" \
  -e 'if application id "org.hammerspoon.Hammerspoon" is not running then' \
  -e '  do shell script "open -g -a Hammerspoon"' \
  -e '  delay 3' \
  -e 'end if' \
  -e 'do shell script "open -g hammerspoon://taipea"' 2>&1)"; then
  echo "$osa_out" >&2
  exit 1
fi

app="$tmp/Taipea.app"
plist="$app/Contents/Info.plist"
pb="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"

if [ -f "$icon" ]; then
  cp "$icon" "$app/Contents/Resources/applet.icns"
fi

set_key() { # key type value
  "$pb" -c "Set :$1 \"$3\"" "$plist" 2>/dev/null || "$pb" -c "Add :$1 $2 \"$3\"" "$plist"
}
set_key CFBundleName string Taipea
set_key CFBundleDisplayName string Taipea
set_key CFBundleIdentifier string com.selektdev.taipea
set_key CFBundleShortVersionString string "$version"
set_key CFBundleVersion string "$version"
set_key NSHumanReadableCopyright string "© 2026 Patricio Escobar / selektdev (MIT)"

# We changed the bundle after osacompile, so re-sign it locally (ad-hoc).
codesign --force --deep --sign - "$app" >/dev/null 2>&1 || true

mkdir -p "$(dirname "$dest")"
rm -rf "$dest"
mv "$app" "$dest"
touch "$dest"
echo "Built $dest"
