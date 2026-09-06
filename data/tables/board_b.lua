--- Board B - "Glasshouse". Player 2's home board.
---
--- design.md §13.1 -- what is each board FOR? -- answered PROVISIONALLY here
--- and in docs/design.md. The short version: Foundry is where a rally
--- SURVIVES, Glasshouse is where it PAYS.
---
--- Re-measured on the boards-v2 layout (probe_identity + probe_reach):
---
---   Foundry     chaotic, forgiving, cheap. A bumper nest across the top of
---               the board keeps the ball alive and crowds the aim. Ball life
---               9.46s, 18 points/s, swept pass 50%, drains 0.0793/s.
---   Glasshouse  clean, precise, expensive. No bumpers, a two-target bank in
---               the left field, and a drain gap 16px wider. Ball life 5.76s,
---               192 points/s, swept pass 50%, drains 0.1533/s.
---
--- Glasshouse pays 10.7x per second of ball time and kills the ball nearly
--- twice as fast. That makes the pass the decision design.md §6.2 asks for,
--- one level up from the devices: do I keep the rally safe, or send it
--- somewhere it can actually score?
---
--- The gap between the boards WIDENED when they grew. Glasshouse used to
--- drain only 7% faster than Foundry despite its wider gap, which made the
--- identity a claim more than a fact; the outlanes cost it far more than they
--- cost Foundry, because a wider flipper gap also means a longer unguarded
--- run down each side. That was not designed and it is worth keeping.
---
--- Deliberately not a mirror of A (design.md §7): the handedness is flipped so
--- the two boards read differently at a glance, but the upper field differs in
--- kind, not just in layout.
---
--- Grown to 448 x 960 in boards-v2 phase 0. x shifts +32 everywhere; y shifts
--- +192 for the flipper furniture only, so the ramp mouth ends up 340px above
--- the pivots instead of 148px and the new room lands in the approach rather
--- than above the arc. board_a.lua carries the full note, including the
--- version of this edit that did it the other way round and broke both
--- boards' upper content.

local pi = math.pi

