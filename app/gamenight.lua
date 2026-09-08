--- Optional party lifecycle. Only loaded when GAMENIGHT=1, never by standalone play.
local Match = require("sim.match")
local input = require("app.input")
local render = require("app.render")
local audio = require("app.audio")
local fx = require("app.fx")
local record = require("app.record")
local intents = require("core.intents")
local Transport = require("app.gamenight_transport")
local screen = require("app.gamenight_window")

local GameNight = {}
GameNight.__index = GameNight

local function hide()
  if love.audio then love.audio.stop() end
  screen.hide()
end

local function show()
  screen.show()
end

function GameNight.new(boards, transport)
  hide()
  local self = setmetatable({ boards = boards, phase = "idle", names = {} }, GameNight)
  self.transport = transport or Transport.new(os.getenv("GAMENIGHT_ADDR") or "127.0.0.1:7912",
    os.getenv("GAMENIGHT_GAME_ID") or "pinpals", os.getenv("GAMENIGHT_TOKEN"))
  self.game = os.getenv("GAMENIGHT_GAME_ID") or "pinpals"
  if love.graphics then render.load(boards); render.attach_fx(fx) end
  audio.load()
  hide()
  return self
end

function GameNight:dispose()
  hide()
  if self.match then
    record.finish(self.match)
    for _, board in pairs(self.match.boards) do board.world:destroy() end
  end
  self.match, self.session, self.phase = nil, nil, "idle"
  input.bind_seats({}, {}, {})
  fx.reset()
end

function GameNight:prepare(message)
  self:dispose()
  self.session = message.session
  self.match = Match.new(self.boards, os.time())
  input.bind_seats(message.seats or {}, message.players or {},
    love.joystick and love.joystick.getJoysticks() or {})
  if love.graphics then
    render.inspect = nil
    render.update_camera(self.match.state, self.boards, 1)
  end
  record.start(self.boards, self.match.seed)
  self.phase = "ready"
  self.transport:send({ type = "ready", session = self.session })
end

function GameNight:release_inputs()
  if not self.match then return end
  for player = 1, 2 do
    for _, action in pairs(input.KEYS[player]) do
      self:push(intents.new(player, action, false, self.match.state.tick))
    end
  end
end

function GameNight:receive(message)
  if message.type == "welcome" then
    assert(message.protocol_version == 1, "unsupported GameNight protocol")
  elseif message.type == "prepare" and message.game == self.game then
    if message.session ~= self.session then self:prepare(message) end
  elseif self.session and message.session == self.session then
    if message.type == "start" and self.phase == "ready" then
      self.phase = "running"
      show()
    elseif message.type == "pause" and self.phase == "running" then
      self:release_inputs()
      self.phase = "paused"
      hide()
    elseif message.type == "resume" and self.phase == "paused" then
      self.phase = "running"
      show()
    elseif message.type == "dispose" then
      self:dispose()
    end
  end
end

function GameNight:update(dt)
  local ok, err = self.transport:poll(function(message) self:receive(message) end)
  if not ok then
    print("GameNight disconnected: " .. tostring(err))
    self:dispose()
    self.transport:close()
    love.event.quit()
    return
  end
  if self.phase ~= "running" then
    if love.timer then love.timer.sleep(0.01) end
    return
  end
  self.match:advance(dt)
  local events = self.match:drain_events()
  audio.update(self.match, events)
  fx.update(self.match, events, dt)
  record.update(self.match, events)
  if love.graphics then render.update_camera(self.match.state, self.boards, dt) end
end

function GameNight:draw()
  if self.phase ~= "running" then return end
  render.draw(self.match, { input.legend(1), input.legend(2) })
end

function GameNight:push(intent)
  if not intent then return end
  self.match:push(intent)
  record.intent(intent)
end

function GameNight:key(key, pressed)
  if self.phase ~= "running" then return end
  self:push(input.from_key(key, pressed, self.match.state.tick))
end

function GameNight:pad(joystick, button, pressed)
  if self.phase ~= "running" then return end
  self:push(input.from_pad(joystick, button, pressed, self.match.state.tick))
end

function GameNight:attach(joystick)
  if self.session then input.attach(joystick) end
end

function GameNight:detach(joystick)
  self:release_inputs()
  input.detach(joystick)
end

function GameNight:focus(focused)
  if focused and self.session and (self.phase == "ready" or self.phase == "paused") then
    self.transport:send({ type = "request_start" })
  end
end

function GameNight:quit()
  self:dispose()
  self.transport:close()
  return false
end

return GameNight
