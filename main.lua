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

local match, render, input, audio, fx, boards
local debug_on = false
local shot_done = false

function love.load()
  love.physics.setMeter(C.METER)      -- §4.2: set once, before any world
  boards = require("data.tables.init").load()

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
end

function love.update(dt)
  if mode ~= "play" then return end
  match:advance(dt)
  -- Drained once and shared: audio and fx must see the same events, and
  -- whichever called drain_events() second would otherwise see none.
  local events = match:drain_events()
  audio.update(match, events)
  fx.update(match, events, dt)
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
    match = require("sim.match").new(boards)
    fx.reset()
    return
  end
  local it = input.from_key(key, true, match.state.tick)
  if it then match:push(it) end
end

function love.keyreleased(key)
  if mode ~= "play" then return end
  local it = input.from_key(key, false, match.state.tick)
  if it then match:push(it) end
end

function love.gamepadpressed(js, button)
  if mode ~= "play" then return end
  local it = input.from_pad(js, button, true, match.state.tick)
  if it then match:push(it) end
end

function love.gamepadreleased(js, button)
  if mode ~= "play" then return end
  local it = input.from_pad(js, button, false, match.state.tick)
  if it then match:push(it) end
end

function love.joystickadded(js)   if input then input.attach(js) end end
function love.joystickremoved(js) if input then input.detach(js) end end
