local cipher = require("cipher")
local util = require("util")
local string = require("resty.string")
local sha1_crypto = require("resty.sha1")
local md5_crypto = require("resty.md5")

local sticky_sessions = ngx.shared.sticky_sessions

local DEFAULT_SESSION_COOKIE_NAME = "route"
-- Currently STICKY_TIMEOUT never expires
local STICKY_TIMEOUT = 0

local _M = {}

local sha1 = sha1_crypto:new()
if not sha1 then
  ngx.say("failed to create the sha1 object")
  return
end

local md5 = md5_crypto:new()
if not md5 then
  ngx.say("failed to create the md5 object")
  return
end

local function md5_digest(raw, eof)
  md5:update(raw)
  if eof then
    return md5:final()
  end
  return nil
end

local function sha1_digest(raw, eof)
  sha1:update(raw)
  if eof then
      return sha1:final()
  end
  return nil
end

local function get_cookie_name(backend)
  local name = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["name"]
  if name == nil then
    ngx.log(ngx.WARN, "nginx.ingress.kubernetes.io/session-cookie-name not defined, defaulting to \"route\"")
    name = DEFAULT_SESSION_COOKIE_NAME
  end
  return name
end

local function is_valid_upstream(backend, address, port)
  for _, ep in ipairs(backend.endpoints) do
    if ep.address == address and ep.port == port then
      return true
    end
  end
  ngx.log(ngx.INFO, "session upstream no longer valid, resetting")
  return false
end

function _M.is_sticky(backend)
  if backend["sessionAffinityConfig"]["name"] == "cookie" then
    return true
  end
  return false
end

function _M.get_upstream(backend)
  local cookie_name = get_cookie_name(backend)
  local cookie_key = "cookie_" .. cookie_name
  local upstream_key = ngx.var[cookie_key]
  if upstream_key == nil then
    ngx.log(ngx.INFO, "cookie \"" .. cookie_name .. "\" does not exists")
    return nil
  end

  local upstream_string = sticky_sessions:get(upstream_key)
  if upstream_string == nil then
    ngx.log(ngx.INFO, "sticky_sessions:get returned nil")
    return nil
  end

  local upstream = util.parse_addr(upstream_string)
  local valid = is_valid_upstream(backend, upstream["host"], upstream["port"])
  if not valid then
    return nil
  end
  return upstream
end

function _M.set_upstream(endpoint, backend)
  local cookie_name = get_cookie_name(backend)
  local upstream = endpoint.address .. ":" .. endpoint.port
  local encrypted
  local hash = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["hash"]

  if hash == "sha1" then
    encrypted = string.to_hex(sha1_digest(upstream, true))
  else
    if hash ~= "md5" then
      ngx.log(ngx.WARN, "nginx.ingress.kubernetes.io/session-cookie-hash not defined, defaulting to md5")
    end
    encrypted = string.to_hex(md5_digest(upstream, true))
  end

  ngx.header["Set-Cookie"] = cookie_name .. "=" .. encrypted .. ";"

  local success, err, forcible
  success, err, forcible = sticky_sessions:set(encrypted, upstream, STICKY_TIMEOUT)
  if not success then
    ngx.log(ngx.WARN, "sticky_sessions:set failed " .. err)
  end
  if forcible then
    ngx.log(ngx.WARN, "sticky_sessions:set valid items forcibly overwritten")
  end
end

return _M
