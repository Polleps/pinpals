--- Validate the reusable mechanism wiring before any physics is constructed.
local M = {}
local function number(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function named(v) return type(v) == "string" and #v > 0 end
local function list(e, b, key)
  if b[key] == nil then return {} end
  if type(b[key]) ~= "table" then e[#e+1] = key .. ": expected a list"; return {} end
  return b[key]
end
local function rectangle(e, spec, at, size)
  if not (number(spec.x) and number(spec.y) and number(spec.w) and number(spec.h))
     or spec.w <= 0 or spec.h <= 0 then
    e[#e+1] = at .. ": expected x/y and positive w/h"
  elseif size and number(size.w) and number(size.h) then
    if spec.x - spec.w/2 < 0 or spec.x + spec.w/2 > size.w
       or spec.y - spec.h/2 < 0 or spec.y + spec.h/2 > size.h then
      e[#e+1] = at .. ": outside playfield"
    end
  end
end
function M.check(b, e)
  local circuits, routes, devices, switches = {}, {}, {}, {}
  for _, r in ipairs(b.ramps or {}) do routes[r.id or false] = r end
  for _, d in ipairs(b.devices or {}) do devices[d.id or false] = d end
  for i, c in ipairs(list(e, b, "circuits")) do
    local at = "circuits[" .. i .. "]"
    if type(c) ~= "table" then e[#e+1] = at .. ": expected table"
    else
      if not named(c.id) or circuits[c.id] then e[#e+1] = at .. ": missing/duplicate id"
      else circuits[c.id] = c end
      if not number(c.capacity) or c.capacity <= 0 then e[#e+1] = at .. ": invalid capacity" end
      if not named(c.label) then e[#e+1] = at .. ": expected label" end
      if not routes[c.route or false] then e[#e+1] = at .. ": unknown route" end
      if type(c.wire) ~= "table" or #c.wire < 4 or #c.wire % 2 ~= 0 then
        e[#e+1] = at .. ": expected wire polyline"
      else
        for _, v in ipairs(c.wire) do
          if not number(v) then e[#e+1] = at .. ": nonnumeric wire coordinate"; break end
        end
      end
    end
  end
  for i, s in ipairs(list(e, b, "switches")) do
    local at = "switches[" .. i .. "]"
    if type(s) ~= "table" then e[#e+1] = at .. ": expected table"
    else
      if not named(s.id) or switches[s.id] then e[#e+1] = at .. ": missing/duplicate id"
      else switches[s.id] = true end
      if s.kind ~= "generator" then e[#e+1] = at .. ": expected generator kind" end
      rectangle(e, s, at, b.size)
      if not circuits[s.circuit or false] then e[#e+1] = at .. ": unknown circuit" end
      if not number(s.threshold) or s.threshold <= 0 or not number(s.strong)
         or s.strong < s.threshold or not number(s.cooldown) or s.cooldown < 0.1 then
        e[#e+1] = at .. ": invalid speed thresholds or cooldown"
      end
    end
  end
  for _, d in ipairs(b.devices or {}) do
    if d.circuit and not circuits[d.circuit] then e[#e+1] = "device: unknown circuit" end
  end
  for _, r in ipairs(b.ramps or {}) do
    if r.device and not devices[r.device] then e[#e+1] = "ramp: unknown device" end
  end
  for _, c in pairs(circuits) do
    local r = routes[c.route or false]
    local d = r and devices[r.device or false]
    if not d or d.circuit ~= c.id then e[#e+1] = "circuit: route must use its powered device" end
  end
  for i, s in ipairs(list(e, b, "sections")) do
    local at = "sections[" .. i .. "]"
    if type(s) ~= "table" then e[#e+1] = at .. ": expected table"
    else
      if not named(s.id) or not named(s.label) then e[#e+1] = at .. ": expected id and label" end
      if not (number(s.x) and number(s.y) and number(s.w) and number(s.h))
         or s.w <= 0 or s.h <= 0 then e[#e+1] = at .. ": invalid bounds" end
      if type(s.color) ~= "table" or #s.color ~= 3 then e[#e+1] = at .. ": expected RGB color"
      else
        for _, v in ipairs(s.color) do
          if not number(v) or v < 0 or v > 1 then e[#e+1] = at .. ": invalid color"; break end
        end
      end
    end
  end
end
return M
