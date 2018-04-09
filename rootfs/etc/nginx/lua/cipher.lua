local sha1_crypto = require("vendor.crypto.sha1")
local md5_crypto = require("vendor.crypto.md5")

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
  sha1:update(raw)
  if eof then
      return sha1:final()
  end
  return nil
end

return _M
