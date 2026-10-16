-- Arrange: a window mode for moving and resizing windows with plain keys.
--
-- Super+A enters the mode; the Arrange service in omarchy-shell then
-- outlines the active window and shows a card with the keys. Inside it:
--
--   arrows          move the window (tiled: to the next spot that way;
--                   floating: a step that way)
--   Shift+arrows    push the window's edge that way (grow towards a
--                   neighbour, or shrink away from the screen edge)
--   T  float / tile      F  full screen      M  maximise
--   S  switch split      C  centre (floating)
--   1-9  send to workspace N      Tab / Shift+Tab  next / previous window
--   Esc, Enter or Super+A  done
--
-- Other keys do nothing while the mode is on, so nothing leaks into the
-- window. The mode ends by itself after IDLE_MS without a key.
--
-- Loaded from ~/.config/hypr/hyprland.lua (tools/install-keys.sh adds the
-- line). Scripts can drive it too: hyprctl eval 'arrange.enter()'.

local MOVE_STEP = 60     -- px a floating window moves per arrow press
local RESIZE_STEP = 60   -- px an edge moves per Shift+arrow press
local EDGE_SLACK = 40    -- px from the screen edge that still counts as touching
local IDLE_MS = 10000

local SUBMAP = "arrange"

local generation = 0

-- Leave the mode after IDLE_MS of quiet: each key starts a fresh one-shot
-- timer, and only the latest one may close the mode.
local function keep_alive()
  generation = generation + 1
  local mine = generation
  hl.timer(function()
    if mine == generation and hl.get_current_submap() == SUBMAP then
      hl.dispatch(hl.dsp.submap("reset"))
    end
  end, { timeout = IDLE_MS, type = "oneshot" })
end

-- Which screen edges the window touches, allowing for gaps and the bar.
local function touching(w)
  local m = w.monitor or hl.get_active_monitor()
  local scale = m.scale > 0 and m.scale or 1
  local r = m.reserved or {}
  local left = m.x + (r.left or 0)
  local top = m.y + (r.top or 0)
  local right = m.x + m.width / scale - (r.right or 0)
  local bottom = m.y + m.height / scale - (r.bottom or 0)
  return {
    l = w.at.x - left <= EDGE_SLACK,
    r = right - (w.at.x + w.size.x) <= EDGE_SLACK,
    u = w.at.y - top <= EDGE_SLACK,
    d = bottom - (w.at.y + w.size.y) <= EDGE_SLACK,
  }
end

local VECTORS = { l = { -1, 0 }, r = { 1, 0 }, u = { 0, -1 }, d = { 0, 1 } }

local function move(dir)
  local w = hl.get_active_window()
  if not w then return end
  if w.floating then
    local v = VECTORS[dir]
    hl.dispatch(hl.dsp.window.move({ x = v[1] * MOVE_STEP, y = v[2] * MOVE_STEP, relative = true }))
  else
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
  end
end

-- Push the window's edge in `dir`. A floating window grows or shrinks from
-- its right and bottom edges. A tiled one grows towards its neighbours, so
-- when it already touches the screen edge in `dir`, the edge that can move
-- is the far one, and pushing means shrinking.
local function push(dir)
  local w = hl.get_active_window()
  if not w then return end
  local v = VECTORS[dir]
  local amount
  if w.floating then
    amount = RESIZE_STEP
  else
    amount = touching(w)[dir] and -RESIZE_STEP or RESIZE_STEP
    v = { math.abs(v[1]), math.abs(v[2]) }
  end
  hl.dispatch(hl.dsp.window.resize({ x = v[1] * amount, y = v[2] * amount, relative = true }))
end

local function center()
  local w = hl.get_active_window()
  if w and w.floating then hl.dispatch(hl.dsp.window.center()) end
end

-- Wrap an action (a function or a dispatcher) so that it also keeps the
-- mode alive.
local function key(fn, ...)
  local args = { ... }
  return function()
    keep_alive()
    if type(fn) == "function" then fn(table.unpack(args)) else hl.dispatch(fn) end
  end
end

local function done()
  generation = generation + 1
  hl.dispatch(hl.dsp.submap("reset"))
end

local function enter()
  if hl.get_current_submap() == SUBMAP then return done() end
  hl.dispatch(hl.dsp.submap(SUBMAP))
  keep_alive()
end

-- For scripts: hyprctl eval 'arrange.enter()', 'arrange.push("r")', ...
_G.arrange = { enter = enter, done = done, move = move, push = push, center = center }

hl.bind("SUPER + A", enter, { description = "Arrange windows (window mode)" })

local DIRECTIONS = {
  { key = "LEFT", dir = "l", name = "left" },
  { key = "RIGHT", dir = "r", name = "right" },
  { key = "UP", dir = "u", name = "up" },
  { key = "DOWN", dir = "d", name = "down" },
}

hl.define_submap(SUBMAP, function()
  for _, d in ipairs(DIRECTIONS) do
    hl.bind(d.key, key(move, d.dir),
      { repeating = true, description = "Arrange: move window " .. d.name })
    hl.bind("SHIFT + " .. d.key, key(push, d.dir),
      { repeating = true, description = "Arrange: push window edge " .. d.name })
  end

  hl.bind("T", key(hl.dsp.window.float({ action = "toggle" })), { description = "Arrange: float / tile" })
  hl.bind("F", key(hl.dsp.window.fullscreen({ mode = "fullscreen" })), { description = "Arrange: full screen" })
  hl.bind("M", key(hl.dsp.window.fullscreen({ mode = "maximized" })), { description = "Arrange: maximise" })
  hl.bind("S", key(hl.dsp.layout("togglesplit")), { description = "Arrange: switch split" })
  hl.bind("C", key(center), { description = "Arrange: centre floating window" })

  for n = 1, 9 do
    hl.bind("code:" .. tostring(n + 9), key(hl.dsp.window.move({ workspace = tostring(n) })),
      { description = "Arrange: send window to workspace " .. n })
  end

  hl.bind("TAB", key(hl.dsp.window.cycle_next()), { description = "Arrange: next window" })
  hl.bind("SHIFT + TAB", key(hl.dsp.window.cycle_next({ next = false })),
    { description = "Arrange: previous window" })

  hl.bind("ESCAPE", done, { description = "Arrange: done" })
  hl.bind("RETURN", done, { description = "Arrange: done" })
  hl.bind("SUPER + A", done, { description = "Arrange: done" })

  -- Swallow everything else, so a stray letter doesn't land in the window.
  hl.bind("catchall", hl.dsp.no_op())
end)
