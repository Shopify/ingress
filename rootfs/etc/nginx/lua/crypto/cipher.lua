local sha1_crypto = require("crypto.sha1")
local md5_crypto = require("crypto.md5")
local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C

local sha1 = sha1_crypto:new()
local md5 = md5_crypto:new()

local _M = {}

function _M.md5_digest(raw, eof)
  md5:update(raw)
  
  if eof then
    return md5:final()
  end
  return nil
end

function _M.sha1_digest(raw, eof)
  local ok = sha1:update(raw)
  if eof then
      return sha1:final()
  end
  return nil
end

-- Copyright (C) by Yichun Zhang (agentzh)

ffi.cdef[[
typedef unsigned char u_char;
u_char * ngx_hex_dump(u_char *dst, const u_char *src, size_t len);
]]

function _M.to_hex(s)
  local str_type = ffi.typeof("uint8_t[?]")
  local len = #s * 2
  local buf = ffi_new(str_type, len)
  C.ngx_hex_dump(buf, s, #s)
  return ffi_str(buf, len)
end

return _M
