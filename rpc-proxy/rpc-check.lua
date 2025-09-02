local http = require "resty.http"
local cjson = require "cjson"
local alerts = require "rpc-proxy.slack"
local dict = ngx.shared.backends_health

local ankr_api_key = os.getenv("ANKR_API_KEY")
if not ankr_api_key or ankr_api_key == "" then
    ngx.log(ngx.ERR, "ANKR_API_KEY not found in environment variables")
end

local drpc_api_key = os.getenv("DRPC_API_KEY")
if not drpc_api_key or drpc_api_key == "" then
    ngx.log(ngx.ERR, "DRPC_API_KEY not found in environment variables")
end

local nownodes_api_key = os.getenv("NOWNODES_API_KEY")
if not nownodes_api_key or nownodes_api_key == "" then
    ngx.log(ngx.ERR, "NOWNODES_API_KEY not found in environment variables")
end

local rpc_api_key = os.getenv("RPC_API_KEY")
if not rpc_api_key or rpc_api_key == "" then
    ngx.log(ngx.ERR, "RPC_API_KEY not found in environment variables")
end

local function get_env_or_log_err(var_name)
    local value = os.getenv(var_name)
    if not value or value == "" then
        ngx.log(ngx.ERR, var_name .. " not found in environment variables")
    end
    return value
end



local _M = {}

