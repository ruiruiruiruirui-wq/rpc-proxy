local chain_base = require "proxy_scripts.chain_base"

local config = {
    endpoint = "tbtc4",
    
    -- Backend configuration
    backends = {
        {
            target = "https://mempool.space/testnet4",
            host = "mempool.space"
        }
    },
    
    -- Health check configuration
    health_check_config = {
        method = "GET",
        headers = {
            ["Content-Type"] = "application/json"
        },
        ssl_verify = false,
        timeout = 10000,
        health_check_url = "/api/blocks/tip/height",
        valid_statuses = { [200] = true },
    },
    
    -- Request handling configuration
    request_config = {
        max_retries = 2,
        timeout = 30000,
        keepalive_timeout = 60000,
        keepalive_pool = 10,
        headers = {
            ["Content-Type"] = "application/json"
        },
        ssl_verify = false
    },
    
    fail_threshold = 3,
    success_threshold = 2
}

local _M = chain_base.create_chain_handler(config, {
    enable_cache = true
})

return _M
