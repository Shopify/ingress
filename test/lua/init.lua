local ffi = require('ffi')
local os = ffi.os:lower()
if os == "osx" then
  nginx_lua_modules_lib = "/usr/local/lib/lua/lib"
else
  nginx_lua_modules_lib = "/usr/lib/nginx/lua/lib"
end

local cwd = io.popen("pwd"):read('*l')
package.path = cwd .. "/rootfs/etc/nginx/lua/?.lua;" ..
  cwd .. "/rootfs/etc/nginx/lua/?/?.lua;" ..
  cwd ..  "/test/lua/mock/?.lua;" ..
  "./lua/?.lua;./test/lua/?.lua;./test/lua/lib/?.lua;"..
  nginx_lua_modules_lib .."/?.lua;" .. package.path

package.cpath = "/usr/lib/lua/5.2/?.so;" .. "./test/lua/lib/_" .. os .."/?.so;" .. package.cpath


lunity = require("lunity")
ngx = require("ngx_mock")
ngx.reset()
