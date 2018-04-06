local _M = {}

local _cache = { __index = {
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

function _M.new()
  return setmetatable({_vals = {
    fake_upstream = {
      name = "fake_upstream",
      endpoints = {
        {address = "000.000.000", port = "8080"},
        {address = "000.000.001", port = "8081"},
      }
    }
  }}, _cache)
end

return _M
