--- Glasshouse's magnet, in physics. tests/probe_magnet.lua has the sweep
--- these numbers come from.
return function(H)
  local A = H.assert
  local C = require("core.constants")
  local Board = require("sim.board")
  local def = require("data.tables.init").load().b
  local mag
  for _, d in ipairs(def.devices) do if d.kind == "magnet" then mag = d end end

  local function cmd(on)
    return { flippers = { left = false, right = false },
             devices = { post = { commanded = false }, [mag.id] = { commanded = on } } }
  end

  local function charged()
    local b = Board.new(def)
    for _ = 1, math.ceil(mag.travel * C.TICK_HZ) + 1 do b:step(cmd(true), false) end
    return b
  end

  H.describe("magnet", function()
    H.it("catches a ball dropping through it and reports the catch once", function()
      local b = charged()
      b:spawn(mag.x + 12, mag.y - mag.r - 4, 0, 500)
      local catches = 0
      for _ = 1, C.TICK_HZ do
        for _, ev in ipairs(b:step(cmd(true), true)) do
          if ev.kind == "magnet" then catches = catches + 1 end
        end
      end
      local x, y = b:ball_pos()
      A.near(mag.x, x, C.MAGNET_HOLD_R)
      A.near(mag.y, y, C.MAGNET_HOLD_R)
      A.equal(1, catches)
      b.world:destroy()
    end)

    H.it("lets a hard shot through", function()
      local b = charged()
      b:spawn(mag.x, mag.y + mag.r + 4, 0, -1400)
      for _ = 1, C.TICK_HZ / 2 do b:step(cmd(true), true) end
      local _, y = b:ball_pos()
      A.truthy(y < mag.y - mag.r, "a 1400px/s shot was held")
      b.world:destroy()
    end)

    H.it("drops a released ball onto the right flipper, not the drain", function()
      local b = charged()
      b:spawn(mag.x, mag.y, 0, 0)
      for _ = 1, C.TICK_HZ do b:step(cmd(true), true) end
      local landed = false
      for _ = 1, C.TICK_HZ do
        b:step(cmd(false), true)
        local x, y = b:ball_pos()
        local right = def.flippers[2]
        if y > right.y - 20 and math.abs(x - right.x) < 20 then landed = true end
      end
      A.truthy(landed, "the drop missed the flipper's pivot end")
      b.world:destroy()
    end)
  end)
end
