local ngx_balancer = require("ngx.balancer")
local ngx_upstream = require("ngx.upstream")
local math = require("math")
local dynamic_upstreams_dict = ngx.shared.dynamic_upstreams
local json = require("cjson")

local _M = {}

local function split_pair(pair, seperator)
  local i = pair:find(seperator)
  if i == nil then
    return pair, nil
  else
    local name = pair:sub(1, i - 1)
    local value = pair:sub(i + 1, -1)
    return name, value
  end
end

local function get_dynamic_peers(upstream_name)
  local peers_data = dynamic_upstreams_dict:get(upstream_name)
  if not peers_data then
    return nil
  end

  local ok, peers = pcall(json.decode, peers_data)
  if not ok then
    ngx.log(ngx.WARN, "error decoding peers for upstream pool: " .. upstream_name)
    return nil
  end

  return peers
end

local function get_peers(upstream_name)
  return get_dynamic_peers(upstream_name) or ngx_upstream.get_primary_peers(upstream_name)
end

local function balance(peers)
  local offset = math.random(1, #peers)
  local peer = peers[offset]
  return split_pair(peer.name, ':')
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
    ngx.log(ngx.DEBUG, "current peer is set to " .. tostring(host) .. ":" .. tostring(port))
  else
    ngx.log(ngx.ERR, "error while setting current upstream peer to: " .. tostring(err))
  end
end

return _M
