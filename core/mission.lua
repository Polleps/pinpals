--- Shot progress survives drains; the timed skyway combo does not.
--- No random objectives: every lit insert corresponds to a shot on the board.
local C = require("core.constants")
local score = require("core.score")
local M = { GOAL = 8, COMBO_TIME = 12, SKILL_TIME = 3.0 }

function M.new()
  return { charge = 0, jackpots = 0, lanes = {}, lane_tick = {}, combo = 0,
           rides = 0, notice = "", notice_time = 0,
           -- Skill shot: which lane is flashing, and for how much longer.
           skill_lane = 2, skill_time = 0, skills = 0 }
end

function M.update(m, dt, playing)
  m.notice_time = math.max(0, m.notice_time - dt)
  if playing then
    m.combo = math.max(0, m.combo - dt)
    m.skill_time = math.max(0, m.skill_time - dt)
  end
end

--- Lane change: the flipper buttons shift every lit lane, and the flashing
--- skill lane with them, one place left or right with wrap-around. That is
--- what makes a ball falling toward the lanes something to steer rather than
--- something to watch.
---@param m table mission state
---@param count integer lanes on this board
---@param dir integer -1 for left, +1 for right
function M.rotate(m, count, dir)
  if count < 2 then return end
  local moved = {}
  for i in pairs(m.lanes) do moved[(i - 1 + dir) % count + 1] = true end
  m.lanes = moved
  m.skill_lane = (m.skill_lane - 1 + dir) % count + 1
end

--- Open the skill-shot window: the ball has just been served, or has just
--- arrived from the partner's board with the sender's aim on it.
---
--- The flashing lane moves on one place each window. The serve and most
--- arrivals come down the middle lane (tests/probe_fun counts the lanes), so
--- a skill lane that stayed put there would be paid for doing nothing; one
--- that moves has to be steered to the ball with the flippers, or the ball
--- aimed at it by the sender in transit.
function M.start_skill(m, count)
  if count < 1 then return end
  m.skill_lane = (m.skill_lane % count) + 1
  m.skill_time = M.SKILL_TIME
end

local function announce(m, text)
  m.notice, m.notice_time = text, 3
end

function M.charge(m, amount)
  local before = m.charge
  m.charge = math.min(M.GOAL, m.charge + amount)
  if before < M.GOAL and m.charge == M.GOAL then announce(m, "JACKPOT READY - SHOOT PASS") end
end

--- Returns the bonus earned by a shot; ordinary contact scoring stays in state.
function M.shot(s, ev)
  local b = s.boards[ev.board]
  local m = b.mission
  if ev.kind == "rollover" then
    if not ev.index or ev.index < 1 or ev.index > b.lane_count then return 0 end
    if s.tick - (m.lane_tick[ev.index] or -10000) < C.TICK_HZ / 2 then return 0 end
    m.lane_tick[ev.index] = s.tick
    local value = score.award(s.stats, "lane")
    -- The first lane crossed inside the window settles the skill shot either
    -- way: through the flashing lane pays, any other lane spends it.
    if m.skill_time > 0 then
      m.skill_time = 0
      if ev.index == m.skill_lane then
        m.skills = m.skills + 1
        value = value + score.award(s.stats, "skill")
        M.charge(m, 2)
        announce(m, "SKILL SHOT!")
      end
    end
    if not m.lanes[ev.index] then
      m.lanes[ev.index] = true
      M.charge(m, 1)
      local count = 0
      for _ in pairs(m.lanes) do count = count + 1 end
      if count == b.lane_count then
        m.lanes = {}
        value = value + score.award(s.stats, "lanes")
        M.charge(m, 2)
        announce(m, "ALL LANES! +500")
      end
    end
    return value
  elseif ev.kind == "ramp" and ev.at == "exit" and ev.complete then
    m.rides = m.rides + 1
    m.combo = M.COMBO_TIME
    m.combo_label = ev.label or "SKYWAY"
    M.charge(m, 3)
    announce(m, (ev.label or "SKYWAY") .. "! PASS FOR COMBO")
    return score.award(s.stats, "ramp")
  elseif ev.kind == "tube" then
    local value = 0
    if m.charge >= M.GOAL then
      m.charge = 0
      m.jackpots = m.jackpots + 1
      value = score.award(s.stats, "jackpot", math.min(5, m.jackpots))
      announce(m, "RELAY JACKPOT!")
    end
    if m.combo > 0 then
      value = value + score.award(s.stats, "combo")
      announce(m, (m.combo_label or "SKYWAY") .. " PASS COMBO!")
    end
    if value > 0 then
      s.shot_notice, s.shot_notice_time = m.notice, 3
    end
    m.combo = 0
    return value
  end
  return 0
end

return M
