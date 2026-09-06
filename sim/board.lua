--- Builds one Box2D world from a declarative board definition (§5.3) and
--- exposes the handful of operations core/ can command.
---
--- love.physics ONLY. No love.graphics / love.window / love.keyboard in this
--- file or anywhere else in sim/ -- that boundary is what keeps the headless
--- test harness working (§5, §7).

local C   = require("core.constants")
local geo = require("core.geometry")

local Board = {}
Board.__index = Board

local function ud(fixture, kind, id)
  fixture:setUserData({ kind = kind, id = id })
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function build_walls(self, def)
  for _, poly in ipairs(def.walls) do
    for i = 1, #poly - 3, 2 do
      local shape = love.physics.newEdgeShape(poly[i], poly[i+1], poly[i+2], poly[i+3])
      local f = love.physics.newFixture(self.ground, shape, 0)
      f:setRestitution(0.22)
      f:setFriction(0.10)
      ud(f, "wall")
    end
  end
end

local function build_bumpers(self, def)
  for i, b in ipairs(def.bumpers or {}) do
    local f = love.physics.newFixture(self.ground, love.physics.newCircleShape(b.x, b.y, b.r), 0)
    f:setRestitution(b.restitution or 1.2)
    f:setFriction(0.02)
    ud(f, "bumper", i)
  end
end

--- Slingshots. Static like a wall, energetic like a bumper: the whole triangle
--- carries the restitution, because the ball only ever meets the face that
--- points into the playfield -- the other two sides are buried against the
--- inlane and the lane divider.
---
--- design.md §6.1 forbids impulses, and this is not one: the rule is about
--- what the OPERATOR can do, and a slingshot is table furniture nobody fires.
--- It is built exactly the way bumpers already are, so it inherits their
--- measured no-debounce-needed behaviour rather than inventing new machinery.
local function build_slingshots(self, def)
  for i, sl in ipairs(def.slingshots or {}) do
    local f = love.physics.newFixture(self.ground, love.physics.newPolygonShape(sl.p), 0)
    f:setRestitution(sl.kick or 1.35)
    f:setFriction(0.04)
    ud(f, "sling", i)
  end
end

--- Standup targets. Static like walls, but they report being hit, which is
--- what makes them content rather than scenery. Corners come from core/ so
--- the fixture, the geometry checks and the drawing cannot disagree.
local function build_targets(self, def)
  for i, t in ipairs(def.targets or {}) do
    local shape = love.physics.newPolygonShape(geo.rect_corners(t))
    local f = love.physics.newFixture(self.ground, shape, 0)
    f:setRestitution(t.restitution or 0.45)
    f:setFriction(0.10)
    ud(f, "target", i)
  end
end

local function build_mouth(self, def)
  local m = def.tube.mouth
  local f = love.physics.newFixture(self.ground, love.physics.newCircleShape(m.x, m.y, m.r), 0)
  f:setSensor(true)
  ud(f, "mouth")
end

local function build_flipper(self, _def, spec)
  local left  = spec.side == "left"
  local sign  = left and 1 or -1
  local rest  = left and  C.FLIPPER_REST or -C.FLIPPER_REST
  local up    = left and  C.FLIPPER_UP   or -C.FLIPPER_UP

  -- Created at angle 0 on purpose: Box2D takes the joint's reference angle
  -- from the bodies' angles at construction, so building the flipper already
  -- rotated would make the limits below mean something else entirely.
  local body = love.physics.newBody(self.world, spec.x, spec.y, "dynamic")
  body:setBullet(true)
  local shape = love.physics.newRectangleShape(sign * C.FLIPPER_LEN / 2, 0,
                                               C.FLIPPER_LEN, C.FLIPPER_THICK)
  local f = love.physics.newFixture(body, shape, C.FLIPPER_DENSITY)
  f:setRestitution(0.06)
  f:setFriction(0.35)
  ud(f, "flipper", spec.side)

  local joint = love.physics.newRevoluteJoint(self.ground, body, spec.x, spec.y, false)
  joint:setLimitsEnabled(true)
  joint:setLimits(math.min(rest, up), math.max(rest, up))
  joint:setMotorEnabled(true)
  joint:setMaxMotorTorque(C.FLIPPER_TORQUE)
  joint:setMotorSpeed(0)
  body:setAngle(rest)                    -- drop it into the rest position

  self.flippers[spec.side] = {
    body = body, joint = joint, rest = rest, up = up,
    dir_up = (up > rest) and 1 or -1,
  }
end

local function build_devices(self, def)
  for _, d in ipairs(def.devices) do
    if d.kind == "gate" then
      local body = love.physics.newBody(self.world, d.pivot.x, d.pivot.y, "kinematic")
      body:setAngle(d.closed)
      local shape = love.physics.newRectangleShape(d.length / 2, 0, d.length, C.GATE_THICK)
      local f = love.physics.newFixture(body, shape, 1)
      f:setRestitution(0.18)
      ud(f, "gate", d.id)
      self.devices[d.id] = {
        def = d, kind = "gate", body = body,
        rate = math.abs(d.open - d.closed) / d.travel,
      }
    elseif d.kind == "paddle" then
      local body = love.physics.newBody(self.world, d.down.x, d.down.y, "kinematic")
      local shape = love.physics.newRectangleShape(0, 0, d.w, d.h)
      local f = love.physics.newFixture(body, shape, 1)
      f:setRestitution(0.30)
      ud(f, "post", d.id)
      local dx, dy = d.up.x - d.down.x, d.up.y - d.down.y
      self.devices[d.id] = {
        def = d, kind = "paddle", body = body,
        rate = math.sqrt(dx * dx + dy * dy) / d.travel,
      }
    end
  end
