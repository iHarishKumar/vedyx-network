# Vedyx Protocol Indexer

A Graph Protocol indexer for the Vedyx Protocol that tracks voting, staking, address verdicts, and all governance activities.

## Overview

This indexer monitors the `VedyxVotingContract` and indexes all events related to:
- **Staking & Unstaking**: Track user stakes and locked amounts
- **Voting Sessions**: Monitor voting creation, votes cast, and finalization
- **Address Verdicts**: Track suspicious address verdicts and auto-marking
- **Karma System**: Monitor voter accuracy and karma changes
- **Fees & Rewards**: Track fee collection and reward distribution
- **Parameter Updates**: Monitor governance parameter changes

## Schema Entities

### Core Entities
- **Staker**: User staking information with karma and voting history
- **Voting**: Complete voting session data with all votes
- **Vote**: Individual vote records with power and outcomes
- **AddressVerdict**: Historical verdicts for suspicious addresses

### Event Entities
- **StakeEvent / UnstakeEvent**: Staking activity logs
- **AutoMarkEvent**: Auto-marking of repeat offenders
- **VerdictClearedEvent**: Governance verdict overrides
- **FeeCollectedEvent**: Fee collection records
- **FinalizationReward**: Finalization reward payments
- **ParameterUpdate**: Governance parameter changes

### Analytics
- **GlobalStats**: Protocol-wide statistics and metrics

## Setup

### Prerequisites
- Node.js v18+
- Graph CLI
- Access to an Ethereum node (Infura, Alchemy, etc.)

### Installation

1. **Install dependencies** (requires approval):
```bash
npm install
```

2. **Add the contract ABI**:
   - Copy your compiled `VedyxVotingContract.json` ABI to `./abis/VedyxVotingContract.json`

3. **Update configuration**:
   - Edit `subgraph.yaml`:
     - Set the correct `network` (mainnet, sepolia, unichain-sepolia, etc.)
     - Set the deployed contract `address`
     - Set the deployment `startBlock`

4. **Generate types**:
```bash
npm run codegen
```

5. **Build the subgraph**:
```bash
npm run build
```

## Deployment

### The Graph Studio (Hosted Service)

1. Create a subgraph at [The Graph Studio](https://thegraph.com/studio/)
2. Get your deploy key
3. Authenticate:
```bash
graph auth --studio <DEPLOY_KEY>
```
4. Deploy:
```bash
npm run deploy
```

### Local Graph Node

1. Start a local Graph Node (requires Docker)
2. Create the subgraph:
```bash
npm run create-local
```
3. Deploy locally:
```bash
npm run deploy-local
```

## Queries

### Example GraphQL Queries

#### Get all stakers with their stats
```graphql
{
  stakers(first: 10, orderBy: stakedAmount, orderDirection: desc) {
    id
    address
    stakedAmount
    karmaPoints
    totalVotes
    correctVotes
  }
}
```

#### Get active votings
```graphql
{
  votings(where: { finalized: false }) {
    id
    votingId
    suspiciousAddress
    votesFor
    votesAgainst
    endTime
  }
}
```

#### Get address verdict history
```graphql
{
  addressVerdict(id: "0x...") {
    address
    hasVerdict
    isSuspicious
    totalIncidents
    votings {
      votingId
      isSuspicious
      finalized
    }
  }
}
```

#### Get global statistics
```graphql
{
  globalStats(id: "global") {
    totalStakers
    totalStaked
    totalVotings
    totalSuspiciousVerdicts
    totalCleanVerdicts
    totalFeesCollected
  }
}
```

## Development

### Testing
```bash
npm run test
```

### Rebuild after changes
```bash
npm run codegen
npm run build
```

## Network Configuration

Update `subgraph.yaml` for different networks:

### Unichain Sepolia
```yaml
network: unichain-sepolia
source:
  address: "YOUR_CONTRACT_ADDRESS"
  startBlock: YOUR_START_BLOCK
```

### Ethereum Mainnet
```yaml
network: mainnet
source:
  address: "YOUR_CONTRACT_ADDRESS"
  startBlock: YOUR_START_BLOCK
```

## Features

✅ **Real-time indexing** of all voting contract events  
✅ **Historical data** for all addresses and votings  
✅ **Karma tracking** for voter accuracy  
✅ **Auto-mark detection** for repeat offenders  
✅ **Fee and reward analytics**  
✅ **Parameter change history**  
✅ **Global protocol statistics**  

## Support

For issues or questions:
- Check the [Graph Protocol Documentation](https://thegraph.com/docs/)
- Review the Vedyx Protocol contracts in `/contracts`
- Open an issue in the repository

## License

MIT
