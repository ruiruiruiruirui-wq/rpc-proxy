#!/bin/bash

# Ethereum RPC Proxy Test Suite in Shell
# Tests various ETH RPC methods through the OneKey proxy using curl
# Usage: ./test/chain/eth.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.json"
TEMP_DIR="/tmp/eth_test_$$"
mkdir -p "$TEMP_DIR"

# Load configuration from JSON file
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Config file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    BASE_URL=$(jq -r '.base_url' "$CONFIG_FILE")
    TIMEOUT=$(jq -r '.timeout' "$CONFIG_FILE")
    TEST_ACCOUNT=$(jq -r '.test_account' "$CONFIG_FILE")
    
    if [[ "$BASE_URL" == "null" || "$TIMEOUT" == "null" || "$TEST_ACCOUNT" == "null" ]]; then
        echo -e "${RED}❌ Invalid config file format${NC}"
        exit 1
    fi
    
    ETH_URL="$BASE_URL/eth/"
    REQUEST_ID=1
}

# Helper function to make RPC calls
make_rpc_call() {
    local method="$1"
    local params="$2"
    local response_file="$TEMP_DIR/response_${REQUEST_ID}.json"
    
    # Default empty params if not provided
    [[ -z "$params" ]] && params="[]"
    
    # Build JSON-RPC payload
    local payload=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "$method",
    "params": $params,
    "id": $REQUEST_ID
}
EOF
)
    
    # Make curl request
    local start_time=$(date +%s.%N)
    local http_code=$(curl -s -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --request POST \
        --url "$ETH_URL" \
        --header "Content-Type: application/json" \
        --header "User-Agent: OneKey-ETH-RPC-Tester-Shell/1.0" \
        --data "$payload" \
        --output "$response_file")
    local end_time=$(date +%s.%N)
    
    # Calculate response time
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Check HTTP status
    if [[ "$http_code" != "200" ]]; then
        echo -e "${RED}❌ HTTP request failed with status: $http_code${NC}"
        return 1
    fi
    
    # Check if response is valid JSON
    if ! jq . "$response_file" > /dev/null 2>&1; then
        echo -e "${RED}❌ Invalid JSON response${NC}"
        return 1
    fi
    
    # Return response file path and time
    echo "$response_file:$response_time"
    REQUEST_ID=$((REQUEST_ID + 1))
}

# Helper function to convert hex to decimal
hex_to_dec() {
    local hex="$1"
    if [[ "$hex" =~ ^0x[0-9a-fA-F]+$ ]]; then
        echo $((hex))
    else
        echo "0"
    fi
}

# Helper function to check if string is valid hex
is_hex_string() {
    local str="$1"
    [[ "$str" =~ ^0x[0-9a-fA-F]*$ ]]
}

# Helper function to check if address is valid
is_valid_address() {
    local addr="$1"
    [[ "$addr" =~ ^0x[0-9a-fA-F]{40}$ ]]
}

# Test function template
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    echo -e "\n${BLUE}Testing: $test_name${NC}"
    
    if $test_func; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        return 1
    fi
}

