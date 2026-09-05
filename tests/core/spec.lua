--- Pure-Lua tests. No LÖVE, runs in a bare interpreter in milliseconds (§7).

return function(H)
  local describe, it, A = H.describe, H.it, H.assert

  local C        = require("core.constants")
  local intents  = require("core.intents")
  local validate = require("core.validate")
  local state    = require("core.state")
  local boards   = require("data.tables.init").load()

  describe("board data", function()
    it("both boards validate", function()
      local ok, errs = validate.set(boards)
      A.truthy(ok, errs and table.concat(errs, "; "))
    end)

    it("tubes point at each other and land on a real entry", function()
      A.equal("b", boards.a.tube.to)
      A.equal("a", boards.b.tube.to)
      A.truthy(boards.a.entry and boards.b.entry)
    end)

    it("rejects a device with no travel time (design.md §6.1)", function()
      local bad = { id = "a", name = "x", size = { w = 10, h = 10 },
                    walls = { {0,0,1,1} }, flippers = {}, devices = {
                      { id = "g", kind = "gate", travel = 0, tradeoff = "x",
                        pivot = {x=1,y=1}, length = 1, closed = 0, open = 1 } } }
      local ok, errs = validate.board(bad)
      A.falsy(ok)
      local found = false
      for _, e in ipairs(errs) do if e:find("travel", 1, true) then found = true end end
      A.truthy(found, "expected a travel-time complaint")
    end)

    it("rejects a device that does not state its trade-off (§6.2)", function()
      local b = boards.a
      local saved = b.devices[1].tradeoff
      b.devices[1].tradeoff = nil
      local ok = validate.board(b)
      b.devices[1].tradeoff = saved
      A.falsy(ok)
    end)

    it("rejects a board that passes to itself", function()
      local b = boards.a
      local saved = b.tube.to
      b.tube.to = "a"
      local ok = validate.board(b)
      b.tube.to = saved
      A.falsy(ok)
    end)
  end)

  describe("roles", function()
    it("are implicit in ball position, never selected", function()
      A.equal("flipper",  intents.role_of(1, "a"))
      A.equal("operator", intents.role_of(2, "a"))
      A.equal("operator", intents.role_of(1, "b"))
      A.equal("flipper",  intents.role_of(2, "b"))
    end)

    it("never leave a player with nothing to do (pillar 1)", function()
      for _, active in ipairs({ "a", "b" }) do
        local r1, r2 = intents.role_of(1, active), intents.role_of(2, active)
        A.truthy(r1 ~= r2, "both players ended up in the same role")
      end
    end)

    it("rejects an unknown action", function()
      A.error_matches("unknown action", function() intents.new(1, "nudge", true, 0) end)
    end)
  end)

  describe("intents", function()
    local s
    local function fresh() s = state.new(boards); s.phase = "play" end

    it("give flippers only to the player whose board holds the ball", function()
      fresh()
      state.apply_intent(s, intents.new(1, "flip_left", true, 0))
      A.truthy(s.boards.a.flippers.left)
      state.apply_intent(s, intents.new(2, "flip_right", true, 0))
      A.falsy(s.boards.a.flippers.right, "the operator must not get flippers")
    end)

    it("give devices on the ACTIVE board to the ball-less player", function()
      fresh()
      state.apply_intent(s, intents.new(2, "operator_gate", true, 0))
      A.truthy(s.boards.a.devices.gate.commanded, "operator acts on the active board, not their own")
      A.falsy(s.boards.b.devices.gate.commanded)
    end)

    it("ignore flipper input when there is no ball", function()
      fresh(); s.phase = "serve"
      state.apply_intent(s, intents.new(1, "flip_left", true, 0))
      A.falsy(s.boards.a.flippers.left)
    end)
  end)

  describe("the pass", function()
    it("hands the board over and clamps the speed it carries (§5)", function()
      local s = state.new(boards); s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 1e9 } })
      A.equal("transit", s.phase)
      A.equal("b", s.active, "the destination becomes active immediately")
      A.equal(C.TRANSIT_MAX_SP, s.transit.speed)
      A.equal(1, s.stats.passes)
    end)

    it("keeps a dribbled pass moving", function()
      local s = state.new(boards); s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 1 } })
      A.equal(C.TRANSIT_MIN_SP, s.transit.speed)
    end)

    it("lets the sender operate the destination during flight", function()
      local s = state.new(boards); s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 900 } })
      -- P1 sent the ball; P1 is now the operator on B, mid-flight.
      A.equal("operator", intents.role_of(1, s.active))
      state.apply_intent(s, intents.new(1, "operator_paddle", true, 0))
      A.truthy(s.boards.b.devices.post.commanded)
    end)

    it("arrives after exactly the transit time and hands over the speed", function()
      local s = state.new(boards); s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 1500 } })
      local arrived, steps = nil, 0
      for _ = 1, C.TICK_HZ * 3 do
        steps = steps + 1
        for _, c in ipairs(state.update(s)) do
          if c.kind == "arrive" then arrived = c break end
        end
        if arrived then break end
      end
      A.truthy(arrived, "the ball never came out of the tube")
      ---@cast arrived -nil
      A.equal("b", arrived.board)
      A.equal(1500, arrived.speed)
      A.near(C.TRANSIT_TIME, steps * C.FIXED_DT, C.FIXED_DT * 2)
      A.equal("play", s.phase)
    end)

    it("releases held flippers when the ball leaves", function()
      local s = state.new(boards); s.phase = "play"
      state.apply_intent(s, intents.new(1, "flip_left", true, 0))
      state.consume(s, { { kind = "tube", board = "a", speed = 900 } })
      A.falsy(s.boards.a.flippers.left, "a held key must not strand a flipper")
    end)
  end)

  describe("draining", function()
    it("resets the relay and re-serves on the same board", function()
      local s = state.new(boards); s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 900 } })
      for _ = 1, C.TICK_HZ do state.update(s) end        -- land on B
      A.equal("play", s.phase)
      A.equal(1, s.stats.relay)
      state.consume(s, { { kind = "drain", board = "b" } })
      A.equal("drain", s.phase)
      A.equal(0, s.stats.relay)
      A.equal(1, s.stats.best_relay, "the best relay must survive the drain")

      local served
      for _ = 1, C.TICK_HZ * 3 do
        for _, c in ipairs(state.update(s)) do if c.kind == "serve" then served = c end end
        if served then break end
      end
      A.truthy(served, "no re-serve after the drain")
      A.equal("b", served.board, "re-serve happens where the ball was lost")
    end)
  end)

  describe("device commands persist (§7 dormant board keeps its state)", function()
    it("a device left open on a board is still open when you come back", function()
      local s = state.new(boards); s.phase = "play"
      state.apply_intent(s, intents.new(2, "operator_gate", true, 0))
      A.truthy(s.boards.a.devices.gate.commanded)
      state.consume(s, { { kind = "tube", board = "a", speed = 900 } })
      for _ = 1, C.TICK_HZ do state.update(s) end
      A.truthy(s.boards.a.devices.gate.commanded, "board A forgot what the operator did")
    end)
  end)
  ---------------------------------------------------------------------------
  -- §5 layering. Impacts are presentation: sim/ reports them so app/ can
  -- sound and light them, and the rules must stay blind to them. A scoring
  -- rule that quietly started keying off contact strength would break the
  -- headless tests and the online plan at the same time.
  ---------------------------------------------------------------------------
  describe("presentation events are not rules", function()
    it("ignores impacts entirely", function()
      local s = state.new(boards)
      s.phase = "play"
      local before = {
        phase = s.phase, passes = s.stats.passes,
        drains = s.stats.drains, relay = s.stats.relay, active = s.active,
      }
      state.consume(s, {
        { kind = "impact", board = "a", what = "bumper", x = 1, y = 2, impulse = 99 },
        { kind = "impact", board = "a", what = "wall",   x = 3, y = 4, impulse = 0.4 },
      })
      A.equal(before.phase,  s.phase)
      A.equal(before.active, s.active)
      A.equal(before.passes, s.stats.passes)
      A.equal(before.drains, s.stats.drains)
      A.equal(before.relay,  s.stats.relay)
    end)
  end)

  ---------------------------------------------------------------------------
  -- §9 Scoring. The multiplier lives on passing, not on shots.
  ---------------------------------------------------------------------------
  describe("relay heat", function()
    local score = require("core.score")

    it("is the crossing count, floored at x1", function()
      A.equal(1, score.heat(0), "a fresh ball must still score")
      A.equal(1, score.heat(1), "the first pass of a life is base rate")
      A.equal(5, score.heat(5))
    end)

    it("has a ceiling", function()
      -- Without one, a long rally makes every earlier rally unreadable and
      -- the multiplier stops being a number anyone can hold in their head.
      A.equal(C.HEAT_MAX, score.heat(C.HEAT_MAX + 40))
    end)

    it("scales arrival speed far more gently than score", function()
      -- Score can escalate wildly and cost nothing. Arrival speed is a
      -- difficulty knob AND a tunneling risk, so the two curves are separate
      -- on purpose and this is the assertion that keeps them separate.
      A.equal(1, score.speed_scale(0))
      A.truthy(score.speed_scale(4) < 1.25, "speed ramps as fast as score")
      A.equal(C.HEAT_SPEED_MAX, score.speed_scale(999))
    end)
  end)

  describe("scoring", function()
    local score = require("core.score")

    local function fresh()
      return { relay = 0, score = 0, rally_score = 0, best_rally_score = 0 }
    end

    it("pays the current multiplier", function()
      local st = fresh()
      st.relay = 3
      A.equal(C.SCORE_PASS * 3, score.award(st, "pass"))
      A.equal(C.SCORE_PASS * 3, st.score)
    end)

    it("keeps the session total but drops the rally on a drain", function()
      local st = fresh()
      st.relay = 2
      score.award(st, "pass")
      local banked = st.score
      A.equal(banked, st.rally_score)
      score.end_rally(st)
      A.equal(banked, st.score,            "a drain took the session score")
      A.equal(0,      st.rally_score,      "the rally survived its own drain")
      A.equal(banked, st.best_rally_score, "best rally was not remembered")
    end)

    it("makes one long rally worth far more than the same passes scattered",
       function()
      -- This is §9 itself, as a test: "the rally becomes simultaneously more
      -- valuable and more likely to end". If these two ever come out equal,
      -- the multiplier has stopped doing the only job it has.
      local together = fresh()
      for _ = 1, 5 do
        together.relay = together.relay + 1
        score.award(together, "pass")
      end
      local scattered = fresh()
      for _ = 1, 5 do
        scattered.relay = 1
        score.award(scattered, "pass")
        scattered.relay = 0
        score.end_rally(scattered)
      end
      -- Measured: 15,000 together against 5,000 scattered at five crossings,
      -- and the gap widens with length (45,000 vs 9,000 at nine).
      A.truthy(together.score >= scattered.score * 3,
               ("a 5-rally paid %d against %d scattered -- the curve is flat")
                 :format(together.score, scattered.score))
    end)
  end)

  describe("scoring through the match rules", function()
    local score = require("core.score")

    it("awards a pass at the heat the crossing just created", function()
      -- Awarding at the OLD heat pays the escalation one pass late, which
      -- makes the readout disagree with the number that floats up.
      local s = state.new(boards)
      s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 1200 } })
      A.equal(1, s.stats.relay)
      A.equal(C.SCORE_PASS * score.heat(1), s.stats.score)
      A.equal(C.SCORE_PASS * score.heat(1), s.last_award.value)
    end)

    it("sends the ball on faster as the rally heats up", function()
      local cold = state.new(boards)
      cold.phase = "play"
      state.consume(cold, { { kind = "tube", board = "a", speed = 1200 } })

      local hot = state.new(boards)
      hot.phase = "play"
      hot.stats.relay = 8
      state.consume(hot, { { kind = "tube", board = "a", speed = 1200 } })

      A.truthy(hot.transit.speed > cold.transit.speed,
               "heat did not reach the ball (§9: worth more AND moving faster)")
      A.truthy(hot.transit.speed <= C.TRANSIT_MAX_SP, "heat outran the clamp")
    end)

    it("takes the rally, not the session, when the ball drains", function()
      local s = state.new(boards)
      s.phase = "play"
      state.consume(s, { { kind = "tube", board = "a", speed = 1200 } })
      local banked = s.stats.score
      s.phase = "play"
      state.consume(s, { { kind = "drain", board = "b" } })
      A.equal(0,      s.stats.relay)
      A.equal(0,      s.stats.rally_score)
      A.equal(banked, s.stats.score)
      A.equal(banked, s.stats.best_rally_score)
    end)

    it("scores a bumper on the board that reported it", function()
      local s = state.new(boards)
      s.phase = "play"
      state.consume(s, { { kind = "bumper", board = "a", index = 1, x = 95, y = 250 } })
      A.equal(C.SCORE_BUMPER * score.heat(0), s.stats.score)
      A.equal("bumper", s.last_award.kind)
    end)
  end)

  ---------------------------------------------------------------------------
  -- §13.1 Board identity, and the target banks that carry it.
  ---------------------------------------------------------------------------
  describe("target banks", function()
    local score = require("core.score")

    --- The board that actually has a bank. Raises rather than returning nil,
    --- so a board set with no targets at all fails here loudly instead of
    --- letting every test below quietly pass over an empty list.
    local function banked_board()
      for id, def in pairs(boards) do
        if def.targets and #def.targets > 0 then return id, def end
      end
      error("no board has targets: Glasshouse has lost its identity", 2)
    end

    it("exists on exactly one board, which is that board's character", function()
      A.equal("b", (banked_board()), "the target bank moved off Glasshouse")
    end)

    it("lights a target when it is hit, and pays for it", function()
      local id = banked_board()
      local s = state.new(boards)
      s.phase = "play"
      state.consume(s, { { kind = "target", board = id, index = 1, x = 1, y = 2 } })
      A.truthy(s.boards[id].targets[1].lit, "a struck target did not light")
      A.equal(C.SCORE_TARGET * score.heat(0), s.stats.score)
    end)

    it("pays a struck target again but does not re-count it", function()
      -- Otherwise the cheapest way to clear a bank is to rattle one target.
      local id, def = banked_board()
      local s = state.new(boards)
      s.phase = "play"
      local hit = { kind = "target", board = id, index = 1, x = 1, y = 2 }
      state.consume(s, { hit })
      local after_one = s.stats.score
      state.consume(s, { hit })
      A.equal(after_one * 2, s.stats.score, "a repeat hit stopped scoring")
      local lit = 0
      for i = 1, #def.targets do
        if s.boards[id].targets[i].lit then lit = lit + 1 end
      end
      A.equal(1, lit, "one target counted twice toward its bank")
    end)

    it("pays a bonus and resets when the whole bank is lit", function()
      local id, def = banked_board()
      local s = state.new(boards)
      s.phase = "play"
      local plain = 0
      for i = 1, #def.targets do
        state.consume(s, { { kind = "target", board = id, index = i, x = 0, y = 0 } })
        if i < #def.targets then plain = s.stats.score end
      end
      A.truthy(s.stats.score > plain + C.SCORE_TARGET,
               "clearing the bank paid nothing over the last target")
      for i = 1, #def.targets do
        A.truthy(not s.boards[id].targets[i].lit,
                 ("target %d stayed lit after the bank cleared"):format(i))
      end
    end)
  end)

  describe("board identity (§13.1)", function()
    --- The geometric half of the identity, which is pure data and therefore
    --- worth asserting cheaply here: Foundry is the forgiving board, and
    --- "forgiving" is mostly the width of the gap the ball falls through.
    --- Behavioural confirmation (ball life, points/s) lives in
    --- tests/probe_identity.lua, which is too slow to be a gate.
    local function drain_gap(def)
      local left, right
      for _, f in ipairs(def.flippers) do
        if f.side == "left" then left = f else right = f end
      end
      local reach = math.cos(C.FLIPPER_REST) * C.FLIPPER_LEN
      return (right.x - reach) - (left.x + reach)
    end

    it("gives Foundry the narrower drain", function()
      -- This was measurably backwards before 2026-09-06: the board documented
      -- as forgiving drained MORE often per second than the one documented as
      -- punishing.
      A.truthy(drain_gap(boards.a) < drain_gap(boards.b) - 8,
        ("Foundry %.1fpx vs Glasshouse %.1fpx: the boards have stopped differing")
          :format(drain_gap(boards.a), drain_gap(boards.b)))
    end)

    it("keeps the ball wider than neither gap", function()
      -- A gap under a ball width is a wall, not a drain, and would quietly
      -- turn one board into a board that cannot lose.
      for _, id in ipairs({ "a", "b" }) do
        A.truthy(drain_gap(boards[id]) > C.BALL_RADIUS * 2,
          ("board %s cannot drain: gap %.1f, ball %.1f")
            :format(id, drain_gap(boards[id]), C.BALL_RADIUS * 2))
      end
    end)
  end)

end
