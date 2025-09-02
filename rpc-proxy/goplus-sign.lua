local http = require "resty.http"
local json = require "cjson"

-- 从环境变量获取应用凭证
local function get_app_credentials()
    local app_key = os.getenv("GOPLUS_SIGN_APP_KEY")
    local app_secret = os.getenv("GOPLUS_SIGN_APP_SECRET")
    
    if not app_key then
        ngx.log(ngx.ERR, "GOPLUS_SIGN_APP_KEY environment variable not set")
        return nil, nil
    end
    
    if not app_secret then
        ngx.log(ngx.ERR, "GOPLUS_SIGN_APP_SECRET environment variable not set")
        return nil, nil
    end
    
    return app_key, app_secret
end

-- 将二进制数据转换为十六进制表示
local function to_hex(str)
    return (str:gsub('.', function(c)
        return string.format('%02x', string.byte(c))
    end))
end

-- 生成sign
local function generate_sign()
    local app_key, app_secret = get_app_credentials()
    if not app_key or not app_secret then
        ngx.log(ngx.ERR, "Failed to get app credentials from environment variables")
        return nil, nil
    end
    
    local time = os.time()
    local data = app_key .. time .. app_secret
    local sha1 = ngx.sha1_bin(data) -- 计算SHA1哈希值
    local sign = to_hex(sha1) -- 将SHA1哈希值转换为十六进制字符串
    ngx.log(ngx.INFO, "Generated sign: ", sign)
    ngx.log(ngx.INFO, "Generated time: ", time)
    return sign, time
end

-- 从API获取token并保存到文件
local function fetch_and_save_token(premature)
    if premature then
        ngx.log(ngx.INFO, "Timer prematurely aborted")
        return
    end

    ngx.log(ngx.INFO, "Fetching new token")
    local sign, time = generate_sign()
    if not sign or not time then
        ngx.log(ngx.ERR, "Failed to generate sign - missing app credentials")
        return nil, "Failed to generate sign - missing app credentials"
    end
    
    local app_key, _ = get_app_credentials()
    if not app_key then
        ngx.log(ngx.ERR, "Failed to get app_key for token request")
        return nil, "Failed to get app_key for token request"
    end
    
    local httpc = http.new()
    local res, err = httpc:request_uri("https://api.gopluslabs.io/api/v1/token", {
        method = "POST",
        body = json.encode({
            app_key = app_key,
            sign = sign,
            time = time
        }),
        headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "*/*"
        },
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "Failed to request token: ", err)
        return nil, "Failed to request token: " .. err
    end

    ngx.log(ngx.INFO, "Response status: ", res.status)
    ngx.log(ngx.INFO, "Response body: ", res.body)

    local response = json.decode(res.body)
    if response.code == 1 then
        local token = response.result.access_token
        local expires_in = response.result.expires_in
        ngx.log(ngx.INFO, "Token fetched successfully, expires in ", expires_in, " seconds")
        local file = io.open("/etc/nginx/logs/goplus-token.conf", "w")
        file:write("token: " .. token .. "\n")
        file:write("expires_in: " .. expires_in .. "\n")
        file:write("create_time: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:close()
        -- 设置定时器在110分钟后刷新 token
        local refresh_interval = 110 * 60  -- 110分钟
        ngx.log(ngx.INFO, "Scheduling next token refresh in ", refresh_interval, " seconds")
        ngx.timer.at(refresh_interval, fetch_and_save_token)
        return token, nil
    else
        ngx.log(ngx.ERR, "Failed to get token: ", response.message)
        return nil, "Failed to get token: " .. response.message
    end
end

-- 定时器，在 token 有效期过半时重新获取 token
local function schedule_token_refresh(delay)
    ngx.log(ngx.INFO, "Scheduling token refresh in ", delay, " seconds")
    local ok, err = ngx.timer.at(delay, fetch_and_save_token)
    if not ok then
        ngx.log(ngx.ERR, "Failed to create timer: ", err)
    else
        ngx.log(ngx.INFO, "Timer created successfully")
    end
end

local function get_saved_token()
    ngx.log(ngx.INFO, "Reading saved token from file")
    local file = io.open("/etc/nginx/logs/goplus-token.conf", "r")
    if not file then
        ngx.log(ngx.ERR, "Failed to open token file")
        return nil, "Failed to open token file"
    end

    local token
    for line in file:lines() do
        if line:find("token: ") then
            token = line:sub(8)
            ngx.log(ngx.INFO, "Read token from file: ", token)
            break
        end
    end
    file:close()

    if not token then
        ngx.log(ngx.ERR, "Failed to read token from file")
        return nil, "Failed to read token from file"
    end

    return token
end

local _M = {}

function _M.fetch_token()
    ngx.log(ngx.INFO, "Manually fetching token")
    return fetch_and_save_token(false)
end

function _M.get_token()
    ngx.log(ngx.INFO, "Getting saved token")
    return get_saved_token()
end

function _M.init_worker()
    ngx.log(ngx.INFO, "Initializing worker - forcing token refresh on startup")
    
    -- 启动时强制刷新 token，无论是否已存在
    ngx.log(ngx.INFO, "Force refreshing token on startup")
    ngx.timer.at(0, fetch_and_save_token)
end

-- HTTP接口：用于cron任务调用token更新
function _M.update_token_http()
    ngx.log(ngx.INFO, "HTTP request to update token")
    local token, err = fetch_and_save_token(false)
    if token then
        ngx.status = 200
        ngx.header.content_type = "application/json"
        ngx.say(json.encode({
            success = true,
            message = "Token updated successfully",
            token = token:sub(1, 10) .. "..." -- 只显示token的前10个字符
        }))
    else
        ngx.status = 500
        ngx.header.content_type = "application/json"
        ngx.say(json.encode({
            success = false,
            message = "Failed to update token: " .. (err or "unknown error")
        }))
    end
    ngx.exit(ngx.status)
end

return _M

