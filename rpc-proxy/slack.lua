local http = require "resty.http"
local cjson = require "cjson"

local _M = {}

function _M.send_slack_alert(group, backend, status)
    -- 获取当前环境
    local api_keys = ngx.shared.api_keys
    local current_env = api_keys:get("RPC_PROXY_ENV") or "development"
    
    -- 只在测试环境发送告警
    if current_env ~= "test" then
        ngx.log(ngx.INFO, "Non-test environment detected (", current_env, "), skipping Slack alert for ", group, " - status: ", status)
        return
    end
    
    -- 告警去重：连续三次相同错误才发送告警
    local dict = ngx.shared.backends_health
    local backend_host = backend and backend.host or "Unknown"
    local backend_url = backend and backend.url or "Unknown"
    
    -- 使用 backend_url 作为唯一标识
    local alert_count_key = "alert_count:" .. backend_url
    local alert_status_key = "alert_status:" .. backend_url
    local last_sent_key = "last_sent:" .. backend_url
    
    local last_status = dict:get(alert_status_key)
    local current_count = dict:get(alert_count_key) or 0
    local last_sent = dict:get(last_sent_key)
    
    -- 如果状态相同，增加计数
    if last_status == status then
        current_count = current_count + 1
        dict:set(alert_count_key, current_count, 1800) -- 30分钟过期
        dict:set(alert_status_key, status, 1800) -- 更新状态时间戳
    else
        -- 状态变化，重置计数
        current_count = 1
        dict:set(alert_count_key, current_count, 1800)
        dict:set(alert_status_key, status, 1800)
    end
    
    -- 检查是否在静默期内（半小时内已发送过告警）
    if last_sent then
        ngx.log(ngx.INFO, "Alert for ", backend_url, " is in silence period (30min), count: ", current_count, "/3")
        return
    end
    
    -- 只有连续三次相同错误才发送告警
    if current_count >= 3 then
        -- 额外检查：只对真正的服务故障发送告警
        local is_real_failure = false
        
        if type(status_code) == "string" then
            -- 真正的服务故障：连接失败、超时、服务器错误等
            if status_code:match("timeout") or 
               status_code:match("connection") or
               status_code:match("500") or
               status_code:match("502") or
               status_code:match("503") or
               status_code:match("504") then
                is_real_failure = true
            end
        end
        
        if is_real_failure then
            dict:set(last_sent_key, "sent", 1800) -- 记录已发送告警，30分钟静默期
            ngx.log(ngx.INFO, "Sending alert after 3 consecutive real failures for ", backend_url, " - status: ", status)
        else
            ngx.log(ngx.INFO, "Skipping alert for ", backend_url, " - not a real service failure: ", status)
            return
        end
    else
        ngx.log(ngx.INFO, "Skipping alert for ", backend_url, " - count: ", current_count, "/3 (need 3 consecutive failures)")
        return
    end
    
    local httpc = http.new()
    local token = os.getenv("SLACK_BOT_TOKEN") or ""
    local channel = os.getenv("SLACK_CHANNEL") or ""
    local slack_api_url = "https://slack.com/api/chat.postMessage"
    local alert_user_id = os.getenv("SLACK_ALERT_USER_ID") or ""
    
    local status_code = status or "Unknown"
    local status_page = "https://v5-rpc-proxy.onekeytest.com/backends-status"
    
    -- 对URL进行脱敏处理 - 处理路径和查询参数
    local function mask_sensitive_url(url)
        if not url or url == "Unknown" then
            return url
        end
        
        local result = url
        
        -- 1. 处理查询参数中的敏感信息 (dkey=, key=等) - 无论长度都脱敏
        result = result:gsub("([?&]d?key=)([%w_%-]+)", function(prefix, value)
            if string.len(value) > 8 then
                return prefix .. string.sub(value, 1, 4) .. "**" .. string.sub(value, -4)
            else
                -- 对于短密钥，也要进行脱敏处理
                return prefix .. string.sub(value, 1, 2) .. "**" .. string.sub(value, -2)
            end
        end)
        
        -- 2. 处理URL路径中的敏感信息 (按/分割处理)
        result = result:gsub("([^/?&]+)", function(part)
            -- 检查是否为纯字母数字下划线组合且长度超过16
            -- 排除查询参数部分 (包含=的不处理，因为已经在上面处理了)
            if not string.match(part, "=") and string.match(part, "^[%w_%-]+$") and string.len(part) > 16 then
                return string.sub(part, 1, 4) .. "**" .. string.sub(part, -4)
            else
                return part
            end
        end)
        
        return result
    end
    
    local masked_url = mask_sensitive_url(backend_url)

    -- 分析错误类型
    local error_type = "未知错误"
    local error_emoji = ":rotating_light:"
    
    if type(status_code) == "string" then
        if status_code:match("403") then
            error_type = "API密钥权限不足"
            error_emoji = ":key:"
        elseif status_code:match("JSON decode error") then
            error_type = "JSON解析失败"
            error_emoji = ":warning:"
        elseif status_code:match("timeout") then
            error_type = "请求超时"
            error_emoji = ":hourglass:"
        elseif status_code:match("connection") then
            error_type = "连接失败"
            error_emoji = ":broken_heart:"
        elseif status_code:match("404") then
            error_type = "接口不存在"
            error_emoji = ":question:"
        elseif status_code:match("500") then
            error_type = "服务器内部错误"
            error_emoji = ":fire:"
        end
    end
    
    -- 过滤掉正常的 RPC 错误响应，避免误报
    if type(status_code) == "string" and status_code:match("400") then
        -- 检查是否是正常的 RPC 错误响应
        if status_code:match("method.*does not exist") or 
           status_code:match("method.*not available") or
           status_code:match("invalid.*method") or
           status_code:match("unsupported.*method") then
            ngx.log(ngx.INFO, "Skipping alert for normal RPC method error: ", status_code)
            return
        end
    end
    
    -- 过滤掉 URL 为 Unknown 的告警，这通常是配置问题
    if backend_url == "Unknown" then
        ngx.log(ngx.INFO, "Skipping alert for Unknown backend URL")
        return
    end

    -- 构建告警消息，测试环境@用户
    local message = string.format(
        "%s *RPC %s 故障告警* <@%s>:\n" ..
        "*环境*: %s\n" ..
        "*错误类型*: %s\n" ..
        "*服务类型*: %s\n" ..
        "*故障节点*: %s\n" ..
        "*完整URL*: `%s`\n" ..
        "*错误详情*: %s\n" ..
        "*状态页面*: %s",
        error_emoji, group, alert_user_id, current_env, error_type, group, backend_host, masked_url, status_code, status_page
    )

    local res, err = httpc:request_uri(slack_api_url, {
        method = "POST",
        body = cjson.encode({
            channel = channel,
            text = message,
            mrkdwn = true
        }),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. token
        },
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "Failed to send Slack alert: ", err)
    elseif res.status ~= 200 then
        ngx.log(ngx.ERR, "Slack API returned non-200 status: ", res.status)
    else
        ngx.log(ngx.INFO, "Slack alert sent successfully for test environment")
    end
end

return _M
