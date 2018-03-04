local router = require("router")

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

local _M = {}

function _M.get_lb_alg(backend_name)
  return backend_lb_algorithms:get(backend_name)
end

function _M.get_backend_data(backend_name)
  return backends_data:get(backend_name)
end

function _M.get_backend_names()
  -- 0 here means get all the keys which can be slow if there are many keys
  -- TODO(elvinefendi) think about storing comma separated backend names in another dictionary and using that to
  -- fetch the list of them here insted of blocking the access to shared dictionary
  return backends_data:get_keys(0)
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
