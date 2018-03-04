local ngx_balancer = require("ngx.balancer")
local ngx_upstream = require("ngx.upstream")
local math = require("math")
local json = require("cjson")
local configuration = require("configuration")

local _M = {}

local function get_peers(upstream_name)
  local backend = configuration.get_backend(upstream_name)
  if backend then
    return backend.endpoints
  end
  ngx_upstream.get_primary_peers(upstream_name)
end

local function balance(peers)
  local offset = math.random(1, #peers)
  local peer = peers[offset]
  return peer.address, peer.port
end

function _M.call()
  ngx.log(ngx.WARN, "I'm the balancer")

  ngx_balancer.set_more_tries(1)

  local peers = get_peers(ngx.var.proxy_upstream_name)
  if not peers or #peers == 0 then
    ngx.log(ngx.ERR, "no upstream peers available")
    return
  end

  local host, port = balance(peers)

  local ok, err = ngx_balancer.set_current_peer(host, port)
  if ok then
    ngx.log(ngx.WARN, "current peer is set to " .. tostring(host) .. ":" .. tostring(port))
  else
    ngx.log(ngx.ERR, "error while setting current upstream peer to: " .. tostring(err))
  end
end

return _M
