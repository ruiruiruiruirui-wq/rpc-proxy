local http = require "resty.http"
local cjson = require "cjson"
local alerts = require "rpc-proxy.slack"
local dict = ngx.shared.backends_health

local function get_env_or_log_err(var_name)
    local value = os.getenv(var_name)
    if not value or value == "" then
        ngx.log(ngx.ERR, var_name .. " not found in environment variables")
    end
    return value
end

local koios_api_token = get_env_or_log_err("KOIOS_API_TOKEN")
local drpc_api_key = os.getenv("DRPC_API_KEY")

local _M = {}

-- 不支持 eth_blockNumber 的后端配置
local other_backends = {
    koios = {
        { url = "https://api.koios.rest", token = koios_api_token , host = "api.koios.rest" }
    },
    noble1 = {
        { url = "https://lcd-noble.keplr.app", host = "lcd-noble.keplr.app" }
    },
    initVerseMainnet = {
        { url = "https://rpc-mainnet.inichain.com", host = "rpc-mainnet.inichain.com" }
    },
    apt = {
        { url = "https://fluent-cool-glitter.aptos-mainnet.quiknode.pro/" .. (get_env_or_log_err("FLUENT_COOL_GLITTER") or "") .. "/", host = "fluent-cool-glitter.aptos-mainnet.quiknode.pro" }
    },
    trx = {
        { url = "https://lingering-rough-wave.tron-mainnet.quiknode.pro/" .. (get_env_or_log_err("LINGERING_ROUGH_WAVE") or "") .. "/", host = "lingering-rough-wave.tron-mainnet.quiknode.pro" }
    },
    dymension = {
        { url = "https://lb.drpc.org/ogrpc?network=dymension&dkey=" .. (drpc_api_key or ""), host = "lb.drpc.org" }
    }
}

-- 添加轮询计数器到共享内存
local round_robin_dict = ngx.shared.backends_health
local fail_threshold = 3
local success_threshold = 2

-- 不同后端的健康检查方法
local health_check_methods = {
    koios = {
        method = "GET",
        url_suffix = "/api/v1/tip",
        headers = function(backend)
            local headers = {
                ["Host"] = backend.host
            }
            if backend.token then
                headers["Authorization"] = "Bearer " .. backend.token
            end
            return headers
        end,
        validate_response = function(data)
            -- Koios API 返回的是数组格式
            return data and type(data) == "table" and #data > 0
        end
    },

    noble1 = {
        method = "GET",
        url_suffix = "/cosmos/bank/v1beta1/balances/noble1z5asz4edtrnayjjxzxetkvwear0f2dd8amwkhd",
        headers = function(backend)
            return {
                ["Host"] = backend.host
            }
        end,
        validate_response = function(data)
            return data and data.balances ~= nil
        end
    },
    initVerseMainnet = {
        method = "POST",
        body = cjson.encode({
            method = "eth_blockNumber",
            id = 1,
            jsonrpc = "2.0"
        }),
        headers = function(backend)
            return {
                ["Content-Type"] = "application/json",
                ["Host"] = backend.host
            }
        end,
        validate_response = function(data)
            return data and data.result ~= nil
        end
    },
    apt = {
        method = "GET",
        url_suffix = "v1/accounts/0xc6bc659f1649553c1a3fa05d9727433dc03843baac29473c817d06d39e7621ba",
        headers = function(backend)
            return {
                ["Host"] = backend.host,
                ["Content-Type"] = "application/json; charset=utf-8"
            }
        end,
        validate_response = function(data)
            return data and data.sequence_number ~= nil
        end
    },
    trx = {
        method = "POST",
        url_suffix = "jsonrpc",
        body = cjson.encode({
            method = "eth_getBalance",
            params = {"0x41f0cc5a2a84cd0f68ed1667070934542d673acbd8", "latest"},
            id = 1,
            jsonrpc = "2.0"
        }),
        headers = function(backend)
            return {
                ["Content-Type"] = "application/json",
                ["Host"] = backend.host
            }
        end,
        validate_response = function(data)
            return data and data.result ~= nil
        end
    },

    dymension = {
        method = "POST",
        body = cjson.encode({
            method = "eth_getBalance",
            params = {"0x5618207d27D78F09f61A5D92190d58c453feB4b7", "latest"},
            id = 1,
            jsonrpc = "2.0"
        }),
        headers = function(backend)
            return {
                ["Content-Type"] = "application/json",
                ["Host"] = backend.host
            }
        end,
        validate_response = function(data)
            return data and data.result ~= nil
        end
    }
}

