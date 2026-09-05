--- Static geometry checks for board data.
---
--- Every board bug in the 2026-09-05 playtest was a coordinate typo that only
--- showed up after thousands of simulated ball drops. All of them are visible
--- in the data. This module finds them without running physics, so a bad edit
--- fails in milliseconds with the offending coordinate named, instead of as a
--- ball quietly sitting still somewhere during play.
---
--- Pure Lua. No love.* here.

local C = require("core.constants")

local M = {}

local BALL_D = C.BALL_RADIUS * 2

---------------------------------------------------------------------------
-- Small geometry helpers
---------------------------------------------------------------------------

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

--- The four corners of a rotated rectangle, as a flat x,y list.
---
--- Exported because three layers need to agree on exactly where a target is:
--- sim/ builds a polygon fixture from it, this module checks its clearances,
--- and app/ draws it. Three copies of this arithmetic would be three chances
--- for the picture to disagree with the physics.
---@param t table x, y, w, h, angle
---@return number[] eight numbers, four corners clockwise
function M.rect_corners(t)
  local a = t.angle or 0
  local c, s = math.cos(a), math.sin(a)
  local hw, hh = t.w / 2, t.h / 2
  local out = {}
  for _, p in ipairs({ { -hw, -hh }, { hw, -hh }, { hw, hh }, { -hw, hh } }) do
    out[#out+1] = t.x + p[1] * c - p[2] * s
    out[#out+1] = t.y + p[1] * s + p[2] * c
  end
  return out
end

--- Distance from a point to a segment, and the closest point on it.
local function point_seg(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local l2 = dx*dx + dy*dy
  local t = (l2 > 0) and clamp(((px-ax)*dx + (py-ay)*dy) / l2, 0, 1) or 0
  local qx, qy = ax + dx*t, ay + dy*t
  return math.sqrt((px-qx)^2 + (py-qy)^2), qx, qy
end

local function cross(ox, oy, px, py, qx, qy)
  return (px-ox)*(qy-oy) - (py-oy)*(qx-ox)
end

--- Minimum distance between two segments. Zero if they properly cross.
local function seg_seg(a1x,a1y,a2x,a2y, b1x,b1y,b2x,b2y)
  local d1 = cross(a1x,a1y,a2x,a2y,b1x,b1y)
  local d2 = cross(a1x,a1y,a2x,a2y,b2x,b2y)
  local d3 = cross(b1x,b1y,b2x,b2y,a1x,a1y)
  local d4 = cross(b1x,b1y,b2x,b2y,a2x,a2y)
  if ((d1 > 0) ~= (d2 > 0)) and ((d3 > 0) ~= (d4 > 0)) then return 0 end
  local best = math.huge
  best = math.min(best, (point_seg(b1x,b1y, a1x,a1y,a2x,a2y)))
  best = math.min(best, (point_seg(b2x,b2y, a1x,a1y,a2x,a2y)))
  best = math.min(best, (point_seg(a1x,a1y, b1x,b1y,b2x,b2y)))
  best = math.min(best, (point_seg(a2x,a2y, b1x,b1y,b2x,b2y)))
  return best
end

--- Wrap an angle to [-pi, pi].
local function norm(a)
  while a >  math.pi do a = a - 2*math.pi end
  while a < -math.pi do a = a + 2*math.pi end
  return a
end

--- Flatten every polyline into a list of segments.
local function segments_of(board)
  local segs = {}
  for pi, poly in ipairs(board.walls or {}) do
    for i = 1, #poly - 3, 2 do
      segs[#segs+1] = {
        ax = poly[i], ay = poly[i+1], bx = poly[i+2], by = poly[i+3],
        poly = pi, index = (i + 1) / 2,
      }
    end
  end
  return segs
end

---------------------------------------------------------------------------
-- 1. Bowls
---------------------------------------------------------------------------

--- A vertex lower than everything it connects to is a bowl: the ball rolls in
--- and stays. A vertex higher than its neighbours is a peak, which sheds the
--- ball and is fine -- so this is not "the chain must be monotone", it is
--- "the chain must never turn back up".
---
--- Vertices are keyed by position, so a bowl formed where two separate
--- polylines meet is caught the same way as one inside a single chain. Board
--- A's (300,702) and board B's (84,702) were both of the first kind.
local function check_bowls(board, segs, out)
  local at = {}
  local function key(x, y) return ("%.1f,%.1f"):format(x, y) end
  local function add(x, y, ox, oy)
    local k = key(x, y)
    at[k] = at[k] or { x = x, y = y, n = {} }
    table.insert(at[k].n, { x = ox, y = oy })
  end
  for _, s in ipairs(segs) do
    add(s.ax, s.ay, s.bx, s.by)
    add(s.bx, s.by, s.ax, s.ay)
  end

  for _, v in pairs(at) do
    -- A free end connects to only one segment and cannot hold anything.
    if #v.n >= 2 and v.y <= board.drain_y then
      local lowest, strict = true, false
      for _, n in ipairs(v.n) do
        if n.y > v.y + 1e-6 then lowest = false break end
        if n.y < v.y - 1e-6 then strict = true end
      end
      if lowest and strict then
        out[#out+1] = {
          kind = "bowl", x = v.x, y = v.y,
          msg = ("wall vertex (%g, %g) is lower than everything it joins: the ball settles here")
                :format(v.x, v.y),
        }
      end
    end
  end
end

---------------------------------------------------------------------------
-- 2. Walls inside a flipper
---------------------------------------------------------------------------

--- A wall inside the arc a flipper sweeps either jams the flipper or creates a
--- notch behind the pivot that the flipper rotates away from, so a slow ball
--- sits there untouchable. Board A's lower-left chain used to end at
--- (133,692), four pixels under its own pivot.
local function check_flipper_arcs(board, segs, out)
  local half = C.FLIPPER_THICK / 2
  local reach = C.FLIPPER_LEN + half

  for _, f in ipairs(board.flippers or {}) do
    local left = f.side == "left"
    local rest = left and  C.FLIPPER_REST or -C.FLIPPER_REST
    local up   = left and  C.FLIPPER_UP   or -C.FLIPPER_UP
    local lo, hi = math.min(rest, up), math.max(rest, up)
    local worst

    for _, s in ipairs(segs) do
      local len = math.sqrt((s.bx-s.ax)^2 + (s.by-s.ay)^2)
      local steps = math.max(1, math.ceil(len / 2))
      for i = 0, steps do
        local t = i / steps
        local px, py = s.ax + (s.bx-s.ax)*t, s.ay + (s.by-s.ay)*t
        local dx, dy = px - f.x, py - f.y
        local r = math.sqrt(dx*dx + dy*dy)
        if r <= reach then
          local inside
          if r <= half then
            inside = true                     -- effectively on the pivot
          else
            -- The body's rectangle runs along +x for a left flipper and -x for
            -- a right one, so a right flipper's world angle is theta + pi.
            local theta = norm(left and math.atan2(dy, dx)
                                    or (math.atan2(dy, dx) - math.pi))
            local slack = math.asin(clamp(half / r, -1, 1))
            inside = theta >= lo - slack and theta <= hi + slack
          end
          if inside and (not worst or r < worst.r) then
            worst = { x = px, y = py, r = r, seg = s }
          end
        end
      end
    end

    if worst then
      out[#out+1] = {
        kind = "flipper-jam", x = worst.x, y = worst.y,
        msg = ("wall %d passes through the %s flipper's swept arc at (%.0f, %.0f), %.1fpx from the pivot")
              :format(worst.seg.poly, f.side, worst.x, worst.y, worst.r),
      }
    end
  end
end

---------------------------------------------------------------------------
-- 3. Wedges
---------------------------------------------------------------------------

--- Two surfaces closer together than the ball is wide form a throat the ball
--- cannot pass but can rest in. Board B's two rails converged to 10.8px and
--- caught the ball 19 times in 182 drops -- they never actually crossed, which
--- is why "do any walls intersect?" would not have found it.
local function check_wedges(board, segs, out)
  local function adjacent(a, b)
    local pts = { {a.ax,a.ay}, {a.bx,a.by} }
    for _, p in ipairs(pts) do
      if (math.abs(p[1]-b.ax) < 0.5 and math.abs(p[2]-b.ay) < 0.5)
      or (math.abs(p[1]-b.bx) < 0.5 and math.abs(p[2]-b.by) < 0.5) then return true end
    end
    return false
  end

  for i = 1, #segs do
    for j = i + 1, #segs do
      local a, b = segs[i], segs[j]
      if not adjacent(a, b) then
        local d = seg_seg(a.ax,a.ay,a.bx,a.by, b.ax,b.ay,b.bx,b.by)
        if d < BALL_D then
          local _, qx, qy = point_seg(b.ax, b.ay, a.ax, a.ay, a.bx, a.by)
          out[#out+1] = {
            kind = "wedge", x = qx, y = qy,
            msg = ("walls %d and %d come within %.1fpx near (%.0f, %.0f); the ball is %.1fpx wide")
                  :format(a.poly, b.poly, d, qx, qy, BALL_D),
          }
        end
      end
    end
  end

  -- Bumpers make the same throat against a wall, or against each other.
  for bi, bump in ipairs(board.bumpers or {}) do
    for _, s in ipairs(segs) do
      local d = (point_seg(bump.x, bump.y, s.ax, s.ay, s.bx, s.by)) - bump.r
      if d < BALL_D then
        out[#out+1] = {
          kind = "wedge", x = bump.x, y = bump.y,
          msg = ("bumper %d sits %.1fpx from wall %d; the ball is %.1fpx wide")
                :format(bi, d, s.poly, BALL_D),
        }
      end
    end
    for bj = bi + 1, #board.bumpers do
      local o = board.bumpers[bj]
      local d = math.sqrt((bump.x-o.x)^2 + (bump.y-o.y)^2) - bump.r - o.r
      if d < BALL_D then
        out[#out+1] = {
          kind = "wedge", x = bump.x, y = bump.y,
          msg = ("bumpers %d and %d are %.1fpx apart; the ball is %.1fpx wide")
                :format(bi, bj, d, BALL_D),
        }
      end
    end
  end

  -- Targets are solid too: a standup parked a sub-ball-width from a wall is
  -- a pocket in exactly the way a bumper is, and it is easier to author by
  -- accident because a target is small and its angle is easy to get wrong.
  for ti, t in ipairs(board.targets or {}) do
    local c = M.rect_corners(t)
    for e = 0, 3 do
      local i = e * 2 + 1                      -- this corner
      local j = ((e + 1) % 4) * 2 + 1          -- the next one, wrapping
      for _, w in ipairs(segs) do
        local d = seg_seg(c[i], c[i+1], c[j], c[j+1], w.ax, w.ay, w.bx, w.by)
        if d < BALL_D then
          out[#out+1] = {
            kind = "wedge", x = t.x, y = t.y,
            msg = ("target %d sits %.1fpx from wall %d; the ball is %.1fpx wide")
                  :format(ti, d, w.poly, BALL_D),
          }
        end
      end
    end

    -- And against each other. A bank is authored as a row of near-identical
    -- entries, which makes it very easy to space them by less than they are
    -- wide -- at which point they overlap into one bar on screen and form a
    -- throat between them in the physics. Both happened on the first draft of
    -- Glasshouse's bank, and only the picture gave it away.
    for tj = ti + 1, #board.targets do
      local o = board.targets[tj]
      local oc = M.rect_corners(o)
      local best = math.huge
      for e1 = 0, 3 do
        local a1, b1 = e1 * 2 + 1, ((e1 + 1) % 4) * 2 + 1
        for e2 = 0, 3 do
          local a2, b2 = e2 * 2 + 1, ((e2 + 1) % 4) * 2 + 1
          best = math.min(best, seg_seg(c[a1], c[a1+1], c[b1], c[b1+1],
                                        oc[a2], oc[a2+1], oc[b2], oc[b2+1]))
        end
      end
      if best < BALL_D then
        out[#out+1] = {
          kind = "wedge", x = t.x, y = t.y,
          msg = ("targets %d and %d are %.1fpx apart; the ball is %.1fpx wide")
                :format(ti, tj, best, BALL_D),
        }
      end
    end
  end
end

---------------------------------------------------------------------------
-- 4. Devices that do not do what they claim
---------------------------------------------------------------------------

--- Both halves of a gate are load-bearing and both are easy to get wrong by a
--- few degrees: closed it has to actually seal the ramp, and open it has to
--- leave the ball room to get past. An earlier open angle left 3px of
--- clearance, which is the sort of thing that reads fine on screen and then
--- eats one shot in five.
local function check_devices(board, segs, out)
  for _, d in ipairs(board.devices or {}) do
    if d.kind == "gate" then
      local tx = d.pivot.x + math.cos(d.closed) * d.length
      local ty = d.pivot.y + math.sin(d.closed) * d.length
      local best, nearest = math.huge, nil
      for _, s in ipairs(segs) do
        local dist = (point_seg(tx, ty, s.ax, s.ay, s.bx, s.by))
        if dist < best then best, nearest = dist, s end
      end
      if best >= BALL_D then
        out[#out+1] = {
          kind = "gate-leaks", x = tx, y = ty,
          msg = ("%s: closed, its tip stops %.1fpx short of the nearest wall; the ball slips past")
                :format(d.id, best),
        }
      elseif nearest then
        local ox = d.pivot.x + math.cos(d.open) * d.length
        local oy = d.pivot.y + math.sin(d.open) * d.length
        local gap = seg_seg(d.pivot.x, d.pivot.y, ox, oy,
                            nearest.ax, nearest.ay, nearest.bx, nearest.by)
                    - C.GATE_THICK / 2
        if gap <= BALL_D then
          out[#out+1] = {
            kind = "gate-blocks", x = ox, y = oy,
            msg = ("%s: open, it leaves only %.1fpx of clearance; the ball is %.1fpx wide")
                  :format(d.id, gap, BALL_D),
          }
        end
      end

    elseif d.kind == "paddle" then
      -- The post exists to plug the gap between the flipper tips. If it does
      -- not span that gap it is guarding nothing, and if it does not retract
      -- clear of the playfield it is guarding it permanently.
      local lo, hi
      for _, f in ipairs(board.flippers or {}) do
        local sgn = (f.side == "left") and 1 or -1
        local tip = f.x + sgn * C.FLIPPER_LEN * math.cos(C.FLIPPER_REST)
        if f.side == "left" then lo = tip else hi = tip end
      end
      if lo and hi then
        if d.up.x - d.w/2 > lo or d.up.x + d.w/2 < hi then
          out[#out+1] = {
            kind = "post-misses", x = d.up.x, y = d.up.y,
            msg = ("%s: raised it spans %.0f..%.0f, but the drain gap is %.0f..%.0f")
                  :format(d.id, d.up.x - d.w/2, d.up.x + d.w/2, lo, hi),
          }
        end
      end
      if d.down.y - d.h/2 <= board.drain_y then
        out[#out+1] = {
          kind = "post-stuck-out", x = d.down.x, y = d.down.y,
          msg = ("%s: retracted it still reaches y=%.0f, above the drain line at %.0f")
                :format(d.id, d.down.y - d.h/2, board.drain_y),
        }
      end
    end
  end
end

---------------------------------------------------------------------------

--- Check one board's geometry.
---@param board table a board definition that has already passed validate.board
---@return table[] defects each { kind, msg, x, y }
function M.check(board)
  local out = {}
  local segs = segments_of(board)
  check_bowls(board, segs, out)
  check_flipper_arcs(board, segs, out)
  check_wedges(board, segs, out)
  check_devices(board, segs, out)
  table.sort(out, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    return (a.x + a.y * 1e-3) < (b.x + b.y * 1e-3)
  end)
  return out
end

--- Human-readable report for a whole board set.
---@return boolean clean, string[] lines
function M.report(boards)
  local lines, clean = {}, true
  for _, id in ipairs({ "a", "b" }) do
    local defects = M.check(boards[id])
    if #defects > 0 then
      clean = false
      for _, d in ipairs(defects) do
        lines[#lines+1] = ("board %s [%s] %s"):format(id, d.kind, d.msg)
      end
    end
  end
  return clean, lines
end

return M
