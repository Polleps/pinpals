--- §5.2 The authoritative match state.
--- One serializable object. No gameplay state lives in the renderer, in
--- closures, or in module-level locals. Written as if there were a server, so
--- that "online" later means "one player hosts", not a rewrite.
---
--- Pure Lua. No love.* here, so this whole file is testable in bare `lua`.

local C       = require("core.constants")
local intents = require("core.intents")

local M = {}

local OTHER = { a = "b", b = "a" }

---@param boards table<string, table>
---@return table state
function M.new(boards)
  local s = {
    tick   = 0,
    time   = 0,
    phase  = "serve",   -- "serve" | "play" | "transit" | "drain"
    timer  = C.SERVE_DELAY,
    active = "a",
    transit = nil,
    boards = {},
    -- Not scoring (§14 puts scoring out of scope). These are the instruments
    -- for the one question the prototype exists to answer: does the rally
    -- feel good? Relay length is the readout.
    stats = { passes = 0, drains = 0, relay = 0, best_relay = 0 },
  }
  for id, def in pairs(boards) do
    local b = { id = id, flippers = { left = false, right = false }, devices = {} }
    for _, d in ipairs(def.devices) do
      -- `commanded` is a rule-level fact: what the operator has asked for.
      -- Where the device physically *is* belongs to sim/, not here.
      b.devices[d.id] = { commanded = false }
    end
    s.boards[id] = b
  end
  return s
end

--- Roles are implicit in ball position; there is no role-select UI (§4).
--- The owner of the active board flips; the other player operates that board.
---@param s table
---@param it Intent
function M.apply_intent(s, it)
  local role = intents.role_of(it.player, s.active)
  local board = s.boards[s.active]
  if not board then return end

  if role == "flipper" then
    if s.phase ~= "play" then return end        -- no ball, no flippers
    if it.action == "flip_left"  then board.flippers.left  = it.pressed end
    if it.action == "flip_right" then board.flippers.right = it.pressed end
  else
    -- The operator acts on the active board at all times, including during
    -- transit: that 800ms is the sender's chance to prepare the landing.
    if it.action == "operator_gate" then
      local d = board.devices.gate;  if d then d.commanded = it.pressed end
    elseif it.action == "operator_paddle" then
      local d = board.devices.post;  if d then d.commanded = it.pressed end
    end
  end
end

---@param s table
---@param list Intent[]
function M.apply_intents(s, list)
  for _, it in ipairs(list) do M.apply_intent(s, it) end
end

--- Release every flipper on every board. Used when the ball leaves, so a held
--- key doesn't leave a flipper stuck up on a board nobody is looking at.
local function release_flippers(s)
  for _, b in pairs(s.boards) do
    b.flippers.left, b.flippers.right = false, false
  end
end

--- Advance non-physics match flow by one fixed step.
--- Pure: returns the commands sim/ should carry out. Never touches physics.
---@param s table
---@return table[] commands
function M.update(s)
  local dt = C.FIXED_DT
  s.tick = s.tick + 1
  s.time = s.time + dt
  local cmds = {}

  if s.phase == "serve" then
    s.timer = s.timer - dt
    if s.timer <= 0 then
      s.phase = "play"
      cmds[#cmds+1] = { kind = "serve", board = s.active }
    end

  elseif s.phase == "drain" then
    s.timer = s.timer - dt
    if s.timer <= 0 then
      s.phase = "serve"
      s.timer = C.SERVE_DELAY
    end

  elseif s.phase == "transit" then
    local t = s.transit
    t.t = t.t + dt
    if t.t >= t.duration then
      s.phase = "play"
      s.transit = nil
      cmds[#cmds+1] = { kind = "arrive", board = t.to, speed = t.speed }
    end
  end

  return cmds
end

--- Fold events reported by sim/ back into the rules.
---@param s table
---@param events table[]
function M.consume(s, events)
  for _, ev in ipairs(events) do
    if ev.kind == "tube" and s.phase == "play" then
      local from = ev.board
      local to   = OTHER[from]
      -- §5: the pass carries state. Exit speed survives the trip, clamped so a
      -- desperate flail still arrives fast and a dribble still arrives moving.
      local speed = math.max(C.TRANSIT_MIN_SP, math.min(C.TRANSIT_MAX_SP, ev.speed))
      release_flippers(s)
      s.phase   = "transit"
      s.transit = { from = from, to = to, t = 0, duration = C.TRANSIT_TIME, speed = speed }
      -- The destination board becomes active immediately: for the ~800ms of
      -- flight the sender is already the operator over there, rearranging the
      -- floor the ball is about to land on.
      s.active  = to
      s.stats.passes = s.stats.passes + 1
      s.stats.relay  = s.stats.relay + 1
      if s.stats.relay > s.stats.best_relay then s.stats.best_relay = s.stats.relay end

    elseif ev.kind == "drain" and s.phase == "play" then
      release_flippers(s)
      s.phase = "drain"
      s.timer = C.DRAIN_DELAY
      s.stats.drains = s.stats.drains + 1
      s.stats.relay  = 0
    end
  end
end

--- Convenience for the renderer and for tests: what is each player doing?
---@param s table
---@return table<1|2, "flipper"|"operator">
function M.roles(s)
  return { [1] = intents.role_of(1, s.active), [2] = intents.role_of(2, s.active) }
end

M.OTHER = OTHER

return M
