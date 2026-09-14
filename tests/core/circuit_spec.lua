return function(H)
  local A = H.assert
  local state = require("core.state")
  local circuit = require("core.circuit")
  local defs = require("data.tables.init").load()
  local function setup()
    local s = state.new(defs)
    s.phase = "play"
    return s, s.boards.a, s.boards.a.circuits.workshop
  end
  local function hit(s, speed)
    state.consume(s, { { kind = "switch", board = "a", index = 1, speed = speed } })
  end
  H.describe("powered circuits", function()
    H.it("requires a real crossing, rewards speed, and debounces repeat contacts", function()
      local s, b, c = setup()
      hit(s, 10)
      A.equal(0, c.charge)
      hit(s, 400)
      A.equal(1, c.charge)
      hit(s, 1000)
      A.equal(1, c.charge)
      s.tick = 240
      hit(s, 1000)
      A.equal(3, c.charge)
      A.truthy(circuit.powered(b, defs.a.devices[2]))
      s.tick = 480
      hit(s, 1600)
      A.equal(3, c.charge, "energy must stay capped")
    end)
    H.it("requires both an operator command and stored power; spending is one-shot", function()
      local s, b, c = setup()
      state.apply_intent(s, { player = 2, action = "operator_gate", pressed = true, tick = s.tick })
      A.truthy(b.devices.gate.commanded)
      A.falsy(circuit.powered(b, defs.a.devices[2]))
      c.charge = 3
      circuit.route(b, { id = "workshop", at = "enter" })
      circuit.route(b, { id = "workshop", at = "enter" })
      A.equal(0, c.charge)
      A.equal(1, c.attempts)
      A.truthy(c.active)
      circuit.route(b, { id = "workshop", at = "exit", complete = true })
      circuit.route(b, { id = "workshop", at = "exit", complete = true })
      A.equal(1, c.completed)
      A.falsy(c.active)
      A.falsy(circuit.powered(b, defs.a.devices[2]))
    end)
    H.it("keeps preparation across drains; rollbacks do not count as completed rides", function()
      local s, b, c = setup()
      c.charge = 2
      state.consume(s, { { kind = "drain", board = "a" } })
      A.equal(2, c.charge)
      c.charge = 3
      circuit.route(b, { id = "workshop", at = "enter" })
      circuit.route(b, { id = "workshop", at = "exit", complete = false })
      A.equal(0, c.completed)
      A.falsy(c.active)
    end)
    H.it("rejects broken wiring and malformed gizmos before loading physics", function()
      local validate = require("core.circuit_validate")
      for _, mutate in ipairs({
        function(d) d.switches[1].circuit = "missing" end,
        function(d) d.circuits[1].route = "missing" end,
        function(d) d.ramps[1].device = "missing" end,
        function(d) d.devices[2].circuit = "missing" end,
        function(d) d.switches[1].cooldown = 0 end,
        function(d) d.circuits[1].wire = { 1, "bad", 3, 4 } end,
        function(d) d.sections[1].color = { 1, "bad", 0 } end,
      }) do
        local d = require("data.tables.init").load().a
        mutate(d)
        local errs = {}
        validate.check(d, errs)
        A.truthy(#errs > 0, "invalid mechanism loaded")
      end
    end)
  end)
end
