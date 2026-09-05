--- Presentation only (§5, §10). Reads sim/core state, draws it, owns nothing.
--- One shared camera on the active board; the dormant board is a live side
--- panel; tube transit pulls the camera out to show both boards at once.

local C       = require("core.constants")
local intents = require("core.intents")
local score   = require("core.score")
local geo     = require("core.geometry")

local M = {}

local W, H = 1000, 780

-- Each board keeps its own side of the screen for the whole match: A is
-- anchored to the left margin, B to the right. Only the scale animates, so
-- nothing ever slides across the screen or trades places with the other board
-- -- you always know where your board is, and the handover has no jump in it.
local TOP_Y      = 30
local LEFT_X     = 24
local RIGHT_EDGE = 976

local S_ACTIVE  = 0.93
local S_DORMANT = 0.40
local S_TRANSIT = 0.70    -- both boards visible for the pass (§10)

--- Screen position of a board at a given scale. This is the whole layout.
local function place(id, s, w)
  local x = (id == "a") and LEFT_X or (RIGHT_EDGE - w * s)
  return x, TOP_Y
end

local THEME = {
  a = { wall = {0.98, 0.62, 0.28}, fill = {0.11, 0.075, 0.055} },
  b = { wall = {0.42, 0.85, 0.95}, fill = {0.055, 0.09, 0.105} },
}

local fonts

-- Injected by main.lua rather than required, so the renderer still draws with
-- no effects attached -- which is what `--shot` does, and what makes a "did fx
-- break this?" bisect one line long.
local fx

---@param module table app.fx
function M.attach_fx(module)
  fx = module
  -- render owns every font in the game; fx borrows one rather than creating
  -- its own, which is what keeps fx loadable in the bare interpreter.
  if fonts then fx.set_font(fonts.body) end
end

function M.load(defs)
  fonts = {
    small = love.graphics.newFont(11),
    body  = love.graphics.newFont(14),
    head  = love.graphics.newFont(20),
    huge  = love.graphics.newFont(34),
  }
  M.view = { a = { s = S_ACTIVE }, b = { s = S_DORMANT } }
  M.hud_a = 1
  for id, v in pairs(M.view) do v.x, v.y = place(id, v.s, defs[id].size.w) end
  M.hud_x = LEFT_X + defs.a.size.w * M.view.a.s + 24
  if fx then fx.set_font(fonts.body) end
end

M.size = { w = W, h = H }

local function lerp(a, b, t) return a + (b - a) * t end

--- 1234500 -> "1,234,500". Pinball scores are large by design and a bare run
--- of digits cannot be read at a glance from across a room.
local function commas(n)
  local out = tostring(math.floor(n))
  local k
  repeat out, k = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
  return out
end

--- §9: relay heat, 0..1. The rally gets visibly hotter as it gets more
--- valuable and more likely to end, which is the whole risk curve made
--- visible. Saturates at 10 crossings so a long rally still has a ceiling.
local function heat_of(state)
  return math.min(1, (state.stats.relay or 0) / 10)
end

--- Interpolate a value between the two most recent sim states (§4.1).
local function ilerp(prev, cur, alpha) return prev and cur and lerp(prev, cur, alpha) or cur end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------

--- Target scale per board. During transit both are pulled back to the same
--- size; otherwise the board with the ball is the big one.
local function target_scale(state, id)
  if state.phase == "transit" then return S_TRANSIT end
  return (id == state.active) and S_ACTIVE or S_DORMANT
end

