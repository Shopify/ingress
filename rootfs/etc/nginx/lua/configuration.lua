local router = require("router")
local json = require("cjson")
local util = require("util")

-- key's are backend names
-- value's are respective load balancing algorithm name to use for the backend
local backend_lb_algorithms = ngx.shared.backend_lb_algorithms

-- key's are always going to be ngx.var.proxy_upstream_name, a uniqueue identifier of an app's Backend object
-- currently it is built our of namepsace, service name and service port
-- value is JSON encoded ingress.Backend object.Backend object, for more info refer to internal//ingress/types.go
local backends_data = ngx.shared.backends_data

-- TODO(elvinefendi) this is for future iteration when/if we decide for example to dynamically configure certificates
-- similar to backends_data
-- local servers_data = ngx.shared.servers_data

-- measured in seconds
-- for an Nginx worker to pick up the new list of upstream peers 
-- it will take <the delay until controller POSTed the backend object to the Nginx endpoint> + BACKEND_PROCESSING_DELAY
local BACKEND_PROCESSING_DELAY = 1

local _M = {}

local lbs = {}
local backends = {}

function _M.get_lb(backend_name)
  return lbs[backend_name]
end

local resty_roundrobin = require("resty.roundrobin")

-- TODO(elvinefendi) make this consider lb_alg instead of always using round robin
local function update_backend(backend)
  ngx.log(ngx.INFO, "updating backend: " .. backend.name)

  local servers, nodes = {}, {}

  for _, endpoint in ipairs(backend.endpoints) do
    id = endpoint.address .. ":" .. endpoint.port
    servers[id] = endpoint
    nodes[id] = 1
  end

  local rr = lbs[backend.name]
  if rr then
    rr:reinit(nodes)
  else
    rr = resty_roundrobin:new(nodes)
  end

  lbs[backend.name] = rr
  backends[backend.name] = backend
end

-- this function will be periodically called in every worker to decode backends and store them in local backends variable
local function process_backends_data()
  -- 0 here means get all the keys which can be slow if there are many keys
  -- TODO(elvinefendi) think about storing comma separated backend names in another dictionary and using that to
  -- fetch the list of them here insted of blocking the access to shared dictionary
  backend_names = backends_data:get_keys(0)

  for _, backend_name in pairs(backend_names) do
    backend_data = backends_data:get(backend_name)

    local ok, backend = pcall(json.decode, backend_data)

    if ok then
      if not util.deep_compare(backends[backend_name], backend, true) then
        update_backend(backend)
      end
    else
      ngx.log(ngx.ERROR,  "could not parse backend_json: " .. tostring(backend))
    end
  end
end

function _M.init_worker()
  _, err = ngx.timer.every(BACKEND_PROCESSING_DELAY, process_backends_data)
  if err then
    ngx.log(ngx.ERROR, "error when setting up timer.every for process_backends_data: " .. tostring(err))
  end
end

function _M.call()
  local r = router.new()

  r:match({
    POST = {
      ["/configuration/backends/:name"] = function(params)
        ngx.req.read_body() -- explicitly read the req body

        local success, err = backends_data:set(params.name, ngx.req.get_body_data())
        if not success then
          return err
        end

        -- TODO(elvinefendi) also check if it is a supported algorith
        if params.lb_alg ~=nil and params.lb_alg ~= "" then
          success, err = backend_lb_algorithms:set(params.name, params.lb_alg)
          if not success then
            return err
          end
        end

        ngx.status = 201
        ngx.log(ngx.INFO, "backend data was updated for " .. params.name .. ": " .. tostring(ngx.req.get_body_data()))
      end
    }
  })

  local ok, errmsg = r:execute(ngx.var.request_method, ngx.var.request_uri, ngx.req.get_uri_args())
  if ok then
    if errmsg then
      ngx.status = 400
      ngx.print(tostring(errmsg))
    end
  else
    ngx.log(ngx.ERROR, tostring(errmsg))
    ngx.status = 404
    ngx.print("Not found!")
  end
end

return _M
