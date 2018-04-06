local _shared_dict = { __index = {
    get_stale = function(self, key)
        if key == nil then error("nil key") end
        return self._vals[key], {}, false
    end,
    get = function(self, key)
        if key == nil then error("nil key") end
        return self._vals[key]
    end,
    set = function(self, key, val, expires)
        if key == nil then error("nil key") end
        self._vals[key] = val
        return true, nil, false
    end,
    delete = function(self, key)
        return self:set(key, nil)
    end,
    incr = function(self, key, val)
        if not self:get(key) then return nil, "not found" end
        self:set(key, self:get(key) + val)
        return self:get(key), nil
    end,
    add = function(self, key, val)
        if self:get(key) then return false, "exists", false end
        return self:set(key, val)
    end,
    get_keys = function(self, count)
      local keys = {}
      for key, _ in pairs(self._vals) do
          table.insert(keys, key)
      end
      return keys
    end
}}

local _ngx = {
    _logs = {},
    req = {},
    reqbody = "",
    var = {},
    printed = nil,
    shared = {},
    config = {
      subsystem = "stream",
      ngx_lua_version = 10020
    },
}

_ngx.WARN = 1
_ngx.ERR = 2

_ngx.OK = 0
_ngx.HTTP_OK = 200
_ngx.HTTP_NOT_FOUND = 404
_ngx.BAD_REQUEST = 400
_ngx.HTTP_CREATED = 201

function _ngx.reset()
    _ngx._logs = {}
    _ngx.reqbody = ""
    _ngx.shared.round_robin_state = setmetatable({_vals = {}}, _shared_dict)
    _ngx.shared.balancer_ewma_last_touched_at = setmetatable({_vals = {}}, _shared_dict)
    _ngx.shared.balancer_ewma = setmetatable({_vals = {}}, _shared_dict)
    _ngx.shared.configuration_data = setmetatable({
        _vals = {
          backends = "backenddata"
        }
      },
      _shared_dict)
    _ngx.var.request_method = "GET"
    _ngx.var.proxy_upstream_name = "fake_upstream"
    _ngx.printed = nil
    _ngx.status = ngx.OK
    _ngx.req.body = "reqbody"
end

function _ngx.log(a, ...)
    table.insert(_ngx._logs, {...})
end

function _ngx.req.get_body_data()
  return _ngx.req.body
end

function _ngx.req.read_body()
end

function _ngx.print(str)
    _ngx.printed = str
end

function _ngx.get_phase()
  return _ngx._phase
end

return _ngx
