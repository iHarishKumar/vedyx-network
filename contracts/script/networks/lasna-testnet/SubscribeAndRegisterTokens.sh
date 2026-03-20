#!/bin/bash

# Script to subscribe VedyxRSC to all mock tokens
# Usage: ./script/networks/lasna-testnet/SubscribeTokens.sh

set -e

# Configuration
DETECTOR_ADDR="0x5920Fa3964dc10BB7bdEA2f9cB01D21362C91aDd"
TOKEN_REG="0xd0c283b6949620eA0BF99E5237dA65E5D46671ED"
ORIGIN_CHAIN_ID="1301"
TRANSFER_TOPIC="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
RPC_URL="https://lasna-rpc.rnk.dev/"
ACCOUNT="harish-reactive-testing"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Subscribe VedyxRSC to Token Events${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Detector: ${GREEN}${DETECTOR_ADDR}${NC}"
echo -e "Origin Chain: ${GREEN}${ORIGIN_CHAIN_ID}${NC}"
echo -e "TokenRegistry: ${GREEN}${TOKEN_REG}${NC}"
echo ""

# Read tokens from deployment file
DEPLOYMENT_FILE="./deployments/unichain-sepolia/deployment.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo -e "${YELLOW}Error: Deployment file not found at $DEPLOYMENT_FILE${NC}"
    exit 1
fi

# Extract token addresses using jq
USDC=$(jq -r '.mockTokens.USDC' "$DEPLOYMENT_FILE")
USDT=$(jq -r '.mockTokens.USDT' "$DEPLOYMENT_FILE")
WETH=$(jq -r '.mockTokens.WETH' "$DEPLOYMENT_FILE")
DAI=$(jq -r '.mockTokens.DAI' "$DEPLOYMENT_FILE")

# Array of tokens
declare -a TOKENS=("$USDC" "$USDT" "$WETH" "$DAI")
declare -a TOKEN_NAMES=("USDC" "USDT" "WETH" "DAI")

echo -e "${BLUE}Tokens to subscribe:${NC}"
for i in "${!TOKENS[@]}"; do
    echo -e "  ${TOKEN_NAMES[$i]}: ${GREEN}${TOKENS[$i]}${NC}"
done
echo ""

# Subscribe to each token
for i in "${!TOKENS[@]}"; do
    TOKEN="${TOKENS[$i]}"
    NAME="${TOKEN_NAMES[$i]}"
    
    echo -e "${BLUE}Subscribing to ${NAME}...${NC}"
    
    cast send "$DETECTOR_ADDR" \
        "subscribe(uint256,address,uint256)" \
        "$ORIGIN_CHAIN_ID" \
        "$TOKEN" \
        "$TRANSFER_TOPIC" \
        --rpc-url "$RPC_URL" \
        --account "$ACCOUNT"
    
    echo -e "${GREEN}✓ Subscribed to ${NAME}${NC}"
    echo ""

    echo -e "${BLUE}Adding to Token Registry..."
    
    # # Fetch token decimals and symbol from the ERC20 contract on origin chain
    # ORIGIN_RPC="https://sepolia.unichain.org"
    # DECIMALS=$(cast call "$TOKEN" "decimals()(uint8)" --rpc-url "$ORIGIN_RPC")
    # SYMBOL=$(cast call "$TOKEN" "symbol()(string)" --rpc-url "$ORIGIN_RPC")
    
    # echo -e "  Decimals: ${YELLOW}${DECIMALS}${NC}"
    # echo -e "  Symbol: ${YELLOW}${SYMBOL}${NC}"
    
    # cast send "$TOKEN_REG" \
    #     "configureToken(address,uint8,string)" \
    #     "$TOKEN" \
    #     "$DECIMALS" \
    #     "$SYMBOL" \
    #     --rpc-url "$RPC_URL" \
    #     --account "$ACCOUNT"
    
    # echo -e "${GREEN}✓ Added ${SYMBOL} to Token Registry${NC}"
    # echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All subscriptions complete!${NC}"
echo -e "${GREEN}========================================${NC}"