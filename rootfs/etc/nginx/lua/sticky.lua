local json = require('cjson')
local str = require("resty.string")
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
  return str.to_hex(md5:final())
end

local function sha1_digest(raw)
  sha1:update(raw)
  return str.to_hex(sha1:final())
end

local function get_cookie_name(backend)
  local name = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["name"]
  return name or DEFAULT_SESSION_COOKIE_NAME
end

local function is_valid_(backend, address, port)
  for _, ep in ipairs(backend.endpoints) do
    if ep.address == address and ep.port == port then
      return true
    end
  end
  return false
end

function _M.is_sticky(backend)
  return backend["sessionAffinityConfig"]["name"] == "cookie"
end

function _M.get_endpoint(backend)
  local cookie_name = get_cookie_name(backend)
  local cookie_key = "cookie_" .. cookie_name
  local endpoint_key = ngx.var[cookie_key]
  if endpoint_key == nil then
    ngx.log(ngx.INFO, string.format(
      "[backend=%s, affinity=cookie] cookie \"%s\" is not set for this request",
      backend.name,
      cookie_name
    ))
    return nil
  end

  local endpoint_string = sticky_sessions:get(endpoint_key)
  if endpoint_string == nil then
    ngx.log(ngx.INFO, string.format("[backend=%s, affinity=cookie] no endpoint assigned", backend.name))
    return nil
  end

  local endpoint = json.decode(endpoint_string)
  local valid = is_valid_endpoint(backend, endpoint.address, endpoint.port)
  if not valid then
    ngx.log(ngx.INFO, string.format("[backend=%s, affinity=cookie] assigned endpoint is no longer valid", backend.name))
    sticky_sessions:delete(endpoint_key)
    return nil
  end
  return endpoint
end

function _M.set_endpoint(endpoint, backend)
  local cookie_name = get_cookie_name(backend)
  local encrypted
  local endpoint_string = json.encode(endpoint)
  local hash = backend["sessionAffinityConfig"]["cookieSessionAffinity"]["hash"]

  if hash == "sha1" then
    encrypted = sha1_digest(endpoint_string)
  else
    if hash ~= DEFAULT_SESSION_COOKIE_HASH then
      ngx.log(ngx.WARN, string.format(
        "[backend=%s, affinity=cookie] session-cookie-hash \"%s\" is not valid, defaulting to %s",
        backend.name,
        hash,
        DEFAULT_SESSION_COOKIE_HASH
      ))
    end
    encrypted = md5_digest(endpoint_string)
  end

  ngx.header["Set-Cookie"] = cookie_name .. "=" .. encrypted .. ";"

  ngx.log(ngx.INFO, string.format("[backend=%s, affinity=cookie] assigning a new endpoint", backend.name))
  local success, err, forcible
  success, err, forcible = sticky_sessions:set(encrypted, endpoint_string, STICKY_TIMEOUT)
  if not success then
    ngx.log(ngx.WARN, string.format("[backend=%s, affinity=cookie] failed to assign endpoint: %s", backend.name, err))
  end
  if forcible then
    ngx.log(ngx.WARN, string.format(
      "[backend=%s, affinity=cookie] sticky_sessions shared dict is full; endpoint forcibly overwritten",
      backend.name
    ))
  end
end

return _M
