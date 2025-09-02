local chain_base = require "proxy_scripts.chain_base"

local api_key = os.getenv("NOWNODES_API_KEY")
if not api_key or api_key == "" then
    ngx.log(ngx.ERR, "NOWNODES_API_KEY not found in environment variables")
end

local config = {
    endpoint = "fil",
    
    backends = {
        {
            target = "https://fil.nownodes.io",
            host = "fil.nownodes.io"
        }
    },
    
    health_check_config = {
        method = "POST",
        path = "/rpc/v0",
        headers = {
            ["api-key"] = api_key,
            ["Content-Type"] = "application/json"
        },
        request_body = {
            jsonrpc = "2.0",
            method = "Filecoin.ChainHead",
            params = {},
            id = 1
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
            ["api-key"] = api_key,
            ["Content-Type"] = "application/json"
        },
        ssl_verify = false
    }
}

return chain_base.create_chain_handler(config, {
    enable_cache = true
})
