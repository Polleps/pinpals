--- Board A - "Foundry". Player 1's home board.
---
--- Character: chaotic and forgiving, and as of this edit that is measured
--- rather than asserted. See board_b.lua for the §13.1 answer in full; the
--- half that lives here is "Foundry is where a rally SURVIVES".
---
---   board        gap    mean ball life   drains/s   points/s
---   Foundry     27.6            12.19s     0.0725         24
---   Glasshouse  43.6             9.86s     0.0777        125
---
--- The ball lives 24% longer here and pays a fifth as much. That is the
--- trade the pass is choosing between.
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
    -- cannot wedge in the gap, clear enough that the wall is never inside the
    -- flipper's swept arc.
    --
    -- Both ends moved with the flippers, and then further. Narrowing the
    -- drain made the ball spend far more time beside the pivots, which found
    -- a pocket that had always been there and was simply never reached: the
    -- ball perches on the wall's endpoint in the shallow V between it and the
    -- flipper's upper surface. Preserving the old 7px offset did NOT fix it
    -- (14% of swept shots stuck); pulling the end back to a 9.9px offset did,
    -- because the V stops being shallow enough to hold a ball and it falls
    -- through onto the flipper instead. Caught by the existing stuck-ball
    -- test, not by the geometry gate -- see docs/overnight.md.
    { 10,610,  70,664,  122,678,  129,681 },
    -- Lower right: same rules. The old chain turned back up at the end to meet
    -- the pivot, which put a V at (300,702) that swallowed the ball.
    { 374,656,  344,668,  300,676,  255,681 },
    -- The pass ramp: a centre channel with a flared mouth, sitting above the
    -- gap between the flippers because that is where flipper shots actually
    -- go -- measured, not guessed.
    --
    -- The mouth used to be at y=600, which is only 88px above the flipper
    -- pivots. At that height it intercepted EVERY shot before one could
    -- travel sideways, and a sweep of 50 contact points across both flippers
    -- found the board had exactly one shot: 62% pass, 38% drain, and 0% that
    -- reached anywhere else on the playfield at all. Nothing above y=550
    -- outside this channel was reachable, which is why the upper playfield
    -- read as empty -- it was not empty, it was unreachable.
    --
    -- Raised to y=540, which leaves ~150px of open playfield above the
    -- flippers for shallow shots to cross into the orbit lanes. The trade is
    -- monotonic and this is the point on it we chose:
    --
    --   mouth y   pass   left orbit   right orbit
    --      600     62%          0%            0%
    --      570     58%          6%            4%
    --      540     52%         14%           10%     <- here
    --      510     42%         42%           16%
    --
    -- 52% keeps the ramp the majority outcome of a good shot while a quarter
    -- of shots now find the orbit, so the flipper player has a choice rather
    -- than one thing to do. prototype.md §5 already suspected the pass was
    -- too easy at ~60%, so moving down is the direction that section asks for.
    { 162,540,  189,495,  189,150 },
    { 268,540,  241,495,  241,150 },
    -- Roof over the ramp head. Without it the closed gate is a shelf the ball
    -- lands on from the upper playfield and sits on forever; tilting the gate
    -- only moves the resting place into the corner against the wall. The peak
    -- sheds anything that lands on it, and it seals the ramp head so the only
    -- two outcomes are "through the mouth" or "back down the ramp".
    { 189,150,  215,128,  241,150 },
  },

  -- A's character: a bumper cluster. Chaotic, keeps the ball alive.
  --
  -- These used to sit at x=95..140 and were hit 3 times in 180 seconds of
  -- play -- twice, by two of the three bumpers, exactly zero. Foundry's whole
  -- declared identity did not exist at the table. The cause was not the
  -- bumpers: with the ramp mouth at y=600 nothing reached this half of the
  -- board, and once the orbit opened the ball ran the lane at x=24..72 and
  -- passed cleanly inside them.
  --
  -- Now placed against the measured lane, so a ball on the inner edge of the
  -- orbit clips one. Swept, averaged over 6 seeds because pinball is chaotic
  -- enough that a single run moved the count by 60%:
  --
  --   x=74 r22   21.8 per 120s      x=80 r20   72.2 per 120s   <- here
  --   x=78 r22   45.8               x=80 r24   55.3
  --   x=82 r22   24.5               x=80 r28   74.7
  --   x=86 r22   17.8
  --
  -- 0.60 hits/s against 0.017 before: 36x. r=20 rather than r=28 (they
  -- measure the same) because a smaller bumper leaves more of the lane open,
  -- and the orbit has to survive them -- verified: left orbit holds at 14%.
  bumpers = {
    { x = 80, y = 196, r = 20, restitution = 1.15 },
    { x = 96, y = 286, r = 20, restitution = 1.15 },
    { x = 80, y = 376, r = 20, restitution = 1.15 },
  },

  -- Moved 3px inward each from 133/251, narrowing the drain gap 33.6 -> 27.6.
  -- This is the whole of Foundry's identity, and it was missing: the board
  -- documented as "forgiving" measured as the DEADLIER of the two, draining
  -- 0.0815/s against Glasshouse's 0.0777 despite a 10px narrower gap. It was
  -- worse on every axis at once, which is a bug rather than a character.
  --
  --   flippers in   gap    mean life   drains/s
  --             0  33.6       10.22s     0.0815
  --             3  27.6       12.19s     0.0725   <- here
  --             6  21.6       17.16s     0.0223
  --
  -- 6px is a wall, not a board: a 21.6px gap against a 17.3px ball barely
  -- drains at all. 3px is forgiving without being safe.
  flippers = {
    { side = "left",  x = 136, y = 688 },
    { side = "right", x = 248, y = 688 },
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
  -- §7 Cross-board state. Foundry is the charging board: the chaos here is
  -- worth little on its own (24 points/s) but it fills the vault waiting on
  -- Glasshouse. You play A to prepare B.
  links = {
    { when = "bumper", charges = { board = "b", meter = "vault" } },
  },

  tube  = { mouth = { x = 215, y = 168, r = 14 }, to = "b" },
  entry = { x = 46,  y = 104, dir = { x = 0.32, y = 1 } },
  serve = { x = 355, y = 560, dir = { x = 0, y = -1 } },

  drain_y = 748,
}
