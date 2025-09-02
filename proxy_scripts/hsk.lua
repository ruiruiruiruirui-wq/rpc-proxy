local chain_base = require "proxy_scripts.chain_base"

-- HSK specific configuration
local drpc_api_key = os.getenv("DRPC_API_KEY") or ""

local config = {
    endpoint = "hsk",
    
    -- Backend configuration
    backends = {
        {
            target = "https://hashkey.drpc.org/" .. drpc_api_key,
            host = "hashkey.drpc.org"
        }
    },
    
    -- Health check configuration
    health_check_config = {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json"
        },
        ssl_verify = false,
        timeout = 10000,  -- 10 seconds for health check
        request_body = {
            jsonrpc = "2.0",
            id = 1,
            method = "eth_getBalance",  -- Ethereum-specific method
            params = {"0x5618207d27D78F09f61A5D92190d58c453feB4b7", "latest"}
        },
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
