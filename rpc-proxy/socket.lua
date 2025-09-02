local ngx = require("ngx")
local cjson = require("cjson")

local socket_url = "https://api.socket.tech"

local function forward_request(method, path, query, body, headers)
    local url = socket_url .. path
    if query then
        url = url .. "?" .. ngx.encode_args(query)
    end

    local http = require("resty.http").new()
    local res, err = http:request_uri(url, {
        method = method,
        body = body,
        headers = headers,
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "socket request error: ", err)
        return
    end

    ngx.status = res.status
    for k, v in pairs(res.headers) do
        ngx.header[k] = v
    end
    ngx.print(res.body)
end

local method = ngx.var.request_method
local path = ngx.var.uri
local query = ngx.req.get_uri_args()
local headers = ngx.req.get_headers()

-- 设置一个常见的浏览器 User-Agent
headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36"

local body = nil
if method == "POST" then
    ngx.req.read_body()
    body = ngx.req.get_body_data()
    
    -- 如果请求体是 JSON,设置相应的 Content-Type
    if string.sub(body, 1, 1) == "{" then
        headers["Content-Type"] = "application/json"
    else
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    end
end

-- 在请求之间添加一些随机延迟,防止被识别为机器人
ngx.sleep(math.random(100, 500) / 1000)

forward_request(method, path, query, body, headers)
