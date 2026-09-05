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
      local b = broken(function(x)
        x.walls[3] = { 374,656, 352,686, 300,702, 251,692 }
      end)
      local found = kinds(b)
      A.truthy(found.bowl, "the bowl at (300,702) was not reported")
    end)

    it("a wall ending underneath its own flipper pivot", function()
      local b = broken(function(x)
        x.walls[2] = { 10,610, 70,664, 124,690, 133,692 }
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

  describe("does not cry wolf", function()
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
