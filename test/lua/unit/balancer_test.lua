local cwd = io.popen("pwd"):read('*l')
package.path = cwd .. "/test/lua/?.lua;" ..package.path

require("init")

module("balancer_tests", lunity)

local balancer = require("balancer")

function setup()
  ngx.reset()
end

function test_call_phase_log()
  ngx.phase = "log"
  ngx.var.proxy_upstream_name = "fake_upstream"
  assertDoesNotError(balancer.call)
end

function test_call_bad_phase()
  ngx.phase = "fakephase"
  assertErrors(balancer.call)
end

function test_call_phase_balancer()
  ngx.phase = "balancer"
  ngx.var.proxy_upstream_name = "fake_upstream"

  balancer.call()

  assertEqual(expected.ngx_balancer.set_more_tries, 1, " ngx_balancer.set_more_tries value")
  assertEqual(expected.ngx_balancer.set_current_peer.host, "000.000.000", "ngx_balancer.set_current_peer.host(1/2)")
  assertEqual(expected.ngx_balancer.set_current_peer.port, "8080", "ngx_balancer.set_current_peer.port(1/2)")

  balancer.call()
  assertEqual(expected.ngx_balancer.set_current_peer.host, "000.000.001", "ngx_balancer.set_current_peer.host(2/2)")
  assertEqual(expected.ngx_balancer.set_current_peer.port, "8081", "ngx_balancer.set_current_peer.port(2/2)")
end

os.exit(runTests() and 0 or 1)
