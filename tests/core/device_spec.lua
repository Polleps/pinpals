--- Operator devices in core/: which key drives what, and duty limits.
return function(H)
  local A = H.assert
  local state   = require("core.state")
  local C       = require("core.constants")
  local boards  = require("data.tables.init").load()

  local function magnet_of(b)
    for _, d in ipairs(boards[b].devices) do if d.kind == "magnet" then return d end end
  end

  H.describe("operator devices", function()
    H.it("the gate key drives Glasshouse's magnet and Foundry's gate", function()
      local s = state.new(boards)
      A.equal("gate", s.boards.a.device_for.operator_gate)
      A.equal(magnet_of("b").id, s.boards.b.device_for.operator_gate)
      A.equal("post", s.boards.b.device_for.operator_paddle)
      s.active = "b"
      state.apply_intent(s, { player = 1, action = "operator_gate", pressed = true, tick = 0 })
      A.truthy(s.boards.b.devices[magnet_of("b").id].commanded)
    end)

    H.it("a magnet held past max_on overheats, drops out, then comes back", function()
      local s = state.new(boards)
      local d = magnet_of("b")
      local dev = s.boards.b.devices[d.id]
      dev.commanded = true
      for _ = 1, math.ceil(d.max_on * C.TICK_HZ) + 1 do state.update(s) end
      A.truthy(dev.cooldown > 0, "never overheated")
      A.falsy(state.device_live(dev), "an overheated magnet is still live")
      for _ = 1, math.ceil(d.cooldown * C.TICK_HZ) + 1 do state.update(s) end
      A.truthy(state.device_live(dev), "never recovered")
    end)

    H.it("tapping does not dodge the duty limit, but resting does cool it", function()
      local s = state.new(boards)
      local dev = s.boards.b.devices[magnet_of("b").id]
      dev.commanded = true
      for _ = 1, C.TICK_HZ do state.update(s) end
      dev.commanded = false
      for _ = 1, C.TICK_HZ / 4 do state.update(s) end
      A.near(0.75, dev.heat, 0.02)
    end)

    H.it("a magnet catch cancels a running skyway combo (§6.2)", function()
      local s = state.new(boards)
      s.phase = "play"
      s.boards.b.mission.combo = 5
      state.consume(s, { { kind = "magnet", board = "b", id = "magnet", x = 0, y = 0 } })
      A.equal(0, s.boards.b.mission.combo)
    end)
  end)
end
