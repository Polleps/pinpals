--- Board B - "Glasshouse". Player 2's home board.
---
--- Foundry is where a rally survives; Glasshouse is where it pays, and where
--- it dies unless your partner is watching. Clean, precise and narrow: no
--- bumpers, every scoring feature is a shot you aim, and the operator's magnet
--- is the difference between a deadly board and a playable one.
---
--- The shape is set by where flipper shots actually travel. tests/probe_shots
--- (MAP=1) shows nearly every upward shot going straight up the centre, so:
---   centre      the pass funnel, its mouth narrowed so the pass is aimed
---               rather than the default outcome of any flip
---   beside it   the VAULT drop bank, where the left flipper's wider shots go
---   right side  the GALLERY, fed by the left flipper and the skyway's exit
---   top right   the S-U-N lanes, where the serve, the orbits and a ball
---               arriving from Foundry all come down
---   left        the plunger lane (x=39..57, nothing may stand in it) and
---               the skyway's only mouth
---
--- History of earlier layouts, and the measurements that moved them, is in
--- docs/glasshouse.md and git history -- not here.

return {
  id   = "b",
  name = "Glasshouse",
  size = { w = 448, h = 960 },

  walls = {
    -- Shell. Both side walls run past the drain line: they are the outer
    -- walls of the outlanes. Rounded top corners so an orbit carries round.
    { 438,948, 438,520, 438,90,
      { to = { 362,14 }, c1 = { 438,40 }, c2 = { 408,14 } },
      86,14,
      { to = { 10,90 }, c1 = { 40,14 }, c2 = { 10,40 } },
      10,948 },
    -- Inlane guides, the same construction as Foundry's.
    { 36, 700, 39, 810,
      { to = { 143.5, 873 }, c1 = { 40, 849 }, c2 = { 99.5, 862 } } },
    { 412, 700, 409, 810,
      { to = { 304.5, 873 }, c1 = { 408, 849 }, c2 = { 348.5, 862 } } },
    -- The pass funnel, left of centre: the right flipper's cross-body shot.
    -- Mouth 84px (was 106): wide enough that the pass is still the board's
    -- main shot, narrow enough that the edges of each flipper's spread go
    -- past it to the banks either side.
    { 159,555, 175,500, 175,380 },
    { 243,555, 227,500, 227,380 },
    { 175,380, 201,358, 227,380 },
    -- S-U-N lane guides. Four short posts make three 28px lanes.
    { 250,120, 250,156 },
    { 278,120, 278,156 },
    { 306,120, 306,156 },
    { 334,120, 334,156 },
    -- Right shoulder: a ball running down the right wall is turned in toward
    -- the inlane rather than delivered to the outlane. Shares the shell's
    -- vertex at (438,520), so it is a bend in the wall and not a pocket.
    { 438,520, 396,556 },
  },

  bumpers = {},  -- none: chaos is Foundry's job

  -- The top lanes. Light all three for the lane award; the flipper buttons
  -- move the lit lanes (see core/mission.lua), so a ball coming down over
  -- them is something to steer, and the lit lane right after a serve is the
  -- skill shot.
  lane_change = true,
  rollovers = {
    { x = 264, y = 140, w = 20, h = 26, label = "S" },
    { x = 292, y = 140, w = 20, h = 26, label = "U" },
    { x = 320, y = 140, w = 20, h = 26, label = "N" },
  },

  slingshots = {
    { p = { 84, 714, 132, 806, 84, 814 } },
    { p = { 364, 714, 316, 806, 364, 814 } },
  },

  targets = {
    -- VAULT: three drop targets beside the funnel mouth. Knocked down stays
    -- down until the third falls; clearing it cashes the charge Foundry
    -- built into it (design.md §7.1) and lights Foundry's bumpers.
    -- Tilted 0.2 rad so its face looks down toward the left flipper and its
    -- top sheds a falling ball instead of being a shelf to rest on.
    { x = 264, y = 508, w = 28, h = 9, bank = "vault", drop = true, angle = -0.2 },
    { x = 293.4, y = 502, w = 28, h = 9, bank = "vault", drop = true, angle = -0.2 },
    { x = 322.8, y = 496, w = 28, h = 9, bank = "vault", drop = true, angle = -0.2 },
    -- GALLERY: an inline bank down the right side, facing the left flipper.
    { x = 349, y = 626, w = 28, h = 9, bank = "gallery", angle = -0.69 },
    { x = 372.1, y = 606.9, w = 28, h = 9, bank = "gallery", angle = -0.69 },
    { x = 395.3, y = 587.8, w = 28, h = 9, bank = "gallery", angle = -0.69 },
  },

  -- The outlane guards: same numbers as Foundry's, since both bottoms are the
  -- same shape down the sides.
  guards = {
    start = "left",
    kick  = 1.30,
    { side = "left",  angle =  0.34, w = 30, h = 11,
      up = { x = 24,  y = 694 }, down = { x = 24,  y = 986 } },
    { side = "right", angle = -0.34, w = 30, h = 11,
      up = { x = 424, y = 694 }, down = { x = 424, y = 986 } },
  },

  flippers = {
    { side = "left",  x = 150.5, y = 880 },
    { side = "right", x = 297.5, y = 880 },
  },

  devices = {
    -- The post. y=912 is level with the flipper tips at rest; the pass-rate
    -- cost is steep per pixel (tests/probe_post.lua), so treat any edit to
    -- it as a redesign and re-run that probe.
    {
      id = "post", kind = "paddle", travel = 0.26,
      up = { x = 224, y = 912 }, down = { x = 224, y = 982 }, w = 52, h = 12,
      tradeoff = "Guards the centre drain; the pass gets much harder.",
      label_closed = "OPEN", label_open = "GUARD",
    },
    -- The magnet, over the right flipper's pivot: a released ball drops onto
    -- the pivot end and rolls down the bat, a slow feed the flipper can
    -- time. Catches a falling ball up to ~700px/s, not a shot
    -- (tests/probe_magnet.lua). Catching cancels the skyway combo.
    {
      id = "magnet", kind = "magnet", action = "operator_gate", hint = "magnet",
      x = 292, y = 640, r = 44, travel = 0.25, max_on = 3.0, cooldown = 4.0,
      tradeoff = "Catches the ball over the right flipper; kills the skyway combo.",
      label_closed = "MAGNET", label_open = "HOLDING",
    },
  },

  -- The skyway: one way, in from the left mouth and out of the right one,
  -- which drops the ball into the gallery. The elevated span crosses the top
  -- lanes' approach and the vault, both of which stay live underneath.
  ramps = {
    {
      id          = "skyway",
      path        = { 94, 460,
                      94, 190, { round = 110 },
                      354, 190, { round = 110 },
                      354, 460 },
      width       = 54,
      height      = 30,
      entry_slope = 0.58,
      exit_slope  = 0.58,
      enter       = "start",
    },
  },

  -- Clearing the vault lights Foundry's bumpers (§7.1, the return half).
  links = {
    { when = "bank:vault", lights = { board = "a", what = "bumpers" } },
  },

  -- The relay inserts sit low between the slings, out of the magnet's way.
  inserts = { x = 224, y = 742 },

  tube  = { mouth = { x = 201, y = 398, r = 14 }, to = "a" },
  -- A ball from Foundry comes in over the S-U-N lanes; the sender's aim in
  -- transit decides which one it crosses.
  entry = { x = 300, y = 64, dir = { x = -0.12, y = 1 } },
  -- Straight up the left lane. Nothing may stand in x=39..57 above y=660.
  serve = { x = 48,  y = 660, dir = { x = 0, y = -1 } },

  drain_y = 940,
}
