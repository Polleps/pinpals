--- Headless physics tests. Run under `love . --test` with the window module
--- disabled: love.physics needs no window (§7).
---
--- These exist for risks table row 1 -- "Box2D can't deliver satisfying
--- pinball feel" -- which technical-choices.md §11 says to test FIRST.

return function(H)
  local describe, it, A = H.describe, H.it, H.assert

  local C       = require("core.constants")
  local intents = require("core.intents")
  local Board   = require("sim.board")
  local Match  = require("sim.match")
  local boards = require("data.tables.init").load()

  --- A core-shaped command block, so sim tests don't need core/state.
  local function cmd(gate, post, left, right)
    return { flippers = { left = left or false, right = right or false },
             devices  = { gate = { commanded = gate or false },
                          post = { commanded = post or false } } }
  end

  local function run(board, seconds, c, sink)
    local n = math.floor(seconds * C.TICK_HZ)
    for _ = 1, n do
      for _, ev in ipairs(board:step(c, board.ball ~= nil)) do
        if sink then sink[#sink+1] = ev end
      end
    end
  end

  describe("world construction", function()
    for _, id in ipairs({ "a", "b" }) do
      it(id .. " builds with two flippers and two devices", function()
        local b = Board.new(boards[id])
        A.truthy(b.flippers.left and b.flippers.right)
        A.truthy(b.devices.gate and b.devices.post)
        A.equal(64, love.physics.getMeter(), "world scale must come from constants (§4.2)")
      end)
    end
  end)

  describe("tunneling (§11)", function()
    it("a ball fired hard from anywhere never leaves through the geometry", function()
      math.randomseed(20260905)
      for _, id in ipairs({ "a", "b" }) do
        local def = boards[id]
        local b = Board.new(def)
        for trial = 1, 60 do
          local x = 30 + math.random() * (def.size.w - 60)
          local y = 40 + math.random() * 560
          local ang = math.random() * math.pi * 2
          local sp  = C.BALL_MAX_SPEED * (0.7 + 0.3 * math.random())
          b:spawn(x, y, math.cos(ang) * sp, math.sin(ang) * sp)
          for _ = 1, math.floor(1.5 * C.TICK_HZ) do
            local drained = false
            for _, ev in ipairs(b:step(cmd(), true)) do
              if ev.kind == "drain" then drained = true end
            end
            -- Draining is a legitimate exit; leaving any other way is not.
            if drained then break end
            local bx, by = b:ball_pos()
            local where = ("%s trial %d from (%.0f,%.0f)"):format(id, trial, x, y)
            A.between(-20, def.size.w + 20, bx, where .. ": escaped sideways")
            A.between(-20, def.drain_y, by, where .. ": escaped through the bottom")
          end
        end
        b:despawn()
      end
    end)

    it("never exceeds the speed at which thin edges start to leak", function()
      local def = boards.a
      local b = Board.new(def)
      b:spawn(192, 120, 900, 1600)
      local peak = 0
      for _ = 1, math.floor(4.0 * C.TICK_HZ) do
        b:step(cmd(), true)
        peak = math.max(peak, b:ball_speed())
      end
      A.truthy(peak <= C.BALL_MAX_SPEED * 1.02,
               ("bumpers pumped the ball to %.0f px/s"):format(peak))
      -- The ceiling has to keep per-step travel under one ball diameter.
      A.truthy(C.BALL_MAX_SPEED * C.FIXED_DT < C.BALL_RADIUS * 2,
               "the speed ceiling allows a step longer than the ball is wide")
    end)
  end)

  describe("the gate (§6.2: opens the pass, closes the safe return)", function()
    it("closed, a shot up the ramp comes back down instead of passing", function()
      local b = Board.new(boards.a)
      local ev = {}
      b:spawn(215, 520, 0, -C.SERVE_SPEED)     -- inside the ramp channel
      run(b, 2.0, cmd(false, false), ev)
      for _, e in ipairs(ev) do A.truthy(e.kind ~= "tube", "the ball passed through a closed gate") end
      local _, y = b:ball_pos()
      A.truthy(y > 300, "the ball should have been returned down the lane, y=" .. tostring(y))
    end)

    it("open, the same shot reaches the tube", function()
      local b = Board.new(boards.a)
      local c = cmd(true, false)
      run(b, 0.40, c)                       -- let the gate finish travelling
      A.between(0.98, 1.02, b:device_progress("gate"))
      local ev = {}
      b:spawn(215, 520, 0, -C.SERVE_SPEED)
      run(b, 1.5, c, ev)
      local passed = false
      for _, e in ipairs(ev) do if e.kind == "tube" then passed = true end end
      A.truthy(passed, "an open gate did not let the ball through")
    end)

    it("takes its stated travel time, both ways (§6.1)", function()
      for _, id in ipairs({ "a", "b" }) do
        local b = Board.new(boards[id])
        local travel = boards[id].devices[1].travel
        run(b, travel * 0.45, cmd(true, false))
        A.between(0.30, 0.70, b:device_progress("gate"),
                  id .. ": gate should be roughly half open half-way through")
        run(b, travel * 0.60, cmd(true, false))
        A.between(0.98, 1.02, b:device_progress("gate"), id .. ": gate never finished opening")
        run(b, travel * 1.10, cmd(false, false))
        A.between(-0.02, 0.02, b:device_progress("gate"), id .. ": gate never closed again")
      end
    end)
  end)

  describe("the post (§6.2: guards the drain, blocks the shots)", function()
    it("raised, it catches a ball headed straight down the middle", function()
      local b = Board.new(boards.a)
      local c = cmd(false, true)
      run(b, 0.35, c)
      A.between(0.98, 1.02, b:device_progress("post"))
      local ev = {}
      b:spawn(192, 380, 0, 0)
      run(b, 2.5, c, ev)
      for _, e in ipairs(ev) do A.truthy(e.kind ~= "drain", "the post let the ball through") end
    end)

    it("retracted, the same ball drains", function()
      local b = Board.new(boards.a)
      local ev = {}
      b:spawn(192, 380, 0, 0)
      run(b, 2.5, cmd(false, false), ev)
      local drained = false
      for _, e in ipairs(ev) do if e.kind == "drain" then drained = true end end
      A.truthy(drained, "the centre gap should be a real drain")
    end)

    it("settles the ball instead of jittering it forever", function()
      local b = Board.new(boards.a)
      local c = cmd(false, true)
      run(b, 0.35, c)
      b:spawn(192, 380, 0, 0)
      run(b, 3.0, c)
      A.truthy(b:ball_speed() < 2.0 * C.METER,
               "resting contact is jittering at " .. tostring(b:ball_speed()))
    end)
  end)

  describe("flippers", function()
    it("throw a resting ball hard enough to reach the top of the board", function()
      local b = Board.new(boards.a)
      -- Placed on the flipper face, not dropped: a resting flipper is a 30
      -- degree slope, so a dropped ball rolls off the tip before you can hit it.
      b:spawn(155, 686, 0, 0)
      local peak = 0
      local c = cmd(false, false, true, false)
      for _ = 1, math.floor(0.35 * C.TICK_HZ) do
        b:step(c, true)
        peak = math.max(peak, b:ball_speed())
      end
      -- Reaching y=100 from y=660 needs sqrt(2*g*560) = 888 px/s of upward
      -- velocity. A flipper that cannot do that cannot make the pass shot.
      A.truthy(peak > 888, "flipper launch too weak: " .. ("%.0f px/s"):format(peak))
    end)
  end)

  describe("the pass shot is makeable (design.md §5)", function()
    -- The prototype cannot answer "does the rally feel good?" if the pass
    -- cannot be made. An earlier layout put the ramp where no flipper shot
    -- reached: shots cross y=560 between x=145 and x=239, and the ramp was at
    -- x=328. It was hit 1 time in 30. This test exists so that cannot come
    -- back silently after a board-data edit.
    local on_flipper
    function on_flipper(fx, side, k)
      local sgn = (side == "left") and 1 or -1
      local a = C.FLIPPER_REST
      return fx + sgn * C.FLIPPER_LEN * k * math.cos(a),
             688 + C.FLIPPER_LEN * k * math.sin(a)
                 - (C.BALL_RADIUS + C.FLIPPER_THICK / 2) / math.cos(a)
    end

    for _, id in ipairs({ "a", "b" }) do
      for fi, side in ipairs({ "left", "right" }) do
        it(("%s: the %s flipper can reach the tube"):format(id, side), function()
          local def = boards[id]
          local made, tried = 0, 0
          for k = 0.25, 0.90, 0.09 do
            local b = Board.new(def)
            run(b, 0.40, cmd(true, false))                  -- gate already open
            b:spawn(on_flipper(def.flippers[fi].x, side, k))
            run(b, 12 * C.FIXED_DT, cmd(true, false))       -- settle into contact
            local c = cmd(true, false, side == "left", side == "right")
            local got = false
            for _ = 1, math.floor(3.5 * C.TICK_HZ) do
              for _, ev in ipairs(b:step(c, true)) do
                if ev.kind == "tube" then got = true end
              end
              if got then break end
            end
            tried = tried + 1
            if got then made = made + 1 end
          end
          A.truthy(made >= 2,
            ("the pass is not reachable from here: %d/%d"):format(made, tried))
        end)
      end
    end

    it("a: the ramp is not the only shot on the board", function()
      -- The companion to the test above, and the more important one. With the
      -- ramp mouth at y=600 the pass test passed at 62% while the board had
      -- exactly ONE shot: a sweep of 50 contact points found 0% reaching
      -- anywhere else on the playfield. A board where every shot has the same
      -- outcome gives the flipper player nothing to decide, which is pillar 1
      -- ("nobody waits") broken in the geometry rather than in the rules.
      --
      -- So: some shot, from somewhere on some flipper, must get the ball up
      -- the board OUTSIDE the ramp channel.
      -- Same spawn geometry as tests/probe_reach.lua, which is where the
      -- 14%/10% orbit figures in board_a.lua's comments come from. Resting
      -- the ball ON the flipper and then flipping is the shot a player is
      -- actually trying to make.
      local def, escaped, tried = boards.a, 0, 0
      for _, side in ipairs({ "left", "right" }) do
        local spec
        for _, f in ipairs(def.flippers) do if f.side == side then spec = f end end
        local sign = (side == "left") and 1 or -1
        local ang  = (side == "left") and C.FLIPPER_REST or -C.FLIPPER_REST
        for frac = 0.30, 1.00, 0.06 do
          local b = Board.new(def)
          local d = C.FLIPPER_LEN * frac
          b:spawn(spec.x + math.cos(ang) * d * sign,
                  spec.y + math.sin(ang) * d * sign - C.BALL_RADIUS - 2, 0, 0)
          run(b, 0.12, cmd())                       -- settle onto the flipper
          local held = cmd(true, false, side == "left", side == "right")
          local rest = cmd(true, false)
          local c, out = held, false
          for tick = 1, math.floor(4.0 * C.TICK_HZ) do
            if tick == math.floor(0.22 * C.TICK_HZ) then c = rest end
            local gone = false
            for _, ev in ipairs(b:step(c, true)) do
              if ev.kind == "tube" or ev.kind == "drain" then gone = true end
            end
            if gone then break end
            local bx, by = b:ball_pos()
            if not bx then break end
            -- Above the ramp neck and outside its channel: an orbit lane.
            if by < 520 and (bx < 180 or bx > 250) then out = true break end
          end
          tried = tried + 1
          if out then escaped = escaped + 1 end
        end
      end
      A.truthy(escaped >= 2,
        ("board a has only one shot again: %d of %d swept shots left the ramp")
          :format(escaped, tried))
    end)

    it("a: every bumper is reachable in play", function()
      -- Foundry's declared character is a bumper cluster that "keeps the ball
      -- alive". Two of its three bumpers were once hit exactly zero times in
      -- 180s, because the cluster sat in a dead band between the orbit lane
      -- and the ramp. A bumper nothing can reach is scenery, and this is the
      -- test that says so out loud.
      local def = boards.a
      local seen, total = {}, 0
      for seed = 1, 3 do
        math.randomseed(4100 + seed)
        local b = Board.new(def)
        b:serve()
        local c = cmd()
        for i = 1, math.floor(40 * C.TICK_HZ) do
          if i % 30 == 0 then
            c = cmd(math.random() < 0.55, math.random() < 0.2,
                    math.random() < 0.35, math.random() < 0.35)
          end
          local dead = false
          for _, ev in ipairs(b:step(c, b.ball ~= nil)) do
            if ev.kind == "drain" or ev.kind == "tube" then dead = true end
            if ev.kind == "bumper" then
              seen[ev.index] = (seen[ev.index] or 0) + 1
              total = total + 1
            end
          end
          if dead then b:serve() end
        end
      end
      for i = 1, #def.bumpers do
        A.truthy((seen[i] or 0) > 0,
          ("bumper %d is unreachable: it is scenery, not a device"):format(i))
      end
      -- Measured 0.60/s over 6 seeds; this floor is well under the noise.
      A.truthy(total / 120 > 0.15,
        ("the cluster is barely live: %.2f hits/s"):format(total / 120))
    end)

    it("but not while the post is up -- the device is a real trade (§6.2)", function()
      -- If raising the post cost nothing, the operator would just hold it up
      -- forever and there would be no conversation to have. Measured: the
      -- pass goes from ~60% to 0% while the post is raised.
      local def = boards.a
      local made = 0
      for k = 0.25, 0.90, 0.09 do
        local b = Board.new(def)
        run(b, 0.45, cmd(true, true))                 -- gate open AND post up
        b:spawn(on_flipper(def.flippers[2].x, "right", k))
        run(b, 12 * C.FIXED_DT, cmd(true, true))
        local c = cmd(true, true, false, true)
        for _ = 1, math.floor(3.5 * C.TICK_HZ) do
          for _, ev in ipairs(b:step(c, true)) do
            if ev.kind == "tube" then made = made + 1 end
          end
        end
      end
      A.truthy(made <= 1, ("the raised post is not blocking anything: %d passes"):format(made))
    end)
  end)

  describe("the fixed timestep (§4.1)", function()
    it("consumes real time in fixed chunks and never varies dt", function()
      local m = Match.new(boards)
      -- Deliberately ugly frame times: the simulation must not notice.
      local frames = { 1/60, 1/59.7, 1/144, 0.033, 1/60, 0.0001, 1/61.3 }
      local total, steps = 0, 0
      for _, dt in ipairs(frames) do
        total = total + dt
        steps = steps + m:advance(dt)
      end
      A.equal(steps, m.state.tick, "every fixed step must advance exactly one tick")
      -- The invariant that matters: real time is conserved. What has been
      -- simulated plus what is still owed equals what actually elapsed.
      A.near(total, steps * C.FIXED_DT + m.acc, 1e-9, "time was invented or lost")
      A.truthy(m.acc < C.FIXED_DT, "a whole step was left unconsumed")
      A.between(0, 1, m.alpha, "interpolation alpha out of range")
    end)

    it("discards a long hitch instead of spiralling to catch up", function()
      local m = Match.new(boards)
      local steps = m:advance(5.0)                 -- e.g. the window was dragged
      A.truthy(steps <= C.MAX_CATCHUP, "the catch-up cap did not hold: " .. steps)
      A.near(0.25 / C.FIXED_DT, steps, 1.5, "the 0.25s clamp is what should bound this")
      A.truthy(m.acc < C.FIXED_DT, "4.75 seconds of debt must be dropped, not banked")
    end)

    it("keeps up with a legitimately slow frame without dropping time", function()
      -- A 30 fps frame is 8 fixed steps. If the catch-up cap can fire here the
      -- game silently runs in slow motion on a slow machine.
      local m = Match.new(boards)
      local total = 0
      for _ = 1, 20 do total = total + 1/30; m:advance(1/30) end
      A.near(total, m.state.tick * C.FIXED_DT + m.acc, 1e-9, "time was dropped on a slow frame")
    end)
  end)

  describe("input bindings (§9)", function()
    local input = require("app.input")
    it("route both devices to the same intents", function()
      local k = input.from_key("a", true, 7)
      ---@cast k -nil
      A.equal(1, k.player); A.equal("flip_left", k.action); A.truthy(k.pressed); A.equal(7, k.tick)
      local k2 = input.from_key("down", false, 9)
      ---@cast k2 -nil
      A.equal(2, k2.player); A.equal("operator_paddle", k2.action); A.falsy(k2.pressed)
      A.falsy(input.from_key("q", true, 0), "unbound keys must produce no intent")
    end)

    it("give each player a full set of both roles' controls", function()
      for p = 1, 2 do
        local L = input.legend(p)
        for _, action in ipairs({ "flip_left", "flip_right", "operator_gate", "operator_paddle" }) do
          A.truthy(L[action], ("player %d has no binding for %s"):format(p, action))
        end
      end
    end)
  end)

  describe("the ball never gets stuck (playtest, 2026-09-05)", function()
    -- A wall chain with a local minimum is a pocket, and a level bar across a
    -- channel is a shelf. Both were in the first layout and both were found by
    -- playing, not by reading the data. These two tests look for them the way
    -- a player does: by using the board.
    local function on_flipper(def, x, y)
      for _, f in ipairs(def.flippers) do
        local sgn = (f.side == "left") and 1 or -1
        local dx = sgn * C.FLIPPER_LEN * math.cos(C.FLIPPER_REST)
        local dy = C.FLIPPER_LEN * math.sin(C.FLIPPER_REST)
        local t = math.max(0, math.min(1, ((x-f.x)*dx + (y-f.y)*dy) / (dx*dx + dy*dy)))
        if math.sqrt((x - f.x - dx*t)^2 + (y - f.y - dy*t)^2) < 24 then return true end
      end
      return false
    end

    it("survives two minutes of random play without stalling", function()
      local ACTIONS = { "flip_left", "flip_right", "operator_gate", "operator_paddle" }
      math.randomseed(7)
      local m = Match.new(boards)
      local still = 0
      for tick = 1, C.TICK_HZ * 120 do
        if tick % 14 == 0 then
          m:push(intents.new(math.random(2), ACTIONS[math.random(4)],
                             math.random() < 0.5, m.state.tick))
        end
        m:run(1)
        local s = m.state
        if s.phase == "play" then
          local b = m.boards[s.active]
          local x, y = b:ball_pos()
          if x and b:ball_speed() < 14 and not on_flipper(m.defs[s.active], x, y) then
            still = still + C.FIXED_DT
            A.truthy(still <= 1.5,
              ("ball stuck on %s at (%.0f, %.0f)"):format(s.active, x, y))
          else still = 0 end
        end
      end
    end)

    it("cannot be stranded by slamming the gate shut mid-shot", function()
      for _, id in ipairs({ "a", "b" }) do
        local def = boards[id]
        for sp = 640, 1400, 120 do
          for delay = 0, 0.60, 0.10 do
            local b = Board.new(def)
            run(b, 0.40, cmd(true, false))
            b:spawn(def.tube.mouth.x, 520, 0, -sp)
            local t, done, still = 0, false, 0
            for _ = 1, math.floor(6 * C.TICK_HZ) do
              for _, ev in ipairs(b:step(cmd(t < delay, false), true)) do
                if ev.kind == "tube" or ev.kind == "drain" then done = true end
              end
              if done then break end
              t = t + C.FIXED_DT
              local x, y = b:ball_pos()
              if b:ball_speed() < 14 and not on_flipper(def, x, y) then
                still = still + C.FIXED_DT
                A.truthy(still <= 1.5, ("%s: stranded at (%.0f, %.0f) after a %.2fs gate"):
                  format(id, x, y, delay))
              else still = 0 end
            end
          end
        end
      end
    end)
  end)

  describe("the round trip", function()
    it("serves, passes through the tube, and lands on the other board", function()
      local m = Match.new(boards)
      local s = m.state
      -- P2 operates board A: hold the gate open so the ramp shot is a pass.
      s.boards.a.devices.gate.commanded = true
      for _ = 1, C.TICK_HZ do m:run(1) end                  -- let the serve happen
      A.equal("play", s.phase)
      -- Stand in for a made ramp shot: the aiming is covered elsewhere, this
      -- test is about the handoff.
      m.boards.a:spawn(215, 520, 0, -C.SERVE_SPEED)
      local saw_transit, landed = false, false
      for _ = 1, C.TICK_HZ * 8 do
        m:run(1)
        if s.phase == "transit" then saw_transit = true end
        if saw_transit and s.phase == "play" and s.active == "b" then landed = true break end
      end
      A.truthy(saw_transit, "the ball never entered the tube")
      A.truthy(landed, "the ball never arrived on board B")
      A.equal(1, s.stats.passes)
      A.truthy(m.boards.b.ball ~= nil, "no ball on the destination board")
      A.truthy(m.boards.a.ball == nil, "the source board kept the ball too")
      local speed = m.boards.b:ball_speed()
      A.truthy(speed > C.TRANSIT_MIN_SP * 0.9, "the pass arrived dead: " .. ("%.0f"):format(speed))
    end)

    it("keeps exactly one ball in existence at all times", function()
      local m = Match.new(boards)
      m.state.boards.a.devices.gate.commanded = true
      for _ = 1, C.TICK_HZ * 12 do
        m:run(1)
        local n = 0
        for _, b in pairs(m.boards) do if b.ball then n = n + 1 end end
        A.truthy(n <= 1, "two balls exist at tick " .. m.state.tick)
        if m.state.phase == "play" then A.equal(1, n, "phase is play with no ball") end
      end
    end)
  end)

  describe("targets (§13.1: Glasshouse's character)", function()
    it("b: every target is reachable in play", function()
      -- Same lesson as Foundry's bumpers: a target nothing can reach is
      -- scenery. Board B's bank is the only aimed scoring content in the
      -- game, so if it is unreachable the board has no identity again.
      local def = boards.b
      local seen, total = {}, 0
      for seed = 1, 3 do
        math.randomseed(8800 + seed)
        local b = Board.new(def)
        b:serve()
        local c = cmd()
        for i = 1, math.floor(40 * C.TICK_HZ) do
          if i % 30 == 0 then
            c = cmd(math.random() < 0.55, math.random() < 0.2,
                    math.random() < 0.35, math.random() < 0.35)
          end
          local dead = false
          for _, ev in ipairs(b:step(c, b.ball ~= nil)) do
            if ev.kind == "drain" or ev.kind == "tube" then dead = true end
            if ev.kind == "target" then
              seen[ev.index] = (seen[ev.index] or 0) + 1
              total = total + 1
            end
          end
          if dead then b:serve() end
        end
      end
      for i = 1, #def.targets do
        A.truthy((seen[i] or 0) > 0,
          ("target %d is unreachable: it is scenery, not content"):format(i))
      end
      -- Floor well under the measured rate, as with the bumpers: this is a
      -- "the bank is still live" tripwire, not a tuning target. Two targets
      -- measure ~0.29 hits/s here and ~0.4/s over the longer identity probe;
      -- 0.12 catches the bank going dead without failing on seed noise.
      A.truthy(total / 120 > 0.12,
        ("the bank is barely live: %.2f hits/s"):format(total / 120))
    end)
  end)

  ---------------------------------------------------------------------------
  -- Bumper scoring. A rule, not a contact: unlike `impact`, this one is meant
  -- to reach core/.
  ---------------------------------------------------------------------------

  describe("bumper scoring events", function()
    it("reports the bumper that was hit, by index", function()
      local def = boards.a
      local b   = Board.new(def)
      local target = 2
      local t = def.bumpers[target]
      -- Fired from directly above, so which bumper is struck is not in doubt.
      b:spawn(t.x, t.y - t.r - C.BALL_RADIUS - 8, 0, 700)
      local seen = {}
      run(b, 0.6, cmd(), seen)
      local found
      for _, ev in ipairs(seen) do
        if ev.kind == "bumper" then found = found or ev.index end
      end
      A.equal(target, found, "the wrong bumper scored, or none did")
    end)

    it("does not score a bumper the ball never touched", function()
      local b = Board.new(boards.a)
      b:spawn(340, 300, 0, 0)          -- right side, clear of the cluster
      local seen = {}
      run(b, 0.4, cmd(), seen)
      for _, ev in ipairs(seen) do
        A.truthy(ev.kind ~= "bumper", "a bumper scored with no ball near it")
      end
    end)
  end)

  ---------------------------------------------------------------------------
  -- Impact events. Presentation only, but they are a contract app/ relies on
  -- and the threshold behind them is the difference between a set of hits and
  -- a 240 Hz buzz.
  ---------------------------------------------------------------------------

  describe("impact events", function()
    local function impacts_of(m, ticks)
      local out = {}
      for _ = 1, ticks do
        m:run(1)
        for _, ev in ipairs(m:drain_events()) do
          if ev.kind == "impact" then out[#out+1] = ev end
        end
      end
      return out
    end

    it("reports a hit with a surface, a place and a strength", function()
      local m = Match.new(boards)
      m:run(C.TICK_HZ)                                  -- let the serve happen
      m.boards.a:spawn(215, 300, 0, 900)                -- straight down, hard
      local hits = impacts_of(m, C.TICK_HZ * 2)
      A.truthy(#hits > 0, "a ball driven into the floor reported no impact")
      for _, ev in ipairs(hits) do
        A.truthy(ev.what ~= nil and ev.x ~= nil and ev.y ~= nil, "malformed impact")
        A.truthy(ev.impulse >= C.IMPACT_MIN_IMPULSE, "impact under the floor got through")
        A.truthy(ev.what ~= "mouth", "the tube sensor must not report as a contact")
      end
    end)

    it("goes silent once the ball is only resting on something", function()
      -- The reason the threshold exists. A ball sitting on the raised post
      -- solves a contact impulse every single step; without a floor above the
      -- ball's own weight that is 240 events a second, forever.
      local m = Match.new(boards)
      m.state.boards.a.devices.post.commanded = true
      m:run(C.TICK_HZ)
      m.boards.a:spawn(192, 600, 0, 0)                  -- drop onto the post
      impacts_of(m, C.TICK_HZ * 4)                      -- settle
      local resting = impacts_of(m, C.TICK_HZ * 2)
      A.equal(0, #resting, "a resting ball is still reporting impacts")
    end)

    it("carries impacts on the feed and nowhere else", function()
      -- §5: core/ has no opinion about how hard the ball hit something. The
      -- other half of this invariant -- that core.consume ignores an impact
      -- even if one reaches it -- is asserted in the core spec, where it
      -- needs no physics.
      local m = Match.new(boards)
      m.state.boards.a.devices.gate.commanded = true
      local kinds = {}
      for _ = 1, C.TICK_HZ * 6 do
        m:run(1)
        for _, ev in ipairs(m:drain_events()) do kinds[ev.kind] = true end
      end
      A.truthy(kinds.impact, "no impact ever reached the presentation feed")
    end)

    it("bounds the feed when nothing drains it", function()
      -- A headless run never drains, so an uncapped feed grows one table per
      -- contact for the length of the test.
      local m = Match.new(boards)
      m.state.boards.a.devices.gate.commanded = true
      m:run(C.TICK_HZ * 20)
      A.truthy(#m.feed <= 96, "feed grew unbounded: " .. #m.feed)
    end)
  end)
end
