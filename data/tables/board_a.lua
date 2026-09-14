-- Foundry: wide shoulders around a compact flipper deck.
-- Dimensions are world pixels; ball/flipper sizes and the lower feed are unchanged.
-- The workshop occupies the left shoulder. Its elevated return crosses the
-- shoulder taper, then lands in the left inlane for another controllable shot.
return {
  id = "a", name = "Foundry", size = { w = 640, h = 960 },
  walls = {
    { 106,948, 106,670, 10,530, 10,90,
      { to = { 90,14 }, c1 = { 10,40 }, c2 = { 40,14 } },
      550,14, { to = { 630,90 }, c1 = { 600,14 }, c2 = { 630,40 } },
      630,530, 534,670, 534,948 },
    { 132,700, 135,810,
      { to = { 244,873 }, c1 = { 136,849 }, c2 = { 200,862 } } },
    { 508,700, 505,810,
      { to = { 396,873 }, c1 = { 504,849 }, c2 = { 440,862 } } },
    -- Always-open pass lane just right of centre. Retains the shortened
    -- 470px mouth of the previous local edit. Farther-right variants lost
    -- the right flipper shot; the outer shoulder remains free for later content.
    { 309,470, 324,444, 324,380 },
    { 391,470, 376,444, 376,380 },
    { 324,380, 350,358, 376,380 },
  },
  sections = {
    { id = "arena", label = "01 / UPPER ARENA", x = 258, y = 55, w = 240, h = 242,
      color = { 0.38, 0.25, 0.13 } },
    { id = "workshop", label = "02 / WORKSHOP", x = 36, y = 180, w = 196, h = 410,
      color = { 0.12, 0.38, 0.32 } },
    { id = "machinery", label = "03 / POWER STATION", x = 358, y = 410, w = 108, h = 158,
      color = { 0.35, 0.28, 0.10 } },
  },
  bumpers = {
    { x = 340, y = 115, r = 22, restitution = 1.15 },
    { x = 438, y = 115, r = 22, restitution = 1.15 },
    { x = 389, y = 220, r = 22, restitution = 1.15 },
  },
  targets = {
    { x = 300, y = 330, w = 28, h = 9, bank = "forge", angle = 0.15 },
    { x = 426, y = 330, w = 28, h = 9, bank = "forge", angle = -0.15 },
  },
  rollovers = {
    { x = 272, y = 190, w = 36, h = 26, label = "L" },
    { x = 587, y = 280, w = 36, h = 26, label = "R" },
    { x = 320, y = 690, w = 68, h = 26, label = "C" },
  },
  -- Flush generator: speed through the marked field charges a reusable circuit.
  -- It does not add another solid obstacle to the shooting area.
  switches = {
    { id = "generator", kind = "generator", x = 411, y = 490, w = 86, h = 24,
      circuit = "workshop", threshold = 180, strong = 850, cooldown = 0.6 },
  },
  circuits = {
    { id = "workshop", label = "WORKSHOP", capacity = 3, route = "workshop",
      wire = { 411,510, 411,580, 290,580, 240,570 } },
  },
  slingshots = {
    { p = { 180,714, 236,806, 180,814 } },
    { p = { 460,714, 404,806, 460,814 } },
  },
  guards = {
    start = "left", kick = 1.30,
    { side = "left", angle = 0.34, w = 30, h = 11,
      up = { x = 120, y = 694 }, down = { x = 120, y = 986 } },
    { side = "right", angle = -0.34, w = 30, h = 11,
      up = { x = 520, y = 694 }, down = { x = 520, y = 986 } },
  },
  flippers = {
    { side = "left", x = 251, y = 880 },
    { side = "right", x = 389, y = 880 },
  },
  devices = {
    { id = "post", kind = "paddle", travel = 0.26,
      up = { x = 320, y = 912 }, down = { x = 320, y = 982 }, w = 52, h = 12,
      tradeoff = "Guards the centre; restricts cross-board shots.",
      label_closed = "OPEN", label_open = "GUARD" },
    { id = "gate", kind = "gate", circuit = "workshop", travel = 0.3,
      pivot = { x = 210, y = 582 }, length = 64, closed = -0.45, open = -1.57,
      tradeoff = "One charge buys one workshop attempt.",
      label_closed = "WORKSHOP", label_open = "ENTER" },
  },
  ramps = {
    { id = "workshop", label = "WORKSHOP", device = "gate",
      path = { 240,550, 240,240, { round = 68 },
               65,240, { round = 68 }, 65,440, { round = 65 },
               153,550, { round = 65 }, 153,650 },
      width = 54, height = 24, entry_slope = 0.5, exit_slope = 0.5, enter = "start" },
  },
  links = { { when = "bumper", charges = { board = "b", meter = "vault" } } },
  tube = { mouth = { x = 350, y = 398, r = 14 }, to = "b" },
  entry = { x = 580, y = 104, dir = { x = -0.32, y = 1 } },
  -- Dedicated outer-right launch path, clear of pass lane and arena furniture.
  serve = { x = 600, y = 510, dir = { x = 0, y = -1 } },
  drain_y = 940,
}
