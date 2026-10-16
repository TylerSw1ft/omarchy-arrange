#!/bin/bash
# Remove the block tools/install-keys.sh added to ~/.config/hypr/hyprland.lua.
# A timestamped backup of hyprland.lua is made first.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
MARKER="Arrange window mode (Omarchy plugin tylersw1ft.arrange)"

[[ -f $CONFIG ]] || { echo "arrange: $CONFIG not found" >&2; exit 1; }
if ! grep -qF "$MARKER" "$CONFIG"; then
  echo "Arrange's keys aren't in $CONFIG; nothing to do."
  exit 0
fi

backup="$CONFIG.arrange-backup.$(date +%Y%m%d-%H%M%S)"
n=1
while [[ -e $backup ]]; do backup="${backup%.*}.$(date +%Y%m%d-%H%M%S).$((n++))"; done
cp -p "$CONFIG" "$backup"

# Drop the marker comment, the blank line before it, and the block up to its
# closing "end". A blank line is held back until we know what follows it.
awk -v marker="$MARKER" '
  skipping { if ($0 == "end") skipping = 0; next }
  index($0, marker) { blank = 0; skipping = 1; next }
  { if (blank) print ""; blank = 0 }
  $0 == "" { blank = 1; next }
  { print }
  END { if (blank) print "" }
' "$backup" >"$CONFIG"

echo "Removed. Backup of the previous file: $backup"
if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
  echo "Hyprland reloaded."
fi
