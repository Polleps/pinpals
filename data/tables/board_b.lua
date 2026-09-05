--- Board B - "Glasshouse". Player 2's home board.
---
--- design.md §13.1 -- what is each board FOR? -- answered PROVISIONALLY here
--- and in docs/design.md. The short version: Foundry is where a rally
--- SURVIVES, Glasshouse is where it PAYS.
---
---   Foundry     chaotic, forgiving, cheap. A bumper cluster in the orbit
---               keeps the ball alive and crowds the aim. Ball life 12.19s,
---               24 points/s, pass 54%.
---   Glasshouse  clean, precise, expensive. No bumpers, a bank of standup
---               targets worth 5x a bumper, and a drain gap 16px wider.
---               Ball life 9.05s, 351 points/s, pass 66% -- the easiest
---               shot in the game to aim, and the shortest ball.
---
--- That makes the pass the decision design.md §6.2 asks for, one level up
--- from the devices: do I keep the rally safe, or do I send it somewhere it
--- can actually score? A hot rally is worth more on Glasshouse and more
--- likely to die there, which is §9's risk curve expressed as geometry.
---
--- The previous identity claim -- "easy to aim, punishing to sit on" -- was
--- never checked and was measurably backwards: Glasshouse had the HIGHER
--- survival rate of the two boards (27% against Foundry's 15%). It was the
--- safer board wearing the dangerous board's description.
---
--- Deliberately not a mirror of A (design.md §7): the handedness is flipped so
--- the two boards read differently at a glance, but the upper field differs in
--- kind, not just in layout.

local pi = math.pi

return {
  id   = "b",
  name = "Glasshouse",
  size = { w = 384, h = 768 },

  walls = {
    -- Outer shell: right wall, top arc, left wall.
    { 374,610,  374,90,  314,14,  70,14,  10,90,  10,656 },
    -- Lower right: monotone descent, ending just outside the pivot.
    { 374,610,  330,656,  296,672,  262,683 },
    -- Lower left: was V-shaped at (84,702) and trapped the ball.
    { 10,656,  44,672,  90,679,  123,683 },
    -- The pass ramp, left of centre: the left flipper's natural shot.
    --
    -- Raised from y=600 for the reason given in board_a.lua -- a mouth 88px
    -- above the pivots intercepts every shot before it can travel sideways.
    -- B responds differently to A, though, and better: raising it makes the
    -- pass EASIER rather than harder, because B's ramp is off-centre and the
    -- extra height lets the right flipper feed it cleanly.
    --
    --   mouth y   pass   right field
    --      600     58%          4%
    --      570     62%          6%
    --      540     66%         10%   <- here
    --      510     50%         42%
    --
    -- 66% against Foundry's 52% is the identity in one number: Glasshouse is
    -- the board you pass FROM. y=510 opens the right field much further but
    -- costs the thing that makes this board itself.
    { 116,540,  143,480,  143,150 },
    { 222,540,  195,480,  195,150 },
    -- Roof over the ramp head -- see board_a.lua for why this is not optional.
    { 143,150,  169,128,  195,150 },
    -- One deflector rail left in the upper right, to feed the bank below it.
    -- There used to be two, and prototype.md called them "not yet a
    -- character, just an absence of one". The lower one has become the bank.
    -- They must not meet -- crossed, they formed a funnel that caught 19 of
    -- 182 test drops.
    { 236,236,  320,300 },
  },

  bumpers = {},  -- none: chaos is Foundry's job

  -- B's character, and the only aimed scoring content in the game. Placed
  -- along the line the lower rail used to occupy, which the reach map puts
  -- squarely in the right field a flipper shot can get to.
  --
  -- A bank: each target lights when struck, and lighting all three pays
  -- SCORE_BANK on top and resets them. Hitting a lit target still scores,
  -- but does not re-count -- otherwise the cheapest way to clear a bank is to
  -- rattle against one target.
  -- Spaced 50px along the rail line against a 28px width, so the gaps are
  -- 22px -- wider than the 17.3px ball. The first draft used 34px targets
  -- 33px apart, which overlapped into a single bar on screen and formed
  -- throats between them in the physics. core/geometry.lua now has a
  -- target-to-target wedge check because of it.
  -- A TWO-target bank, not three, and that is measured rather than tidy.
  -- The rail above splits the falling ball into two streams, at roughly
  -- x=244 and x=336, with nothing coming down the middle. A three-target row
  -- across that span puts its middle at x=290 -- geometry forbids closer,
  -- since the gaps must clear a 17.3px ball -- and there it took 4 hits
  -- against its neighbours' 50 and 52. A bank whose middle target is
  -- unreachable is a bank that never completes, which is worse than no bank:
  -- it is a mechanic that visibly exists and silently cannot be finished.
  --
  -- Trying to feed the middle by moving the rail produced the other failure
  -- mode: at (214,250)-(296,318) the distribution balanced beautifully at
  -- 18/24/12 and the board became a ball trap -- mean ball life 30.00s, the
  -- probe's timeout, with a drain rate of exactly zero. The ball rattled in
  -- the bank forever. Balance is not worth a board the ball cannot leave.
  targets = {
    { x = 244, y = 400, w = 28, h = 9, angle = 0, bank = "vault" },
    { x = 336, y = 400, w = 28, h = 9, angle = 0, bank = "vault" },
  },

  flippers = {
    -- Wider gap than A. B drains.
    { side = "left",  x = 128, y = 688 },
    { side = "right", x = 256, y = 688 },
  },

  devices = {
    {
      id     = "gate",
      kind   = "gate",
      travel = 0.30,
      pivot  = { x = 195, y = 215 },
      length = 52,
      closed = pi - 0.13,    -- arm seals the ramp
      -- 3pi/2, not -pi/2: the gate lerps between these angles, and the negative
      -- form would sweep the arm the long way round, straight across the ramp.
      open   = 3 * pi / 2,   -- arm straight up the ramp wall
      tradeoff = "Opens the pass, closes the safe return loop.",
      label_closed = "RETURN",
      label_open   = "PASS",
    },
    {
      id     = "post",
      kind   = "paddle",
      travel = 0.26,
      up     = { x = 192, y = 676 },
      down   = { x = 192, y = 790 },
      w = 52, h = 12,
      tradeoff = "Guards the centre drain, but blocks almost every shot.",
      label_closed = "OPEN",
      label_open   = "GUARD",
    },
  },

  -- §7 Cross-board state, the return half. Clearing the vault cashes the
  -- charge Foundry built, and lights Foundry's bumpers on the way back -- so
  -- arriving on a board you prepared feels like coming home to something.
  -- The loop only closes if both players keep passing.
  links = {
    { when = "bank:vault", lights = { board = "a", what = "bumpers" } },
  },

  tube  = { mouth = { x = 169, y = 168, r = 14 }, to = "a" },
  entry = { x = 338, y = 104, dir = { x = -0.32, y = 1 } },
  serve = { x = 45,  y = 560, dir = { x = 0, y = -1 } },

  drain_y = 748,
}
