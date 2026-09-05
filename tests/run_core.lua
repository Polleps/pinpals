--- Bare-interpreter runner for core/. No LÖVE involved.
package.path = "./?.lua;./?/init.lua;" .. package.path
local H = require("tests.harness")
require("tests.core.spec")(H)
require("tests.core.geometry_spec")(H)
os.exit(H.report("core") and 0 or 1)