function M.update_camera(state, defs, dt)
  local k = 1 - math.exp(-12 * dt)      -- frame-rate independent smoothing
  -- The HUD stays up during transit. It used to fade out for the whole beat,
  -- on the assumption that the pulled-back boards reached into its column --
  -- they do not: at S_TRANSIT the gap between the boards is 390px against
  -- 214px in normal play, so pulling back makes *more* room, not less.
  --
  -- It mattered because prototype.md §4.5 hands the sender the destination
  -- board's devices for exactly these ~800ms. Hiding the operator's panel for
  -- the one window in which they are the operator is what made the transit
  -- read as dead air, and it is a pillar-1 violation ("nobody waits") dressed
  -- up as a camera move.
  M.hud_a = lerp(M.hud_a, 1, k)
  for id, v in pairs(M.view) do
    v.s = lerp(v.s, target_scale(state, id), k)
    v.x, v.y = place(id, v.s, defs[id].size.w)
  end
  -- The HUD lives in the gap between the two boards, wherever that currently
  -- is: derived from the live scale, so it is always in the right place.
  M.hud_x = LEFT_X + defs.a.size.w * M.view.a.s + 24
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------

--- The landing, telegraphed on the receiving board. §10 wants the incoming
--- ball legible without looking at it, and this is the visual half of that:
--- rings that tighten onto the entry point as the ball closes, so the
--- operator can see how long they have left to rearrange the floor.
---
--- Drawn in board space, inside the receiving board's transform.
local function draw_incoming(def, u)
  local e = def.entry
  local lg = love.graphics
  -- Entry points sit against a wall by construction -- the ball arrives
  -- through one -- so a fixed ring radius spills over the board edge and gets
  -- scissored into a stray arc. Size the rings to the room actually there.
  local room = math.min(e.x, def.size.w - e.x, e.y, 52)
  local span = math.max(14, room - 12)   -- 10 is the inner radius below
  -- Three rings, staggered, each collapsing onto the entry point. Staggering
  -- them means there is always one mid-collapse, so the countdown reads at a
  -- glance instead of only at the moment a single ring lands.
  for i = 0, 2 do
    local ru = (u + i / 3) % 1
    lg.setColor(0.55, 0.95, 0.7, 0.55 * (1 - ru))
    lg.setLineWidth(2)
    lg.circle("line", e.x, e.y, 10 + span * (1 - ru))
  end
  -- The arrival vector, so "where" is as clear as "when".
  lg.setColor(0.6, 1, 0.75, 0.35 + 0.45 * u)
  lg.setLineWidth(2 + 2 * u)
  lg.line(e.x, e.y, e.x + e.dir.x * 34, e.y + e.dir.y * 34)
  lg.setColor(0.6, 1, 0.75, 0.25 + 0.6 * u)
  lg.circle("fill", e.x, e.y, 4 + 3 * u)
end

