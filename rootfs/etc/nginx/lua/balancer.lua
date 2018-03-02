_M = {}

-- curl localhost:18080/lua_dicts
function _M.call()
  ngx.log(ngx.WARN, "I'm the balancer")
end

return _M
