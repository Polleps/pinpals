--- app/render.lua: the parts that are state rather than drawing.
---
--- Testable in the bare interpreter because requiring the module only builds
--- tables -- nothing reaches love.graphics until a draw call.

return function(H)
  local describe, it, A = H.describe, H.it, H.assert

  local render = require("app.render")

  describe("coordinate overlay mode (key 2)", function()
    it("switches on to the active board, and back off again", function()
      -- `M.inspect and nil or active` reads like a toggle and is not one:
      -- it can never produce nil, so the overlay used to be unclosable.
      render.inspect = nil
      render.toggle_inspect("a")
      A.equal("a", render.inspect)
      render.toggle_inspect("a")
      A.equal(nil, render.inspect, "second press left the overlay on")
    end)

    it("switches off from whichever board TAB left it on", function()
      render.inspect = nil
      render.toggle_inspect("a")
      render.swap_inspect()
      A.equal("b", render.inspect)
      render.toggle_inspect("a")
      A.equal(nil, render.inspect, "swapping boards made the mode sticky")
    end)

    it("does not swap boards while the overlay is off", function()
      render.inspect = nil
      render.swap_inspect()
      A.equal(nil, render.inspect)
    end)
  end)

  render.inspect = nil

  H.describe("dormant board status", function()
    local state = require("core.state")
    local boards = require("data.tables.init").load()
    H.it("lists what is waiting on the other board, and nothing when empty", function()
      local s = state.new(boards)
      A.equal(0, #render.dormant_lines(s.boards.b, boards.b))
      s.boards.b.meters.vault = 3
      s.boards.b.targets[1].lit = true
      s.boards.a.circuits.workshop.charge = 1
      local b = table.concat(render.dormant_lines(s.boards.b, boards.b), "|")
      A.truthy(b:find("VAULT 1/3  x4", 1, true), b)
      local a = table.concat(render.dormant_lines(s.boards.a, boards.a), "|")
      A.truthy(a:find("WORKSHOP POWER 1/2", 1, true), a)
    end)
  end)
end
