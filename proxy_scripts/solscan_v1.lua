local chain_base = require "proxy_scripts.chain_base"

local token = os.getenv("SOLSCAN_API_KEY") or ""

-- Solscan V1 specific configuration
local config = {
    endpoint = "solscan",
    
    -- Backend configuration
    backends = {
        {
            target = "https://pro-api.solscan.io",
            host = "pro-api.solscan.io"
        }
    },
    
    -- Health check configuration
    health_check_config = {
        method = "GET",
        headers = {
            ["Content-Type"] = "application/json",
            ["Host"] = "pro-api.solscan.io",
            ["Token"] = token
        },
        ssl_verify = false,
        timeout = 10000,  -- 10 seconds for health check
        -- Solscan-specific health check URL
        health_check_url = "/v2.0/token/meta?address=JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN",
        -- Valid response status codes
        valid_statuses = { [200] = true },
    },
    
    -- Request handling configuration
    request_config = {
        max_retries = 2,
        timeout = 30000,  -- 30 seconds for regular requests
        keepalive_timeout = 60000,
        keepalive_pool = 10,
        headers = {
            ["Content-Type"] = "application/json",
            ["Token"] = token
        },
        ssl_verify = false
    },
    
    -- Health check thresholds
    fail_threshold = 3,
    success_threshold = 2
}

-- Create chain handler using the simplified base with caching enabled
local _M = chain_base.create_chain_handler(config, {
    enable_cache = true
})

return _M
