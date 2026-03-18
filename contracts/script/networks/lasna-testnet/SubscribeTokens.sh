#!/bin/bash

# Script to subscribe VedyxRSC to all mock tokens
# Usage: ./script/networks/lasna-testnet/SubscribeTokens.sh

set -e

# Configuration
VEDYX_RSC="0x4A85DFB50782BBd8Fc3f94AbF2A6C585070B1420"
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
echo -e "VedyxRSC: ${GREEN}${VEDYX_RSC}${NC}"
echo -e "Origin Chain: ${GREEN}${ORIGIN_CHAIN_ID}${NC}"
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
    
    cast send "$VEDYX_RSC" \
        "subscribe(uint256,address,uint256)" \
        "$ORIGIN_CHAIN_ID" \
        "$TOKEN" \
        "$TRANSFER_TOPIC" \
        --rpc-url "$RPC_URL" \
        --account "$ACCOUNT"
    
    echo -e "${GREEN}✓ Subscribed to ${NAME}${NC}"
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All subscriptions complete!${NC}"
echo -e "${GREEN}========================================${NC}"
