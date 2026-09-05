--- Loads and validates the board set. Both the game and the tests come through
--- here, so a malformed board fails identically in both (§5.3).

local validate = require("core.validate")

local M = {}

--- @return table<string, table> boards keyed by id
function M.load()
  local boards = {
    a = require("data.tables.board_a"),
    b = require("data.tables.board_b"),
  }
  local ok, errs = validate.set(boards)
  if not ok then
    error("invalid board data:\n  " .. table.concat(errs, "\n  "), 2)
  end
  return boards
end

return M
