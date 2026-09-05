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
end
