--- Reusable switch -> stored energy -> powered device/route connections.
--- State is plain match data; the renderer and physics only read it.
local C = require("core.constants")
local M = {}

function M.new(def)
  local circuits = {}
  for _, spec in ipairs(def.circuits or {}) do
    circuits[spec.id] = { charge = 0, capacity = spec.capacity, route = spec.route,
      label = spec.label, active = false, attempts = 0, completed = 0 }
  end
  return circuits
end

function M.powered(board, device)
  if not device.circuit then return true end
  local c = board.circuits and board.circuits[device.circuit]
  return c ~= nil and c.charge >= c.capacity
end

function M.switch(board, ev, tick)
  local spec = board.switches and board.switches[ev.index]
  if not spec or (ev.speed or 0) < spec.threshold then return false end
  local last = board.switch_ticks[spec.id]
  if last and tick - last < spec.cooldown * C.TICK_HZ then return false end
  board.switch_ticks[spec.id] = tick
  local c = board.circuits[spec.circuit]
  local amount = ev.speed >= spec.strong and 2 or 1
  c.charge = math.min(c.capacity, c.charge + amount)
  return true
end

function M.route(board, ev)
  for _, c in pairs(board.circuits or {}) do
    if ev.id == c.route then
      if ev.at == "enter" and not c.active then
        c.charge, c.active = 0, true
        c.attempts = c.attempts + 1
      elseif ev.at == "exit" and c.active then
        c.active = false
        if ev.complete then c.completed = c.completed + 1 end
      end
    end
  end
end

function M.drain(board)
  for _, c in pairs(board.circuits or {}) do c.active = false end
end

return M
