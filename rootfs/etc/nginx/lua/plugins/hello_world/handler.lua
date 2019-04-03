local _M = {}

function _M.rewrite()
  ngx.say("Hellow world!")
  ngx.exit(200)
end

return _M
