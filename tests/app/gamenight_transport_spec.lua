return function(H)
  local Transport = require("app.gamenight_transport")
  local A = H.assert
  H.describe("party transport", function()
    H.it("preserves partial sends and fragmented incoming lines", function()
      local peer = { sent = "", reads = 0 }
      function peer:send(data)
        local n = math.min(3, #data)
        self.sent = self.sent .. data:sub(1, n)
        return nil, "timeout", n
      end
      function peer:receive(_, prefix)
        self.reads = self.reads + 1
        if self.reads == 1 then return nil, "timeout", prefix .. '{"type":' end
        if self.reads == 2 then return prefix .. '"pause","session":"s"}' end
        return nil, "timeout", prefix
      end
      local t = setmetatable({ peer = peer, incoming = "", outgoing = "" }, Transport)
      t:send({ type = "ready", session = "s" })
      local expected, messages = t.outgoing, {}
      for _ = 1, 30 do
        A.truthy(t:poll(function(m) messages[#messages + 1] = m end))
      end
      A.equal(expected, peer.sent)
      A.equal(1, #messages)
      A.equal("pause", messages[1].type)
    end)
    H.it("reports closed sockets and malformed messages", function()
      local peer = {}
      function peer.receive() return nil, "closed", "" end
      local t = setmetatable({ peer = peer, incoming = "", outgoing = "" }, Transport)
      local ok, err = t:poll(function() error("unexpected message") end)
      A.falsy(ok); A.equal("closed", err)
      t.peer = { receive = function() return "not JSON" end }
      ok, err = t:poll(function() error("unexpected message") end)
      A.falsy(ok); A.equal("invalid JSON message", err)
    end)
  end)
end
