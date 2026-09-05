--- §5.2 The authoritative match state.
--- One serializable object. No gameplay state lives in the renderer, in
--- closures, or in module-level locals. Written as if there were a server, so
--- that "online" later means "one player hosts", not a rewrite.
---
--- Pure Lua. No love.* here, so this whole file is testable in bare `lua`.

local C       = require("core.constants")
local intents = require("core.intents")
local score   = require("core.score")

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
    stats = {
      passes = 0, drains = 0, relay = 0, best_relay = 0,
      -- §9. `score` is the session record; `rally_score` is what the current
      -- rally has been worth and dies with it, so `best_rally_score` is the
      -- one that says how good these two got together.
      score = 0, rally_score = 0, best_rally_score = 0,
    },
  }
  for id, def in pairs(boards) do
    local b = {
      id = id, flippers = { left = false, right = false },
      devices = {}, targets = {}, banks = {},
      -- §7 cross-board state. `meters` is what the OTHER board has been
      -- filling up here and this board can cash; `lit` is what the other
      -- board has switched on here. Both are plain numbers so the whole
      -- state stays serializable (§5.2), and both survive the ball leaving
      -- -- that is the point: the dormant board keeps what you built.
      meters = {}, lit = {}, links = def.links or {},
    }
    for _, d in ipairs(def.devices) do
      -- `commanded` is a rule-level fact: what the operator has asked for.
      -- Where the device physically *is* belongs to sim/, not here.
      b.devices[d.id] = { commanded = false }
    end
    -- Which targets make up which bank, resolved once here rather than
    -- rediscovered from the definitions on every hit. Plain data, so the
    -- whole state stays serializable (§5.2).
    for i, t in ipairs(def.targets or {}) do
      b.targets[i] = { lit = false, bank = t.bank }
      local bank = b.banks[t.bank]
      if not bank then bank = { members = {}, cleared = 0 }; b.banks[t.bank] = bank end
      bank.members[#bank.members+1] = i
      b.meters[t.bank] = b.meters[t.bank] or 0
    end
    b.lit.bumpers = 0
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
  -- One-frame signal for app/: what was just scored and where. Cleared here
  -- rather than by the reader, so nothing depends on someone remembering to.
  s.last_award = nil
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

--- Fire every link on `from` whose trigger matches, against the whole state.
--- Links are board data (§5.3), so adding a new cross-board relationship is a
--- table entry rather than a branch in here.
---@param s table
---@param from string board id the trigger happened on
---@param trigger string "bumper" | "bank:<name>"
local function fire_links(s, from, trigger)
  for _, l in ipairs(s.boards[from].links or {}) do
    if l.when == trigger then
      if l.charges then
        local dest = s.boards[l.charges.board]
        local m = l.charges.meter
        if dest and dest.meters[m] then
          dest.meters[m] = math.min(C.CHARGE_MAX, dest.meters[m] + 1)
        end
      elseif l.lights then
        local dest = s.boards[l.lights.board]
        if dest then dest.lit[l.lights.what] = C.LIT_HITS end
      end
    end
  end
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
      -- §9 "worth more, and moving faster": heat scales the arrival before
      -- the clamp, so a hot rally lands harder and is genuinely harder to
      -- hold. The clamp still has the last word, so this can never outrun the
      -- ball's own ceiling or the tunneling budget behind it.
      local scaled = ev.speed * score.speed_scale(s.stats.relay)
      local speed = math.max(C.TRANSIT_MIN_SP, math.min(C.TRANSIT_MAX_SP, scaled))
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
      -- Awarded at the NEW heat: the crossing that makes the rally hotter is
      -- itself worth the hotter rate, so the escalation is visible on the
      -- pass that earned it rather than one pass late.
      s.last_award = { kind = "pass", value = score.award(s.stats, "pass"), board = to }

    elseif ev.kind == "target" and s.phase == "play" then
      local board = s.boards[ev.board]
      local t = board and board.targets[ev.index]
      if t then
        -- A standup scores every time it is struck, the way a real one does,
        -- but only counts once toward its bank. Otherwise the cheapest way to
        -- clear a bank is to rattle against a single target.
        local total = score.award(s.stats, "target")
        if not t.lit then
          t.lit = true
          local bank = board.banks[t.bank]
          if bank and M.bank_complete(board, bank) then
            -- §7's payoff. The bonus is scaled by everything the partner
            -- board charged into this meter, so clearing a vault Foundry has
            -- been filling is worth many times clearing a cold one -- which
            -- is what makes "play A to prepare B" a real sentence rather
            -- than a description of nothing.
            local charge = board.meters[t.bank] or 0
            total = total + score.award(s.stats, "bank", 1 + charge)
            board.meters[t.bank] = 0
            bank.cleared = bank.cleared + 1
            for _, mi in ipairs(bank.members) do board.targets[mi].lit = false end
            fire_links(s, ev.board, "bank:" .. t.bank)
          end
        end
        s.last_award = {
          kind = "target", value = total, board = ev.board, x = ev.x, y = ev.y,
        }
      end

    elseif ev.kind == "bumper" and s.phase == "play" then
      local board = s.boards[ev.board]
      -- A lit bumper is the payoff coming home: Glasshouse cleared its vault,
      -- and Foundry's cheap chaos is briefly worth LIT_MULT times as much.
      local boost = 1
      if (board.lit.bumpers or 0) > 0 then
        boost = C.LIT_MULT
        board.lit.bumpers = board.lit.bumpers - 1
      end
      s.last_award = {
        kind = "bumper", value = score.award(s.stats, "bumper", boost),
        board = ev.board, x = ev.x, y = ev.y, boosted = boost > 1,
      }
      fire_links(s, ev.board, "bumper")

    elseif ev.kind == "drain" and s.phase == "play" then
      release_flippers(s)
      s.phase = "drain"
      s.timer = C.DRAIN_DELAY
      s.stats.drains = s.stats.drains + 1
      s.stats.relay  = 0
      score.end_rally(s.stats)
    end
  end
end

--- Is every target in this bank lit?
---@param board table per-board state
---@param bank table
---@return boolean
function M.bank_complete(board, bank)
  for _, i in ipairs(bank.members) do
    if not board.targets[i].lit then return false end
  end
  return true
end

--- Convenience for the renderer and for tests: what is each player doing?
---@param s table
---@return table<1|2, "flipper"|"operator">
function M.roles(s)
  return { [1] = intents.role_of(1, s.active), [2] = intents.role_of(2, s.active) }
end

M.OTHER = OTHER

return M
