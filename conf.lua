--- §7: agents must be able to prove their work without a human looking at a
--- screen. `love . --test` disables the window entirely; love.physics needs
--- none, so the whole simulation is testable headless.

local function has_flag(name)
  for _, v in ipairs(arg or {}) do if v == name then return true end end
  return os.getenv("PINPALS_HEADLESS") == "1"
end

function love.conf(t)
  t.identity           = "pinpals"
  t.version            = "11.5"          -- §2.4: pinned, verified at setup
  t.window.title       = "Pinpals - prototype"
  t.window.width       = 1000
  t.window.height      = 780
  t.window.resizable   = false
  t.window.vsync       = 1
  t.window.msaa        = 4

  t.modules.joystick   = true
  t.modules.physics    = true
  t.modules.audio      = false
  t.modules.sound      = false
  t.modules.video      = false
  t.modules.touch      = false

  if has_flag("--test") then
    t.modules.window   = false
    t.modules.graphics = false
    t.modules.joystick = false
  end
end
