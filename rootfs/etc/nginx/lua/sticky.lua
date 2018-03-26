local crypto = require("crypto")
local util = require("util")

local sticky_hosts = ngx.shared.sticky_hosts

local DEFAULT_HASH = "md5"
local DEFAULT_STICKY_COOKIE = "route"
-- Currently STICKY_TIMEOUT never expires
local STICKY_TIMEOUT = 0

local _M = {}

local function get_sticky_cookie_name(backend)
  local route = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["name"]
  if route == nil then 
    ngx.log(ngx.WARN, "nginx.ingress.kubernetes.io/session-cookie-name not defined, defaulting to \"route\"")
    route = DEFAULT_STICKY_COOKIE
  end
  return route
end

local function get_sticky_cookie_hash(backend)
  local hash = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["hash"]
  if hash == nil or hash ~= "sha1" then 
    ngx.log(ngx.WARN, "nginx.ingress.kubernetes.io/session-cookie-hash defined incorrectly, defaulting to \"md5\"")
    hash = DEFAULT_HASH
  end
  return hash
end

local function is_valid_upstream(backend, address, port)
  for i, ep in ipairs(backend.endpoints) do
    if ep.address == address and ep.port == port then
      return true
    end
  end
  return false
end

function _M.is_sticky(backend)
  if backend["sessionAffinityConfig"]["name"] == "cookie" then
    return true
  end
  return false
end

function _M.get_sticky_upstream(backend)
  local cookie_name = get_sticky_cookie_name(backend)
  local cookie_key = "cookie_" .. cookie_name
  local upstream_key = ngx.var[cookie_key]
  if upstream_key == nil then
    ngx.log(ngx.INFO, "Cookie \"" .. cookie_name .. "\" does not exists")
    return nil
  end

  local upstream_string = sticky_hosts:get(upstream_key)
  if upstream_string == nil then
    ngx.log(ngx.INFO, "sticky_hosts:get returned nil")
    return nil
  end
  
  local upstream = util.split_upstream_var(upstream_string)
  local valid = is_valid_upstream(backend, upstream[1], upstream[2])
  if not valid then
    return nil
  end
  return upstream
end

function _M.set_sticky_upstream(endpoint, backend)
  local cookie_name = get_sticky_cookie_name(backend)
  local hash = get_sticky_cookie_hash(backend)
  local upstream = endpoint.address .. ":" .. endpoint.port
  local encrypted
  if hash == "sha1" then
    encrypted = crypto.to_hex(crypto.sha1_hash(upstream))
  else
    encrypted = crypto.to_hex(crypto.md5_hash(upstream))
  end

  ngx.header["Set-Cookie"] = cookie_name .. "=" .. encrypted .. ";"

  local upstream = endpoint.address .. ":" .. endpoint.port
  success, err, forcible = sticky_hosts:set(encrypted, upstream, STICKY_TIMEOUT)
  if not success then
    ngx.log(ngx.WARN, "sticky_hosts:set failed " .. err)
  end
  if forcible then
    ngx.log(ngx.WARN, "sticky_hosts:set valid items forcibly overwritten")
  end
end

return _M