local backends = {
    eth = {
        { url = "https://polished-light-patina.quiknode.pro/" .. (get_env_or_log_err("POLISHED_LIGHT_PATINA") or "") .. "/", host = "polished-light-patina.quiknode.pro" },
        { url = "https://lingering-fittest-aura.quiknode.pro/" .. (get_env_or_log_err("LINGERING_FITTEST_AURA") or "") .. "/", host = "lingering-fittest-aura.quiknode.pro" },
        { url = "https://skilled-serene-emerald.quiknode.pro/" .. (get_env_or_log_err("SKILLED_SERENE_EMERALD") or "") .. "/", host = "skilled-serene-emerald.quiknode.pro" }
    },

    birdlayer = {
        { url = "https://rpc.birdlayer.xyz/", host = "rpc.birdlayer.xyz" },
        { url = "https://rpc1.birdlayer.xyz/", host = "rpc1.birdlayer.xyz" }
    },
    bsc = {
        -- { url = "https://fabled-frequent-borough.bsc.quiknode.pro/" .. (get_env_or_log_err("FABLED_FREQUENT_BOROUGH") or ""), host = "fabled-frequent-borough.bsc.quiknode.pro" }
        -- { url = "https://bnb-mainnet.g.alchemy.com/v2/" .. (get_env_or_log_err("ALCHEMY_API_KEY") or ""), host = "bnb-mainnet.g.alchemy.com" },
        { url = "https://greatest-damp-mountain.bsc.quiknode.pro/" .. (get_env_or_log_err("GREATEST_DAMP_MOUNTAIN") or "") .. "/", host = "greatest-damp-mountain.bsc.quiknode.pro" }
    },
    matic = {
        { url = "https://responsive-long-water.matic.quiknode.pro/" .. (get_env_or_log_err("RESPONSIVE_LONG_WATER") or "") .. "/", host = "responsive-long-water.matic.quiknode.pro"}
        -- { url = "https://polygon-mainnet.g.alchemy.com/v2/dZ_wqxvrranF4j1kfK7zsYk-U6lgUr58", host = "polygon-mainnet.g.alchemy.com" }
    },
    optimism = {
        { url = "https://billowing-lively-wave.optimism.quiknode.pro/" .. (get_env_or_log_err("BILLOWING_LIVELY_WAVE") or "") .. "/", host = "billowing-lively-wave.optimism.quiknode.pro" },
    },
    arbitrum = {
        { url = "https://summer-cosmopolitan-dream.arbitrum-mainnet.quiknode.pro/" .. (get_env_or_log_err("SUMMER_COSMOPOLITAN_DREAM") or "") .. "/", host = "summer-cosmopolitan-dream.arbitrum-mainnet.quiknode.pro" },
	    { url = "https://fittest-orbital-market.arbitrum-mainnet.quiknode.pro/" .. (get_env_or_log_err("FITTEST_ORBITAL_MARKET") or "") .. "/", host = "fittest-orbital-market.arbitrum-mainnet.quiknode.pro"},
	    { url = "https://orbital-yolo-smoke.arbitrum-mainnet.quiknode.pro/" .. (get_env_or_log_err("ORBITAL_YOLO_SMOKE") or "") .. "/", host = "orbital-yolo-smoke.arbitrum-mainnet.quiknode.pro" }
    },
    base = {
	{ url = "https://billowing-weathered-wave.base-mainnet.quiknode.pro/" .. (get_env_or_log_err("BILLOWING_WEATHERED_WAVE") or "") .. "/", host = "billowing-weathered-wave.base-mainnet.quiknode.pro" }
    },
    avax = {
        {url = "https://thrilling-methodical-sailboat.avalanche-mainnet.quiknode.pro/" .. (get_env_or_log_err("THRILLING_METHODICAL_SAILBOAT") or "") .. "/ext/bc/C/rpc/", host = "thrilling-methodical-sailboat.avalanche-mainnet.quiknode.pro"}
    },
    etc = {
        { url = "https://etc.nownodes.io/" .. (nownodes_api_key), host = "etc.nownodes.io" },
        { url = "https://etc.rivet.link/", host = "etc.rivet.link" }
    },
    okb = {
        { url = "https://rpc.ankr.com/xlayer/" .. (ankr_api_key), host = "rpc.ankr.com" },
        { url = "https://lb.drpc.org/ogrpc?network=xlayer&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    ftm = {
        { url = "https://ftm.nownodes.io/" .. (nownodes_api_key), host = "ftm.nownodes.io" }
    },
    xdai = {
        { url = "https://broken-divine-mountain.xdai.quiknode.pro/" .. (get_env_or_log_err("BROKEN_DIVINE_MOUNTAIN") or "") .. "/", host = "broken-divine-mountain.xdai.quiknode.pro" }
    },
    celo = {
        { url = "https://rpc.ankr.com/celo/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    aurora = {
        { url = "https://aurora.nownodes.io/" .. (nownodes_api_key), host = "aurora.nownodes.io" },
    { url = "https://lb.drpc.org/ogrpc?network=aurora&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    boba = {
        { url = "https://lb.drpc.org/ogrpc?network=boba-eth&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    ethw = {
        { url = "https://ethw.nownodes.io/" .. (nownodes_api_key), host = "ethw.nownodes.io" },
        { url = "https://mainnet.ethereumpow.org", host = "mainnet.ethereumpow.org" }
    },
    etf = {
        { url = "https://rpc.dischain.xyz/", host = "rpc.dischain.xyz" }
    },
    fevm = {
        { url = "https://rpc.ankr.com/filecoin/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    linea = {
        { url = "https://rpc.ankr.com/linea/" .. (ankr_api_key) .. "/", host = "rpc.ankr.com" },
        { url = "https://linea-rpc.publicnode.com", host = "linea-rpc.publicnode.com" }
    },
    mantle = {
        { url = "https://rpc.mantle.xyz", host = "rpc.mantle.xyz" },
        { url = "https://tame-alien-arm.mantle-mainnet.quiknode.pro/" .. (get_env_or_log_err("TAME_ALIEN_ARM") or "") .. "/", host = "tame-alien-arm.mantle-mainnet.quiknode.pro" }
    },
    zksyncera = {
        { url = "https://zksync2-mainnet.zksync.io/", host = "zksync2-mainnet.zksync.io" },
        { url = "https://rpc.ankr.com/zksync_era/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    cronos = {
        { url = "https://lb.drpc.org/ogrpc?network=cronos&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://cronos-evm-rpc.publicnode.com", host = "cronos-evm-rpc.publicnode.com" }
    },
    mvm = {
    },
    ["manta-pacific"] = {
        { url = "https://lb.drpc.org/ogrpc?network=manta-pacific&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    blast = {
        { url = "https://lb.drpc.org/ogrpc?network=blast&dkey="  .. (drpc_api_key), host = "lb.drpc.org" },
        { url = "https://blast.nownodes.io/" .. (nownodes_api_key), host = "blast.nownodes.io" }
    },
    iotex = {
        { url = "https://babel-api.fastblocks.io/", host = "babel-api.fastblocks.io" },
    { url = "https://babel-api.mainnet.iotex.io", host = "babel-api.mainnet.iotex.io" }
    },
    octa = {
        { url = "https://rpc.octa.space/", host = "rpc.octa.space" }
    },
    ["polygon-zkevm"] = {
        { url = "https://lb.drpc.org/polygon-zkevm/" .. (drpc_api_key), host = "lb.drpc.org" },
        { url = "https://rpc.ankr.com/polygon_zkevm/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    okt = {
        { url = "https://lb.drpc.org/ogrpc?network=oktc&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    core = {
        { url = "https://lb.drpc.org/core/" .. (drpc_api_key), host = "lb.drpc.org" },
        { url = "https://rpc.ankr.com/core/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    klay = {
        { url = "https://lb.drpc.org/ogrpc?network=kaia&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    metis = {
        { url = "https://metis.nownodes.io/" .. (nownodes_api_key), host = "metis.nownodes.io" },
    { url = "https://lb.drpc.org/ogrpc?network=metis&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    glmr = {
        { url = "https://rpc.ankr.com/moonbeam/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    ron = {
        { url = "https://lb.drpc.org/ogrpc?network=ronin&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://api.roninchain.com/rpc", host = "api.roninchain.com" }
    },
    one = {
        { url = "https://lb.drpc.org/ogrpc?network=harmony-0&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    flare = {
        { url = "https://rpc.ftso.au/flare", host = "rpc.ftso.au" },
        { url = "https://rpc.ankr.com/flare/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    kava = {
        { url = "https://lb.drpc.org/ogrpc?network=kava&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://evm.kava.io", host = "evm.kava.io" }
    },
    pulse = {
        { url = "https://rpc.pulsechain.com/", host = "rpc.pulsechain.com" },
    { url = "https://rpc-pulsechain.g4mm4.io", host = "rpc-pulsechain.g4mm4.io" }
    },
    opbnb = {
        { url = "https://lb.drpc.org/ogrpc?network=opbnb&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
        { url = "https://opbnb-mainnet-rpc.bnbchain.org/", host = "opbnb-mainnet-rpc.bnbchain.org" }
    },
    scroll = {
        { url = "https://lb.drpc.org/ogrpc?network=scroll&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
        { url = "https://rpc.ankr.com/scroll/" .. (ankr_api_key), host = "rpc.ankr.com" }
    },
    wemix = {
        { url = "https://lb.drpc.org/ogrpc?network=wemix&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    merlin = {
        { url = "https://rpc.merlinchain.io/", host = "rpc.merlinchain.io" },
    { url = "https://merlin.blockpi.network/v1/rpc/public", host = "merlin.blockpi.network" }
    },
    taiko = {
        { url = "https://rpc.mainnet.taiko.xyz/", host = "rpc.mainnet.taiko.xyz" }
    },
    bob = {
        { url = "https://lb.drpc.org/ogrpc?network=bob&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://rpc.gobob.xyz", host = "rpc.gobob.xyz" }
    },
    unichain = {
        { url = "https://lb.drpc.org/ogrpc?network=unichain&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    zora = {
        { url = "https://lb.drpc.org/ogrpc?network=zora&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://rpc.zora.energy", host = "rpc.zora.energy" }
    },
    zeta = {
        { url = "https://zetachain-mainnet.public.blastapi.io/", host = "zetachain-mainnet.public.blastapi.io" },
        { url = "https://lb.drpc.org/ogrpc?network=zeta-chain&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    },
    xphere = {
        { url = "https://en-hkg.x-phere.com", host = "en-hkg.x-phere.com" },
        { url = "https://en-bkk.x-phere.com", host = "en-bkk.x-phere.com" },    
    },
    xphereTestnet = {
        { url = "https://testnet.x-phere.com", host = "testnet.x-phere.com" }
    },
    mode = {
        { url = "https://lb.drpc.org/ogrpc?network=mode&dkey=" .. (drpc_api_key), host = "lb.drpc.org" },
    { url = "https://mainnet.mode.network", host = "mainnet.mode.network" }
    },
    zklink = {
        { url = "https://rpc.zklink.io/", host = "rpc.zklink.io" }
    },
    b2 = {
        { url = "https://rpc.ankr.com/b2/" .. (ankr_api_key), host = "rpc.ankr.com" },
        { url = "https://mainnet.b2-rpc.com/", host = "mainnet.b2-rpc.com" }
    },
    bitlayer = {
        { url = "https://rpc.bitlayer-rpc.com/", host = "rpc.bitlayer-rpc.com" },
    { url = "https://rpc.bitlayer.org", host = "rpc.bitlayer.org" }
    },
    cyber = {
        { url = "https://cyber.alt.technology/", host = "cyber.alt.technology" },
    { url = "https://rpc.cyber.co", host = "rpc.cyber.co" }
    },
    bouncebit = {
        { url = "https://fullnode-mainnet.bouncebitapi.com/", host = "fullnode-mainnet.bouncebitapi.com" }
    },
    endurance = {
        { url = "https://rpc-endurance.fusionist.io/", host = "rpc-endurance.fusionist.io" }
    },
    -- zircuit = {
    --     { url = "https://lb.drpc.org/ogrpc?network=zircuit-mainnet&dkey=" .. (drpc_api_key), host = "lb.drpc.org" }
    -- },
    alephzero = {
        { url = "https://rpc.alephzero.raas.gelato.cloud", host = "rpc.alephzero.raas.gelato.cloud" }
    },

    holesky = {
        { url = "https://quiet-greatest-cloud.ethereum-holesky.quiknode.pro/" .. (get_env_or_log_err("QUIET_GREATEST_CLOUD") or "") .. "/", host = "quiet-greatest-cloud.ethereum-holesky.quiknode.pro" }
    },

    ethSepolia = {
        { url = "https://shy-fluent-layer.ethereum-sepolia.quiknode.pro/" .. (get_env_or_log_err("SHY_FLUENT_LAYER") or "") .. "/", host = "shy-fluent-layer.ethereum-sepolia.quiknode.pro" }
    },
    wldchain = {
        { url = "https://lb.drpc.org/ogrpc?network=worldchain&dkey=".. (drpc_api_key) , host = "lb.drpc.org" }
    },
    hyperliquid = {
        { url = "https://lb.drpc.org/ogrpc?network=hyperliquid&dkey=".. (drpc_api_key) , host = "lb.drpc.org" }
    }
}

-- 添加轮询计数器到共享内存
local round_robin_dict = ngx.shared.backends_health
local fail_threshold = 3
local success_threshold = 2

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
                        method = "eth_blockNumber",
                        id = 1,
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
