local split = require('util.split')
local ngx_upstream = require("ngx.upstream")

local _M = {}
_M.static_backends = {}

local DEFAULT_LB_ALG = "ewma"

local function marshal_endpoint(endpoint)
    if (not endpoint.address) or (not endpoint.port) then
        if endpoint.addr then
            local addr, err = split.parse_addr(endpoint.addr)
            if err then
                return nil, err
            end

            endpoint.address = addr.host
            endpoint.port = addr.port
            endpoint.addr = nil

            return endpoint, nil
        end
    end
    return nil, "error in grabbing address & port" 
end

local function create_static_backend(upstream_name)
    local sb = {}
    sb.name = upstream_name

    sb.endpoints = ngx_upstream.get_servers(upstream_name)

    for index, endpoint in ipairs(sb.endpoints) do
        sb.endpoints[index] = marshal_endpoint(endpoint)
    end

    sb['load-balance'] = DEFAULT_LB_ALG

    return sb
end

-- If any static upstream matches this pattern, add to _M.static_backends
function _M.configure(pattern)
    local upstreams = ngx_upstream.get_upstreams()
    for _, upstream_name in ipairs(upstreams) do
        if string.match(upstream_name, pattern) then
            if upstream_name ~= "upstream_balancer" then
                local sb = create_static_backend(upstream_name)
                _M.static_backends[upstream_name] = sb
            end
        end
    end
end

function _M.sync()
end

return _M
