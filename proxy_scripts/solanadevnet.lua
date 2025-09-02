local chain_base = require "proxy_scripts.chain_base"

-- Solana Devnet specific configuration
local config = {
    endpoint = "tsol",
    
    -- Backend configuration
    backends = {
        {
            target = "https://quick-sparkling-mound.solana-devnet.quiknode.pro/" .. (os.getenv("SOLANA_DEVNET_QUICKNODE_KEY") or "") .. "/",
            host = "quick-sparkling-mound.solana-devnet.quiknode.pro"
        }
    },
    
    -- Health check configuration
    health_check_config = {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
        },
        ssl_verify = false,
        timeout = 10000,  -- 10 seconds for health check
        -- Solana-specific health check request body
        request_body = {
            jsonrpc = "2.0",
            id = 1,
            method = "getBlockHeight",  -- Solana-specific method
            params = {}
        },
        -- Valid response status codes
        valid_statuses = { [200] = true }
    },
    
    -- Request handling configuration
    request_config = {
        max_retries = 2,
        timeout = 30000,  -- 30 seconds for regular requests
        keepalive_timeout = 60000,
        keepalive_pool = 10,
        headers = {
            ["Content-Type"] = "application/json"
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
