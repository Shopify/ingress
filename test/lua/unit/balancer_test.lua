local cwd = io.popen("pwd"):read('*l')
package.path = cwd .. "/test/lua/?.lua;" ..package.path

require("init")

module("balancer_tests", lunity)

local balancer = require("balancer")

function setup()
  ngx.reset()
end

function test_call_bad_phase()
  ngx.phase = "fakephase"
  assertErrors(balancer.call)
end

os.exit(runTests() and 0 or 1)
