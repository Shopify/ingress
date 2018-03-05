-- key's are always going to be ngx.var.proxy_upstream_name, a uniqueue identifier of an app's Backend object
-- currently it is built our of namepsace, service name and service port
-- value is JSON encoded ingress.Backend object.Backend object, for more info refer to internal//ingress/types.go
local configuration_data = ngx.shared.configuration_data

local _M = {}

function _M.get_backends_data()
  return configuration_data:get("backends")
end

function _M.get_backend_names()
  -- 0 here means get all the keys which can be slow if there are many keys
  -- TODO(elvinefendi) think about storing comma separated backend names in another dictionary and using that to
  -- fetch the list of them here insted of blocking the access to shared dictionary
  return backends_data:get_keys(0)
end

function _M.call()
  if ngx.var.request_method ~= "POST" or ngx.var.request_uri ~= "/configuration/backends" then
    ngx.status = 404
    ngx.print("Not found!")

    return
  end

  ngx.req.read_body()

  local success, err = configuration_data:set("backends", ngx.req.get_body_data())
  if not success then
    ngx.log(ngx.ERR, "error while saving configuration: " .. tostring(err))
    ngx.status = 400
    return
  end

  ngx.status = 201
end

return _M
