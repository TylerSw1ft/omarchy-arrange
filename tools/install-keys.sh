#!/bin/bash
# Add Arrange's keys to Hyprland: appends a short, guarded block to
# ~/.config/hypr/hyprland.lua that loads hypr/arrange.lua, after showing it
# and asking. A timestamped backup of hyprland.lua is made first.
#
#   tools/install-keys.sh          ask before changing anything
#   tools/install-keys.sh --yes    don't ask
#
# Undo with tools/remove-keys.sh.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
MARKER="Arrange window mode (Omarchy plugin tylersw1ft.arrange)"
ASSUME_YES=0
[[ ${1:-} == --yes || ${1:-} == -y ]] && ASSUME_YES=1

fail() {
  echo "arrange: $*" >&2
  exit 1
}

[[ -f $CONFIG ]] || fail "$CONFIG not found; Arrange needs Hyprland's Lua config (Omarchy Quattro or later)"

if grep -qF "$MARKER" "$CONFIG"; then
  echo "Arrange's keys are already in $CONFIG."
  exit 0
fi

BLOCK=$(cat <<'EOF'

-- Arrange window mode (Omarchy plugin tylersw1ft.arrange). Skipped if the plugin is removed.
local arrange_binds = (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/tylersw1ft.arrange/hypr/arrange.lua"
local arrange_file = io.open(arrange_binds, "r")
if arrange_file then
  arrange_file:close()
  dofile(arrange_binds)
end
EOF
)

# Super+A is Arrange's key; say so if something else already has it.
if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
  taken=$(hyprctl binds -j 2>/dev/null |
    jq -r '.[] | select(.modmask == 64 and (.key | ascii_upcase) == "A" and .submap == "") | .description // .arg' |
    head -1 || true)
  if [[ -n $taken ]]; then
    echo "Note: Super+A is already bound (\"$taken\"). Hyprland runs both bindings;"
    echo "remove the other one, or change \"SUPER + A\" in hypr/arrange.lua."
    echo
  fi
fi

if (( ! ASSUME_YES )); then
  echo "This adds the following to the end of $CONFIG:"
  echo "$BLOCK"
  echo
  read -r -p "Add it? [y/N] " answer
  [[ $answer == [yY]* ]] || fail "nothing changed"
fi

backup="$CONFIG.arrange-backup.$(date +%Y%m%d-%H%M%S)"
n=1
while [[ -e $backup ]]; do backup="${backup%.*}.$(date +%Y%m%d-%H%M%S).$((n++))"; done
cp -p "$CONFIG" "$backup"
printf '%s\n' "$BLOCK" >>"$CONFIG"
echo "Added. Backup of the previous file: $backup"

if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
  echo "Hyprland reloaded: press Super+A to arrange windows."
else
  echo "Reload Hyprland (or log out and in), then press Super+A."
fi
