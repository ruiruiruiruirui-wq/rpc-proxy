-- Initialize token refresh logic
local sign_generator = require "rpc-proxy.goplus-sign"
sign_generator.init_worker()

local api_keys = ngx.shared.api_keys

ngx.log(ngx.INFO, "Flushing shared memory before writing keys...")
api_keys:flush_all()

local keys = {
    ONRAMPER_API_KEY = os.getenv("ONRAMPER_API_KEY"),
    COINGECKO_API_KEY = os.getenv("COINGECKO_API_KEY"),
    SOLSCAN_API_KEY = os.getenv("SOLSCAN_API_KEY"),
    SOLSCAN_V2_API_KEY = os.getenv("SOLSCAN_V2_API_KEY"),
    BLOCKIN_API_KEY = os.getenv("BLOCKIN_API_KEY"),
    SUBSCAN_API_KEY = os.getenv("SUBSCAN_API_KEY"),
    INCH_API_KEY = os.getenv("INCH_API_KEY"),
    ZEROx_API_KEY = os.getenv("ZEROx_API_KEY"),
    BLOCKAID_API_KEY = os.getenv("BLOCKAID_API_KEY"),
    CONFLUXSCAN_API_KEY = os.getenv("CONFLUXSCAN_API_KEY"),
    DAPPRADAR_API_KEY = os.getenv("DAPPRADAR_API_KEY"),
    ALCHEMY_API_KEY = os.getenv("ALCHEMY_API_KEY"),
    BLOCKFROST_API_KEY = os.getenv("BLOCKFROST_API_KEY"),
    BLOCKFNATIVE_API_KEY = os.getenv("BLOCKFNATIVE_API_KEY"),
    THORSWAP_API_KEY = os.getenv("THORSWAP_API_KEY"),
    GETBLOCK_API_KEY = os.getenv("GETBLOCK_API_KEY"),
    UNISAT_API_KEY = os.getenv("UNISAT_API_KEY"),
    UNISAT_TESTNET_API_KEY = os.getenv("UNISAT_TESTNET_API_KEY"),
    DODO_API_KEY = os.getenv("DODO_API_KEY"),
    DRPC_API_KEY = os.getenv("DRPC_API_KEY"),
    NOWNODES_API_KEY_ROUTE = os.getenv("NOWNODES_API_KEY_ROUTE"),
    RPC_API_KEY = os.getenv("RPC_API_KEY"),
    NOWNODES_API_KEY = os.getenv("NOWNODES_API_KEY"),
    ANKR_API_KEY = os.getenv("ANKR_API_KEY"),
    TRON_PRO_API_KEY = os.getenv("TRON_PRO_API_KEY"),
    SUMSUB_APP_TOKEN = os.getenv("SUMSUB_APP_TOKEN"),
    SUMSUB_SECRET_KEY = os.getenv("SUMSUB_SECRET_KEY"),
    CHANGE_HERO_API_KEY = os.getenv("CHANGE_HERO_API_KEY"),
    RPC_PROXY_ENV = os.getenv("RPC_PROXY_ENV"),
    BTCBOOK_TESTNET_NOWNODES_IO_KEY = os.getenv("BTCBOOK_TESTNET_NOWNODES_IO_KEY"),
    GOPLUS_SIGN_APP_KEY = os.getenv("GOPLUS_SIGN_APP_KEY"),
    GOPLUS_SIGN_APP_SECRET = os.getenv("GOPLUS_SIGN_APP_SECRET"),
    GO_GETBLOCK_IO_KEY = os.getenv("GO_GETBLOCK_IO_KEY"),
    API_COVALENTHQ_COM_KEY = os.getenv("API_COVALENTHQ_COM_KEY"),
    APIS_MINTSCAN_IO_KEY = os.getenv("APIS_MINTSCAN_IO_KEY"),
    BIRDEYE_API_KEY = os.getenv("BIRDEYE_API_KEY"),
    POLISHED_LIGHT_PATINA = os.getenv("POLISHED_LIGHT_PATINA"),
    LINGERING_FITTEST_AURA = os.getenv("LINGERING_FITTEST_AURA"),
    SKILLED_SERENE_EMERALD = os.getenv("SKILLED_SERENE_EMERALD"),
    FABLED_FREQUENT_BOROUGH = os.getenv("FABLED_FREQUENT_BOROUGH"),
    RESPONSIVE_LONG_WATER = os.getenv("RESPONSIVE_LONG_WATER"),
    BILLOWING_LIVELY_WAVE = os.getenv("BILLOWING_LIVELY_WAVE"),
    SUMMER_COSMOPOLITAN_DREAM = os.getenv("SUMMER_COSMOPOLITAN_DREAM"),
    FITTEST_ORBITAL_MARKET = os.getenv("FITTEST_ORBITAL_MARKET"),
    ORBITAL_YOLO_SMOKE = os.getenv("ORBITAL_YOLO_SMOKE"),
    BILLOWING_WEATHERED_WAVE = os.getenv("BILLOWING_WEATHERED_WAVE"),
    THRILLING_METHODICAL_SAILBOAT = os.getenv("THRILLING_METHODICAL_SAILBOAT"),
    BROKEN_DIVINE_MOUNTAIN = os.getenv("BROKEN_DIVINE_MOUNTAIN"),
    TAME_ALIEN_ARM = os.getenv("TAME_ALIEN_ARM"),
    PURPLE_BOLD_HILL = os.getenv("PURPLE_BOLD_HILL"),
    CLEAN_SNOWY_LOG = os.getenv("CLEAN_SNOWY_LOG"),
    BOLD_SKILLED_RIVER = os.getenv("BOLD_SKILLED_RIVER"),
    PALPABLE_WARMHEARTED_ARROW = os.getenv("PALPABLE_WARMHEARTED_ARROW"),
    PROUD_STYLISH_SUNSET = os.getenv("PROUD_STYLISH_SUNSET"),
    FLUENT_COOL_GLITTER = os.getenv("FLUENT_COOL_GLITTER"),
    QUIET_GREATEST_CLOUD = os.getenv("QUIET_GREATEST_CLOUD"),
    LINGERING_ROUGH_WAVE = os.getenv("LINGERING_ROUGH_WAVE"),
    SHY_FLUENT_LAYER = os.getenv("SHY_FLUENT_LAYER"),
}


