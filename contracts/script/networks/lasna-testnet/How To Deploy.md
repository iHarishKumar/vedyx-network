# Lasna Testnet Deployment Guide

This directory contains split deployment scripts to avoid the EIP-3860 initcode size limit (49,152 bytes).

## Deployment Steps

Run these scripts **in order**:

### 1. Deploy TokenRegistry
```bash
forge script script/networks/lasna-testnet/01_DeployRegistry.s.sol:DeployRegistry \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --account harish-reactive-testing \
  --broadcast
```

### 2. Deploy Detectors
```bash
forge script script/networks/lasna-testnet/02_DeployDetectors.s.sol:DeployDetectors \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --account harish-reactive-testing \
  --broadcast
```

### 3. Deploy VedyxRSC and Register Detectors
```bash
forge script script/networks/lasna-testnet/03_DeployVedyxRSC.s.sol:DeployVedyxRSC \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --account harish-reactive-testing \
  --broadcast
```

### 4. Subscribe to Token Events
```bash
./script/networks/lasna-testnet/SubscribeAndRegisterTokens.sh
```

## Prerequisites

- Voting contract must be deployed on Unichain Sepolia
- Mock tokens should be deployed on Unichain Sepolia
- Deployment file at `./deployments/unichain-sepolia/deployment.json` should exist

## Environment Variables (Optional)

If deployment files are not available:

```bash
export VOTING_CONTRACT_ADDRESS=0x...
export TOKEN_1=0x...
export TOKEN_2=0x...
# etc.
```

## Why Split Scripts?

The original `DeployLasnaTestnet.s.sol` exceeded the EIP-3860 initcode size limit (49,152 bytes) because it deployed all contracts in a single transaction. Splitting into 3 separate scripts keeps each deployment under the limit.
