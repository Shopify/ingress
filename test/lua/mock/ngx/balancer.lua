local _M = {}

function _M.set_more_tries(x)
  expected. ngx_balancer.set_more_tries = x
end

function _M.set_current_peer(host, port)
  expected. ngx_balancer.set_current_peer = {
    host = host,
    port = port
  }
end

return _M
