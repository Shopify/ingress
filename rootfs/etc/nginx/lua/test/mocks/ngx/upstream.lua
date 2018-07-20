return {
    get_upstreams = function(...)
        return {
            [1] = "upstream_balancer",
            [2] = "remote_pool1_ssl",
            [3] = "remote_pool2_ssl"
        } 
    end,
    get_servers = function(upstream_name)
        local mock_servers = {
            ["upstream_balancer"] = {
                [1] = {
                    addr = "192.168.0.1:443",
                    weight = 1,
                    fail_timeout = 1,
                    name = "192.168.0.1:443",
                    max_fails = 2
                }
            },
            ["remote_pool1_ssl"] = {
                [1] = {
                    addr = "192.168.1.1:443",
                    weight = 1,
                    fail_timeout = 1,
                    name = "192.168.1.1:443",
                    max_fails = 2
                }
            },
            ["remote_pool2_ssl"] = {
                [1] = {
                    addr = "192.168.2.1:443",
                    weight = 1,
                    fail_timeout = 1,
                    name = "192.168.2.1:443",
                    max_fails = 2
                }
            }
        }

        if not mock_servers[upstream_name] then
            return nil, "no servers for upstream " .. upstream_name
        else
            return mock_servers[upstream_name], nil
        end
    end
}
