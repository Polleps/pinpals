return function(H)
  local A = H.assert
  local C = require("core.constants")
  local Match = require("sim.match")
  local defs = require("data.tables.init").load()
  H.describe("workshop mechanism", function()
    H.it("charges from physics crossings, opens, spends power, and returns with the gate closing", function()
      local m = Match.new(defs, 8831)
      m.state.phase = "play"
      local b, c = m.boards.a, m.state.boards.a.circuits.workshop
      local gen = defs.a.switches[1]
      m:push({ player = 2, action = "operator_gate", pressed = true })
      m:run(100)
      A.near(0, b:device_progress("gate"), 0.01, "an unpowered gate opened")
      for _ = 1, 2 do
        b:spawn(gen.x, gen.y + 30, 0, -1200)
        m:run(25)
        b:despawn()
        m:run(160)
      end
      A.equal(3, c.charge)
      A.near(1, b:device_progress("gate"), 0.01)
      local r = defs.a.ramps[1]
      b:spawn(r.path[1], r.path[2] + 38, 0, -1600)
      local returned = false
      for _ = 1, 6 * C.TICK_HZ do
        m:run(1)
        local x, y = b:ball_pos()
        if c.completed > 0 and x and y > 840 and y < 910
           and x > defs.a.flippers[1].x - 15 and x < defs.a.flippers[2].x + 15 then
          returned = true
        end
      end
      A.equal(1, c.attempts)
      A.equal(1, c.completed)
      A.equal(0, c.charge)
      A.falsy(c.active)
      A.truthy(returned, "workshop never returned to the flipper deck")
      A.near(0, b:device_progress("gate"), 0.01)
      for _, world in pairs(m.boards) do world.world:destroy() end
    end)
    H.it("does not admit a ball when powered but the operator has not opened it", function()
      local m = Match.new(defs, 9901)
      m.state.phase = "play"
      m.state.boards.a.circuits.workshop.charge = 3
      local r = defs.a.ramps[1]
      m.boards.a:spawn(r.path[1], r.path[2] + 38, 0, -1600)
      m:run(C.TICK_HZ)
      A.equal(0, m.state.boards.a.circuits.workshop.attempts)
      A.equal(3, m.state.boards.a.circuits.workshop.charge)
      for _, world in pairs(m.boards) do world.world:destroy() end
    end)
  end)
end
