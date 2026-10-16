# Changelog

## 1.0.0

First release.

- Super+A window mode, built on a Hyprland submap: arrows move, Shift+arrows
  push edges, T/F/M/S/C for float, full screen, maximise, split and centre,
  1–9 to send to a workspace, Tab to switch windows.
- Outline and key card drawn by an omarchy-shell service, in the theme's
  colours, click-through and never taking keyboard focus.
- Closes by itself after 10 seconds without a key; unlisted keys are
  swallowed while it's on.
- `tools/install-keys.sh` and `tools/remove-keys.sh` add and remove the
  Hyprland config block, asking first and keeping backups.
- `arrange.enter()`, `arrange.push()` and friends for scripts, via
  `hyprctl eval`.
