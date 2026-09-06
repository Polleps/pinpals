--- Entry point. Three modes:
---   love .            play
---   love . --test     headless physics tests, results to stdout (§7)
---   love . --shot N   run N fixed steps, screenshot, quit (§7 visual check)

local C = require("core.constants")

local mode, shot_ticks, shot_open, shot_pass = "play", 240, false, false

for i, v in ipairs(arg or {}) do
  if v == "--test" then mode = "test" end
  if v == "--shot" then mode = "shot"; shot_ticks = tonumber(arg[i + 1]) or 240 end
  if v == "--open" then shot_open = true end
  if v == "--pass" then shot_open = true; shot_pass = true end
end

local match, render, input, audio, fx, record, boards
local debug_on = false
local shot_done = false

--- The window in conf.lua is a floor, not a choice: 1000x780 was sized around
--- a 768px board, and a taller board simply gets drawn smaller inside it. Take
--- whatever the display can spare instead, so the playfield grows with the
--- screen. app/render.lua reads the result rather than assuming it.
---
--- Done here and not in love.conf because love.window does not exist yet at
--- conf time, so the desktop size cannot be asked for there.
local function fit_window()
  if not (love.window and love.window.getDesktopDimensions) then return end
  local dw, dh = love.window.getDesktopDimensions()
  if not dw or dw == 0 then return end
  local w = math.min(1360, math.max(1000, math.floor(dw * 0.86)))
  local h = math.min(1040, math.max(780,  math.floor(dh * 0.86)))
  local cw, ch = love.window.getMode()
  if w == cw and h == ch then return end
  -- setMode replaces the whole flag set, so every flag conf.lua chose has to
  -- be restated or vsync and MSAA quietly turn themselves off.
  love.window.setMode(w, h, { resizable = false, vsync = 1, msaa = 4 })
end

function love.load()
  love.physics.setMeter(C.METER)      -- §4.2: set once, before any world
  boards = require("data.tables.init").load()
  if mode ~= "test" then fit_window() end

  if mode == "test" then
    local ok = require(os.getenv("PINPALS_SUITE") or "tests.run_sim")()
    love.event.quit(ok and 0 or 1)
    return
  end

  local Match = require("sim.match")
  match  = Match.new(boards)
  render = require("app.render")
  input  = require("app.input")
  audio  = require("app.audio")
  fx     = require("app.fx")
  record = require("app.record")
  render.load(boards)
  render.attach_fx(fx)
  audio.load()          -- no-ops if the audio modules are off (--shot, --test)

  -- §7's visual check is only worth anything if what it captures is what the
  -- player sees. fx state exists only because something advanced it, so the
  -- shot path drives it exactly as love.update does -- otherwise every
  -- screenshot shows a game with no trail, no sparks and no lit bumpers.
  local function run_with_fx(n)
    for _ = 1, n do
      match:run(1)
      fx.update(match, match:drain_events(), C.FIXED_DT)
    end
  end

  if mode == "shot" then
    -- Stand in for an operator holding the gate open, so a screenshot can
    -- catch the pass rather than only the safe return loop.
    if shot_open then
      for _, b in pairs(match.state.boards) do b.devices.gate.commanded = true end
    end
    -- --pass puts the ball up the ramp on cue, so the transit and the
    -- handed-over camera can both be captured deterministically.
    if shot_pass then
      run_with_fx(200)
      match.boards[match.state.active]:spawn(
        boards[match.state.active].tube.mouth.x, 520, 0, -C.SERVE_SPEED)
      run_with_fx(math.max(0, shot_ticks - 200))
    else
      run_with_fx(shot_ticks)
    end
    return
  end

  for _, js in ipairs(love.joystick.getJoysticks()) do input.attach(js) end
  -- §5.1: the intent stream makes a session recordable for free. Only in
  -- play mode -- --test and --shot never touch the disk.
  record.start(boards)
end

--- Every intent goes through here, so the recording cannot miss one by
--- someone adding a fifth input path and forgetting about it.
local function push_intent(it)
  if not it then return end
  match:push(it)
  record.intent(it)
end

function love.update(dt)
  if mode ~= "play" then return end
  match:advance(dt)
  -- Drained once and shared: audio and fx must see the same events, and
  -- whichever called drain_events() second would otherwise see none.
  local events = match:drain_events()
  audio.update(match, events)
  fx.update(match, events, dt)
  record.update(match, events)
  render.update_camera(match.state, boards, dt)
end

function love.draw()
  if mode == "test" then return end

  if mode == "shot" then
    render.update_camera(match.state, boards, 1)   -- snap the camera, no easing
    render.draw(match, { input.legend(1), input.legend(2) }, true)
    if not shot_done then
      shot_done = true
      local name = ("shot-%d.png"):format(shot_ticks)
      love.graphics.captureScreenshot(function(img)
        img:encode("png", name)
        print("screenshot: " .. love.filesystem.getSaveDirectory() .. "/" .. name)
        love.event.quit(0)
      end)
    end
    return
  end

  render.draw(match, { input.legend(1), input.legend(2) }, debug_on)
end

---------------------------------------------------------------------------
-- Input -> intents. Nothing else in the codebase reads a device (§5.1).
---------------------------------------------------------------------------

function love.keypressed(key)
  if mode ~= "play" then return end
  if key == "escape" then love.event.quit() return end
  if key == "f1" then debug_on = not debug_on return end
  if key == "r" then
    -- Bank the run before discarding it, or its numbers leave with the Match
    -- that produced them and the session log reports the wrong game.
    record.restart(match)
    match = require("sim.match").new(boards)
    fx.reset()
    return
  end
  push_intent(input.from_key(key, true, match.state.tick))
end

function love.keyreleased(key)
  if mode ~= "play" then return end
  push_intent(input.from_key(key, false, match.state.tick))
end

function love.gamepadpressed(js, button)
  if mode ~= "play" then return end
  push_intent(input.from_pad(js, button, true, match.state.tick))
end

function love.gamepadreleased(js, button)
  if mode ~= "play" then return end
  push_intent(input.from_pad(js, button, false, match.state.tick))
end

function love.joystickadded(js)   if input then input.attach(js) end end
function love.joystickremoved(js) if input then input.detach(js) end end

--- Write the playtest capture on the way out, and say where it went, so a
--- session that felt like something also produced something to read.
function love.quit()
  if mode ~= "play" or not record then return false end
  print(("\n%s\n"):format(record.summary(match)))
  local path = record.finish(match)
  if path then print("session log: " .. path .. "\n") end
  return false
end
