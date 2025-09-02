local function show_backends_status()
    local dict = ngx.shared.backends_health
    local keys = dict:get_keys(1000)

    ngx.header["Content-Type"] = "text/html; charset=utf-8"
    ngx.say("<html>")
    ngx.say("<head><meta charset='utf-8'><style>")
    ngx.say([[
        body {
            font-family: Arial, sans-serif;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            table-layout: auto;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
            white-space: normal;
        }
        th {
            background-color: #f2f2f2;
        }
        .healthy {
            color: green;
            font-weight: bold;
        }
        .unhealthy {
            color: red;
            font-weight: bold;
        }
        .healthy:before {
            content: '● ';
            color: green;
        }
        .unhealthy:before {
            content: '● ';
            color: red;
        }
    ]])
    ngx.say("</style></head>")
    ngx.say("<body>")
    ngx.say("<h1>RPC Health Status</h1>")
    ngx.say("<table>")
    ngx.say("<tr><th>Endpoint</th><th>Host</th><th>Health</th></tr>")

    -- 按endpoint和host分组
    local endpoint_hosts = {}
    local seen_keys = {}
    
    for _, key in ipairs(keys) do
        -- 过滤掉计数键，只处理主要的健康状态键
        if not seen_keys[key] and 
           not key:find(":block_number") and 
           not key:find(":success_count") and 
           not key:find(":fail_count") and 
           not key:find(":round_robin") and
           not key:find(":last_sent") and
           not key:find(":alert_count") and
           not key:find(":alert_status") and
           not key:find(":last_") and
           not key:find("alert_count:") and
           not key:find("alert_status:") and
           not key:find("last_sent:") and
           not key:find("round_robin_counter:") then
            seen_keys[key] = true
            local status = dict:get(key)
            local endpoint, rpc = key:match("^(.-):(.+)")
            
            -- 提取host信息，避免显示完整URL
            local host = rpc
            if rpc and rpc:find("://") then
                -- 如果是完整URL，提取host部分
                local protocol, domain = rpc:match("^(https?://)(.+)")
                if domain then
                    -- 移除路径部分，只保留host
                    host = domain:match("^([^/]+)")
                end
            end
            
            -- 创建分组键
            local group_key = endpoint .. ":" .. (host or rpc)
            
            if not endpoint_hosts[group_key] then
                endpoint_hosts[group_key] = {
                    endpoint = endpoint,
                    host = host or rpc,
                    statuses = {}
                }
            end
            
            -- 收集状态
            table.insert(endpoint_hosts[group_key].statuses, status)
        end
    end
    
    -- 准备显示数据，分为健康和不健康两组
    local healthy_items = {}
    local unhealthy_items = {}
    
    for group_key, data in pairs(endpoint_hosts) do
        local endpoint = data.endpoint
        local host = data.host
        local statuses = data.statuses
        
        -- 计算整体状态：如果有任何一个健康，则显示为健康
        local overall_status = false
        local has_healthy = false
        local has_unhealthy = false
        
        for _, status in ipairs(statuses) do
            if status == true then
                has_healthy = true
            elseif status == false then
                has_unhealthy = true
            end
        end
        
        -- 如果有健康的，整体状态为健康
        if has_healthy then
            overall_status = true
        end
        
        local status_class = overall_status and "healthy" or "unhealthy"
        local status_text = overall_status and "Healthy" or "Unhealthy"
        
        -- 如果有多个状态，添加计数信息
        if #statuses > 1 then
            local healthy_count = 0
            local unhealthy_count = 0
            for _, status in ipairs(statuses) do
                if status == true then
                    healthy_count = healthy_count + 1
                elseif status == false then
                    unhealthy_count = unhealthy_count + 1
                end
            end
            status_text = status_text .. " (" .. healthy_count .. "/" .. #statuses .. ")"
        end
        
        local item = {
            endpoint = endpoint,
            host = host,
            status_class = status_class,
            status_text = status_text
        }
        
        -- 根据健康状态分组
        if overall_status then
            table.insert(healthy_items, item)
        else
            table.insert(unhealthy_items, item)
        end
    end
    
    -- 先显示不健康的条目
    for _, item in ipairs(unhealthy_items) do
        ngx.say("<tr><td>" .. item.endpoint .. "</td><td>" .. item.host .. "</td><td class='" .. item.status_class .. "'>" .. item.status_text .. "</td></tr>")
    end
    
    -- 再显示健康的条目
    for _, item in ipairs(healthy_items) do
        ngx.say("<tr><td>" .. item.endpoint .. "</td><td>" .. item.host .. "</td><td class='" .. item.status_class .. "'>" .. item.status_text .. "</td></tr>")
    end

    ngx.say("</table>")
    ngx.say("</body></html>")
end

return show_backends_status



