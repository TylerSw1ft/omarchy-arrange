# Arrange

A window mode for Hyprland on Omarchy. Press **Super+A**, then move and
resize the active window with plain keys: no chords to remember. A card next
to the window shows every key while the mode is on, and the window gets an
outline.

| Key | Does |
|---|---|
| ← → ↑ ↓ | Move the window (tiled: to the next spot that way; floating: a step) |
| Shift + arrows | Push the window's edge that way |
| T | Float / tile |
| F | Full screen |
| M | Maximise |
| S | Switch split (side by side ↔ stacked) |
| C | Centre (floating windows) |
| 1 – 9 | Send to workspace |
| Tab / Shift+Tab | Next / previous window |
| Esc, Enter, Super+A | Done |

The mode stays on until you leave it, so you can keep nudging, and ends by
itself after 10 seconds without a key. Other keys do nothing while it's on,
so nothing you type lands in the window by mistake.

**Pushing edges.** Shift+→ moves the window's edge to the right. A tiled
window grows towards its neighbour, or, if it already touches the right side
of the screen, shrinks from the left. Floating windows grow and shrink from
their right and bottom edges.

## Install

```bash
omarchy plugin add https://github.com/TylerSw1ft/omarchy-arrange.git --enable
```

The keys live in Hyprland's config, so add this to the end of
`~/.config/hypr/hyprland.lua`:

```lua
-- Arrange window mode (Omarchy plugin tylersw1ft.arrange). Skipped if the plugin is removed.
local arrange_binds = (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/tylersw1ft.arrange/hypr/arrange.lua"
local arrange_file = io.open(arrange_binds, "r")
if arrange_file then
  arrange_file:close()
  dofile(arrange_binds)
end
```

Super+A must be free; on a stock Omarchy it is.

## How it works

`hypr/arrange.lua` defines the mode as a Hyprland submap, so Hyprland itself
handles every key. `Service.qml`, inside omarchy-shell, listens for the
submap and draws the outline and card on a click-through layer that never
takes keyboard focus. Step sizes and the idle time are at the top of
`hypr/arrange.lua`.

You can also drive it from a script: `hyprctl eval 'arrange.enter()'`.

## Remove

```bash
omarchy plugin remove tylersw1ft.arrange
```

Then delete the "Arrange window mode" block from `~/.config/hypr/hyprland.lua`.
