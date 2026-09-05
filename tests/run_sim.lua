--- Headless LÖVE runner. Invoked from main.lua under `love . --test`.
return function()
  local H = require("tests.harness")
  require("tests.core.spec")(H)
  require("tests.core.geometry_spec")(H)
  require("tests.app.fx_spec")(H)
  local core_ok = H.report("core")
  H.reset()
  require("tests.sim.spec")(H)
  local sim_ok = H.report("sim (headless love.physics)")
  return core_ok and sim_ok
end
