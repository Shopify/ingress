local string_format = string.format
local new_tab = require "table.new"
local ngx_log = ngx.log
local INFO = ngx.INFO
local ERR = ngx.ERR

local _M = {}
local MAX_NUMBER_OF_PLUGINS = 10000
-- TODO: is this good for a dictionary?
local plugins = new_tab(MAX_NUMBER_OF_PLUGINS, 0)

local function load_plugin(name)
  local path = string_format("plugins.%s.main", name)

  local plugin = require(path)

  plugins[name] = plugin
end

function _M.init(names)
  for _, name in ipairs(names) do
    load_plugin(name)
  end
end

function _M.run()
  local phase = ngx.get_phase()

  for name, plugin in pairs(plugins) do
    if plugin[phase] then
      ngx_log(INFO, string_format("Running plugin \"%s\" in phase \"%s\"", name, phase))

      -- TODO: consider sandboxing this, should we?
      -- probably yes, at least prohibit plugin from accessing env vars etc
      local ok, err = pcall(plugin[phase])
      if not ok then
        ngx_log(ERR, string_format("Error while running plugin \"%s\" in phase \"%s\": %s", name, phase, err))
      end
    end
  end
end

return _M
