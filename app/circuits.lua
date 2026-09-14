--- Mechanism surfaces and wiring, drawn below the physical furniture.
local M = {}

function M.draw(def, board, dim, fonts, tick)
  local lg = love.graphics
  lg.setFont(fonts.small)
  for _, s in ipairs(def.sections or {}) do
    lg.setColor(s.color[1], s.color[2], s.color[3], 0.28 * dim)
    lg.rectangle("fill", s.x, s.y, s.w, s.h, 20)
    lg.setColor(s.color[1] + 0.2, s.color[2] + 0.2, s.color[3] + 0.2, 0.5 * dim)
    lg.setLineWidth(1)
    lg.rectangle("line", s.x, s.y, s.w, s.h, 20)
    lg.printf(s.label, s.x + 8, s.y + 10, s.w - 16, "center")
  end
  for _, spec in ipairs(def.circuits or {}) do
    local c = board and board.circuits[spec.id]
    local ready = c and c.charge >= c.capacity
    lg.setColor(0.2, 0.45, 0.4, 0.3 * dim)
    lg.setLineWidth(5)
    lg.line(spec.wire)
    if c and c.charge > 0 then
      lg.setColor(0.3, 1, 0.75, (ready and 0.9 or 0.5) * dim)
      lg.setLineWidth(2)
      lg.line(spec.wire)
    end
    local x, y = spec.wire[#spec.wire-1], spec.wire[#spec.wire]
    lg.setColor(0.4, 1, 0.8, 0.8 * dim)
    local status = "CHARGE GENERATOR"
    if c and c.active then status = "WORKSHOP RUNNING"
    elseif ready then status = "OPERATOR: HOLD GATE" end
    lg.printf(status, x - 95, y + 28, 190, "center")
    if c then
      for i = 1, c.capacity do
        lg.setColor(0.3, 1, 0.75, (i <= c.charge and 0.95 or 0.15) * dim)
        lg.rectangle("fill", x - c.capacity * 9 + (i-1) * 18, y + 12, 12, 5, 2)
      end
    end
  end
  for _, s in ipairs(def.switches or {}) do
    local c = board and board.circuits[s.circuit]
    local last = board and board.switch_ticks[s.id]
    local pulse = last and math.max(0, 1 - ((tick or 0) - last) / 150) or 0
    lg.setColor(0.85, 0.65, 0.18, (0.16 + pulse * 0.35) * dim)
    lg.rectangle("fill", s.x - s.w/2, s.y - s.h/2, s.w, s.h, 6)
    lg.setLineWidth(2)
    lg.setColor(1, 0.8, 0.3, 0.8 * dim)
    lg.rectangle("line", s.x - s.w/2, s.y - s.h/2, s.w, s.h, 6)
    for i = -2, 2 do
      local x = s.x + i * 14
      lg.line(x - 4, s.y + 4, x, s.y - 4, x + 4, s.y + 4)
    end
    lg.printf(c and ("POWER %d / %d"):format(c.charge, c.capacity) or "GENERATOR",
      s.x - 60, s.y + 22, 120, "center")
  end
end
return M
