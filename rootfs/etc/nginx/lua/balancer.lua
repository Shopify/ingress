local ngx_balancer = require("ngx.balancer")
local ngx_upstream = require("ngx.upstream")
local json = require("cjson")
local configuration = require("configuration")
local util = require("util")

-- measured in seconds
-- for an Nginx worker to pick up the new list of upstream peers 
-- it will take <the delay until controller POSTed the backend object to the Nginx endpoint> + BACKENDS_SYNC_INTERVAL
local BACKENDS_SYNC_INTERVAL = 1

local round_robin_state = ngx.shared.round_robin_state

local _M = {}

local backends = {}

local function balance()
  local backend_name = ngx.var.proxy_upstream_name
  local lb_alg = configuration.get_lb_alg(backend_name)
  local backend = backends[backend_name]

  if lb_alg == "ip_hash" then
    -- TODO(elvinefendi) implement me
    return backends.endpoints[0].address, backends.endpoints[0].port
  end

  -- Round-Robin
  -- TODO(elvinefendi) use resty lock here, otherwise there can be race
  local index = round_robin_state:get(backend_name)
  local index, endpoint = next(backend.endpoints, index)
  if not index then
    index = 1
    endpoint = backend.endpoints[index]
  end
  round_robin_state:set(backend_name, index)
  return endpoint.address, endpoint.port
end

local function sync_backend(backend)
  backends[backend.name] = backend

  -- also reset the respective balancer state since backend has changed
  round_robin_state:delete(backend.name)

  ngx.log(ngx.INFO, "syncronization completed for: " .. backend.name)
end

local function sync_backends()
  local backend_names = configuration.get_backend_names()

  for _, backend_name in pairs(backend_names) do
    backend_data = configuration.get_backend_data(backend_name)

    local ok, backend = pcall(json.decode, backend_data)

    if ok then
      if not util.deep_compare(backends[backend_name], backend, true) then
        sync_backend(backend)
      end
    else
      ngx.log(ngx.ERROR,  "could not parse backend_json: " .. tostring(backend))
    end
  end
end

function _M.init_worker()
  _, err = ngx.timer.every(BACKENDS_SYNC_INTERVAL, sync_backends)
  if err then
    ngx.log(ngx.ERROR, "error when setting up timer.every for sync_backends: " .. tostring(err))
  end
end

function _M.call()
  ngx_balancer.set_more_tries(1)

  local host, port = balance()

  local ok, err = ngx_balancer.set_current_peer(host, port)
  if ok then
    ngx.log(ngx.INFO, "current peer is set to " .. host .. ":" .. port)
  else
    ngx.log(ngx.ERR, "error while setting current upstream peer to: " .. tostring(err))
  end
end

return _M
