local ngx_balancer = require("ngx.balancer")
local ngx_upstream = require("ngx.upstream")
local math = require("math")
local json = require("cjson")
local resty_chash = require("resty.chash")
local resty_roundrobin = require("resty.roundrobin")
local configuration = require("configuration")
local util = require("util")

local DEFAULT_ALGORITHM = "round_robin"

local _M = {}

local function balance_least_conn(endpoints)
  local servers, nodes = {}, {}
  local str_null = string.char(0)

  for _, endpoint in ipairs(endpoints) do
    local id = endpoint.address .. str_null .. endpoint.port
    servers[id] = endpoint
    nodes[id] = 1
  end

  -- TODO(elvinefendi) move this out of hot path and do it in process_backends_data function instead
  local chash = resty_chash:new(nodes)

  local id = chash:find()
  local endpoint = servers[id]
  return endpoint.address, endpoint.port
end

function _M.call()
  ngx_balancer.set_more_tries(1)

  local lb = configuration.get_lb(ngx.var.proxy_upstream_name)
  local host_port_string = lb:find()
  ngx.log(ngx.INFO, "selected host_port_string: " .. host_port_string)
  local host, port = util.split_pair(host_port_string, ":")

  local ok, err = ngx_balancer.set_current_peer(host, port)
  if ok then
    ngx.log(ngx.INFO, "current peer is set to " .. host_port_string)
  else
    ngx.log(ngx.ERR, "error while setting current upstream peer to: " .. tostring(err))
  end
end

return _M
