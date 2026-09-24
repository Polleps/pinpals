--- What does each flipper shot HIT?
---
--- probe_reach says where the ball goes; this says what it touches on the
--- way, per feature and per flipper -- the shot inventory a board designer
--- actually needs (docs/table-design.md §2: every shot must be makeable). A
--- feature nothing reaches is scenery, and a feature only the post-bounce
--- chaos reaches is not a shot.
---
--- Two launches per contact point, both a real press-and-release:
---   rest   the ball dropped onto the flipper and flipped as it settles
---   roll   the ball fed down the flipper from its pivot end and flipped as it
---          passes the contact point -- the shot off an inlane feed
---
--- Counted within the first 2.5s, before the shot turns into general play.
---
---   PINPALS_SUITE=tests.probe_shots love . --test [a|b]
return function()
  local C      = require("core.constants")
  local Board  = require("sim.board")
  local boards = require("data.tables.init").load()

  local function cmd(left, right)
    return { flippers = { left = left, right = right },
             devices  = { gate = { commanded = true }, post = { commanded = false } } }
  end

  local POINTS  = 21
  local WINDOW  = 2.5

  --- Every feature a shot can touch, keyed to a readable name.
  local function feature_names(def)
    local names = {}
    for i, t in ipairs(def.targets or {}) do
      names["target:" .. i] = ("target %d %-8s (%3.0f,%3.0f)%s"):format(i, t.bank, t.x, t.y,
        t.drop and " drop" or "")
    end
    for i, r in ipairs(def.rollovers or {}) do
      names["rollover:" .. i] = ("lane %-3s          (%3.0f,%3.0f)"):format(r.label, r.x, r.y)
    end
    for _, r in ipairs(def.ramps or {}) do
      names["ramp:" .. r.id] = ("ramp %s ridden"):format(r.id)
    end
    for i, sw in ipairs(def.switches or {}) do
      names["switch:" .. i] = ("switch %s"):format(sw.id)
    end
    for i, bp in ipairs(def.bumpers or {}) do
      names["bumper:" .. i] = ("bumper %d (%3.0f,%3.0f)"):format(i, bp.x, bp.y)
    end
    names.tube  = "PASS"
    names.drain = "drain"
    return names
  end

  local function key_of(ev)
    if ev.kind == "target" or ev.kind == "rollover" or ev.kind == "switch"
       or ev.kind == "bumper" then
      return ev.kind .. ":" .. ev.index
    elseif ev.kind == "ramp" and ev.at == "exit" and ev.complete then
      return "ramp:" .. ev.id
    elseif ev.kind == "tube" or ev.kind == "drain" then
      return ev.kind
    end
  end

  --- Where shots travel UPWARD, per flipper: the only places a target that
  --- faces the flippers can be struck by an aimed shot. Off unless MAP=1.
  local CELL = 16
  local function flux_grid(def)
    return { w = math.ceil(def.size.w / CELL), h = math.ceil(def.size.h / CELL) }
  end

  local function one_shot(def, side, frac, mode, seen, flux)
    local b = Board.new(def)
    local spec
    for _, f in ipairs(def.flippers) do if f.side == side then spec = f end end
    local sign = (side == "left") and 1 or -1
    local ang  = (side == "left") and C.FLIPPER_REST or -C.FLIPPER_REST
    local flip_at
    if mode == "rest" then
      local d = C.FLIPPER_LEN * frac
      b:spawn(spec.x + math.cos(ang) * d * sign,
              spec.y + math.sin(ang) * d * sign - C.BALL_RADIUS - 2, 0, 0)
      flip_at = math.floor(0.12 * C.TICK_HZ)
    else
      local d = C.FLIPPER_LEN * 0.12
      b:spawn(spec.x + math.cos(ang) * d * sign,
              spec.y + math.sin(ang) * d * sign - C.BALL_RADIUS - 2,
              sign * 160, 0)
      flip_at = nil
    end
    local target_x = spec.x + math.cos(ang) * C.FLIPPER_LEN * frac * sign
    local release
    local hit = {}
    for tick = 1, math.floor(WINDOW * C.TICK_HZ) do
      if not flip_at then
        local x = b:ball_pos()
        if x and (x - target_x) * sign >= 0 then flip_at = tick end
        if tick > C.TICK_HZ then flip_at = tick end
      end
      local held = flip_at and tick >= flip_at and tick < flip_at + math.floor(0.22 * C.TICK_HZ)
      if flip_at and not release then release = flip_at end
      local c = cmd(side == "left" and held or false, side == "right" and held or false)
      local over = false
      if flux and release and tick > release then
        local x, y = b:ball_pos()
        local _, vy = b:ball_velocity()
        if x and vy < -150 and not b.on_ramp then flux.cur[#flux.cur+1] = { x, y } end
      end
      for _, ev in ipairs(b:step(c, true)) do
        local k = key_of(ev)
        if k and not hit[k] then hit[k] = true end
        if ev.kind == "tube" or ev.kind == "drain" then over = true end
      end
      if over or not b:ball_pos() then break end
    end
    b.world:destroy()
    if flux then
      -- One count per shot per cell, so a ball that rattles in a corner does
      -- not look like ten shots.
      local once = {}
      for _, p in ipairs(flux.cur) do
        local cx, cy = math.floor(p[1] / CELL), math.floor(p[2] / CELL)
        local k = cy * flux.grid.w + cx
        if not once[k] then
          once[k] = true
          flux.count[side][k] = (flux.count[side][k] or 0) + 1
        end
      end
      flux.cur = {}
    end
    for k in pairs(hit) do
      seen[k] = seen[k] or { left = 0, right = 0 }
      seen[k][side] = seen[k][side] + 1
    end
  end

  local which
  for _, v in ipairs(arg or {}) do if v == "a" or v == "b" then which = v end end
  for _, id in ipairs(which and { which } or { "a", "b" }) do
    local def = boards[id]
    local names = feature_names(def)
    local seen = {}
    local n = 0
    local flux = os.getenv("MAP") and { grid = flux_grid(def), cur = {},
                                        count = { left = {}, right = {} } } or nil
    for _, side in ipairs({ "left", "right" }) do
      for _, mode in ipairs({ "rest", "roll" }) do
        for p = 0, POINTS - 1 do
          one_shot(def, side, 0.25 + 0.75 * p / (POINTS - 1), mode, seen, flux)
          if side == "left" then n = n + 1 end
        end
      end
    end
    print("")
    print(("SHOTS on %s: %d per flipper (%d contact points x rest/roll), first %.1fs")
      :format(def.name, n, POINTS, WINDOW))
    print("  feature                              left  right")
    local keys = {}
    for k in pairs(names) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local s = seen[k] or { left = 0, right = 0 }
      print(("  %-36s %4d  %4d%s"):format(names[k], s.left, s.right,
        (s.left + s.right == 0) and "   <- unreachable" or ""))
    end
    if flux then
      --- Shots per cell, left flipper digit | right flipper digit, 0-9+.
      local g = flux.grid
      print("")
      print(("  UPWARD flux, %dpx cells: each cell prints L R shot counts (capped at 9)"):format(CELL))
      local ruler = "      "
      for cx = 0, g.w - 1 do
        ruler = ruler .. ((cx % 4 == 0) and ("%-3d"):format(math.floor(cx * CELL / 10)) or "   ")
      end
      print(ruler .. " (x/10)")
      for cy = 0, g.h - 1 do
        local row = ("  %4d"):format(cy * CELL)
        local any = false
        for cx = 0, g.w - 1 do
          local k = cy * g.w + cx
          local l, r = flux.count.left[k] or 0, flux.count.right[k] or 0
          if l + r == 0 then row = row .. " . "
          else
            any = true
            row = row .. (" %s%s"):format(l > 0 and math.min(9, l) or " ", r > 0 and math.min(9, r) or " ")
          end
        end
        if any then print(row) end
      end
    end
  end
end
