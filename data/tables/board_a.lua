--- Board A - "Foundry". Player 1's home board.
---
--- Character: chaotic and forgiving, and as of this edit that is measured
--- rather than asserted. See board_b.lua for the answer to design.md §13.1 in
--- full; the half that lives here is "Foundry is where a rally SURVIVES".
---
--- Re-measured on the boards-v2 layout (tests/probe_identity.lua, 2026-09-06):
---
---   board        gap   mean ball life   drains/s   survival   points/s
---   Foundry     27.6           10.76s     0.0666        26%         14
---   Glasshouse  43.6            5.40s     0.1543        17%        242
---
--- The ball lives twice as long here and pays a seventeenth as much. That is
--- the trade the pass is choosing between, and both halves of it got sharper
--- when the boards grew: Glasshouse now drains 2.3x as fast as Foundry, where
--- before it was only 7% faster and the identity was a claim rather than a
--- fact.
---
--- Foundry is barely changed on ball life (12.19s -> 10.76s) and is actually
--- SAFER per second than before (0.0725 -> 0.0666 drains/s) despite gaining
--- two outlanes, because the five-bumper nest keeps the ball up the board.
--- Glasshouse lost nearly half its ball life (9.86s -> 5.40s): a wider flipper
--- gap also means a longer unguarded run down each side, so the outlanes cost
--- it far more. That was not designed and it is worth keeping.
---
--- Coordinates are world pixels (core/constants.lua: 64 px = 1 m), y down,
--- origin at the board's top-left. Playfield is 448 x 960.
---
--- Grown from 384 x 768 in boards-v2 phase 0. Nothing is stretched: every
--- shape keeps its exact dimensions and only moves. x shifts +32 everywhere,
--- so the board is 64px wider with the shell further out. y shifts +192 for
--- the flipper furniture ONLY -- flippers, post, lower wall chains, serve,
--- drain line -- while the ramp, the bumpers, the gate, the tube and the top
--- arc stay exactly where they were.
---
--- That is where the 192px goes, and it is the whole point of the resize: the
--- ramp mouth was 148px above the flipper pivots, which is what made the ramp
--- feel like it was sitting on top of them, and is also why a flipper shot
--- could never travel far enough sideways to get past the channel. It is now
--- 340px above. See docs/boards-v2.md §1 for the reach map that says so.
---
--- The first attempt put the room at the top instead, translating everything
--- below the arc by +192. That lengthened the orbit climb by 192px and made
--- bumper 1 and Glasshouse's whole bank unreachable -- the existing
--- reachability tests caught it. Worth recording: there is no such thing as a
--- neutral resize here, only a choice about where the new room goes.

local pi = math.pi

