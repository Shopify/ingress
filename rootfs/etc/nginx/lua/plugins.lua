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
  local path = string_format("plugins.%s.handler", name)
  ngx_log(ngx.WARN, "xiyar: ", path)

  local plugin = require(path)
  -- TODO: check for nil here
  ngx_log(ngx.WARN, "xiyar: ", tostring(plugin))

  plugins[name] = plugin
end

function run_plugin(name)
  local plugin = plugins[name]

  ngx_log(INFO, string_format("Running plugin \"%s\"", name))
  -- TODO: consider sandboxing this, should we?
  local ok, err = pcall(plugin.call)
  if not ok then
    ngx_log(ERR, string_format("Error while running plugin \"%s\": %s", name, err))
  end
end

function _M.init(names)
  for _, name in ipairs(names) do
    load_plugin(name)
  end
end

function _M.run(names)
  for _, name in ipairs(names) do
    run_plugin(name)
  end
end

return _M
