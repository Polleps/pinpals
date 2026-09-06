--- Every case below is a bug that actually shipped, reconstructed from the
--- 2026-09-05 playtest. The validator earns its place by catching them; if it
--- cannot, it is decoration.

return function(H)
  local describe, it, A = H.describe, H.it, H.assert
  local geo    = require("core.geometry")
  local boards = require("data.tables.init").load()

  local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
  end

  --- Board A with one thing broken.
  local function broken(mutate)
    local b = copy(boards.a)
    mutate(b)
    return b
  end

  local function kinds(board)
    local seen = {}
    for _, d in ipairs(geo.check(board)) do seen[d.kind] = (seen[d.kind] or 0) + 1 end
    return seen
  end

  describe("geometry of the shipped boards", function()
    it("is clean", function()
      local clean, lines = geo.report(boards)
      A.truthy(clean, "\n  " .. table.concat(lines, "\n  "))
    end)
  end)

  describe("catches the bugs that shipped", function()
    it("the V in board A's lower-right wall", function()
      -- The chain turned back up at the end to meet the pivot, putting a bowl
      -- at (300,702) that swallowed the ball. Reported by playtest, not tests.
      -- Coordinates carried onto the 448x960 board with the same (+32, +192)
      -- the boards themselves moved by, so the fixture still describes the
      -- shipped chain rather than a wall floating in the middle of the field.
      local b = broken(function(x)
        x.walls[3] = { 438,848, 384,878, 332,894, 283,884 }
      end)
      local found = kinds(b)
      A.truthy(found.bowl, "the bowl at (332,894) was not reported")
    end)

    it("a wall ending underneath its own flipper pivot", function()
      local b = broken(function(x)
        x.walls[2] = { 10,802, 102,856, 156,882, 165,884 }
      end)
      A.truthy(kinds(b)["flipper-jam"], "the wall inside the left flipper was not reported")
    end)

    it("board B's rails converging into a throat", function()
      -- They never crossed, so an intersection test would have missed this.
      local b = broken(function(x)
        x.walls[#x.walls+1] = { 240,250, 300,330 }
        x.walls[#x.walls+1] = { 336,246, 292,306 }
      end)
      A.truthy(kinds(b).wedge, "the 10.8px throat between the rails was not reported")
    end)

    it("a bumper parked against a wall", function()
      local b = broken(function(x) x.bumpers[1] = { x = 24, y = 300, r = 24 } end)
      A.truthy(kinds(b).wedge, "a bumper one ball-width from the wall was not reported")
    end)

    it("a gate too short to seal the ramp", function()
      local b = broken(function(x) x.devices[1].length = 30 end)
      A.truthy(kinds(b)["gate-leaks"], "a gate that does not reach the wall was not reported")
    end)

    it("a gate that barely opens", function()
      local b = broken(function(x) x.devices[1].open = -0.6 end)
      A.truthy(kinds(b)["gate-blocks"], "a gate leaving 4.6px of clearance was not reported")
    end)

    it("a post that does not cover the drain gap", function()
      local b = broken(function(x) x.devices[2].up.x = 120 end)
      A.truthy(kinds(b)["post-misses"], "a post guarding nothing was not reported")
    end)

    it("a post that never retracts out of play", function()
      local b = broken(function(x) x.devices[2].down.y = 700 end)
      A.truthy(kinds(b)["post-stuck-out"], "a post left in the playfield was not reported")
    end)
  end)

  describe("catches the target-bank bugs from 2026-09-06", function()
    -- Board B is the one with a bank, so these mutate it rather than A.
    local function broken_b(mutate)
      local b = copy(boards.b)
      mutate(b)
      return b
    end

    it("three targets authored closer together than they are wide", function()
      -- This shipped in the first draft of Glasshouse's bank: 34px targets
      -- spaced 33px apart. They overlapped into a single bar on screen and
      -- formed throats between them in the physics, and only a screenshot
      -- gave it away -- the wedge check did not cover targets at all, which
      -- is why it does now.
      local b = broken_b(function(x)
        x.targets = {
          { x = 280, y = 388, w = 34, h = 9, angle = 0.558, bank = "vault" },
          { x = 308, y = 405, w = 34, h = 9, angle = 0.558, bank = "vault" },
          { x = 336, y = 422, w = 34, h = 9, angle = 0.558, bank = "vault" },
        }
      end)
      A.truthy(kinds(b).wedge, "overlapping targets were not reported")
    end)

    it("a target parked against a wall", function()
      -- Same failure as a bumper against a wall, and easier to author by
      -- accident because a target is small and its angle is easy to get wrong.
      local b = broken_b(function(x)
        -- Parked against Glasshouse's right wall, which is at x=438 since the
        -- board grew to 448x960: the target's own edge lands 10px off it.
        x.targets = { { x = 414, y = 592, w = 28, h = 9, angle = 0, bank = "vault" } }
      end)
      A.truthy(kinds(b).wedge, "a target one ball-width from the wall was not reported")
    end)
  end)

  describe("does not cry wolf", function()
    it("a properly spaced bank is not a wedge", function()
      -- The shipped bank: 28px targets 92px apart. If this trips, the check
      -- is too strict to author a bank with at all.
      local b = copy(boards.b)
      A.truthy(not kinds(b).wedge, "the shipped target bank was reported as a wedge")
    end)

    it("a peak is not a bowl", function()
      -- The ramp roof is a chevron. Sheds the ball; must not be flagged.
      local b = broken(function(x) x.walls[#x.walls+1] = { 60,400, 90,360, 120,400 } end)
      A.falsy(kinds(b).bowl, "a peak was reported as a bowl")
    end)

    it("a free wall end is not a bowl", function()
      local b = broken(function(x) x.walls[#x.walls+1] = { 60,300, 96,400 } end)
      A.falsy(kinds(b).bowl, "a dangling wall end was reported as a bowl")
    end)
  end)
end