# Test: Get current block number
test_block_number() {
    local result=$(make_rpc_call "eth_blockNumber")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local block_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$block_hex"; then
        echo "  Invalid hex string: $block_hex"
        return 1
    fi
    
    local block_dec=$(hex_to_dec "$block_hex")
    if [[ "$block_dec" -le 0 ]]; then
        echo "  Invalid block number: $block_dec"
        return 1
    fi
    
    echo "  ✓ eth_blockNumber: $block_hex (decimal: $block_dec)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get chain ID
test_chain_id() {
    local result=$(make_rpc_call "eth_chainId")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local chain_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$chain_hex"; then
        echo "  Invalid hex string: $chain_hex"
        return 1
    fi
    
    local chain_dec=$(hex_to_dec "$chain_hex")
    if [[ "$chain_dec" -ne 1 ]]; then
        echo "  Expected chain ID 1, got: $chain_dec"
        return 1
    fi
    
    echo "  ✓ eth_chainId: $chain_hex (decimal: $chain_dec)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get network version
test_network_version() {
    local result=$(make_rpc_call "net_version")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local version=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if [[ "$version" != "1" ]]; then
        echo "  Expected network version 1, got: $version"
        return 1
    fi
    
    echo "  ✓ net_version: $version"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get gas price
test_gas_price() {
    local result=$(make_rpc_call "eth_gasPrice")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local price_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$price_hex"; then
        echo "  Invalid hex string: $price_hex"
        return 1
    fi
    
    local price_dec=$(hex_to_dec "$price_hex")
    if [[ "$price_dec" -le 0 ]]; then
        echo "  Invalid gas price: $price_dec"
        return 1
    fi
    
    # Convert to Gwei (1 Gwei = 1e9 Wei)
    local price_gwei=$(echo "scale=2; $price_dec / 1000000000" | bc -l)
    
    echo "  ✓ eth_gasPrice: $price_hex ($price_gwei Gwei)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get account balance
test_account_balance() {
    local params='["'$TEST_ACCOUNT'", "latest"]'
    local result=$(make_rpc_call "eth_getBalance" "$params")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local balance_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$balance_hex"; then
        echo "  Invalid hex string: $balance_hex"
        return 1
    fi
    
    local balance_dec=$(hex_to_dec "$balance_hex")
    if [[ "$balance_dec" -lt 0 ]]; then
        echo "  Invalid balance: $balance_dec"
        return 1
    fi
    
    # Convert to ETH (1 ETH = 1e18 Wei)
    local balance_eth=$(echo "scale=6; $balance_dec / 1000000000000000000" | bc -l)
    
    echo "  ✓ eth_getBalance (latest): $balance_hex ($balance_eth ETH)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get transaction count
test_transaction_count() {
    local params='["'$TEST_ACCOUNT'", "latest"]'
    local result=$(make_rpc_call "eth_getTransactionCount" "$params")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local count_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$count_hex"; then
        echo "  Invalid hex string: $count_hex"
        return 1
    fi
    
    local count_dec=$(hex_to_dec "$count_hex")
    if [[ "$count_dec" -lt 0 ]]; then
        echo "  Invalid transaction count: $count_dec"
        return 1
    fi
    
    echo "  ✓ eth_getTransactionCount: $count_hex (decimal: $count_dec)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get latest block
test_latest_block() {
    local params='["latest", false]'
    local result=$(make_rpc_call "eth_getBlockByNumber" "$params")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local block=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if [[ "$block" == "null" ]]; then
        echo "  Block not found"
        return 1
    fi
    
    local block_number=$(jq -r '.result.number' "$response_file")
    local block_hash=$(jq -r '.result.hash' "$response_file")
    local tx_count=$(jq -r '.result.transactions | length' "$response_file")
    
    if ! is_hex_string "$block_number" || ! is_hex_string "$block_hash"; then
        echo "  Invalid block data"
        return 1
    fi
    
    local block_dec=$(hex_to_dec "$block_number")
    
    echo "  ✓ eth_getBlockByNumber (latest): Block #$block_dec with $tx_count txs"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Estimate gas
test_estimate_gas() {
    local params='[{"from": "'$TEST_ACCOUNT'", "to": "0x0000000000000000000000000000000000000000", "value": "0x1"}]'
    local result=$(make_rpc_call "eth_estimateGas" "$params")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local gas_hex=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$gas_hex"; then
        echo "  Invalid hex string: $gas_hex"
        return 1
    fi
    
    local gas_dec=$(hex_to_dec "$gas_hex")
    if [[ "$gas_dec" -le 0 || "$gas_dec" -gt 1000000 ]]; then
        echo "  Invalid gas estimate: $gas_dec"
        return 1
    fi
    
    echo "  ✓ eth_estimateGas: $gas_hex (decimal: $gas_dec)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Get contract code (USDT)
test_contract_code() {
    local usdt_contract="0xdAC17F958D2ee523a2206206994597C13D831ec7"
    local params='["'$usdt_contract'", "latest"]'
    local result=$(make_rpc_call "eth_getCode" "$params")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local code=$(jq -r '.result' "$response_file")
    local error=$(jq -r '.error' "$response_file")
    
    if [[ "$error" != "null" ]]; then
        echo "  Error: $error"
        return 1
    fi
    
    if ! is_hex_string "$code"; then
        echo "  Invalid hex string: $code"
        return 1
    fi
    
    if [[ ${#code} -le 2 ]]; then
        echo "  No contract code found"
        return 1
    fi
    
    echo "  ✓ eth_getCode (USDT): Contract code found (${#code} chars)"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Test: Error handling - invalid method
test_error_handling() {
    local result=$(make_rpc_call "invalid_method")
    local response_file=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    local error=$(jq -r '.error' "$response_file")
    local result_data=$(jq -r '.result' "$response_file")
    
    if [[ "$error" == "null" ]]; then
        echo "  Expected error for invalid method"
        return 1
    fi
    
    if [[ "$result_data" != "null" ]]; then
        echo "  Unexpected result for invalid method"
        return 1
    fi
    
    local error_message=$(jq -r '.error.message' "$response_file")
    echo "  ✓ Invalid method error: $error_message"
    echo "  ✓ Response time: ${response_time}s"
    return 0
}

# Performance test: Multiple consecutive requests
test_performance() {
    local num_requests=5
    local total_time=0
    local success_count=0
    
    echo "  Testing $num_requests consecutive requests..."
    
    for i in $(seq 1 $num_requests); do
        local start_time=$(date +%s.%N)
        local result=$(make_rpc_call "eth_blockNumber")
        local end_time=$(date +%s.%N)
        
        local response_file=$(echo "$result" | cut -d: -f1)
        local error=$(jq -r '.error' "$response_file")
        
        if [[ "$error" == "null" ]]; then
            success_count=$((success_count + 1))
        fi
        
        local req_time=$(echo "$end_time - $start_time" | bc -l)
        total_time=$(echo "$total_time + $req_time" | bc -l)
    done
    
    local avg_time=$(echo "scale=3; $total_time / $num_requests" | bc -l)
    
    if [[ "$success_count" -ne "$num_requests" ]]; then
        echo "  Only $success_count/$num_requests requests succeeded"
        return 1
    fi
    
    echo "  ✓ Multiple requests: $num_requests requests in ${total_time}s (avg: ${avg_time}s)"
    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}🚀 Starting ETH RPC Proxy Tests (Shell)${NC}"
    
    # Load configuration
    load_config
    
    echo -e "${BLUE}📍 Endpoint: $ETH_URL${NC}"
    echo -e "${BLUE}👤 Test Account: $TEST_ACCOUNT${NC}"
    echo -e "${BLUE}⚙️  Config loaded from: $CONFIG_FILE${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
    
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is required but not installed. Please install it first.${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}❌ bc is required but not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Run tests
    local passed=0
    local failed=0
    
    # Basic RPC method tests
    echo -e "\n${YELLOW}📋 ETH RPC Basic Methods${NC}"
    run_test "Get current block number" test_block_number && passed=$((passed + 1)) || failed=$((failed + 1))
    run_test "Get chain ID" test_chain_id && passed=$((passed + 1)) || failed=$((failed + 1))
    run_test "Get network version" test_network_version && passed=$((passed + 1)) || failed=$((failed + 1))
    run_test "Get gas price" test_gas_price && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Account-related tests
    echo -e "\n${YELLOW}👤 ETH RPC Account Methods${NC}"
    run_test "Get account balance" test_account_balance && passed=$((passed + 1)) || failed=$((failed + 1))
    run_test "Get transaction count" test_transaction_count && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Block-related tests
    echo -e "\n${YELLOW}🧱 ETH RPC Block Methods${NC}"
    run_test "Get latest block" test_latest_block && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Transaction-related tests
    echo -e "\n${YELLOW}💸 ETH RPC Transaction Methods${NC}"
    run_test "Estimate gas" test_estimate_gas && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Contract-related tests
    echo -e "\n${YELLOW}📄 ETH RPC Contract Methods${NC}"
    run_test "Get contract code" test_contract_code && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Error handling tests
    echo -e "\n${YELLOW}⚠️  ETH RPC Error Handling${NC}"
    run_test "Handle invalid method" test_error_handling && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Performance tests
    echo -e "\n${YELLOW}🏃 ETH RPC Performance${NC}"
    run_test "Multiple consecutive requests" test_performance && passed=$((passed + 1)) || failed=$((failed + 1))
    
    # Test summary
    echo -e "\n${BLUE}$(printf '=%.0s' {1..60})${NC}"
    echo -e "${BLUE}📊 ETH RPC Shell Tests Completed${NC}"
    echo -e "${GREEN}✅ Passed: $passed${NC}"
    [[ $failed -gt 0 ]] && echo -e "${RED}❌ Failed: $failed${NC}" || echo -e "${GREEN}❌ Failed: $failed${NC}"
    echo -e "${BLUE}📋 Configuration loaded from: $CONFIG_FILE${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    # Exit with appropriate code
    [[ $failed -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"