return {
  id   = "b",
  name = "Glasshouse",
  size = { w = 448, h = 960 },

  walls = {
    -- Outer shell: right wall, top arc, left wall.
    -- Outer shell: right wall, top arc, left wall. Both side walls run past
    -- the drain line -- they are the outer wall of an outlane.
    { 438,948,  438,90,  372,14,  76,14,  10,90,  10,948 },
    -- The traditional bottom, same construction as Foundry's -- see
    -- board_a.lua for what each chain is and why the outlanes matter. The
    -- inlane floors end further apart here because Glasshouse's flippers
    -- are, which is the board's whole identity.
    { 36,700,  40,852,  104,864,  153,873 },
    { 412,700,  408,852,  344,864,  295,873 },
    -- The pass ramp, left of centre: the right flipper's cross-body shot,
    -- where Foundry's is the left flipper's. Shortened to end at y=380 for
    -- the reason given at length in board_a.lua -- a long centre channel is a
    -- wall across the board, and it is why neither board's upper playfield
    -- was reachable.
    --
    --   swept shots        pass   drain   left orbit   right orbit
    --   old 384x768 board   66%     34%           6%          10%
    --   boards-v2           50%     44%          36%          30%
    --
    -- Glasshouse gave up 16 points of pass rate for a playfield with six
    -- times the reach. It is still the board you pass FROM by received-ball
    -- rate -- 62% against Foundry's 32% -- which is the number that decides
    -- whether a rally continues.
    --
    -- x=201 is reachable from both flippers (3 left / 6 right of 8 contact
    -- points swept). The right-flipper bias is the handedness: Foundry's ramp
    -- reads 5 left / 3 right at x=236.
    --
    { 148,560,  175,500,  175,380 },
    { 254,560,  227,500,  227,380 },
    -- Roof over the ramp head -- see board_a.lua for why this is not optional.
    { 175,380,  201,358,  227,380 },
    -- The deflector rail is gone. It survived two redesigns as "one rail left
    -- in the upper right, to feed the bank below it", and both times the bank
    -- it fed measured a dead target: a single sloping rail does not split a
    -- stream, it aims one. probe_where puts Glasshouse's falling traffic down
    -- the LEFT of the ramp, so the bank went there instead and the rail had
    -- nothing left to do.
  },

  bumpers = {},  -- none: chaos is Foundry's job

  -- Two slingshots, one above each flipper, hypotenuse facing up-board and
  -- roughly parallel to the flipper below it. A ball coming down the side
  -- meets the face and is thrown back across the playfield instead of rolling
  -- into the drain, which is what fills the 340px of empty approach the ramp
  -- vacated when the board grew.
  --
  -- The tip stops 28px short of the pivot in x. Closer than that and the
  -- triangle reaches inside the flipper's swept arc, which the geometry gate
  -- rejects: at pivot-24 it is 56.3px from the pivot against a 52.96px reach.
  slingshots = {
    { p = { 66,772,  132,822,  66,830 } },
    { p = { 382,772, 316,822, 382,830 } },
  },


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
    { x = 56,  y = 470, w = 28, h = 9, angle = 0, bank = "vault" },
    { x = 124, y = 470, w = 28, h = 9, angle = 0, bank = "vault" },
  },

  flippers = {
    -- Wider gap than A. B drains.
    { side = "left",  x = 160, y = 880 },
    { side = "right", x = 288, y = 880 },
  },

  devices = {
    {
      id     = "gate",
      kind   = "gate",
      travel = 0.30,
      pivot  = { x = 227, y = 445 },
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
      -- Lowered from y=676, which was ABOVE the flipper pivots at y=688 and
      -- therefore sat directly in the launch path. Measured, the old post was
      -- not a trade at all but a pause button: with it raised the pass rate
      -- was 0% AND the drain rate was 0%. Nothing could happen in either
      -- direction, which leaves the flipper player with nothing to do and
      -- nothing to fear -- pillar 1 ("nobody waits") and §6.2 ("every
      -- operator action is a trade") broken by the same 12 pixels.
      --
      -- At y=713 it sits below the pivots, where a draining ball still meets
      -- it but a shot leaving the flipper mostly clears it:
      --
      --   post y    Foundry pass   Glasshouse pass   drains stopped
      --      676              0%                0%             100%
      --      711              8%               15%             100%
      --      713             40%               31%             100%   <- here
      --      715             73%               60%             100%
      --      726             58%               69%             100%
      --   (down)             58%               69%              32%
      --
      -- 726 is the opposite failure: a guard that costs nothing would simply
      -- be held up forever. 713 keeps 69% of Foundry's pass rate and 45% of
      -- Glasshouse's, so raising it is a decision rather than a reflex.
      --
      --
      -- The cost is sharply ASYMMETRIC, and that is the best thing about the
      -- device. Each board's ramp is off-centre, so the post mainly blocks
      -- whichever flipper has to shoot ACROSS the middle:
      --
      --                    left flipper   right flipper
      --   Foundry     down          58%             58%
      --   Foundry     UP            25%             54%
      --   Glasshouse  down          75%             63%
      --   Glasshouse  UP            54%              8%
      --
      -- So a raised post does not stop the pass, it moves it: you have to get
      -- the ball to the near flipper first. The flipper player has something
      -- to do while their partner guards, which is what pillar 1 asks for,
      -- and the two boards are blocked on opposite sides so the skill does
      -- not transfer. None of this was designed -- it fell out of the ramps
      -- being on opposite sides -- but it is worth keeping deliberately.
      --
      -- NOTE this is a steep slope -- roughly 16 percentage points of pass
      -- rate per pixel between 711 and 715 -- because the post is a flat bar
      -- and a shot either clears it or does not. Treat any edit to this
      -- number as a redesign of the device and re-run tests/probe_post.lua.
      up     = { x = 224, y = 905 },
      down   = { x = 224, y = 982 },
      w = 52, h = 12,
      tradeoff = "Guards the centre drain; the pass gets much harder.",
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

  tube  = { mouth = { x = 201, y = 398, r = 14 }, to = "a" },
  entry = { x = 370, y = 104, dir = { x = -0.32, y = 1 } },
  serve = { x = 48,  y = 660, dir = { x = 0, y = -1 } },

  drain_y = 940,
}
