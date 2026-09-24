--- What does Glasshouse's magnet catch, and what happens when it lets go?
---
--- Two questions, because a magnet can fail either way: one that misses
--- fast balls is scenery, and one whose release drops the ball into the drain
--- is a trap the operator springs on their own partner.
---
---   catch    a ball crossing the field at a sweep of speeds and offsets,
---            magnet fully on. Caught = at rest on the centre within 1s.
---   release  a caught ball let go, flippers parked and then flipped once:
---            where does the drop go?
---   play     random flipper play with an operator who engages the magnet
---            whenever the ball is falling inside its rim, against one who
---            never does. Drains per ball is the save the device is worth.
---
---   PINPALS_SUITE=tests.probe_magnet love . --test
return function()
  local C      = require("core.constants")
  local Board  = require("sim.board")
  local boards = require("data.tables.init").load()
  local def    = boards.b
  local mag
  for _, d in ipairs(def.devices) do if d.kind == "magnet" then mag = d end end
  assert(mag, "board b has no magnet")

  local function cmd(on, left, right)
    return { flippers = { left = left or false, right = right or false },
             devices  = { post = { commanded = false }, [mag.id] = { commanded = on } } }
  end

  local function destroy(b) b.world:destroy() end

  --- Catch sweep.
  local caught, total = 0, 0
  local by_speed = {}
  for _, speed in ipairs({ 200, 400, 700, 1000, 1400 }) do
    local n, k = 0, 0
    for _, off in ipairs({ -30, -15, 0, 15, 30 }) do
      for _, ang in ipairs({ -0.4, 0, 0.4 }) do
        local b = Board.new(def)
        -- Magnet already at full field, ball arriving from above the rim.
        for _ = 1, math.ceil(mag.travel * C.TICK_HZ) + 1 do b:step(cmd(true), false) end
        b:spawn(mag.x + off - math.sin(ang) * mag.r, mag.y - mag.r - 4,
                math.sin(ang) * speed, math.cos(ang) * speed)
        local ok = false
        for _ = 1, C.TICK_HZ do
          b:step(cmd(true), true)
          local x, y = b:ball_pos()
          if not x then break end
          if math.abs(x - mag.x) < C.MAGNET_HOLD_R and math.abs(y - mag.y) < C.MAGNET_HOLD_R
             and b:ball_speed() < 30 then ok = true break end
        end
        n, total = n + 1, total + 1
        if ok then k, caught = k + 1, caught + 1 end
        destroy(b)
      end
    end
    by_speed[#by_speed+1] = ("    %5d px/s   %2d / %d"):format(speed, k, n)
  end
  print("")
  print(("MAGNET catch: %d / %d crossings caught"):format(caught, total))
  for _, line in ipairs(by_speed) do print(line) end

  --- Release: hold, let go, then the flipper player gets one flip timed to
  --- the ball reaching the flipper. Counts where it ends up after 4s.
  local out = {}
  for _, delay in ipairs({ 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25 }) do
    local b = Board.new(def)
    for _ = 1, math.ceil(mag.travel * C.TICK_HZ) + 1 do b:step(cmd(true), false) end
    b:spawn(mag.x, mag.y, 0, 0)
    for _ = 1, C.TICK_HZ do b:step(cmd(true), true) end
    local result = "alive"
    local flip_at = math.floor(delay * C.TICK_HZ)
    for t = 1, 4 * C.TICK_HZ do
      local flip = t >= flip_at and t < flip_at + math.floor(0.22 * C.TICK_HZ)
      for _, ev in ipairs(b:step(cmd(false, false, flip), true)) do
        if ev.kind == "drain" then result = "drain" end
        if ev.kind == "tube" then result = "pass" end
        if ev.kind == "target" then result = result == "alive" and "target" or result end
      end
      if result == "drain" or result == "pass" then break end
    end
    out[#out+1] = ("    flip %.2fs after release -> %s"):format(delay, result)
    destroy(b)
  end
  print("")
  print("MAGNET release, right flipper flipped once:")
  for _, line in ipairs(out) do print(line) end

  --- Play: does an attentive operator save balls?
  local function play(seed, attentive)
    math.randomseed(seed)
    local b = Board.new(def, seed)
    b:serve()
    local balls, drains = 1, 0
    local on, heat, cool, rest = false, 0, 0, 0
    local c = cmd(false)
    for i = 1, 180 * C.TICK_HZ do
      if i % 30 == 0 then
        c = cmd(false, math.random() < 0.35, math.random() < 0.35)
      end
      -- A person, not a servo: they see the ball dropping toward the magnet,
      -- press, hold it for a beat once it is caught, let go for the flipper,
      -- and do not immediately re-grab the ball they just dropped.
      local want = false
      rest = math.max(0, rest - C.FIXED_DT)
      if attentive and rest <= 0 then
        local x, y = b:ball_pos()
        local _, vy = b:ball_velocity()
        if x and vy > -50 and y > mag.y - mag.r * 2 and y < mag.y + mag.r
           and math.abs(x - mag.x) < mag.r then want = true end
        if on and not b.devices[mag.id].holding and y and y > mag.y + mag.r then want = false end
        if b.devices[mag.id].holding and heat > 0.6 then want = false; rest = 1.5 end
      end
      -- Mirror core/state.lua's duty limit, which this bare Board skips.
      if cool > 0 then cool = cool - C.FIXED_DT; want = false
      elseif want then heat = heat + C.FIXED_DT
        if heat >= mag.max_on then heat, cool, want = 0, mag.cooldown, false end
      else heat = math.max(0, heat - C.FIXED_DT) end
      on = want
      c.devices[mag.id].commanded = on
      local dead = false
      for _, ev in ipairs(b:step(c, true)) do
        if ev.kind == "drain" then drains = drains + 1; dead = true end
        if ev.kind == "tube" then dead = true end
      end
      if dead then b:serve(); balls = balls + 1 end
    end
    destroy(b)
    return balls, drains
  end
  print("")
  print("MAGNET in play, 180s x 8 seeds, random flippers:")
  for _, attentive in ipairs({ false, true }) do
    local tb, td = 0, 0
    for seed = 1, 8 do
      local balls, drains = play(4100 + seed * 37, attentive)
      tb, td = tb + balls, td + drains
    end
    print(("    %-10s balls %4d  drains %4d  drain share %.0f%%")
      :format(attentive and "attentive" or "idle", tb, td, 100 * td / tb))
  end
end
