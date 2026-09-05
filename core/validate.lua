--- §5.3 Board data validator.
--- Board layouts are declarative data. Both the game and the tests load the
--- same definitions, so a bad table must fail loudly and early rather than as
--- a nil index somewhere inside sim/.
--- Pure Lua. No love.* here.

local M = {}

local function isnum(v) return type(v) == "number" and v == v end

local function vec(errs, where, v)
  if type(v) ~= "table" or not isnum(v.x) or not isnum(v.y) then
    errs[#errs + 1] = where .. ": expected {x=number, y=number}"
    return false
  end
  return true
end

---@param b table board definition
---@return boolean ok, string[] errors
function M.board(b)
  local e = {}
  if type(b) ~= "table" then return false, { "board: not a table" } end

  if b.id ~= "a" and b.id ~= "b" then e[#e+1] = "id: must be 'a' or 'b'" end
  if type(b.name) ~= "string" then e[#e+1] = "name: must be a string" end

  if type(b.size) ~= "table" or not isnum(b.size.w) or not isnum(b.size.h) then
    e[#e+1] = "size: expected {w=number, h=number}"
  end

  -- Walls are polylines: flat lists of x,y pairs, at least two points.
  if type(b.walls) ~= "table" or #b.walls == 0 then
    e[#e+1] = "walls: expected a non-empty list of polylines"
  else
    for i, poly in ipairs(b.walls) do
      if type(poly) ~= "table" or #poly < 4 or #poly % 2 ~= 0 then
        e[#e+1] = ("walls[%d]: expected an even list of >=4 coordinates"):format(i)
      end
    end
  end

  for i, bump in ipairs(b.bumpers or {}) do
    if not (isnum(bump.x) and isnum(bump.y) and isnum(bump.r)) then
      e[#e+1] = ("bumpers[%d]: expected x, y, r"):format(i)
    end
  end

  -- Exactly one left and one right flipper.
  local sides = {}
  if type(b.flippers) ~= "table" or #b.flippers ~= 2 then
    e[#e+1] = "flippers: expected exactly 2"
  else
    for i, f in ipairs(b.flippers) do
      if f.side ~= "left" and f.side ~= "right" then
        e[#e+1] = ("flippers[%d].side: expected 'left' or 'right'"):format(i)
      elseif sides[f.side] then
        e[#e+1] = ("flippers[%d]: duplicate %s flipper"):format(i, f.side)
      else
        sides[f.side] = true
      end
      if not (isnum(f.x) and isnum(f.y)) then
        e[#e+1] = ("flippers[%d]: expected x, y"):format(i)
      end
    end
  end

  -- §6.1: every device must be a persistent state with a real travel time.
  -- A device that snaps is a design bug, so it is a validation error.
  local seen, kinds = {}, {}
  if type(b.devices) ~= "table" or #b.devices ~= 2 then
    e[#e+1] = "devices: prototype expects exactly 2 (one gate, one paddle)"
  end
  for i, d in ipairs(b.devices or {}) do
    local at = ("devices[%d]"):format(i)
    if type(d.id) ~= "string" then
      e[#e+1] = at .. ".id: must be a string"
    elseif seen[d.id] then
      e[#e+1] = at .. ": duplicate id " .. d.id
    else
      seen[d.id] = true
    end
    kinds[d.kind or "?"] = true
    if not isnum(d.travel) or d.travel < 0.15 then
      e[#e+1] = at .. ".travel: must be >= 0.15s (design.md §6.1: states, not impulses)"
    end
    if type(d.tradeoff) ~= "string" or #d.tradeoff == 0 then
      e[#e+1] = at .. ".tradeoff: must state what this device gives up (§6.2)"
    end
    if d.kind == "gate" then
      vec(e, at .. ".pivot", d.pivot)
      if not isnum(d.length) then e[#e+1] = at .. ".length: expected number" end
      if not (isnum(d.closed) and isnum(d.open)) then
        e[#e+1] = at .. ": expected closed/open angles in radians"
      elseif math.abs(d.open - d.closed) < 0.2 then
        e[#e+1] = at .. ": open and closed angles are too close to tell apart"
      end
    elseif d.kind == "paddle" then
      vec(e, at .. ".down", d.down)
      vec(e, at .. ".up", d.up)
      if not (isnum(d.w) and isnum(d.h)) then e[#e+1] = at .. ": expected w, h" end
    else
      e[#e+1] = at .. ".kind: expected 'gate' or 'paddle'"
    end
  end
  if b.devices and #b.devices == 2 and not (kinds.gate and kinds.paddle) then
    e[#e+1] = "devices: prototype expects one gate and one paddle"
  end

  -- The link (§5). One tube out, one arrival point in.
  if type(b.tube) ~= "table" then
    e[#e+1] = "tube: missing"
  else
    vec(e, "tube.mouth", b.tube.mouth)
    if not isnum(b.tube.mouth and b.tube.mouth.r) then
      e[#e+1] = "tube.mouth.r: expected number"
    end
    if b.tube.to ~= "a" and b.tube.to ~= "b" then
      e[#e+1] = "tube.to: expected 'a' or 'b'"
    elseif b.tube.to == b.id then
      e[#e+1] = "tube.to: a board may not pass to itself"
    end
  end

  if vec(e, "entry", b.entry) then
    -- vec() appends its own error for a bad shape, so the only thing left
    -- to check here is that a well-formed direction is not the zero vector.
    if vec(e, "entry.dir", b.entry.dir)
       and b.entry.dir.x == 0 and b.entry.dir.y == 0 then
      e[#e+1] = "entry.dir: must be a non-zero direction"
    end
  end
  if vec(e, "serve", b.serve) then vec(e, "serve.dir", b.serve.dir) end

  if not isnum(b.drain_y) then e[#e+1] = "drain_y: expected number" end

  -- Everything must sit inside the playfield.
  if type(b.size) == "table" and isnum(b.size.w) and isnum(b.size.h) then
    local function inside(where, x, y)
      if isnum(x) and isnum(y) and (x < 0 or y < 0 or x > b.size.w or y > b.size.h) then
        e[#e+1] = ("%s: (%g, %g) is outside the playfield"):format(where, x, y)
      end
    end
    for _, f in ipairs(b.flippers or {}) do inside("flipper", f.x, f.y) end
    for _, bump in ipairs(b.bumpers or {}) do inside("bumper", bump.x, bump.y) end
    if b.tube and b.tube.mouth then inside("tube.mouth", b.tube.mouth.x, b.tube.mouth.y) end
    if b.entry then inside("entry", b.entry.x, b.entry.y) end
    if b.serve then inside("serve", b.serve.x, b.serve.y) end
  end

  return #e == 0, e
end

--- Validate a full board set and the wiring between them.
---@param boards table<string, table>
---@return boolean ok, string[] errors
function M.set(boards)
  local e = {}
  for _, id in ipairs({ "a", "b" }) do
    local b = boards[id]
    if not b then
      e[#e+1] = "board " .. id .. ": missing"
    else
      local ok, errs = M.board(b)
      if not ok then
        for _, msg in ipairs(errs) do e[#e+1] = "board " .. id .. ": " .. msg end
      end
      if b.id ~= id then e[#e+1] = "board " .. id .. ": id field disagrees with key" end
    end
  end
  -- Each tube must land somewhere real (§5).
  for _, id in ipairs({ "a", "b" }) do
    local b = boards[id]
    if b and b.tube and b.tube.to then
      local dest = boards[b.tube.to]
      if not dest then
        e[#e+1] = ("board %s: tube leads to unknown board %s"):format(id, b.tube.to)
      elseif not dest.entry then
        e[#e+1] = ("board %s: destination board %s has no entry point"):format(id, b.tube.to)
      end
    end
  end
  return #e == 0, e
end

return M
