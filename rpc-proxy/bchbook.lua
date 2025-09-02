local chain_base = require "proxy_scripts.chain_base"

local api_key = os.getenv("NOWNODES_API_KEY")
if not api_key or api_key == "" then
    ngx.log(ngx.ERR, "NOWNODES_API_KEY not found in environment variables")
end

local config = {
    endpoint = "bchbook",

    backends = {
        {
            target = "https://bch.nownodes.io",
            host = "bch.nownodes.io"
        }
    },

    health_check_config = {
        method = "GET",
        path = "/api/v2/status",
        headers = {
            ["api-key"] = api_key
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
            ["api-key"] = api_key
        },
        ssl_verify = false
    }
}

return chain_base.create_chain_handler(config, {
    enable_cache = true
})
