local cjson = require("cjson")
local io = require("io")
local http = require("resty.http")

local UPDATE_INTERVAL = 15 * 60  -- 15分钟，单位为秒

local function update_fees()
    local url = "https://mempool.space/api/v1/fees/recommended"
    local httpc = http.new()
    httpc:set_timeout(5000)
    local res, err = httpc:request_uri(url, {
        method = "GET",
        ssl_verify = false
    })
    if not res then
        ngx.log(ngx.ERR, "Failed to request mempool API: ", err)
        return
    end
    if res.status ~= 200 then
        ngx.log(ngx.ERR, "Mempool API responded with non-200 status: ", res.status)
        return
    end
    local fees = cjson.decode(res.body)
    local file, err = io.open("/etc/nginx/logs/mempool-gas.conf", "w")
    if not file then
        ngx.log(ngx.ERR, "Failed to open file: ", err)
        return
    end
    file:write(res.body)
    file:close()
    ngx.log(ngx.INFO, "Fees data updated and written to file successfully.")
end

local function handle_request()
    local file, err = io.open("/etc/nginx/logs/mempool-gas.conf", "r")
    if not file then
        ngx.log(ngx.ERR, "Failed to open file: ", err)
        ngx.say(cjson.encode({error = "Failed to open file: " .. err}))
        return
    end
    local content = file:read("*a")
    file:close()
    ngx.header.content_type = "application/json"
    ngx.say(content)
    ngx.exit(ngx.HTTP_OK)
end

-- 初始调用一次更新
update_fees()

-- 设置定时器，每隔15分钟更新一次
local function periodic_update(premature)
    if not premature then
        update_fees()
        local ok, err = ngx.timer.at(UPDATE_INTERVAL, periodic_update)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create periodic timer: ", err)
        end
    end
end

local ok, err = ngx.timer.at(UPDATE_INTERVAL, periodic_update)
if not ok then
    ngx.log(ngx.ERR, "Failed to create initial timer: ", err)
end

handle_request()
