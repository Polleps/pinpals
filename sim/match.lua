--- Owns both board worlds, the fixed-step accumulator, and the wiring between
--- core/ (rules) and sim/ (physics).
---
--- love.physics only.

local C     = require("core.constants")
local core  = require("core.state")
local Board = require("sim.board")

local Match = {}
Match.__index = Match

---@param boards table<string, table> validated definitions
function Match.new(boards)
  local self = setmetatable({}, Match)
  self.defs   = boards
  self.state  = core.new(boards)
  self.boards = { a = Board.new(boards.a), b = Board.new(boards.b) }
  self.acc    = 0
  self.alpha  = 0
  self.pending = {}
  self.prev = { a = self:_snapshot("a"), b = self:_snapshot("b") }
  self.cur  = { a = self.prev.a, b = self.prev.b }
  return self
end

--- Queue intents for the next fixed step (§5.1). Local play delivers them with
--- zero delay; a socket would deliver them here too.
function Match:push(intent)
  self.pending[#self.pending+1] = intent
end

function Match:_snapshot(id)
  local b = self.boards[id]
  local snap = { flippers = {}, devices = {} }
  local x, y = b:ball_pos()
  if x then snap.ball = { x = x, y = y } end
  for side, f in pairs(b.flippers) do snap.flippers[side] = f.body:getAngle() end
  for did, dev in pairs(b.devices) do
    if dev.kind == "gate" then
      snap.devices[did] = { angle = dev.body:getAngle(), p = b:device_progress(did) }
    else
      local dx, dy = dev.body:getPosition()
      snap.devices[did] = { x = dx, y = dy, p = b:device_progress(did) }
    end
  end
  return snap
end

function Match:_tick()
  local s = self.state

  core.apply_intents(s, self.pending)
  self.pending = {}

  for _, cmd in ipairs(core.update(s)) do
    if cmd.kind == "serve" then
      self.boards[cmd.board]:serve()
    elseif cmd.kind == "arrive" then
      self.boards[cmd.board]:arrive(cmd.speed)
    end
  end

  -- Step both worlds. The dormant board has no ball but keeps simulating, so
  -- its devices hold and animate the state the operator left them in (§7).
  local events = {}
  for id, b in pairs(self.boards) do
    local has_ball = b.ball ~= nil
    for _, ev in ipairs(b:step(s.boards[id], has_ball)) do
      events[#events+1] = ev
    end
  end

  core.consume(s, events)

  if s.phase == "transit" and s.transit then
    self.boards[s.transit.from]:despawn()
  elseif s.phase == "drain" then
    for _, b in pairs(self.boards) do b:despawn() end
  end
end

--- §4.1: accumulate real time, consume it in fixed chunks. The simulation
--- never sees a variable dt.
function Match:advance(real_dt)
  self.acc = self.acc + math.min(real_dt, 0.25)
  local steps = 0
  while self.acc >= C.FIXED_DT and steps < C.MAX_CATCHUP do
    self.prev.a, self.prev.b = self.cur.a, self.cur.b
    self:_tick()
    self.cur.a, self.cur.b = self:_snapshot("a"), self:_snapshot("b")
    self.acc = self.acc - C.FIXED_DT
    steps = steps + 1
  end
  if steps == C.MAX_CATCHUP then self.acc = 0 end   -- we are behind; drop it
  self.alpha = self.acc / C.FIXED_DT
  return steps
end

--- Run n fixed steps with no wall-clock involved. For headless tests.
function Match:run(n)
  for _ = 1, n do
    self.prev.a, self.prev.b = self.cur.a, self.cur.b
    self:_tick()
    self.cur.a, self.cur.b = self:_snapshot("a"), self:_snapshot("b")
  end
end

return Match
