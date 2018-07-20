local round_robin = require("balancer.round_robin")
local chash = require("balancer.chash")
local sticky = require("balancer.sticky")
local ewma = require("balancer.ewma")

local DEFAULT_LB_ALG = "round_robin"

local IMPLEMENTATIONS = {
  round_robin = round_robin,
  chash = chash,
  sticky = sticky,
  ewma = ewma,
}

local _M = {}

function _M.get(backend)
    local name = backend["load-balance"] or DEFAULT_LB_ALG

    if backend["sessionAffinityConfig"] and backend["sessionAffinityConfig"]["name"] == "cookie" then
      name = "sticky"
    elseif backend["upstream-hash-by"] then
      name = "chash"
    end

    local implementation = IMPLEMENTATIONS[name]
    if not implementation then
      local warning = string.format("%s is not supported, falling back to %s", backend["load-balance"], DEFAULT_LB_ALG)
      ngx.log(ngx.WARN, warning)
      implementation = IMPLEMENTATIONS[DEFAULT_LB_ALG]
    end

    return implementation
  end

return _M
