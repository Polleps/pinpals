--- Seeded Foundry shots: powered entry, completed rides, and post-loop returns.
--- PINPALS_SUITE=tests.probe_workshop love . --test
--- PINPALS_PASS_SWEEP=1 also compares alternative pass-lane placements.
return function()
  local C = require("core.constants")
  local Board = require("sim.board")
  local state = require("core.state")
  local defs = require("data.tables.init").load()
  local function shots(def, powered)
    local counts = { pass = 0, enter = 0, complete = 0, returned = 0, stalled = 0, n = 0 }
    local sides = {}
    for fi, side in ipairs({ "left", "right" }) do
      local made = 0
      for _, frac in ipairs({ 0.34, 0.48, 0.62, 0.76, 0.90 }) do
        for seed = 1, 14 do
          local rng = love.math.newRandomGenerator(9700 + seed * 31)
          local b = Board.new(def, 9700 + seed * 31)
          local s = state.new({ a = def, b = defs.b })
          local c = s.boards.a
          c.circuits.workshop.charge = powered and 3 or 0
          c.devices.gate.commanded = true
          for _ = 1, 100 do b:step(c, false) end
          local f, sign = def.flippers[fi], side == "left" and 1 or -1
          local d = C.FLIPPER_LEN * frac
          b:spawn(f.x + math.cos(C.FLIPPER_REST) * d * sign + (rng:random() - 0.5) * 5,
            f.y + math.sin(C.FLIPPER_REST) * d - C.BALL_RADIUS - 2 - rng:random() * 5,
            (rng:random() - 0.5) * 40, 0)
          for _ = 1, math.floor(0.12 * C.TICK_HZ) do b:step(c, true) end
          local entered, complete, passed, returned, still = false, false, false, false, 0
          local rescue_until, rescue_side = 0, nil
          for tick = 1, 9 * C.TICK_HZ do
            c.flippers.left = side == "left" and tick < 0.22 * C.TICK_HZ
            c.flippers.right = side == "right" and tick < 0.22 * C.TICK_HZ
            if rescue_side and tick < rescue_until then c.flippers[rescue_side] = true end
            local done = false
            for _, ev in ipairs(b:step(c, true)) do
              if ev.kind == "ramp" then
                if ev.at == "enter" then entered = true end
                if ev.complete then complete = true end
              elseif ev.kind == "tube" then passed, done = true, true
              elseif ev.kind == "drain" then done = true end
            end
            local x, y = b:ball_pos()
            if complete and y > 840 and y < 910 and x > def.flippers[1].x - 15 and x < def.flippers[2].x + 15 then
              returned = true
            end
            if b:ball_speed() < 30 then still = still + 1 else still = 0 end
            if still == C.TICK_HZ and not rescue_side then
              for _, paddle in ipairs(def.flippers) do
                if math.abs(x - paddle.x) < 20 and math.abs(y - paddle.y) < 25 then
                  rescue_side, rescue_until = paddle.side, tick + math.floor(0.22 * C.TICK_HZ)
                end
              end
            end
            if still > 3 * C.TICK_HZ then
              counts.stalled = counts.stalled + 1
              print(("  stuck %s seed %d frac %.2f at %.1f,%.1f"):format(side, seed, frac, x, y))
              break
            end
            if done then break end
          end
          counts.n = counts.n + 1
          if passed then counts.pass = counts.pass + 1; made = made + 1 end
          if entered then counts.enter = counts.enter + 1 end
          if complete then counts.complete = counts.complete + 1 end
          if returned then counts.returned = counts.returned + 1 end
          b.world:destroy()
        end
      end
      sides[side] = made
    end
    print(("powered=%s shots=%d pass=%d (L %d R %d) workshop=%d complete=%d return=%d stall=%d")
      :format(tostring(powered), counts.n, counts.pass, sides.left, sides.right,
        counts.enter, counts.complete, counts.returned, counts.stalled))
    return counts
  end
  if os.getenv("PINPALS_PASS_SWEEP") then
    local old = defs.a.tube.mouth.x
    for _, x in ipairs({ 380, 410, 440, 470, 500, 520 }) do
      local dx = x - old
      for i = 4, 6 do
        for j = 1, #defs.a.walls[i], 2 do defs.a.walls[i][j] = defs.a.walls[i][j] + dx end
      end
      defs.a.tube.mouth.x, old = x, x
      print("pass lane x", x)
      shots(defs.a, true)
    end
    return true
  end
  local cold, hot = shots(defs.a, false), shots(defs.a, true)
  return cold.enter == 0 and hot.complete > 0 and hot.returned > 0 and hot.stalled == 0
end
