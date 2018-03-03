local ngx_balancer = require("ngx.balancer")
local ngx_upstream = require("ngx.upstream")
local math = require("math")
local json = require("cjson")

local dynamic_upstreams_dict = ngx.shared.dynamic_upstreams

local _M = {}

-- http://nginx.org/en/docs/http/ngx_http_upstream_module.html#example
-- CAVEAT: nginx is giving out : instead of , so the docs are wrong
-- 127.0.0.1:26157 : 127.0.0.1:26157 , ngx.var.upstream_addr
-- 200 : 200 , ngx.var.upstream_status
-- 0.00 : 0.00, ngx.var.upstream_response_time
local function split_upstream_var(var)
  if not var then
    return nil, nil
  end
  local t = {}
  for v in var:gmatch("[^%s|,]+") do
    if v ~= ":" then
      t[#t+1] = v
    end
  end
  return t
end

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

-- dynamic peers are stored per upstream name
-- <upstream_name>: "<host1:port1> : <host2:port2> : <host3:port3>"
local function get_dynamic_peers(upstream_name)
  local peers_string = dynamic_upstreams_dict:get(upstream_name)
  if not peers_string then
    return nil
  end

  local raw_peers = split_upstream_var(peers_string)
  local peers = {}
  for i, p in pairs(raw_peers) do
    peers[i] = {
      name = p,
      down = false
    }
  end

  return peers
end

local function get_peers(upstream_name)
  return get_dynamic_peers(upstream_name) or ngx_upstream.get_primary_peers(upstream_name)
end

local function balance(peers)
  local offset = math.random(1, #peers)
  local peer = peers[offset]
  return split_pair(peer.name, ":")
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
