local router = require 'router'
local json = require("cjson")

local dynamic_upstreams_dict = ngx.shared.dynamic_upstreams

local _M = {}

--curl -XPOST -d '{"key": "upstream-default-backend", "value": "172.17.0.4:8080 : 172.17.0.4:8081 : 172.17.0.5:8080", "ttl": 0}' localhost:18080/lua_dicts/dynamic_upstreams/keys
function _M.call()
  ngx.log(ngx.WARN, "I'm the dicts handler")

  local r = router.new()

  r:match({
    POST = {
      ["/configuration/backends/:name/endpoints"] = function(params)
        ngx.req.read_body() -- explicitly read the req body
        local ok, endpoints = pcall(json.decode, ngx.req.get_body_data())
        if not ok then
          return "could not parse request body: " .. tostring(endpoints)
        end

        endpoints_with_ports = {}
        for i, endpoint in pairs(endpoints) do
          endpoints_with_ports[i] = endpoint.address .. ":" .. endpoint.port
        end
        endpoints_string = table.concat(endpoints_with_ports, " : ")

        local success, err = dynamic_upstreams_dict:set(params.name, endpoints_string, 0)
        if not success then
          return err
        end

        ngx.status = 201
        ngx.print("endpoints for '" .. tostring(params.name) .. "' updated to '" .. endpoints_string .. "'")
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
    ngx.log(ngx.ERROR, errmsg)
    ngx.status = 404
    ngx.print("Not found!")
  end
end

return _M
