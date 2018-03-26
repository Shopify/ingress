-- local resty_sha1 = require("resty.sha1")
-- local resty_md5 = require("resty.md5")
-- local str = require("resty.string")

local _M = {}

-- local sha1 = resty_sha1:new()
-- if not sha1 then
--     ngx.say("failed to create the sha1 object")
--     return
-- end

-- local md5 = resty_md5:new()
-- if not md5 then
--     ngx.say("failed to create md5 object")
--     return
-- end

function _M.md5_hash(raw)
  -- local ok = md5:update(raw)
  -- if not ok then
  --     ngx.log(ngx.WARN, "md5 hash failed")
  --     return nil
  -- end
  -- return md5:final()
  return raw
end

function _M.sha1_hash(raw)
  -- local ok = sha1:update(raw)
  -- if not ok then
  --     ngx.log(ngx.WARN, "sha1 hash failed")
  --     return nil
  -- end
  -- return sha1:final()
  return raw
end

function _M.to_hex(digest)
  -- return str.to_hex(digest)
  return digest
end

return _M