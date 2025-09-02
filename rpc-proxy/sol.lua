local http = require "resty.http"
local cjson = require "cjson"
local alerts = require "rpc-proxy.slack"
local dict = ngx.shared.backends_health

-- 定义模块
local _M = {}

local backends = {
    sol = {
        { url = "https://bold-skilled-river.solana-mainnet.quiknode.pro/" .. (os.getenv("BOLD_SKILLED_RIVER") or ""), host = "bold-skilled-river.solana-mainnet.quiknode.pro" },
        { url = "https://palpable-warmhearted-arrow.solana-mainnet.quiknode.pro/" .. (os.getenv("PALPABLE_WARMHEARTED_ARROW") or ""), host = "palpable-warmhearted-arrow.solana-mainnet.quiknode.pro" },
        { url = "https://proud-stylish-sunset.solana-mainnet.quiknode.pro/" .. (os.getenv("PROUD_STYLISH_SUNSET") or ""), host = "proud-stylish-sunset.solana-mainnet.quiknode.pro" }
        -- { url = "https://sol.nownodes.io/" .. (os.getenv("SOL_NOWNODES_API_KEY") or ""), host = "sol.nownodes.io" }
    }
}

-- 添加轮询计数器到共享内存
local round_robin_dict = ngx.shared.backends_health

function _M.check_backends_health()
    local httpc = http.new()
    local valid_statuses = { [200] = true }
    local fail_threshold = 3
    local success_threshold = 2

    for group, servers in pairs(backends) do
        for _, backend in ipairs(servers) do
            local success, err = pcall(function()
                local res, request_err = httpc:request_uri(backend.url, {
                    method = "POST",
                    body = cjson.encode({
                        jsonrpc = "2.0",
                        id = 1,
                        method = "getBlockHeight"
                    }),
                    headers = {
                        ["Content-Type"] = "application/json",
                        ["Host"] = backend.host
                    },
                    ssl_verify = false
                })

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
    end
end

function _M.get_backend(group)
    local servers = backends[group]
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
    ngx.log(ngx.INFO, "Initializing all backends as healthy")
    for group, servers in pairs(backends) do
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
