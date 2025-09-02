local pcall = pcall
local ngx = ngx
local ngx_log = ngx.log
local ngx_err = ngx.ERR
local _M = {}

function _M.init()
    uris = ngx.shared.uri_by_host
    global_set = ngx.shared.global_set
    global_set:set("initted", false)
    global_set:set("looped", false)
    
    -- 使用 counter.conf 初始化的全局 prometheus 实例
    if not prometheus then
        ngx_log(ngx_err, "ERROR: prometheus instance not found, please check counter.conf initialization")
        _M.metric_latency = nil
        return
    end
    
    -- 安全地创建指标，添加fullurl标签
    local success, metric_latency = pcall(function()
        return prometheus:histogram("nginx_http_request_duration_seconds", "HTTP request latency status", {"host", "status", "scheme", "method", "endpoint", "fullurl"})
    end)
    
    if not success then
        ngx_log(ngx_err, "ERROR: Failed to create prometheus histogram: ", metric_latency)
        _M.metric_latency = nil
        return
    end
    
    -- 保存到模块变量
    _M.metric_latency = metric_latency
    ngx_log(ngx_err, "INFO: Prometheus metrics initialized successfully")
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

local function parse_fullurl(request_uri)
    local result_table = {}
    
    -- 添加调试日志
    local debug_msg = "=== DEBUG: parse_fullurl ==="
    ngx_log(ngx_err, debug_msg)
    
    debug_msg = "Input request_uri: " .. request_uri
    ngx_log(ngx_err, debug_msg)
    
    -- 分割URI
    local parts = split(request_uri, "/")
    
    -- 添加调试信息
    debug_msg = "Split parts: " .. table.concat(parts, "|")
    ngx_log(ngx_err, debug_msg)
    
    -- 检查是否有足够的段
    if #parts < 1 then
        debug_msg = "Not enough URI segments, skipping"
        ngx_log(ngx_err, debug_msg)
       return nil
    end
    
    local first_part = parts[1]  -- 第一个非空段
    
    debug_msg = "First part: " .. first_part
    ngx_log(ngx_err, debug_msg)
    
    -- 排除纯数字的endpoint
    if first_part:match("^%d+$") then
        debug_msg = "First part is numeric, skipping"
        ngx_log(ngx_err, debug_msg)
        return nil
    end
    
    -- 排除域名（包含点号的）
    if first_part:find("%.") then
        debug_msg = "First part contains dot (domain), skipping"
        ngx_log(ngx_err, debug_msg)
        return nil
    end
    
    local endpoint = nil
    local fullurl = nil
    
    -- 检查是否是 /node/xx 模式
    if first_part == "node" and #parts >= 2 then
        local second_part = parts[2]
        -- 检查第二段是否匹配特定模式
        if second_part:match("^[%w%-]+$") then  -- 匹配字母、数字、连字符
            endpoint = "/" .. first_part .. "/" .. second_part
            debug_msg = "Node pattern matched: endpoint=" .. endpoint
            ngx_log(ngx_err, debug_msg)
        end
    end
    
    -- 检查是否是 /nownodes/xx 模式
    if first_part == "nownodes" and #parts >= 2 then
        local second_part = parts[2]
        -- 检查第二段是否匹配特定模式
        if second_part:match("^[%w%-]+$") then  -- 匹配字母、数字、连字符
            endpoint = "/" .. first_part .. "/" .. second_part
            debug_msg = "Nownodes pattern matched: endpoint=" .. endpoint
            ngx_log(ngx_err, debug_msg)
        end
    end
    
    -- 默认使用第一段作为endpoint
    if not endpoint then
        endpoint = "/" .. first_part
        debug_msg = "Using first segment as endpoint: " .. endpoint
        ngx_log(ngx_err, debug_msg)
    end
    
    -- 参考用户的fullurl获取方式
    for j = 1, #parts do
        if j == 1 then
            fullurl = "/" .. parts[j]
        elseif j <= 5 then
            if tonumber(parts[j]) ~= nil then
                break
            end
            fullurl = fullurl .. "/" .. parts[j]
        else
            break
        end
    end
    
    result_table["endpoint"] = endpoint
    result_table["fullurl"] = fullurl
    return result_table
end

function _M.log()
    -- 检查指标是否可用
    if not _M.metric_latency then
        local msg = "WARNING: metric_latency not available, skipping metrics"
        ngx_log(ngx_err, msg)
        return
    end
    
    local request_host = ngx.var.host
    local request_uri = ngx.unescape_uri(ngx.var.uri)
    local request_status = ngx.var.status
    local request_scheme = ngx.var.scheme
    local request_method = ngx.var.request_method
    local remote_ip = ngx.var.remote_addr
    local ngx_sent = ngx.var.body_bytes_sent
    local latency = ngx.var.upstream_response_time or 0

    local result_table = parse_fullurl(request_uri)
    if result_table == nil then
        return
    end
    
    -- 安全地记录指标，添加fullurl标签
    local success = pcall(function()
        local label_values = {request_host, request_status, request_scheme, request_method, result_table["endpoint"], result_table["fullurl"]}
        _M.metric_latency:observe(tonumber(latency), label_values)
    end)
    
    if not success then
        local debug_msg = "ERROR: Failed to record metric"
        ngx_log(ngx_err, debug_msg)
    end
end

return _M