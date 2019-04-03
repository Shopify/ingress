local _M = {}

function _M.content()
  ngx.say("Hello World!")
  ngx.exit(200)
end

return _M