return {
  id   = "a",
  name = "Foundry",
  size = { w = 448, h = 960 },

  -- Static geometry. Each entry is a polyline: a flat list of x,y pairs.
  walls = {
    -- Outer shell: left wall, top arc, right wall.
    -- Outer shell: left wall, top arc, right wall. Both side walls now run
    -- past the drain line: they are the outer wall of an outlane, and an
    -- outlane that stops above the drain is a shelf.
    { 10,948,  10,90,  76,14,  372,14,  438,90,  438,948 },
    -- The traditional bottom (docs/boards-v2.md §3). Down each side, in order
    -- from the outer wall: an OUTLANE that drains, a lane divider, an INLANE
    -- that feeds the flipper, and a slingshot above it. Before this the ball
    -- simply funnelled down one chain into the flipper and the sides of the
    -- board did nothing.
    --
    -- The outlanes are the point of the exercise. They give each board a
    -- second and third way to lose the ball, which the post cannot guard --
    -- and a post that stopped 100% of drains was a guard costing nothing,
    -- which board_a.lua's own note worried about. It also means a ball lost
    -- down the side cannot be rescued (§8), so the rescue stops being a
    -- universal undo.
    --
    -- Each side is one chain: divider first, then the inlane floor, so the
    -- two cannot drift apart and leave a gap the ball falls through. The
    -- chain descends throughout -- the bowl check would say so otherwise --
    -- and ends 9.9px outside its pivot, the offset measured for the old
    -- lower-wall chains and kept for the same reason.
    { 36,700,  40,852,  110,864,  161,873 },
    { 412,700,  408,852,  338,864,  287,873 },
    -- The pass ramp. A short channel high on the board, not the 390px
    -- corridor that used to run from y=150 to y=540 through the dead centre.
    --
    -- That corridor was the single worst thing on either board, and it took a
    -- reach map to see it: 106px wide down the middle of a 384px board, it
    -- was a WALL a flipper shot could not travel far enough sideways to get
    -- past. Foundry measured 0% right-orbit reach and nothing at all above
    -- y=280 outside the channel. The upper playfield was never sparse; it was
    -- unreachable. docs/boards-v2.md §1 has the map.
    --
    -- Two changes, and the second is the one that mattered:
    --
    --   * the mouth is now 320px above the flipper pivots instead of 148px,
    --     which is what "the ramp is too close to the flippers" asked for;
    --   * the channel ENDS at y=380 instead of y=150, so the whole top third
    --     of the board is open field rather than two rails.
    --
    -- Raising the mouth alone made the pass unmakeable -- 0 of 8 from the
    -- right flipper. Shortening the channel gave it all back and more, which
    -- is why the two are one edit and not two:
    --
    --   swept shots        pass   drain   left orbit   right orbit
    --   old 384x768 board   54%     44%          14%           0%
    --   tall mouth only     26%     64%          46%          32%
    --   and short channel   50%     28%          40%          30%   <- here
    --
    -- Same pass rate, drains cut by a third, and the orbits went from one
    -- working lane to two. tests/probe_ramp.lua is the sweep behind this.
    --
    -- x=236 is measured too, and it is the one number here with a cliff under
    -- it: the mouth has to be reachable from BOTH flippers, and it stops being
    -- so within about 24px either way.
    --
    --   ramp x   reachable from left / right flipper, of 8 contact points
    --      200            1 / 4
    --      212            4 / 5
    --      224            6 / 4
    --      236            5 / 3   <- here
    --      248            5 / 1
    --      272            6 / 0
    --
    { 183,560,  210,515,  210,380 },
    { 289,560,  262,515,  262,380 },
    -- Roof over the ramp head. Without it the closed gate is a shelf the ball
    -- lands on from the upper playfield and sits on forever; tilting the gate
    -- only moves the resting place into the corner against the wall. The peak
    -- sheds anything that lands on it, and it seals the ramp head so the only
    -- two outcomes are "through the mouth" or "back down the ramp".
    { 210,380,  236,358,  262,380 },
  },

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
    { p = { 66,772,  140,822,  66,830 } },
    { p = { 382,772, 308,822, 382,830 } },
  },

  -- A's character: a bumper cluster. Chaotic, keeps the ball alive.
  --
  -- Re-placed for the 448x960 board. The old positions were tuned against a
  -- lane that no longer exists: with the ramp channel shortened to y=380 the
  -- whole top third of the board opened up, and probe_reach's play map puts
  -- the heaviest traffic across the top and down both orbits rather than in
  -- the narrow left lane the cluster used to straddle.
  --
  -- Arranged as a nest rather than a column, which is what a real table does
  -- and what makes a bumper cluster feel like a place the ball gets stuck in
  -- for a moment instead of three things it passes.
  --
  -- Spread across the band, NOT stacked. Two arrangements were tried and both
  -- measured a dead bumper: two-up-one-down shadowed the lower one, and
  -- one-up-two-down shadowed the lower left. In a top-down board the ball
  -- arrives from above along a mostly vertical path, so anything with another
  -- bumper directly above it is in a shadow -- the rattling that keeps every
  -- bumper of a real nest live comes from the ball entering at angles this
  -- board does not produce up here. Each of these three has open sky.
  bumpers = {
    { x = 56,  y = 230, r = 22, restitution = 1.15 },
    { x = 168, y = 175, r = 22, restitution = 1.15 },
    { x = 240, y = 205, r = 22, restitution = 1.15 },
    -- Two more on the right, where probe_where puts a second heavy stream --
    -- x=272..336 and x=368..400 at every height it samples -- and where the
    -- board was simply empty. Foundry's identity is chaos, so the right way
    -- to fill its dead half is more of the thing it already is.
    { x = 312, y = 190, r = 22, restitution = 1.15 },
    { x = 376, y = 252, r = 22, restitution = 1.15 },
  },

  -- The drain gap is 27.6px, 16px narrower than Glasshouse's, and it is the
  -- whole of Foundry's identity: the board that was documented as forgiving
  -- once measured as the deadlier of the two, which is a bug rather than a
  -- character. It is now forgiving by the numbers in the header.
  --
  -- The gap survived the move to 448x960 unchanged, because the pivots moved
  -- together with everything else. The sweep that chose it (33.6 / 27.6 /
  -- 21.6px) was run on the old board and is not repeated here: 21.6px against
  -- a 17.3px ball barely drained at all, which is a wall, not a board.
  flippers = {
    { side = "left",  x = 168, y = 880 },
    { side = "right", x = 280, y = 880 },
  },

  -- §6.1: both devices are persistent states with a visible travel time.
  -- §6.2: both give and take.
  devices = {
    {
      id     = "gate",
      kind   = "gate",
      travel = 0.30,
      pivot  = { x = 210, y = 445 },
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
      -- The post sits BELOW the flipper pivots, where a draining ball still
      -- meets it but a shot leaving the flipper mostly clears it. Above them
      -- it was not a trade at all but a pause button: pass rate 0% AND drain
      -- rate 0%, which leaves the flipper player with nothing to do and
      -- nothing to fear -- pillar 1 and §6.2 broken by the same 12 pixels.
      --
      -- The sweep that picked the offset (711 / 713 / 715 on the old board,
      -- roughly 16 percentage points of pass rate per pixel) is not carried
      -- forward: those are pre-resize coordinates and the geometry under them
      -- has changed. The offset from the pivots is preserved at 25px, and it
      -- is still a steep slope, so treat any edit to it as a redesign of the
      -- device and re-run tests/probe_post.lua.
      --
      -- What HAS changed, and changed the device's meaning: the post no
      -- longer guards the only drain. Each board now has two outlanes it
      -- cannot reach, so a raised post stops the centre and nothing else. It
      -- was previously a 100% guard, which is a guard costing nothing, and
      -- §8's rescue rode on top of that -- a ball lost down an outlane cannot
      -- be rescued at all now. Both effects are intended and both still need
      -- re-measuring against tests/probe_post.lua.
      --
      -- The asymmetry is still the best thing about it: each board's ramp is
      -- off-centre, so the post mainly blocks whichever flipper has to shoot
      -- ACROSS the middle, and the two boards are blocked on opposite sides
      -- so the skill does not transfer.
      up     = { x = 224, y = 905 },   -- extended: spans the drain gap
      down   = { x = 224, y = 982 },   -- retracted below the playfield
      w = 52, h = 12,
      tradeoff = "Guards the centre drain; the pass gets much harder.",
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

  tube  = { mouth = { x = 236, y = 398, r = 14 }, to = "b" },
  entry = { x = 90, y = 116, dir = { x = -0.20, y = 1 } },
  -- Served into the open right field, clear of the lane furniture: a real
  -- shooter lane is phase 5, and a serve inside a 26px outlane rattles.
  serve = { x = 400, y = 660, dir = { x = 0, y = -1 } },

  drain_y = 940,
}
