local chain_base = require "proxy_scripts.chain_base"


local api_key = os.getenv("PANORA_API_KEY") or ""
if not api_key or api_key == "" then
    ngx.log(ngx.ERR, "PANORA_API_KEY not found in environment variables")
end

local config = {
    endpoint = "panora",
    
    -- Backend configuration
    backends = {
        {
            target = "https://api.panora.exchange",
            host = "api.panora.exchange"
        }
    },
    
    -- Health check configuration
    health_check_config = {
        method = "GET",
        headers = {
            ["x-api-key"] = api_key
        },
        ssl_verify = false,
        timeout = 10000,
        path = "/swap/quote?fromTokenAddress=0x1%3A%3Aaptos_coin%3A%3AAptosCoin&toTokenAddress=0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b&fromTokenAmount=0.1&integratorFeeAddress=0x2ec591139f84f8fad665777cdd1821bc8954f12ebecc5121d83d82d072647e4d&integratorFeePercentage=0.3&slippagePercentage=0",
        valid_statuses = { [200] = true }
    },
    
    -- Request handling configuration
    request_config = {
        max_retries = 2,
        timeout = 30000,
        keepalive_timeout = 60000,
        keepalive_pool = 10,
        headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = api_key
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
