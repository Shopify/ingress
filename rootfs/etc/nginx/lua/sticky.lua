local json = require('cjson')
local string = require("resty.string")
local sha1_crypto = require("resty.sha1")
local md5_crypto = require("resty.md5")

local sticky_sessions = ngx.shared.sticky_sessions

local DEFAULT_SESSION_COOKIE_NAME = "route"
local DEFAULT_SESSION_COOKIE_HASH = "md5"
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

local function md5_digest(raw)
  md5:update(raw)
  return string.to_hex(md5:final())
end

local function sha1_digest(raw)
  sha1:update(raw)
  return string.to_hex(sha1:final())
end

local function get_cookie_name(backend)
  local name = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["name"]
  return name or DEFAULT_SESSION_COOKIE_NAME
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
  return backend["sessionAffinityConfig"]["name"] == "cookie"
end

function _M.get_upstream(backend)
  local cookie_name = get_cookie_name(backend)
  local cookie_key = "cookie_" .. cookie_name
  local upstream_key = ngx.var[cookie_key]
  if upstream_key == nil then
    ngx.log(ngx.INFO, "backend=".. backend.name .. ": cookie \"" .. cookie_name .. "\" is not set for this request")
    return nil
  end

  local upstream_string = sticky_sessions:get(upstream_key)
  if upstream_string == nil then
    ngx.log(ngx.INFO, "sticky_sessions:get returned nil")
    return nil
  end

  local upstream = json.decode(upstream_string)
  local valid = is_valid_upstream(backend, upstream.address, upstream.port)
  if not valid then
    sticky_sessions:delete(upstream_key)
    return nil
  end
  return upstream
end

function _M.set_upstream(endpoint, backend)
  local cookie_name = get_cookie_name(backend)
  local encrypted
  local upstream_string = json.encode(endpoint)
  local hash = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["hash"]

  if hash == "sha1" then
    encrypted = sha1_digest(upstream_string)
  else
    if hash ~= DEFAULT_SESSION_COOKIE_HASH then
      ngx.log(
        ngx.WARN,
        "nginx.ingress.kubernetes.io/session-cookie-hash not defined, defaulting to" .. DEFAULT_SESSION_COOKIE_HASH
      )
    end
    encrypted = md5_digest(upstream_string)
  end

  ngx.header["Set-Cookie"] = cookie_name .. "=" .. encrypted .. ";"

  local success, err, forcible
  success, err, forcible = sticky_sessions:set(encrypted, upstream_string, STICKY_TIMEOUT)
  if not success then
    ngx.log(ngx.WARN, "sticky_sessions:set failed " .. err)
  end
  if forcible then
    ngx.log(ngx.WARN, "sticky_sessions:set valid items forcibly overwritten")
  end
end

return _M
