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
-- Pinned to the ball's own ceiling rather than set independently. At 40 m/s
-- the top 384 px/s of this clamp was dead range: sim/ clamps the ball to
-- BALL_MAX_SPEED on the very next step, so an arrival could never actually
-- reach it and the constant quietly lied about the range.
C.TRANSIT_MAX_SP = C.BALL_MAX_SPEED

-- §9 Scoring: the multiplier lives on passing, not on shots ------------------
-- Heat is earned only by crossing the tube, and then multiplies everything.
-- That is what makes a rally simultaneously more valuable and more likely to
-- end -- a risk curve generated entirely by cooperation, with no timer and no
-- difficulty setting behind it.
C.HEAT_MAX       = 10          -- x10 ceiling, so a long rally still has a top
C.SCORE_PASS     = 1000        -- awarded per crossing, at the new heat
C.SCORE_BUMPER   = 50          -- the only shot content that exists yet
-- There is deliberately no bumper cooldown constant. One was written, then
-- measured away: see the note in sim/board.lua:_begin and the numbers in
-- tests/probe_scoring.lua.

-- §9 "worth more, AND MOVING FASTER". Heat raises the speed the ball arrives
-- at, so the rally gets physically harder to hold as it gets valuable.
--
-- Deliberately NOT done by shortening transit: §5 and §11 make that 800ms the
-- online latency budget, so spending it on escalation would foreclose network
-- play to buy something a speed multiplier already gives us.
C.HEAT_SPEED_STEP = 0.05       -- +5% arrival speed per crossing
C.HEAT_SPEED_MAX  = 1.55       -- ceiling on that multiplier

-- Match flow -----------------------------------------------------------------
C.SERVE_SPEED    = 1050        -- px/s off the plunger; enough to reach the gate
C.SERVE_DELAY    = 0.60        -- pause before a ball is served
C.DRAIN_DELAY    = 0.90        -- pause after a drain before re-serve

-- Impacts (presentation only) ------------------------------------------------
-- sim/ reports ball contacts so app/ can sound and light them. The floor
-- separates a hit from a lean: a ball merely resting on a surface still
-- solves a contact impulse every step, and at 240 Hz an unfiltered feed is a
-- machine-gun rather than a set of hits.
--
-- That resting impulse is not a matter of taste, it is the ball's own weight
-- carried for one step: m*g*dt, reported by Box2D in pixel units. Measuring
-- 240s of play put 90% of wall contacts at 0.249-0.250 against a predicted
-- 0.2519 -- the cluster IS the ball sitting still. So the floor is defined as
-- a margin above that, and any real bounce clears it comfortably: an impact
-- at v m/s solves about m*v*(1+e)*METER, so even a 0.05 m/s nudge lands at
-- 0.34. Event rate across the cliff: 96.9/s at 0.20, 7.2/s at 0.30.
C.BALL_MASS           = C.BALL_DENSITY * math.pi * 0.135 * 0.135   -- kg
C.IMPACT_REST_IMPULSE = C.BALL_MASS * C.GRAVITY_MS2 * C.FIXED_DT * C.METER
C.IMPACT_MIN_IMPULSE  = C.IMPACT_REST_IMPULSE * 1.19   -- 0.300
C.IMPACT_MAX_PER_STEP = 4      -- one ball cannot meaningfully hit more

-- §6.1 Operator devices: persistent states, never impulses.
C.GATE_THICK     = 9           -- gate arm thickness; core/geometry.lua needs it
-- Travel times are deliberately long enough to read across a room.
C.GATE_TRAVEL    = 0.30
C.PADDLE_TRAVEL  = 0.26

return C
