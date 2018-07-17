package.path = "./rootfs/etc/nginx/lua/?.lua;./rootfs/etc/nginx/lua/test/mocks/?.lua;" .. package.path

local util = require("util")

describe("Balancer static upstreams", function()  
  local static_upstreams = require("balancer.static_upstreams")

  before_each(function()
    static_upstreams.reset()
  end)

  it("marshals static upstreams into the expected backend format", function()
      static_upstreams.configure(".*")


      local remote_pool1_ssl = static_upstreams.get()["remote_pool1_ssl"]
      assert.equal("192.168.1.1", remote_pool1_ssl.endpoints[1].address)
      assert.equal("443", remote_pool1_ssl.endpoints[1].port)
      assert.equal("ewma", remote_pool1_ssl['load-balance'])

      local remote_pool2_ssl = static_upstreams.get()["remote_pool2_ssl"]
      assert.equal("192.168.2.1", remote_pool2_ssl.endpoints[1].address)
      assert.equal("443", remote_pool2_ssl.endpoints[1].port)
      assert.equal("ewma", remote_pool2_ssl['load-balance'])
  end)

  it("shouldn't include upstream_balancer", function()
    static_upstreams.configure(".*")

    local su = static_upstreams.get()["upstream_balancer"]

    assert.is_nil(ub)
  end)

  it("pattern matches correctly", function()
    static_upstreams.configure("pool1")

    local su = static_upstreams.get()

    assert.is.truthy(su["remote_pool1_ssl"])
    assert.equal(1, util.tablelength(su))
  end)
end)
