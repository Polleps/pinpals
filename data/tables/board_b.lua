--- Board B - "Glasshouse". Player 2's home board.
--- Character: clean and fast. No bumpers, two bare deflector rails, and a
--- wider flipper gap. Its ramp sits left of centre -- the mirror handedness of
--- A -- so the two boards do not reward the same muscle memory.
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
    { 116,600,  143,540,  143,150 },
    { 222,600,  195,540,  195,150 },
    -- Roof over the ramp head -- see board_a.lua for why this is not optional.
    { 143,150,  169,128,  195,150 },
    -- B's character: two bare rails in the open right field. Nothing here
    -- keeps the ball alive; it just comes back down. They must not meet --
    -- crossed, they formed a funnel that caught 19 of 182 test drops.
    { 236,236,  320,300 },
    { 268,380,  348,430 },
  },

  bumpers = {},  -- none: B is the quiet board

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

  tube  = { mouth = { x = 169, y = 168, r = 14 }, to = "a" },
  entry = { x = 338, y = 104, dir = { x = -0.32, y = 1 } },
  serve = { x = 45,  y = 560, dir = { x = 0, y = -1 } },

  drain_y = 748,
}