end

---@param def table validated board definition
---@return table board
function Board.new(def)
  local self = setmetatable({}, Board)
  self.def      = def
  self.id       = def.id
  self.world    = love.physics.newWorld(0, C.GRAVITY_PX, true)
  self.ground   = love.physics.newBody(self.world, 0, 0, "static")
  self.flippers = {}
  self.devices  = {}
  self.ball     = nil
  self.events   = {}

  build_walls(self, def)
  build_bumpers(self, def)
  build_slingshots(self, def)
  build_targets(self, def)
  build_mouth(self, def)
  build_devices(self, def)
  for _, spec in ipairs(def.flippers) do build_flipper(self, def, spec) end

  self.world:setCallbacks(
    function(fa, fb, coll) self:_begin(fa, fb, coll) end,
    nil, nil,
    function(fa, fb, coll, ni) self:_postsolve(fa, fb, coll, ni) end)
  return self
end

---------------------------------------------------------------------------
-- Ball
---------------------------------------------------------------------------

function Board:spawn(x, y, vx, vy)
  self:despawn()
  local body = love.physics.newBody(self.world, x, y, "dynamic")
  body:setBullet(true)                       -- §4.1: CCD on the ball, always
  body:setLinearDamping(C.BALL_DAMPING)
  local f = love.physics.newFixture(body, love.physics.newCircleShape(C.BALL_RADIUS), C.BALL_DENSITY)
  f:setRestitution(C.BALL_RESTIT)
  f:setFriction(C.BALL_FRICTION)
  ud(f, "ball")
  body:setLinearVelocity(vx or 0, vy or 0)
  self.ball = body
  return body
end

function Board:despawn()
  if self.ball then
    if not self.ball:isDestroyed() then self.ball:destroy() end
    self.ball = nil
  end
end

function Board:ball_pos()
  if not self.ball or self.ball:isDestroyed() then return nil end
  return self.ball:getX(), self.ball:getY()
end

function Board:ball_speed()
  if not self.ball or self.ball:isDestroyed() then return 0 end
  local vx, vy = self.ball:getLinearVelocity()
  return math.sqrt(vx * vx + vy * vy)
end

--- Velocity components. Anything predicting where the ball is going -- a
--- timing probe, and later an AI opponent or a replay scrubber -- needs the
--- direction, which the scalar speed above throws away.
---@return number vx, number vy
function Board:ball_velocity()
  if not self.ball or self.ball:isDestroyed() then return 0, 0 end
  return self.ball:getLinearVelocity()
end

--- Serve from the plunger lane (§ board data `serve`).
function Board:serve()
  local s = self.def.serve
  self:spawn(s.x, s.y, s.dir.x * C.SERVE_SPEED, s.dir.y * C.SERVE_SPEED)
end

--- A ball arriving out of the tube. §5: exit velocity survives the trip; the
--- entry point decides the direction it arrives from.
function Board:arrive(speed)
  local e = self.def.entry
  local len = math.sqrt(e.dir.x * e.dir.x + e.dir.y * e.dir.y)
  self:spawn(e.x, e.y, e.dir.x / len * speed, e.dir.y / len * speed)
end

---------------------------------------------------------------------------
-- Collision
---------------------------------------------------------------------------

