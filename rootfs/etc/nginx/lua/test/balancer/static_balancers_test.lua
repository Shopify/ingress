package.path = "./rootfs/etc/nginx/lua/?.lua;./rootfs/etc/nginx/lua/test/mocks/?.lua;" .. package.path
_G._TEST = true

local util = require("util")

describe("Static balancers", function()
  local static_balancers = require("balancer.static_balancers")

  before_each(function()
    package.loaded["balancer.static_balancers"] = nil
    static_balancers = require("balancer.static_balancers")
  end)

  describe("Balancers", function()
    it("should be configured", function()
      static_balancers.configure()

      local balancers = static_balancers.get()

      local pool1 = {
        peers = {
          [1] = {
            address = '192.168.1.1',
            fail_timeout = 1,
            max_fails = 2,
            name = '192.168.1.1:443',
            port = '443',
            weight = 1,
          }
        }
      }

      assert.are.same(pool1, balancers["remote_pool1_ssl"])

      local pool2 = {
        peers = {
          [1] = {
            address = '192.168.2.1',
            fail_timeout = 1,
            max_fails = 2,
            name = '192.168.2.1:443',
            port = '443',
            weight = 1,
          }
        }
      }

      assert.are.same(pool2, balancers["remote_pool2_ssl"])
    end)
  end)

  describe("Backends", function()
    it("marshals static upstreams into the expected backend format", function()
      static_balancers.configure()

      local pools = static_balancers.backends()

      local expected_pool1 = {
        ['load-balance'] = 'ewma',
        endpoints = {
          [1] = {
            fail_timeout = 1,
            max_fails = 2,
            name = '192.168.1.1:443',
            port = '443',
            weight = 1,
            address = '192.168.1.1',
          }
        },
        name = 'remote_pool1_ssl',
      }

      assert.are.same(expected_pool1, pools["remote_pool1_ssl"])

      local expected_pool2 = {
        ['load-balance'] = 'ewma',
        endpoints = {
          [1] = {
            fail_timeout = 1,
            max_fails = 2,
            name = '192.168.2.1:443',
            port = '443',
            weight = 1,
            address = '192.168.2.1',
          }
        },
        name = 'remote_pool2_ssl',
      }

      assert.are.same(expected_pool2, pools["remote_pool2_ssl"])
    end)

    it("grabs all valid upstreams", function()
      static_balancers.configure()

      local sb = static_balancers.backends()

      assert.equal(2, util.tablelength(sb))
    end)

    it("shouldn't include upstream_balancer", function()
      static_balancers.configure()

      local sb = static_balancers.backends()

      assert.is_nil(sb["upstream_balancer"])
    end)
  end)
end)
