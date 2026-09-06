--- A long random-play soak with invariants checked every single tick.
---
--- Written after a night of stacking systems on each other -- scoring,
--- cross-board meters, purgatory rescue, an objective readout -- each of
--- which is tested in isolation and none of which was tested against the
--- others running for half an hour. The bugs that survive unit tests are the
--- ones that need two features and twenty minutes.
---
---   PINPALS_SUITE=tests.probe_soak love . --test [minutes]

return function()
  local C         = require("core.constants")
  local Match     = require("sim.match")
  local objective = require("core.objective")
  local boards    = require("data.tables.init").load()

  local minutes = 10
  for _, v in ipairs(arg or {}) do
    local n = tonumber(v)
    if n and n > 0 and n < 600 then minutes = n end
  end

  local PHASES = {
    serve = true, play = true, transit = true, purgatory = true, drain = true,
  }
  local names = {}
  for id, def in pairs(boards) do names[id] = def.name end

  math.randomseed(1312)
  local m = Match.new(boards)
  local steps = math.floor(minutes * 60 * C.TICK_HZ)
  local seen  = {}
  local worst_feed, worst_meter = 0, 0
  local fails = {}

  local function fail(tick, msg)
    if #fails < 12 then fails[#fails+1] = ("tick %d: %s"):format(tick, msg) end
  end

  for i = 1, steps do
    if i % 22 == 0 then
      local s = m.state
      for _, b in pairs(s.boards) do
        if math.random() < 0.30 then b.devices.gate.commanded = math.random() < 0.6 end
        if math.random() < 0.25 then b.devices.post.commanded = math.random() < 0.4 end
        -- §6.2 The outlane guard, switched often. The bar sweeps the whole
        -- length of its lane on every change, so this is where a ball ridden
        -- down out of play, or wedged against a moving kinematic body, would
        -- show up over ten minutes.
        if b.guard and math.random() < 0.15 then
          b.guard = (math.random() < 0.5) and "left" or "right"
        end
      end
      local act = s.boards[s.active]
      act.flippers.left  = math.random() < 0.4
      act.flippers.right = math.random() < 0.4
    end
    m:run(1)
    local s = m.state
    seen[s.phase] = (seen[s.phase] or 0) + 1

    if not PHASES[s.phase] then fail(i, "unknown phase " .. tostring(s.phase)) end

    -- Exactly one ball while playing, and none while it is elsewhere.
    local balls = 0
    for _, b in pairs(m.boards) do if b.ball then balls = balls + 1 end end
    if s.phase == "play" and balls ~= 1 then
      fail(i, ("phase play with %d balls"):format(balls))
    elseif s.phase ~= "play" and balls > 1 then
      fail(i, ("phase %s with %d balls"):format(s.phase, balls))
    end

    -- Scores only ever go up; a rally never exceeds the session.
    if s.stats.score < 0 or s.stats.rally_score < 0 then fail(i, "negative score") end
    if s.stats.rally_score > s.stats.score then fail(i, "rally exceeds session score") end
    if s.stats.relay > s.stats.best_relay then fail(i, "relay exceeds its own best") end

    -- The guard is on exactly one side at all times: it is one value, not
    -- two booleans, precisely so "both" and "neither" cannot be reached.
    for id, b in pairs(s.boards) do
      if b.guard ~= nil and b.guard ~= "left" and b.guard ~= "right" then
        fail(i, ("%s guard is %s"):format(id, tostring(b.guard)))
      end
      -- And the cooldown only ever counts down, from one save's worth. A
      -- value above the constant means something re-armed a running timer,
      -- which is how "works once" quietly becomes "works once per contact".
      local cool = b.guard_cooldown or 0
      if cool < 0 or cool > C.GUARD_COOLDOWN then
        fail(i, ("%s guard cooldown out of range: %.2f"):format(id, cool))
      end
    end

    -- Cross-board meters stay in range, and lit counters never go negative.
    for id, b in pairs(s.boards) do
      for name, v in pairs(b.meters) do
        if v < 0 or v > C.CHARGE_MAX then
          fail(i, ("%s meter %s out of range: %d"):format(id, name, v))
        end
        if v > worst_meter then worst_meter = v end
      end
      if (b.lit.bumpers or 0) < 0 then fail(i, id .. " lit went negative") end
      if (b.lit.bumpers or 0) > C.LIT_HITS then fail(i, id .. " lit exceeds its grant") end
    end

    -- The readout must always have something to say (checked live, because a
    -- state that only occurs after twenty minutes is exactly the one that
    -- would return nil).
    local ok, o = pcall(objective.current, s, names)
    if not ok then fail(i, "objective errored: " .. tostring(o))
    elseif not (o and o.text and #o.text > 0) then fail(i, "objective was empty") end

    if #m.feed > worst_feed then worst_feed = #m.feed end
    if i % 4000 == 0 then m:drain_events() end       -- a renderer draining
  end

  local st = m.state.stats
  print("")
  print(("soak: %d minutes of random play, %d ticks"):format(minutes, steps))
  print(("  score %d   passes %d   drains %d   rescues %d   best rally %d")
    :format(st.score, st.passes, st.drains, st.rescues, st.best_relay))
  local order = { "serve", "play", "transit", "purgatory", "drain" }
  local parts = {}
  for _, p in ipairs(order) do
    parts[#parts+1] = ("%s %.0f%%"):format(p, 100 * (seen[p] or 0) / steps)
  end
  print("  time by phase: " .. table.concat(parts, "   "))
  print(("  peak feed %d (cap 96)   peak meter %d (cap %d)")
    :format(worst_feed, worst_meter, C.CHARGE_MAX))
  if #fails == 0 then
    print("  invariants: all held")
  else
    print(("  INVARIANTS BROKEN (%d shown):"):format(#fails))
    for _, f in ipairs(fails) do print("    " .. f) end
  end
  print("")
  return #fails == 0
end
