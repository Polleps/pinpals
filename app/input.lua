--- Raw devices -> intents (§5.1, §9).
--- This is the ONLY place that touches love.keyboard / love.joystick. Nothing
--- downstream knows or cares which device an intent came from.

local intents = require("core.intents")

local M = {}

-- Shared keyboard fallback: P1 on the left cluster, P2 on the arrows, so two
-- people can sit at one keyboard.
M.KEYS = {
  [1] = { a = "flip_left", d = "flip_right", w = "operator_gate", s = "operator_paddle" },
  [2] = { left = "flip_left", right = "flip_right", up = "operator_gate", down = "operator_paddle" },
}

-- Target configuration: two gamepads.
M.PAD = {
  leftshoulder = "flip_left", rightshoulder = "flip_right",
  a = "operator_gate", b = "operator_paddle",
}

M.joysticks = {}   -- [1] and [2], in connection order

---@param key string
---@param pressed boolean
---@param tick integer
---@return Intent|nil
function M.from_key(key, pressed, tick)
  for player, map in pairs(M.KEYS) do
    local action = map[key]
    if action then return intents.new(player, action, pressed, tick) end
  end
  return nil
end

---@return Intent|nil
function M.from_pad(joystick, button, pressed, tick)
  local action = M.PAD[button]
  if not action then return nil end
  for player, js in pairs(M.joysticks) do
    if js == joystick then return intents.new(player, action, pressed, tick) end
  end
  return nil
end

function M.attach(joystick)
  if #M.joysticks < 2 then M.joysticks[#M.joysticks + 1] = joystick end
end

function M.detach(joystick)
  for i, js in ipairs(M.joysticks) do
    if js == joystick then table.remove(M.joysticks, i) return end
  end
end

--- Human-readable bindings, for the on-screen legend.
function M.legend(player)
  local out = {}
  for key, action in pairs(M.KEYS[player]) do out[action] = key end
  return out
end

return M