for key, value in pairs(keys) do
    if value then
        api_keys:set(key, value)
    end
end


local bfc_health_checker = require "rpc-proxy.bfc"
local sol_health_checker = require "rpc-proxy.sol"
local dot_health_checker = require "rpc-proxy.dot"
local ton_health_checker = require "rpc-proxy.ton"
local near_health_checker = require "rpc-proxy.near"
local apt_health_checker = require "rpc-proxy.apt"
local evm_health_checker = require "rpc-proxy.rpc-check"
local other_health_checker = require "rpc-proxy.other"

-- 外部 API 监控
local coingecko_checker = require "rpc-proxy.coingecko"
local infura_checker = require "rpc-proxy.infura"
local alchemy_checker = require "rpc-proxy.alchemy_monitor"
local fil_checker = require "rpc-proxy.fil"
local dogebook_checker = require "rpc-proxy.dogebook"
local btcbook_checker = require "rpc-proxy.btcbook"
local ltcbook_checker = require "rpc-proxy.ltcbook"
local bchbook_checker = require "rpc-proxy.bchbook"
local algo_checker = require "rpc-proxy.algo"
local tsol_health_checker = require "proxy_scripts.solanadevnet"
local solscan_v1_health_checker = require "proxy_scripts.solscan_v1"
local solscan_v2_health_checker = require "proxy_scripts.solscan_v2"
local hsk_health_checker = require "proxy_scripts.hsk"
local tbtc4_health_checker = require "proxy_scripts.tbtc4"
local zircuit_health_checker = require "proxy_scripts.zircuit"
local sui_new_health_checker = require "proxy_scripts.sui"
local panora_health_checker = require "proxy_scripts.panora"

-- 初始化所有后端为健康状态
ngx.log(ngx.INFO, "Starting to initialize all health checkers...")

-- rpc-proxy/ 目录下的健康检查器
if bfc_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing bfc health checker...")
    bfc_health_checker.init_backends()
end

if sol_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing sol health checker...")
    sol_health_checker.init_backends()
end

if dot_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing dot health checker...")
    dot_health_checker.init_backends()
end

if ton_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing ton health checker...")
    ton_health_checker.init_backends()
end

if near_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing near health checker...")
    near_health_checker.init_backends()
end

if apt_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing apt health checker...")
    apt_health_checker.init_backends()
end

if evm_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing evm health checker...")
    evm_health_checker.init_backends()
end

if other_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing other health checker...")
    other_health_checker.init_backends()
end

-- 初始化外部 API 监控
if coingecko_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing Coingecko health checker...")
    coingecko_checker.init_backends()
end

if infura_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing Infura health checker...")
    infura_checker.init_backends()
end

if alchemy_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing Alchemy health checker...")
    alchemy_checker.init_backends()
end

if fil_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing FIL health checker...")
    fil_checker.init_backends()
end

if dogebook_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing Dogebook health checker...")
    dogebook_checker.init_backends()
end

if btcbook_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing BTCBook health checker...")
    btcbook_checker.init_backends()
end

if ltcbook_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing LTCBook health checker...")
    ltcbook_checker.init_backends()
end

if bchbook_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing BCHBook health checker...")
    bchbook_checker.init_backends()
end

if algo_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing Algorand health checker...")
    algo_checker.init_backends()
end


-- proxy_scripts/ 目录下的健康检查器
if tsol_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing tsol health checker...")
    tsol_health_checker.init_backends()
end

if solscan_v1_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing solscan v1 health checker...")
    solscan_v1_health_checker.init_backends()
end

if solscan_v2_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing solscan v2 health checker...")
    solscan_v2_health_checker.init_backends()
end

if hsk_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing hsk health checker...")
    hsk_health_checker.init_backends()
end

if tbtc4_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing tbtc4 health checker...")
    tbtc4_health_checker.init_backends()
