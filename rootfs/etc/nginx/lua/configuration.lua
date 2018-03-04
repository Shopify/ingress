local router = require("router")
local json = require("cjson")

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

local backends = {}

function _M.get_backend(name)
  return backends[name]
end

-- this function will be periodically called in every worker to decode backends and store them in local backends variable
local function process_backends_data()
  ngx.log(ngx.DEBUG, "processing backends_data")

  -- 0 here means get all the keys which can be slow if there are many keys
  -- TODO(elvinefendi) think about storing comma separated backend names in another dictionary and using that to
  -- fetch the list of them here insted of blocking the access to shared dictionary
  backend_names = backends_data:get_keys(0)

  for _, backend_name in pairs(backend_names) do
    backend_data = backends_data:get(backend_name)

    local ok, backend = pcall(json.decode, backend_data)

    if ok then
      backends[backend_name] = backend
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