local function draw_board(def, snap, prev, alpha, view, active, heat, incoming, tstates)
  local th = THEME[def.id]
  local dim = active and 1.0 or 0.45

  love.graphics.push()
  love.graphics.translate(view.x, view.y)
  love.graphics.scale(view.s)

  love.graphics.setColor(th.fill[1], th.fill[2], th.fill[3], active and 1 or 0.8)
  love.graphics.rectangle("fill", 0, 0, def.size.w, def.size.h, 8)

  -- The post parks below the playfield when retracted (that is what "sinks
  -- into the floor" means in the data), so clip to the board.
  love.graphics.setScissor(view.x, view.y, def.size.w * view.s, def.size.h * view.s)

  -- Drain line
  love.graphics.setColor(0.6, 0.15, 0.15, 0.55 * dim)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, def.drain_y, def.size.w, def.drain_y)

  -- Walls
  love.graphics.setColor(th.wall[1] * dim, th.wall[2] * dim, th.wall[3] * dim, 1)
  love.graphics.setLineWidth(3)
  for _, poly in ipairs(def.walls) do love.graphics.line(poly) end

  -- Bumpers. A struck bumper lights and swells for ~300ms: they are board A's
  -- declared character (prototype.md §4.1) and were previously indistinguishable
  -- from scenery whether or not the ball had just hit them.
  for i, b in ipairs(def.bumpers or {}) do
    local pulse = fx and fx.hit_pulse(def.id, "bumper", i) or 0
    local r = b.r * (1 + 0.18 * pulse)
    love.graphics.setColor(0.95 * dim, 0.85 * dim, 0.30 * dim, 0.85 + 0.15 * pulse)
    love.graphics.setLineWidth(2 + 3 * pulse)
    love.graphics.circle("line", b.x, b.y, r)
    love.graphics.setColor(0.95 * dim, 0.85 * dim, 0.30 * dim, 0.18 + 0.62 * pulse)
    love.graphics.circle("fill", b.x, b.y, r)
    love.graphics.setLineWidth(3)
  end

  -- Targets. A lit one has been hit and is waiting for the rest of its bank;
  -- the difference has to be visible at a glance or the bank is a mechanic
  -- only the scoreboard knows about.
  for i, t in ipairs(def.targets or {}) do
    local tstate = tstates and tstates[i]
    local lit    = tstate and tstate.lit
    local pulse  = fx and fx.hit_pulse(def.id, "target", i) or 0
    local corners = geo.rect_corners(t)
    if lit then
      love.graphics.setColor(0.55 * dim, 0.98 * dim, 0.70 * dim, 0.85 + 0.15 * pulse)
    else
      love.graphics.setColor(0.80 * dim, 0.82 * dim, 0.90 * dim, 0.45 + 0.55 * pulse)
    end
    love.graphics.polygon("fill", corners)
    love.graphics.setColor(1, 1, 1, (lit and 0.5 or 0.22) + 0.5 * pulse)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", corners)
  end

  -- Tube mouth and arrival point (§5: the link, always visible)
  local m = def.tube.mouth
  love.graphics.setColor(0.55 * dim, 0.95 * dim, 0.65 * dim, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", m.x, m.y, m.r)
  love.graphics.circle("line", m.x, m.y, m.r * 0.55)
  local e = def.entry
  love.graphics.setColor(0.55 * dim, 0.95 * dim, 0.65 * dim, 0.35)
  love.graphics.circle("line", e.x, e.y, 13)
  love.graphics.line(e.x, e.y, e.x + e.dir.x * 26, e.y + e.dir.y * 26)

  -- Devices
  for _, d in ipairs(def.devices) do
    local ds, dp = snap.devices[d.id], prev and prev.devices[d.id]
    local p = ilerp(dp and dp.p, ds.p, alpha) or ds.p
    -- Amber when moving or engaged; this is the operator's tell (§6.1).
    love.graphics.setColor(lerp(0.35, 1.0, p) * dim, lerp(0.45, 0.72, p) * dim, lerp(0.55, 0.20, p) * dim, 1)
    love.graphics.setLineWidth(7)
    if d.kind == "gate" then
      local ang = ilerp(dp and dp.angle, ds.angle, alpha) or ds.angle
      love.graphics.line(d.pivot.x, d.pivot.y,
                         d.pivot.x + math.cos(ang) * d.length,
                         d.pivot.y + math.sin(ang) * d.length)
      love.graphics.circle("fill", d.pivot.x, d.pivot.y, 4)
    else
      local x = ilerp(dp and dp.x, ds.x, alpha) or ds.x
      local y = ilerp(dp and dp.y, ds.y, alpha) or ds.y
      love.graphics.rectangle("fill", x - d.w / 2, y - d.h / 2, d.w, d.h, 4)
    end
  end

  -- Flippers
  love.graphics.setColor(0.92 * dim, 0.92 * dim, 0.96 * dim, 1)
  love.graphics.setLineWidth(C.FLIPPER_THICK)
  for _, f in ipairs(def.flippers) do
    local ang = ilerp(prev and prev.flippers[f.side], snap.flippers[f.side], alpha)
    local sign = (f.side == "left") and 1 or -1
    local tx = f.x + math.cos(ang) * C.FLIPPER_LEN * sign
    local ty = f.y + math.sin(ang) * C.FLIPPER_LEN * sign
    love.graphics.line(f.x, f.y, tx, ty)
    love.graphics.circle("fill", f.x, f.y, C.FLIPPER_THICK * 0.62)
  end

  -- Effects sit under the ball and over the geometry, in board space.
  if fx then fx.draw_board(def.id, heat) end

  -- Incoming ball, on the board that is about to receive it.
  if incoming then draw_incoming(def, incoming) end

  -- Ball. Its halo takes the rally heat: at rally 0 it is a plain white ball,
  -- and by rally 10 it is visibly running hot (§9).
  if snap.ball then
    local bx = ilerp(prev and prev.ball and prev.ball.x, snap.ball.x, alpha)
    local by = ilerp(prev and prev.ball and prev.ball.y, snap.ball.y, alpha)
    love.graphics.setColor(1, 0.95 - 0.35 * heat, 0.85 - 0.65 * heat, 0.25 + 0.22 * heat)
    love.graphics.circle("fill", bx, by, C.BALL_RADIUS * (2.1 + 0.9 * heat))
    love.graphics.setColor(1, 1 - 0.10 * heat, 1 - 0.22 * heat, 1)
    love.graphics.circle("fill", bx, by, C.BALL_RADIUS)
  end

  love.graphics.setScissor()
  love.graphics.pop()

  -- Board nameplate
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(th.wall[1], th.wall[2], th.wall[3], active and 0.95 or 0.5)
  love.graphics.print(def.name:upper(), view.x, view.y - 15)
end

---------------------------------------------------------------------------
-- Transit
---------------------------------------------------------------------------

--- The ball in flight, drawn between the two boards. §10: this beat gets its
--- own moment, and it doubles as the handoff telegraph.
local function draw_transit(state, defs)
  local t = state.transit
  if not t then return end
  local vf, vt = M.view[t.from], M.view[t.to]
  local mf = defs[t.from].tube.mouth
  local et = defs[t.to].entry

  local x0, y0 = vf.x + mf.x * vf.s, vf.y + mf.y * vf.s
  local x1, y1 = vt.x + et.x * vt.s, vt.y + et.y * vt.s
  local cx, cy = (x0 + x1) / 2, math.min(y0, y1) - 90   -- arc up over the gap

  local function at(u)
    local iu = 1 - u
    return iu*iu*x0 + 2*iu*u*cx + u*u*x1, iu*iu*y0 + 2*iu*u*cy + u*u*y1
  end

  local u = math.min(1, t.t / t.duration)

  love.graphics.setColor(0.45, 0.95, 0.6, 0.30)
  love.graphics.setLineWidth(3)
  local pts = {}
  for i = 0, 24 do
    local px, py = at(i / 24)
    pts[#pts+1], pts[#pts+2] = px, py
  end
  love.graphics.line(pts)

  -- The travelled part of the arc, brightened: the ball leaves a wake, so the
  -- direction of the pass is readable from a still frame.
  love.graphics.setColor(0.6, 1, 0.75, 0.55)
  love.graphics.setLineWidth(3)
  local wake = {}
  for i = 0, 16 do
    local px, py = at(u * i / 16)
    wake[#wake+1], wake[#wake+2] = px, py
  end
  if #wake >= 4 then love.graphics.line(wake) end

  local bx, by = at(u)
  love.graphics.setColor(0.6, 1, 0.75, 0.25)
  love.graphics.circle("fill", bx, by, 20)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", bx, by, 9)

  love.graphics.setFont(fonts.body)
  love.graphics.setColor(0.55, 0.95, 0.7, 0.9)
  local msg = ("IN TRANSIT  %.2fs   arriving at %.0f px/s   RALLY %d")
    :format(t.duration - t.t, t.speed, state.stats.relay)
  love.graphics.printf(msg, 0, H - 74, W, "center")

  -- A bar under the readout, because "0.43s" is a number you have to read and
  -- a shrinking bar is one you can see while watching the board instead.
  local bw = 260
  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.rectangle("fill", (W - bw) / 2, H - 52, bw, 5, 2)
  love.graphics.setColor(0.55, 0.95, 0.7, 0.85)
  love.graphics.rectangle("fill", (W - bw) / 2, H - 52, bw * (1 - u), 5, 2)
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

local HA = 1     -- HUD opacity, set per frame by draw()
local function col(r, g, b, a) love.graphics.setColor(r, g, b, (a or 1) * HA) end

local function bar(x, y, w, h, p, r, g, b)
  col(1, 1, 1, 0.10)
  love.graphics.rectangle("fill", x, y, w, h, 3)
  col(r, g, b, 1)
  love.graphics.rectangle("fill", x, y, w * math.max(0, math.min(1, p)), h, 3)
end

local function draw_hud(state, defs, snaps, legend)
  local x, y = M.hud_x, 380
  local active = state.active
  local def = defs[active]

  love.graphics.setFont(fonts.head)
  local transit = state.phase == "transit"
  col(1, 1, 1, 0.92)
  -- "PREPARING" rather than "ON": during the pass nobody is standing on this
  -- board yet, and the sender needs to know the devices they are reaching for
  -- are the ones under the ball's landing point (prototype.md §4.5).
  local head = (transit and "PREPARING " or "ON ") .. def.name:upper()
  love.graphics.print(head, x, y)
  if transit then
    -- Measured, not offset by a guess: "GLASSHOUSE" is long enough that a
    -- fixed x+210 printed the countdown straight through the board name.
    love.graphics.setFont(fonts.small)
    col(0.55, 0.95, 0.7, 0.85)
    love.graphics.print(("BALL INCOMING  %.2fs"):format(state.transit.duration - state.transit.t),
                        x + fonts.head:getWidth(head) + 14, y + 9)
  end
  y = y + 30

  -- Roles: implicit in ball position, so just report them (§4).
  local roles = { [1] = intents.role_of(1, active), [2] = intents.role_of(2, active) }
  love.graphics.setFont(fonts.body)
  for p = 1, 2 do
    local flip = roles[p] == "flipper"
    col(flip and 1 or 0.45, flip and 0.78 or 0.6, flip and 0.25 or 0.85, 1)
    -- Mid-pass the receiver is not flipping yet, they are waiting to catch.
    local label = flip and (transit and "RECEIVING" or "FLIPPER") or "OPERATOR"
    love.graphics.print(("P%d  %s"):format(p, label), x, y)
    local L = legend[p]
    col(1, 1, 1, 0.35)
    love.graphics.setFont(fonts.small)
    love.graphics.print(flip
      and ("%s / %s"):format(L.flip_left, L.flip_right)
      or  ("%s gate / %s post"):format(L.operator_gate, L.operator_paddle), x + 120, y + 3)
    love.graphics.setFont(fonts.body)
    y = y + 22
  end

  y = y + 14
  col(1, 1, 1, 0.5)
  love.graphics.setFont(fonts.small)
  love.graphics.print("OPERATOR DEVICES  (on " .. def.name .. ")", x, y)
  y = y + 18

  for _, d in ipairs(def.devices) do
    local p = snaps[active].devices[d.id].p
    local cmd = state.boards[active].devices[d.id].commanded
    love.graphics.setFont(fonts.body)
    col(1, 1, 1, 0.9)
    love.graphics.print(cmd and d.label_open or d.label_closed, x, y)
    bar(x + 92, y + 5, 150, 8, p, lerp(0.35, 1.0, p), lerp(0.45, 0.72, p), lerp(0.55, 0.20, p))
    love.graphics.setFont(fonts.small)
    col(1, 1, 1, 0.42)
    love.graphics.print(d.tradeoff, x, y + 19)
    y = y + 42
  end

  -- The prototype's instrument panel (§14: does the rally feel good?).
  -- The multiplier is the biggest thing on it on purpose: §9 puts the entire
  -- risk curve on relay heat, so it is the one number both players are
  -- deciding against every time they choose whether to pass.
  local st   = state.stats
  local heat = score.heat(st.relay)
  local hot  = math.min(1, (heat - 1) / (C.HEAT_MAX - 1))

  y = y + 8
  col(1, 1, 1, 0.45)
  love.graphics.setFont(fonts.small)
  love.graphics.print("SCORE", x, y)
  love.graphics.setFont(fonts.head)
  col(1, 1, 1, 0.92)
  love.graphics.print(commas(st.score), x + 60, y - 6)
  y = y + 30

  col(1, 1, 1, 0.45)
  love.graphics.setFont(fonts.small)
  love.graphics.print("RALLY", x, y + 12)
  love.graphics.setFont(fonts.huge)
  -- Green when cold, amber-hot as the multiplier climbs.
  col(lerp(0.55, 1.0, hot), lerp(0.95, 0.66, hot), lerp(0.70, 0.20, hot), 1)
  love.graphics.print(("x%d"):format(heat), x + 60, y)
  love.graphics.setFont(fonts.small)
  col(1, 1, 1, 0.5)
  love.graphics.print(("%d crossing%s"):format(st.relay, st.relay == 1 and "" or "s"),
                      x + 130, y + 6)
  col(1, 1, 1, 0.42)
  love.graphics.print(("worth %s   best rally %s")
    :format(commas(st.rally_score), commas(st.best_rally_score)), x + 130, y + 22)
  y = y + 48

  col(1, 1, 1, 0.35)
  love.graphics.print(("best run %d crossings    passes %d    drains %d")
    :format(st.best_relay, st.passes, st.drains), x, y)

  -- Phase banner
  if state.phase == "serve" or state.phase == "drain" then
    love.graphics.setFont(fonts.head)
    col(1, 1, 1, 0.75)
    love.graphics.printf(state.phase == "drain" and "DRAINED" or "SERVING",
                         M.view[active].x, M.view[active].y + 300,
                         defs[active].size.w * M.view[active].s, "center")
  end

  love.graphics.setFont(fonts.small)
  col(1, 1, 1, 0.28)
  love.graphics.print("R restart    F1 debug    ESC quit", M.hud_x, H - 26)
end

---------------------------------------------------------------------------

function M.draw(match, legend, debug_on)
  love.graphics.clear(0.045, 0.045, 0.058)
  local state = match.state
  local heat  = heat_of(state)

  -- One shake for the whole frame, including the HUD: shaking the boards but
  -- not the panel next to them reads as a rendering fault rather than impact.
  local sx, sy = 0, 0
  if fx then sx, sy = fx.shake_offset() end
  love.graphics.push()
  love.graphics.translate(sx, sy)
  -- During transit the destination board counts as active: it is the one the
  -- operator is working on, and the one the ball is about to land on.
  local t = state.transit
  local incoming_u = t and math.min(1, t.t / t.duration) or nil
  for _, id in ipairs({ "a", "b" }) do
    draw_board(match.defs[id], match.cur[id], match.prev[id], match.alpha,
               M.view[id], id == state.active, heat,
               (t and id == t.to) and incoming_u or nil,
               state.boards[id] and state.boards[id].targets)
  end
  if state.phase == "transit" then draw_transit(state, match.defs) end
  HA = M.hud_a
  if HA > 0.02 then draw_hud(state, match.defs, match.cur, legend) end
  HA = 1
  love.graphics.pop()

  if debug_on then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 1, 0.5, 0.8)
    local b = match.boards[state.active]
    -- Right-aligned: the HUD column moves from side to side, and a bottom-left
    -- readout collides with it when the HUD is on the left.
    love.graphics.printf(("tick %d  phase %s  fps %d  ball %.0f px/s  acc %.4f")
      :format(state.tick, state.phase, love.timer.getFPS(), b:ball_speed(), match.acc),
      0, H - 18, RIGHT_EDGE, "right")
  end
end

return M
