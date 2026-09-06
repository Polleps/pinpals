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

-- Slot 1 is player 1 and slot 2 is player 2, permanently. Holes are expected:
-- a disconnected pad empties its slot rather than closing the gap, so `#` is
-- never used on this table (it is undefined on a table with holes anyway).
M.joysticks = {}

local MAX_PADS = 2

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
  for player = 1, MAX_PADS do
    if M.joysticks[player] == joystick then
      return intents.new(player, action, pressed, tick)
    end
  end
  return nil
end

--- Take the lowest free slot. A pad reconnecting after a dropout gets its
--- number back rather than queueing behind the player who stayed connected.
function M.attach(joystick)
  for player = 1, MAX_PADS do
    if M.joysticks[player] == nil then
      M.joysticks[player] = joystick
      return player
    end
  end
  return nil                      -- a third pad is ignored
end

--- Empty the slot; do NOT close the gap.
---
--- This used to be a table.remove, which shifted player 2's pad into slot 1.
--- Unplugging player 1 -- a dead battery, a kicked cable -- silently handed
--- player 2 the other player's board: their flippers, their devices, the
--- wrong half of a two-player game, with nothing on screen to say so.
function M.detach(joystick)
  for player = 1, MAX_PADS do
    if M.joysticks[player] == joystick then
      M.joysticks[player] = nil
      return player
    end
  end
  return nil
end

--- Human-readable bindings, for the on-screen legend.
function M.legend(player)
  local out = {}
  for key, action in pairs(M.KEYS[player]) do out[action] = key end
  return out
end

return M
