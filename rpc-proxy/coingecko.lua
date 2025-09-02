local chain_base = require "proxy_scripts.chain_base"

local api_key = os.getenv("COINGECKO_API_KEY")
if not api_key or api_key == "" then
    ngx.log(ngx.ERR, "COINGECKO_API_KEY not found in environment variables")
end

local config = {
    endpoint = "coingecko",
    
    backends = {
        {
            target = "https://pro-api.coingecko.com",
            host = "pro-api.coingecko.com"
        }
    },
    
    health_check_config = {
        method = "GET",
        path = "/api/v3/ping",
        headers = {
            ["x-cg-pro-api-key"] = api_key
        },
        ssl_verify = false,
        timeout = 10000,
        valid_statuses = { [200] = true }
    },
    
    request_config = {
        max_retries = 2,
        timeout = 30000,
        keepalive_timeout = 60000,
        keepalive_pool = 10,
        headers = {
            ["x-cg-pro-api-key"] = api_key
        },
        ssl_verify = false
    }
}

return chain_base.create_chain_handler(config, {
    enable_cache = true
})
