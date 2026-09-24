return function(H)
  local A = H.assert
  local state = require("core.state")
  local mission = require("core.mission")
  local boards = require("data.tables.init").load()
  local function playing()
    local s = state.new(boards)
    s.phase = "play"
    return s
  end
  local function hit(s, kind, index)
    state.consume(s, { { kind = kind, board = "a", index = index, speed = 900 } })
  end
  H.describe("relay missions", function()
    H.it("requires different lanes and debounces a repeated contact", function()
      local s = playing()
      hit(s, "rollover", 1)
      local points = s.stats.score
      hit(s, "rollover", 1)
      A.equal(points, s.stats.score)
      A.equal(1, s.boards.a.mission.charge)
      hit(s, "rollover", 2)
      hit(s, "rollover", 3)
      A.equal(725, s.stats.score)
      A.equal(nil, next(s.boards.a.mission.lanes))
      A.equal(5, s.boards.a.mission.charge)
    end)
    H.it("keeps preparation through a drain and pays a jackpot only once", function()
      local s = playing()
      mission.charge(s.boards.a.mission, 8)
      hit(s, "drain")
      A.equal(8, s.boards.a.mission.charge)
      s.phase = "play"
      hit(s, "tube")
      A.equal(1, s.boards.a.mission.jackpots)
      A.equal(0, s.boards.a.mission.charge)
      local before = s.stats.score
      hit(s, "tube")
      A.equal(before, s.stats.score, "transit paid twice")
    end)
    H.it("does not reward ramp entry or a rollback", function()
      local s = playing()
      state.consume(s, { { kind = "ramp", board = "a", at = "enter" },
        { kind = "ramp", board = "a", at = "exit", complete = false } })
      A.equal(0, s.stats.score)
      A.equal(0, s.boards.a.mission.combo)
    end)
    H.it("rewards a full ride and a timed pass; drains cancel the combo", function()
      local s = playing()
      state.consume(s, { { kind = "ramp", board = "a", at = "exit", complete = true } })
      A.equal(750, s.stats.score)
      A.equal(3, s.boards.a.mission.charge)
      hit(s, "tube")
      A.truthy(s.stats.score >= 2250)
      A.equal(0, s.boards.a.mission.combo)
      s.phase, s.active = "play", "a"
      s.boards.a.mission.combo = 10
      hit(s, "drain")
      A.equal(0, s.boards.a.mission.combo)
    end)
    H.it("lane change moves the lit lanes and the skill lane with the flippers", function()
      local s = state.new(boards)
      s.phase, s.active = "play", "b"
      local b = s.boards.b
      A.truthy(b.lane_change)
      b.mission.lanes = { [1] = true }
      b.mission.skill_lane = 3
      state.apply_intent(s, { player = 2, action = "flip_right", pressed = true, tick = 0 })
      A.truthy(b.mission.lanes[2] and not b.mission.lanes[1])
      A.equal(1, b.mission.skill_lane, "the skill lane wraps round")
      state.apply_intent(s, { player = 2, action = "flip_left", pressed = true, tick = 1 })
      A.truthy(b.mission.lanes[1])
      state.apply_intent(s, { player = 2, action = "flip_left", pressed = false, tick = 2 })
      A.truthy(b.mission.lanes[1], "a release moved the lanes")
      A.falsy(s.boards.a.lane_change, "Foundry has no lane change")
    end)
    H.it("pays the skill shot through the flashing lane only, once per window", function()
      local s = state.new(boards)
      s.phase, s.active = "serve", "b"
      s.timer = 0
      state.update(s)
      local m = s.boards.b.mission
      A.truthy(m.skill_time > 0, "a serve did not open the skill window")
      local lane = m.skill_lane
      local other = lane % 3 + 1
      state.consume(s, { { kind = "rollover", board = "b", index = other } })
      A.equal(0, m.skills)
      A.equal(0, m.skill_time, "a wrong lane should spend the window")
      m.skill_time = 1
      state.consume(s, { { kind = "rollover", board = "b", index = lane } })
      A.equal(1, m.skills)
    end)
    H.it("counts down only during active play", function()
      local s = playing()
      s.boards.a.mission.combo = 5
      s.phase = "serve"
      state.update(s)
      A.equal(5, s.boards.a.mission.combo)
      s.phase = "play"
      state.update(s)
      A.truthy(s.boards.a.mission.combo < 5)
      mission.update(s.boards.a.mission, 10, true)
      A.equal(0, s.boards.a.mission.combo)
    end)
  end)
end
