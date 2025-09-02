local http = require "resty.http"
local cjson = require "cjson"
local alerts = require "rpc-proxy.slack"
local dict = ngx.shared.backends_health

-- 定义模块
local _M = {}

local backends = {
    bfc = {
        { url = "https://rpc-mainnet.benfen.org", host = "rpc-mainnet.benfen.org" }
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
                        method = "bfc_getTotalTransactionBlocks",
                        id = "52818f0d-53fb-4111-a620-bb4d755d4bc2",
                        jsonrpc = "2.0"
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
    -- 单节点时，直接返回，不管健康状态
    if #servers == 1 then
        ngx.log(ngx.INFO, "Only one backend for group " .. group .. ", always forwarding to it regardless of health status: " .. servers[1].host)
        return servers[1]
    end
    local healthy_backends = {}

    for _, backend in ipairs(servers) do
        local key = group .. ":" .. backend.host
        if dict:get(key) then
            table.insert(healthy_backends, backend)
        end
    end

    local selected_backend
    if #healthy_backends > 0 then
        selected_backend = healthy_backends[math.random(#healthy_backends)]
        ngx.log(ngx.INFO, "Selected healthy backend: " .. selected_backend.host .. " for group " .. group)
    else
        ngx.log(ngx.ERR, "No healthy backends available for group " .. group .. ", choosing a random backend as a fallback.")
        selected_backend = servers[math.random(#servers)]
        ngx.log(ngx.WARN, "Selected fallback backend: " .. selected_backend.host .. " for group " .. group)
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