end

if zircuit_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing zircuit health checker...")
    zircuit_health_checker.init_backends()
end

if sui_new_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing sui health checker...")
    sui_new_health_checker.init_backends()
end

if panora_health_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing panora health checker...")
    panora_health_checker.init_backends()
end

-- gas 相关的健康检查器
local btc_gas_checker = require "rpc-proxy.blockcypher-btc-gas"
local dash_gas_checker = require "rpc-proxy.blockcypher-dash-gas"
local ltc_gas_checker = require "rpc-proxy.blockcypher-ltc-gas"
local mempool_gas_checker = require "rpc-proxy.mempool-gas"
local mempool_signet_checker = require "rpc-proxy.mempool-signet"
local mempool_testnet_checker = require "rpc-proxy.mempool-testnet"
local socket_checker = require "rpc-proxy.socket"

if btc_gas_checker.init_backends then btc_gas_checker.init_backends() end
if dash_gas_checker.init_backends then dash_gas_checker.init_backends() end
if ltc_gas_checker.init_backends then ltc_gas_checker.init_backends() end
if mempool_gas_checker.init_backends then mempool_gas_checker.init_backends() end
if mempool_signet_checker.init_backends then mempool_signet_checker.init_backends() end
if mempool_testnet_checker.init_backends then mempool_testnet_checker.init_backends() end
if socket_checker.init_backends then socket_checker.init_backends() end

local function schedule_health_check(health_checker, interval)
    local function run_health_checks(premature)
        if not premature then
            if health_checker.check_backends_health then
                health_checker.check_backends_health()
            elseif health_checker.check_health then
                health_checker.check_health()
            end
        end
        local ok, err = ngx.timer.at(interval, run_health_checks)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create timer: ", err)
        end
    end

    local ok, err = ngx.timer.at(0, run_health_checks)
    if not ok then
        ngx.log(ngx.ERR, "Failed to create initial timer: ", err)
    end
end

-- 为每种链注册定时健康检查
-- rpc-proxy/ 目录下的健康检查器
schedule_health_check(bfc_health_checker, 180)
schedule_health_check(sol_health_checker, 180)
schedule_health_check(dot_health_checker, 180)
schedule_health_check(ton_health_checker, 180)
schedule_health_check(near_health_checker, 180)
schedule_health_check(apt_health_checker, 180)
schedule_health_check(evm_health_checker, 180)
schedule_health_check(other_health_checker, 180)
schedule_health_check(alchemy_checker, 180)
schedule_health_check(fil_checker, 180)
schedule_health_check(dogebook_checker, 180)
schedule_health_check(btcbook_checker, 180)
schedule_health_check(ltcbook_checker, 180)
schedule_health_check(bchbook_checker, 180)
schedule_health_check(algo_checker, 180)

-- 外部 API 监控的健康检查
schedule_health_check(coingecko_checker, 180)
schedule_health_check(infura_checker, 180)
schedule_health_check(alchemy_checker, 180)
schedule_health_check(fil_checker, 180)
schedule_health_check(dogebook_checker, 180)

-- proxy_scripts/ 目录下的健康检查器
schedule_health_check(tsol_health_checker, 180)
schedule_health_check(solscan_v1_health_checker, 180)
schedule_health_check(solscan_v2_health_checker, 180)
schedule_health_check(hsk_health_checker, 180)
schedule_health_check(tbtc4_health_checker, 180)
schedule_health_check(zircuit_health_checker, 180)
schedule_health_check(sui_new_health_checker, 180)
schedule_health_check(panora_health_checker, 180)

-- gas 相关的健康检查器
if btc_gas_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing btc gas checker...")
    btc_gas_checker.init_backends()
end

if dash_gas_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing dash gas checker...")
    dash_gas_checker.init_backends()
end

if ltc_gas_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing ltc gas checker...")
    ltc_gas_checker.init_backends()
end

if mempool_gas_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing mempool gas checker...")
    mempool_gas_checker.init_backends()
end

if mempool_signet_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing mempool signet checker...")
    mempool_signet_checker.init_backends()
end

if mempool_testnet_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing mempool testnet checker...")
    mempool_testnet_checker.init_backends()
end

if socket_checker.init_backends then
    ngx.log(ngx.INFO, "Initializing socket checker...")
    socket_checker.init_backends()
end

-- 设置定时健康检查
if btc_gas_checker.check_backends_health then schedule_health_check(btc_gas_checker, 180) end
if dash_gas_checker.check_backends_health then schedule_health_check(dash_gas_checker, 180) end
if ltc_gas_checker.check_backends_health then schedule_health_check(ltc_gas_checker, 180) end
if mempool_gas_checker.check_backends_health then schedule_health_check(mempool_gas_checker, 180) end
if mempool_signet_checker.check_backends_health then schedule_health_check(mempool_signet_checker, 180) end
if mempool_testnet_checker.check_backends_health then schedule_health_check(mempool_testnet_checker, 180) end
if socket_checker.check_backends_health then schedule_health_check(socket_checker, 180) end
