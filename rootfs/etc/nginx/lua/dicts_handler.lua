local router = require 'router'
local json = require("cjson")

local _M = {}

--curl -XPOST -d '{"key": "upstream-default-backend", "value": "172.17.0.4:8080 : 172.17.0.4:8081 : 172.17.0.5:8080", "ttl": 0}' localhost:18080/lua_dicts/dynamic_upstreams/keys
function _M.call()
  ngx.log(ngx.WARN, "I'm the dicts handler")

  local r = router.new()

  r:match({
    POST = {
      ["/lua_dicts/:name/keys"] = function(params)
        local dict = ngx.shared[params.name]
        if not dict then
          return params.name .. " could not be found"
        end

        ngx.req.read_body() -- explicitly read the req body
        local ok, body = pcall(json.decode, ngx.req.get_body_data())
        if not ok then
          return "could not parse request body: " .. tostring(body)
        end

        if body.value == json.null then
          body.value = nil
        end

        local success, err = dict:set(body.key, body.value, body.ttl or 0)
        if not success then
          return err
        end

        ngx.print(tostring(body.key) .. " is set to " .. tostring(body.value) .. " in " .. tostring(params.name))
      end
    }
  })

  local ok, errmsg = r:execute(ngx.var.request_method, ngx.var.request_uri, ngx.req.get_uri_args())
  if ok then
    if errmsg then
      ngx.status = 400
      ngx.print(tostring(errmsg))
    else
      ngx.status = 200
    end
  else
    ngx.status = 404
    ngx.print("Not found!")
    ngx.log(ngx.ERROR, errmsg)
  end
end

return _M
