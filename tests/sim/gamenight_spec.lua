return function(H)
  local GameNight = require("app.gamenight")
  local A = H.assert
  H.describe("party lifecycle with real physics", function()
    H.it("requests the lobby on Back or Escape without forwarding gameplay input", function()
      local messages = {}
      local game = setmetatable({ session = "one", phase = "paused", transport = {
        send = function(_, message) messages[#messages + 1] = message end,
      } }, GameNight)
      game:key("escape", true)
      game:pad({}, "back", true)
      game:key("escape", false)
      game:pad({}, "back", false)
      A.equal(2, #messages)
      A.equal("request_overlay", messages[1].type)
      A.equal("request_overlay", messages[2].type)
      game.session = nil
      game:key("escape", true)
      A.equal(2, #messages)
    end)
    H.it("warms frozen, plays, pauses, rejects stale commands, and replays ten times", function()
      local transport = { messages = {} }
      function transport:send(message) self.messages[#self.messages + 1] = message end
      function transport.poll() return true end
      function transport.close() end
      local game = GameNight.new(require("data.tables.init").load(), transport)
      for cycle = 1, 10 do
        local session = "session-" .. cycle
        game:receive({ type = "prepare", game = "pinpals", session = session,
          seats = { { index = 0, occupant = { kind = "local" } } } })
        A.equal("ready", transport.messages[cycle].type)
        A.equal(session, transport.messages[cycle].session)
        local match = game.match
        game:update(0.1)
        A.equal(0, match.state.tick)
        game:key("a", true)
        A.equal(0, #match.pending)
        game:receive({ type = "start", session = "stale" })
        A.equal("ready", game.phase)
        game:receive({ type = "start", session = session })
        game:key("a", true)
        game:update(0.1)
        A.truthy(match.state.tick > 0)
        game:receive({ type = "pause", session = session })
        local tick = match.state.tick
        local pending = #match.pending
        game:update(0.1)
        game:key("r", true)
        game:key("a", true)
        A.equal(pending, #match.pending)
        A.equal(tick, match.state.tick)
        game:receive({ type = "resume", session = session })
        game:update(0.1)
        A.truthy(match.state.tick > tick)
        game:receive({ type = "dispose", session = "stale" })
        A.equal(match, game.match)
        game:receive({ type = "dispose", session = session })
        A.equal("idle", game.phase)
        A.falsy(game.match)
        A.truthy(match.boards.a.world:isDestroyed())
        A.truthy(match.boards.b.world:isDestroyed())
      end
      game:quit()
      require("app.input").standalone()
    end)
  end)
end
