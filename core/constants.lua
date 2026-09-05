--- Single source of truth for physical and timing constants.
--- Per technical-choices.md §4.2: agents must never hardcode these at call sites.
--- Pure Lua. No love.* here.

local C = {}

-- §4.2 World scale -----------------------------------------------------------
-- Box2D is tuned for bodies of 0.1m-10m. A real pinball is 27mm, well under
-- that floor, so the whole game runs at 10x real-world scale.
C.SCALE          = 10          -- real-world multiplier
C.METER          = 64          -- pixels per Box2D meter
C.GRAVITY_MS2    = 11.0        -- ~1.11 m/s^2 down-playfield at 6.5deg, x10
C.GRAVITY_PX     = C.GRAVITY_MS2 * C.METER

-- Board dimensions in world pixels. 6m x 12m at 64 px/m.
C.BOARD_W        = 384
C.BOARD_H        = 768

-- Ball: 27mm x10 = 0.27m diameter.
C.BALL_RADIUS    = 0.135 * C.METER   -- 8.64 px
C.BALL_DENSITY   = 1.5
C.BALL_RESTIT    = 0.30
C.BALL_FRICTION  = 0.04
C.BALL_DAMPING   = 0.05
-- Velocity ceiling. At 10x scale distances are 10x and gravity is 10x, so
-- speeds scale by sqrt(10): a real 10 m/s ball is ~32 m/s here. Above ~34 the
-- ball covers more than its own diameter in a 240 Hz step and thin static
-- edges start to leak, energy-adding bumpers being the usual culprit.
C.BALL_MAX_SPEED = 34 * C.METER      -- 2176 px/s = 9.1 px per fixed step

-- §4.1 Fixed timestep --------------------------------------------------------
C.TICK_HZ        = 240
C.FIXED_DT       = 1 / C.TICK_HZ
-- Backstop against a death spiral, in sim steps per frame. It must sit above
-- what a legitimately slow frame needs: a 30 fps frame is already 8 steps at
-- 240 Hz, so a low cap silently drops time and the game runs in slow motion on
-- a slow machine. The real spiral guard is the 0.25s clamp in Match:advance;
-- this should effectively never fire.
C.MAX_CATCHUP    = 60          -- 0.25s of simulation, matching that clamp

-- Flippers -------------------------------------------------------------------
C.FLIPPER_LEN    = 0.76 * C.METER    -- 76mm x10
C.FLIPPER_THICK  = 0.16 * C.METER
C.FLIPPER_DENSITY= 14
C.FLIPPER_TORQUE = 5.0e6
C.FLIPPER_SPEED  = 34                -- rad/s
C.FLIPPER_REST   = 0.52              -- rad below horizontal, at rest
C.FLIPPER_UP     = -0.36             -- rad above horizontal, when flipped

-- §5 The link ----------------------------------------------------------------
C.TRANSIT_TIME   = 0.80        -- seconds in the tube (latency budget, §6)
C.TRANSIT_MIN_SP = 12 * C.METER
C.TRANSIT_MAX_SP = 40 * C.METER

-- Match flow -----------------------------------------------------------------
C.SERVE_SPEED    = 1050        -- px/s off the plunger; enough to reach the gate
C.SERVE_DELAY    = 0.60        -- pause before a ball is served
C.DRAIN_DELAY    = 0.90        -- pause after a drain before re-serve

-- §6.1 Operator devices: persistent states, never impulses.
C.GATE_THICK     = 9           -- gate arm thickness; core/geometry.lua needs it
-- Travel times are deliberately long enough to read across a room.
C.GATE_TRAVEL    = 0.30
C.PADDLE_TRAVEL  = 0.26

return C
