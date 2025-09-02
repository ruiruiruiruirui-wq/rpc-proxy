local http = require "resty.http"
local cjson = require "cjson"
local alerts = require "rpc-proxy.slack"

local _M = {}

-- 简化的共享内存管理
local shared_dict = ngx.shared.backends_health

-- 简化的缓存（单层）
local handler_cache = {}
local cache_ttl = 1800  -- 30分钟

-- 获取缓存的handler
local function get_cached_handler(endpoint)
    local entry = handler_cache[endpoint]
    if entry and os.time() - entry.created_at <= cache_ttl then
        return entry.handler
    end
    if entry then
        handler_cache[endpoint] = nil  -- 清理过期缓存
    end
    return nil
end

-- 添加handler到缓存
local function add_to_cache(endpoint, handler)
    handler_cache[endpoint] = {
        handler = handler,
        created_at = os.time()
    }
end

-- 简化的chain handler创建函数
function _M.create_chain_handler(config, options)
    local endpoint = config.endpoint
    local options = options or {}
    
    -- 检查缓存
    local cached_handler = get_cached_handler(endpoint)
    if cached_handler then
        return cached_handler
    end
    
    ngx.log(ngx.INFO, "Creating new handler for endpoint '", endpoint, "'")
    
    local backends = config.backends
    local health_check_config = config.health_check_config
    local request_config = config.request_config
    local fail_threshold = config.fail_threshold or 3
    local success_threshold = config.success_threshold or 2
    
    local round_robin_key = endpoint .. ":round_robin_index"
    
    -- 预计算headers（性能优化）
    local backend_headers = {}
    for _, backend in ipairs(backends) do
        local headers = {}
        for k, v in pairs(request_config.headers) do
            headers[k] = v
        end
        headers["Host"] = backend.host
        backend_headers[backend.host] = headers
    end
    
    local chain_handler = {}
    
    function chain_handler.check_health()
        local httpc = http.new()
        httpc:set_timeout(health_check_config.timeout)

        for _, backend in ipairs(backends) do
            local success, err = pcall(function()
                local health_check_url = backend.target
                if health_check_config.health_check_url then
                    health_check_url = health_check_url .. health_check_config.health_check_url
                end

                local request_options = {
                    method = health_check_config.method,
                    headers = health_check_config.headers,
                    ssl_verify = health_check_config.ssl_verify
                }

                if health_check_config.request_body then
                    request_options.body = cjson.encode(health_check_config.request_body)
                end

                local res, request_err = httpc:request_uri(health_check_url, request_options)

                local key = endpoint .. ":" .. backend.host
                local fail_key = key .. ":fail_count"
                local success_key = key .. ":success_count"
                local is_healthy = shared_dict:get(key)

                if res and health_check_config.valid_statuses[res.status] then
                    shared_dict:set(fail_key, 0)
                    local sc = (shared_dict:get(success_key) or 0) + 1
                    shared_dict:set(success_key, sc)
                    
                    if (not is_healthy or is_healthy == false) and sc >= success_threshold then
                        shared_dict:set(key, true)
                        ngx.log(ngx.INFO, endpoint, " backend ", backend.host, " recovered")
                    end
                    
                    if sc >= success_threshold then
                        shared_dict:set(key, true)
                    end
                else
                    local status_info = res and (res.status .. " - " .. (res.body or "No body")) or request_err
                    shared_dict:set(success_key, 0)
                    local fc = (shared_dict:get(fail_key) or 0) + 1
                    shared_dict:set(fail_key, fc)
                    if is_healthy and fc >= fail_threshold then
                        shared_dict:set(key, false)
                        ngx.log(ngx.WARN, endpoint, " backend ", backend.host, " unhealthy after ", fc, " failures")
                    end
                    alerts.send_slack_alert(endpoint, backend, status_info)
                end
            end)

            if not success then
                ngx.log(ngx.ERR, endpoint, " health check error for ", backend.host, ": ", err)
                local key = endpoint .. ":" .. backend.host
                local fail_key = key .. ":fail_count"
                local success_key = key .. ":success_count"
                shared_dict:set(success_key, 0)
                local fc = (shared_dict:get(fail_key) or 0) + 1
                shared_dict:set(fail_key, fc)
                local is_healthy = shared_dict:get(key)
                if is_healthy and fc >= fail_threshold then
                    shared_dict:set(key, false)
                    ngx.log(ngx.WARN, endpoint, " backend ", backend.host, " unhealthy after ", fc, " exceptions")
                end
                alerts.send_slack_alert(endpoint, backend, tostring(err))
            end
        end
    end

    function chain_handler.get_backend()
        local healthy_backends = {}
        local healthy_count = 0
        
        for i, backend in ipairs(backends) do
            local key = endpoint .. ":" .. backend.host
            local is_healthy = shared_dict:get(key)
            
            if is_healthy then
                healthy_count = healthy_count + 1
                healthy_backends[healthy_count] = {index = i, backend = backend}
            end
        end
        
        if healthy_count > 0 then
            local current_index = shared_dict:incr(round_robin_key, 1)
            if not current_index then
                shared_dict:set(round_robin_key, 0)
                current_index = shared_dict:incr(round_robin_key, 1)
            end
            
            local selected_index = (current_index % healthy_count) + 1
            local selected = healthy_backends[selected_index]
            
            return selected.backend
        end
        
        local backend = backends[1]
        if backend then
            local key = endpoint .. ":" .. backend.host
            local is_healthy = shared_dict:get(key)
            ngx.log(ngx.WARN, "No healthy ", endpoint, " backend, using: ", backend.host)
            return backend
        else
            ngx.log(ngx.ERR, endpoint, " no backend available")
            return nil
        end
    end

    function chain_handler.handle_request()
        local max_retries = request_config.max_retries
        
        for retry_count = 0, max_retries do
            local backend = chain_handler.get_backend()
            if not backend then
                ngx.log(ngx.ERR, "No ", endpoint, " backend available")
                ngx.status = 500
                ngx.say('{"error": "no backend available"}')
                return
            end
            
            local uri = ngx.var.uri
            local args = ngx.var.args
            
            local path = string.gsub(uri, "^/" .. endpoint:gsub("%-", "%%-") .. "/?", "")
            if path ~= "" and not string.match(path, "^/") then
                path = "/" .. path
            end
            
            local upstream_url = backend.target
            if string.match(upstream_url, "/$") then
                upstream_url = string.gsub(upstream_url, "/$", "")
            end
            upstream_url = upstream_url .. path
            
            if args and args ~= "" then
                upstream_url = upstream_url .. "?" .. args
            end
            
            local httpc = http.new()
            httpc:set_timeout(request_config.timeout)
            
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            
            -- 动态获取headers，支持运行时修改
            local headers = backend_headers[backend.host]
            
            local res, err = httpc:request_uri(upstream_url, {
                method = ngx.var.request_method,
                body = body,
                headers = headers,
                ssl_verify = request_config.ssl_verify,
                keepalive_timeout = request_config.keepalive_timeout,
                keepalive_pool = request_config.keepalive_pool
            })
            
            if not res then
                ngx.log(ngx.ERR, "Failed to request ", endpoint, " backend: ", backend.host, " error: ", err)
                
                if retry_count >= max_retries then
                    ngx.status = 502
                    ngx.say('{"error": "upstream request failed after retries", "details": "' .. (err or "unknown error") .. '"}')
                    return
                end
                
                ngx.log(ngx.WARN, "Retrying ", endpoint, " (attempt: ", retry_count + 1, "/", max_retries, ")")
            else
                if res.status >= 500 and retry_count < max_retries then
                    ngx.log(ngx.WARN, "Received 5xx from ", backend.host, " status: ", res.status, ", retrying...")
                else
                    ngx.status = res.status
                    
                    if res.headers then
                        for k, v in pairs(res.headers) do
                            if k ~= "connection" and k ~= "transfer-encoding" and k ~= "content-length" then
                                ngx.header[k] = v
                            end
                        end
                    end
                    
                    if res.body then
                        ngx.say(res.body)
                    else
                        ngx.say("")
                    end
                    
                    return
                end
            end
        end
        
        ngx.log(ngx.ERR, endpoint, " handle_request failed after all retries")
        ngx.status = 502
        ngx.say('{"error": "all retry attempts failed"}')
    end

    function chain_handler.init_backends()
        ngx.log(ngx.INFO, "Initializing ", endpoint, " backends")
        for _, backend in ipairs(backends) do
            local key = endpoint .. ":" .. backend.host
            shared_dict:set(key, true)
        end
        
        shared_dict:set(round_robin_key, 0)
    end
    
    -- 添加到缓存
    if options.enable_cache then
        add_to_cache(endpoint, chain_handler)
    end
    
    return chain_handler
end

-- 缓存管理函数
function _M.clear_cache()
    handler_cache = {}
    ngx.log(ngx.INFO, "Handler cache cleared")
end

function _M.get_cache_stats()
    local size = 0
    for _ in pairs(handler_cache) do
        size = size + 1
    end
    return {
        size = size,
        ttl = cache_ttl
    }
end

return _M 