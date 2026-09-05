--- Board A - "Foundry". Player 1's home board.
--- Character: chaotic and forgiving. A bumper cluster on the left keeps the
--- ball alive; the pass ramp sits right of centre, so it is the right
--- flipper's natural shot and a tip shot for the left.
---
--- Coordinates are world pixels (core/constants.lua: 64 px = 1 m), y down,
--- origin at the board's top-left. Playfield is 384 x 768.

local pi = math.pi

return {
  id   = "a",
  name = "Foundry",
  size = { w = 384, h = 768 },

  -- Static geometry. Each entry is a polyline: a flat list of x,y pairs.
  walls = {
    -- Outer shell: left wall, top arc, right wall.
    { 10,610,  10,90,  70,14,  314,14,  374,90,  374,656 },
    -- Lower left: feeds the left flipper. Descends monotonically -- any local
    -- minimum in a wall chain is a pocket the ball settles into and never
    -- leaves. Ends just outside and above the pivot: close enough that a ball
    -- cannot wedge in the gap (7px, the ball is 17px), clear enough that the
    -- wall is never inside the flipper's swept arc.
    { 10,610,  70,664,  120,678,  128,683 },
    -- Lower right: same rules. The old chain turned back up at the end to meet
    -- the pivot, which put a V at (300,702) that swallowed the ball.
    { 374,656,  344,668,  300,676,  256,683 },
    -- The pass ramp: a centre-right channel with a flared mouth. Placed here
    -- because that is where flipper shots actually go -- measured, not
    -- guessed: shots cross y=560 between x=145 and x=239.
    { 162,600,  189,540,  189,150 },
    { 268,600,  241,540,  241,150 },
    -- Roof over the ramp head. Without it the closed gate is a shelf the ball
    -- lands on from the upper playfield and sits on forever; tilting the gate
    -- only moves the resting place into the corner against the wall. The peak
    -- sheds anything that lands on it, and it seals the ramp head so the only
    -- two outcomes are "through the mouth" or "back down the ramp".
    { 189,150,  215,128,  241,150 },
  },

  -- A's character: a bumper cluster. Chaotic, keeps the ball alive.
  -- Left of the ramp, so they add chaos without blocking the pass.
  bumpers = {
    { x = 95,  y = 250, r = 24, restitution = 1.15 },
    { x = 140, y = 186, r = 24, restitution = 1.15 },
    { x = 105, y = 342, r = 24, restitution = 1.15 },
  },

  flippers = {
    { side = "left",  x = 133, y = 688 },
    { side = "right", x = 251, y = 688 },
  },

  -- §6.1: both devices are persistent states with a visible travel time.
  -- §6.2: both give and take.
  devices = {
    {
      id     = "gate",
      kind   = "gate",
      travel = 0.30,
      pivot  = { x = 189, y = 215 },
      length = 52,
      closed = 0.13,     -- arm seals the ramp: shots come back down it
      open   = -1.57,    -- arm straight up the ramp wall: the mouth is reachable
      tradeoff = "Opens the pass, closes the safe return loop.",
      label_closed = "RETURN",
      label_open   = "PASS",
    },
    {
      id     = "post",
      kind   = "paddle",
      travel = 0.26,
      up     = { x = 192, y = 676 },   -- extended: spans the drain gap
      down   = { x = 192, y = 790 },   -- retracted below the playfield
      w = 52, h = 12,
      tradeoff = "Guards the centre drain, but blocks almost every shot.",
      label_closed = "OPEN",
      label_open   = "GUARD",
    },
  },

  -- §5 The link.
  -- The mouth sits directly above the ramp exit, so clearing the gate is the
  -- pass. The right orbit is the plunger lane and the way back down.
  tube  = { mouth = { x = 215, y = 168, r = 14 }, to = "b" },
  entry = { x = 46,  y = 104, dir = { x = 0.32, y = 1 } },
  serve = { x = 355, y = 560, dir = { x = 0, y = -1 } },

  drain_y = 748,
}
