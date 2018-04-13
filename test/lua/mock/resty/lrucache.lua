local _M = {}

local _cache = { __index = {
  get = function(self, key)
      if key == nil then error("nil key") end
      return self._vals[key]
  end,
  set = function(self, key, val, expires)
      if key == nil then error("nil key") end
      self._vals[key] = val
      return true, nil, false
  end,
}}

function _M.new()
  return setmetatable({_vals =
  { round_robin_upstream = {
      ["load-balance"] = "round_robin",
      name = "round_robin_upstream",
      endpoints = {
        {address = "000.000.000", port = "8080"},
        {address = "000.000.001", port = "8081"},
      }
    },
    ewma_upstream = {
      ["load-balance"] = "ewma",
      name = "ewma_upstream",
      endpoints = {
        {address = "000.000.000", port = "8080"},
        {address = "000.000.001", port = "8081"},
      }
    }
  }}, _cache)
end

return _M