function Board:_begin(fa, fb, _)
  local a, b = fa:getUserData(), fb:getUserData()
  if not (a and b) then return end
  local other
  if a.kind == "ball" then other = b elseif b.kind == "ball" then other = a else return end
  if other.kind == "mouth" then
    self.events[#self.events+1] = { kind = "tube", board = self.id, speed = self:ball_speed() }

  elseif other.kind == "bumper" then
    -- A scoring hit, which is a rule and not a contact: it goes to core/,
    -- where the presentation `impact` below deliberately does not.
    --
    -- No debounce here, and that is a measured decision rather than an
    -- oversight. The worry was that a ball leaving a bumper with restitution
    -- > 1 would register several begin-contacts on the way out and score for
    -- each. tests/probe_scoring.lua says it does not: a 0.02s cooldown
    -- suppresses exactly as many repeats as no cooldown at all (21 of 120
    -- approaches either way), so there is no solver jitter to filter. The
    -- repeats that do exist are spread over 50-400ms -- the ball genuinely
    -- coming back for a second hit, which is a thing pinball rewards.
    local hit = self.def.bumpers[other.id]
    self.events[#self.events+1] = {
      kind = "bumper", board = self.id, index = other.id, x = hit.x, y = hit.y,
    }

  elseif other.kind == "sling" then
    local sl = self.def.slingshots[other.id]
    local c = sl.p
    self.events[#self.events+1] = {
      kind = "sling", board = self.id, index = other.id,
      x = (c[1] + c[3] + c[5]) / 3, y = (c[2] + c[4] + c[6]) / 3,
    }

  elseif other.kind == "target" then
    local t = self.def.targets[other.id]
    self.events[#self.events+1] = {
      kind = "target", board = self.id, index = other.id, x = t.x, y = t.y,
    }
  end
end

--- Impacts, for presentation only: app/ turns these into sound and light.
--- Reported from postSolve rather than beginContact because the solver's
--- normal impulse is the actual strength of the hit, where a begin-contact
--- event only says that one happened -- a ball resting on the post and a ball
--- slammed into it are the same event and wildly different sounds.
---
--- A resting ball generates a small impulse every step, so the threshold is
--- what separates a hit from a lean. It is measured, not guessed: see
--- `tests/probe_impulses.lua`.
function Board:_postsolve(fa, fb, coll, normal_impulse)
  if normal_impulse < C.IMPACT_MIN_IMPULSE then return end
  if #self.events >= C.IMPACT_MAX_PER_STEP then return end
  local a, b = fa:getUserData(), fb:getUserData()
  if not (a and b) then return end
  local other
  if a.kind == "ball" then other = b elseif b.kind == "ball" then other = a else return end
  if other.kind == "mouth" then return end
  local x, y = coll:getPositions()
  if not x then x, y = self:ball_pos() end
  self.events[#self.events+1] = {
    kind = "impact", board = self.id, what = other.kind,
    x = x, y = y, impulse = normal_impulse,
  }
end

---------------------------------------------------------------------------
-- Step
---------------------------------------------------------------------------

--- Held: drive at the "up" limit and let the joint limit hold it there.
--- Released: drive back to the rest limit. Deliberately NOT a per-step
--- comparison against the current angle -- that chatters, because Box2D lets
--- a limit overshoot slightly and the motor then reverses every other step.
local function drive_flipper(f, held)
  f.joint:setMotorSpeed((held and f.dir_up or -f.dir_up) * C.FLIPPER_SPEED)
end

--- Move a kinematic device toward its commanded state. Velocity-driven, never
--- teleported, so Box2D sees the motion and the ball gets a real contact
--- response -- which is also what makes §6.1's "persistent state" readable.
local function drive_device(dev, commanded, dt)
  if dev.kind == "gate" then
    local d      = dev.def
    local target = commanded and d.open or d.closed
    local cur    = dev.body:getAngle()
    local delta  = target - cur
    if math.abs(delta) < 1e-4 then
      dev.body:setAngularVelocity(0)
      dev.body:setAngle(target)
    else
      local step = dev.rate * dt
      if math.abs(delta) <= step then
        dev.body:setAngularVelocity(delta / dt)
      else
        dev.body:setAngularVelocity(dev.rate * (delta > 0 and 1 or -1))
      end
    end
  else
    local d      = dev.def
    local target = commanded and d.up or d.down
    local cx, cy = dev.body:getPosition()
    local dx, dy = target.x - cx, target.y - cy
    local dist   = math.sqrt(dx * dx + dy * dy)
    if dist < 1e-3 then
      dev.body:setLinearVelocity(0, 0)
      dev.body:setPosition(target.x, target.y)
    else
      local step = dev.rate * dt
      local v    = (dist <= step) and (dist / dt) or dev.rate
      dev.body:setLinearVelocity(dx / dist * v, dy / dist * v)
    end
  end
end

--- One fixed step. Never called with a variable dt (§4.1).
---@param bstate table core state for this board (flippers + device commands)
---@param has_ball boolean
---@return table[] events
function Board:step(bstate, has_ball)
  local dt = C.FIXED_DT
  self.events = {}

  for side, f in pairs(self.flippers) do
    drive_flipper(f, has_ball and bstate.flippers[side] or false)
  end
  for id, dev in pairs(self.devices) do
    drive_device(dev, bstate.devices[id].commanded, dt)
  end

  self.world:update(dt)

  if self.ball and not self.ball:isDestroyed() then
    -- Clamp: past this speed CCD starts losing thin geometry (§11 tunneling).
    local vx, vy = self.ball:getLinearVelocity()
    local sp = math.sqrt(vx * vx + vy * vy)
    if sp > C.BALL_MAX_SPEED then
      local k = C.BALL_MAX_SPEED / sp
      self.ball:setLinearVelocity(vx * k, vy * k)
    end
    local _, y = self.ball:getPosition()
    if y > self.def.drain_y then
      self.events[#self.events+1] = { kind = "drain", board = self.id }
    end
  end

  return self.events
end

--- Device travel as 0..1, for the renderer and for tests. 0 = closed/down.
function Board:device_progress(id)
  local dev = self.devices[id]
  if not dev then return 0 end
  local d = dev.def
  if dev.kind == "gate" then
    return (dev.body:getAngle() - d.closed) / (d.open - d.closed)
  end
  local _, y = dev.body:getPosition()
  return (y - d.down.y) / (d.up.y - d.down.y)
end

return Board
