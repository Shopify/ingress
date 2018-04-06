local _M = {}

local _lock = { __index = {
  lock = function()
  end,
  unlock = function()
  end,
}}

function _M.new()
  return setmetatable({_vals = {}}, _lock)
end

return _M
