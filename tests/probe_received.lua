--- Can a RECEIVED ball be passed on? The same player model as the
--- received-ball gate in tests/sim/spec.lua, with more attempts, every lead
--- time printed, and where the misses went. Use it before moving anything
--- near a funnel or an entry point.
---
---   PINPALS_SUITE=tests.probe_received love . --test [a|b]
return function()
  local C      = require("core.constants")
  local Board  = require("sim.board")
  local boards = require("data.tables.init").load()
  local N = tonumber(os.getenv("N") or "48")

  local function cmd(left, right)
    return { flippers = { left = left, right = right },
             devices = { gate = { commanded = true }, post = { commanded = false } } }
  end

  local TRACE = os.getenv("TRACE")
  local function attempt(def, lead, i)
    math.randomseed(4242 + i * 977)
    local b = Board.new(def)
    local e = def.entry
    local speed = C.TRANSIT_MIN_SP + (C.TRANSIT_MAX_SP - C.TRANSIT_MIN_SP) * math.random()
    local ang = math.atan2(e.dir.y, e.dir.x) + (math.random() * 2 - 1) * 0.10
    for _ = 1, math.floor(0.45 * C.TICK_HZ) do b:step(cmd(false, false), false) end
    b:spawn(e.x + (math.random() * 2 - 1) * 6, e.y, math.cos(ang) * speed, math.sin(ang) * speed)
    local fired, held, side = false, 0, nil
    local SWING = math.floor(0.22 * C.TICK_HZ)
    local mid = def.size.w / 2
    for tick = 1, math.floor(6 * C.TICK_HZ) do
      local bx, by = b:ball_pos()
      if not bx then break end
      if TRACE and tick % 24 == 0 then io.write(("(%.0f,%.0f) "):format(bx, by)) end
      local _, vy = b:ball_velocity()
      local fy = def.flippers[1].y
      if not fired and vy > 0 and by < fy and (fy - by) / vy <= lead then
        fired, held = true, 0
        side = (bx < mid) and "left" or "right"
      end
      local flipping = false
      if fired then
        held = held + 1
        flipping = held < SWING
        if held >= SWING * 2 then fired = false end
      end
      for _, ev in ipairs(b:step(cmd(flipping and side == "left", flipping and side == "right"), true)) do
        if ev.kind == "tube" then b.world:destroy(); return "pass" end
        if ev.kind == "drain" then
          local x = bx
          b.world:destroy()
          if x < 60 then return "left out" end
          if x > def.size.w - 60 then return "right out" end
          return "centre"
        end
      end
    end
    b.world:destroy()
    return "alive"
  end

  local which
  for _, v in ipairs(arg or {}) do if v == "a" or v == "b" then which = v end end
  for _, id in ipairs(which and { which } or { "a", "b" }) do
    local def = boards[id]
    print(("RECEIVED on %s, %d arrivals per lead"):format(def.name, N))
    if TRACE then
      for i = 1, 6 do print("\n" .. attempt(def, 0.03, i)) end
      return
    end
    for _, lead in ipairs({ 0.01, 0.02, 0.03, 0.04, 0.05 }) do
      local t = { pass = 0, centre = 0, ["left out"] = 0, ["right out"] = 0, alive = 0 }
      for i = 1, N do local r = attempt(def, lead, i); t[r] = t[r] + 1 end
      print(("  lead %.2f  pass %3.0f%%  centre %3.0f%%  left out %3.0f%%  right out %3.0f%%  alive %3.0f%%")
        :format(lead, 100 * t.pass / N, 100 * t.centre / N, 100 * t["left out"] / N,
                100 * t["right out"] / N, 100 * t.alive / N))
    end
  end
end
