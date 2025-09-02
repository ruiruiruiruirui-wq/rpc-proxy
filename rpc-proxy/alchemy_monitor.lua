local chain_base = require "proxy_scripts.chain_base"

local api_key = os.getenv("ALCHEMY_API_KEY")
if not api_key or api_key == "" then
    ngx.log(ngx.ERR, "ALCHEMY_API_KEY not found in environment variables")
end

local config = {
    endpoint = "alchemy",
    
    backends = {
        {
            target = "https://eth-mainnet.g.alchemy.com/v2/" .. api_key,
            host = "eth-mainnet.g.alchemy.com"
        }
    },
    
    health_check_config = {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json"
        },
        request_body = {
            jsonrpc = "2.0",
            id = 1,
            method = "eth_blockNumber",
            params = {}
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
            ["Content-Type"] = "application/json"
        },
        ssl_verify = false
    }
}

return chain_base.create_chain_handler(config, {
    enable_cache = true
})