function _M.check_backends_health()
    local httpc = http.new()
    local valid_statuses = { [200] = true }
    local fail_threshold = 3
    local success_threshold = 2

    for group, servers in pairs(other_backends) do
        local health_check = health_check_methods[group]
        if not health_check then
            ngx.log(ngx.WARN, "No health check method defined for group: " .. group)
            goto continue
        end

        for _, backend in ipairs(servers) do
            local success, err = pcall(function()
                local target_url = backend.url
                if health_check.url_suffix then
                    target_url = target_url .. health_check.url_suffix
                end

                local request_options = {
                    method = health_check.method,
                    headers = health_check.headers(backend),
                    ssl_verify = false
                }

                if health_check.body then
                    request_options.body = health_check.body
                end

                local res, request_err = httpc:request_uri(target_url, request_options)

                local key = group .. ":" .. backend.host
                local fail_key = key .. ":fail_count"
                local success_key = key .. ":success_count"
                local is_healthy = dict:get(key)

                if res and valid_statuses[res.status] then
                    dict:set(fail_key, 0)
                    local sc = (dict:get(success_key) or 0) + 1
                    dict:set(success_key, sc)
                    if (not is_healthy or is_healthy == false) and sc >= success_threshold then
                        dict:set(key, true)
                        ngx.log(ngx.INFO, group, " backend ", backend.host, " recovered")
                    end
                else
                    dict:set(success_key, 0)
                    local fc = (dict:get(fail_key) or 0) + 1
                    dict:set(fail_key, fc)
                    if is_healthy and fc >= fail_threshold then
                        dict:set(key, false)
                        ngx.log(ngx.WARN, group, " backend ", backend.host, " unhealthy after ", fc, " failures")
                    end
                    local status_info = res and (res.status .. " - " .. (res.body or "No body")) or request_err
                    alerts.send_slack_alert(group, backend, status_info)
                end
            end)

            if not success then
                local key = group .. ":" .. backend.host
                local fail_key = key .. ":fail_count"
                local success_key = key .. ":success_count"
                dict:set(success_key, 0)
                local fc = (dict:get(fail_key) or 0) + 1
                dict:set(fail_key, fc)
                local is_healthy = dict:get(key)
                if is_healthy and fc >= fail_threshold then
                    dict:set(key, false)
                    ngx.log(ngx.WARN, group, " backend ", backend.host, " unhealthy after ", fc, " exceptions")
                end
                alerts.send_slack_alert(group, backend, tostring(err))
            end
        end
        ::continue::
    end
end

function _M.get_backend(group)
    local servers = other_backends[group]
    if not servers then
        return nil
    end

    -- 单节点时，直接返回，不管健康状态
    if #servers == 1 then
        ngx.log(ngx.INFO, "Only one backend for group " .. group .. ", always forwarding to it regardless of health status: " .. servers[1].host)
        return servers[1]
    end
    
    local healthy_backends = {}

    ngx.log(ngx.INFO, "Getting backend for group: " .. group .. ", total servers: " .. #servers)

    -- 遍历该组的所有后端，检查它们的健康状态
    for _, backend in ipairs(servers) do
        local key = group .. ":" .. backend.host
        local is_healthy = dict:get(key)
        ngx.log(ngx.INFO, "Backend " .. backend.host .. " health status: " .. tostring(is_healthy))
        if is_healthy then
            table.insert(healthy_backends, backend)
        end
    end

    ngx.log(ngx.INFO, "Healthy backends count: " .. #healthy_backends)

    -- 使用轮询策略选择后端
    local selected_backend
    if #healthy_backends > 0 then
        -- 有健康节点时，只在健康节点中进行轮询
        local counter_key = "round_robin_counter:" .. group
        local current_counter = round_robin_dict:get(counter_key) or 0
        
        ngx.log(ngx.INFO, "Current round-robin counter for " .. group .. ": " .. current_counter)
        
        -- 轮询选择：只在健康节点中进行轮询
        current_counter = current_counter + 1
        local index = (current_counter - 1) % #healthy_backends + 1  -- 使用健康节点数量
        selected_backend = healthy_backends[index]
        
        -- 更新共享内存中的计数器
        round_robin_dict:set(counter_key, current_counter)
        
        ngx.log(ngx.INFO, "Selected healthy backend: " .. selected_backend.host .. " for group " .. group .. " (round-robin index: " .. index .. "/" .. #healthy_backends .. ", counter: " .. current_counter .. ")")
    else
        -- 只有当healthy_backends为0时，才会转发到不健康节点
        local counter_key = "round_robin_counter:" .. group
        local current_counter = round_robin_dict:get(counter_key) or 0
        
        ngx.log(ngx.WARN, "No healthy backends available for group " .. group .. ", using round-robin fallback. Counter: " .. current_counter)
        
        -- 轮询选择：基于固定节点数量进行轮询
        current_counter = current_counter + 1
        local index = (current_counter - 1) % #servers + 1
        selected_backend = servers[index]
        
        -- 更新共享内存中的计数器
        round_robin_dict:set(counter_key, current_counter)
        
        ngx.log(ngx.WARN, "Selected fallback backend: " .. selected_backend.host .. " for group " .. group .. " (round-robin index: " .. index .. "/" .. #servers .. ", counter: " .. current_counter .. ")")
    end

    return selected_backend
end

-- 初始化函数：将所有节点标记为健康状态
function _M.init_backends()
    ngx.log(ngx.INFO, "Initializing all other backends as healthy")
    for group, servers in pairs(other_backends) do
        for _, backend in ipairs(servers) do
            local key = group .. ":" .. backend.host
            dict:set(key, true)
            ngx.log(ngx.INFO, "Initialized backend as healthy: " .. key)
        end
        -- 重置轮询计数器
        local counter_key = "round_robin_counter:" .. group
        round_robin_dict:set(counter_key, 0)
        ngx.log(ngx.INFO, "Reset round-robin counter for group: " .. group)
    end
end

return _M
