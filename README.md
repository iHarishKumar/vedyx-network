# Vedyx Protocol

> **Decentralized Threat Detection & Community-Driven Security for DeFi**

Vedyx is a cross-chain security protocol that combines **real-time exploit detection** on Reactive Network with **community-driven validation** on destination chains. The protocol monitors suspicious on-chain activity, enables stake-based voting on flagged addresses, and integrates risk assessments into DeFi protocols through dynamic fee mechanisms.

---

## 🎯 Overview

Vedyx Protocol consists of three core modules working together to create a comprehensive security layer for DeFi:

1. **Reactive Detectors** - Real-time exploit pattern detection on Reactive Network
2. **Voting Contract** - Community-driven validation with stake-based governance
3. **Risk Engine & Uniswap V4 Hook** - Risk-based fee management and access control

### Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ORIGIN CHAIN (e.g., Ethereum)                         │
│                                                                           │
│  ┌──────────────────┐         ┌──────────────────┐                      │
│  │  Exploit Occurs  │         │  Large Transfer  │                      │
│  │  or Suspicious   │────────▶│  Mixer Usage     │                      │
│  │  Activity        │         │  Flash Loan      │                      │
│  └──────────────────┘         └──────────────────┘                      │
│                                        │                                  │
└────────────────────────────────────────┼──────────────────────────────────┘
                                         │ Event Logs
                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       REACTIVE NETWORK                                   │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              VedyxExploitDetectorRSC (Singleton)               │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │  Detector Registry (Modular & Pluggable)             │     │    │
│  │  │  • LargeTransferDetector                             │     │    │
│  │  │  • MixerInteractionDetector                          │     │    │
│  │  │  • TracePeelChainDetector                            │     │    │
│  │  │  • [Future: FlashLoan, Reentrancy, etc.]            │     │    │
│  │  └──────────────────────────────────────────────────────┘     │    │
│  │                                                                 │    │
│  │  react(log) → detect() → emit Callback                        │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                         │                                │
└─────────────────────────────────────────┼────────────────────────────────┘
                                          │ Callback
                                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                  DESTINATION CHAIN (e.g., Ethereum, Polygon)             │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                   VedyxVotingContract                          │    │
│  │                                                                 │    │
│  │  tagSuspicious() ← Receives callback from Reactive Network    │    │
│  │         │                                                       │    │
│  │         ├─ Has Suspicious Verdict? → Auto-Mark (87% gas save) │    │
│  │         └─ No/Clean Verdict? → Create Community Voting        │    │
│  │                                                                 │    │
│  │  Voting Process:                                               │    │
│  │  • Stake-weighted voting (7 days)                             │    │
│  │  • Karma-based reputation system                              │    │
│  │  • Penalty for incorrect votes (10% stake slash)              │    │
│  │  • Rewards for correct votes (karma + tokens)                 │    │
│  │                                                                 │    │
│  │  finalizeVoting() → Record Verdict                            │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                         │                                │
│                                         ▼                                │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    VedyxRiskEngine                             │    │
│  │                                                                 │    │
│  │  getRiskAssessment() → Calculate Risk Score (0-100)           │    │
│  │  • Verdict Score (0-40)                                        │    │
│  │  • Incident History (0-20)                                     │    │
│  │  • Detector Severity (0-20)                                    │    │
│  │  • Voting Consensus (0-10)                                     │    │
│  │  • Time Recency (0-10)                                         │    │
│  │                                                                 │    │
│  │  Risk Levels: SAFE | LOW | MEDIUM | HIGH | CRITICAL           │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                         │                                │
│                                         ▼                                │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              VedyxRiskHook (Uniswap V4)                        │    │
│  │                                                                 │    │
│  │  beforeSwap() → Query Risk Engine                             │    │
│  │         │                                                       │    │
│  │         ├─ SAFE: 1% fee                                        │    │
│  │         ├─ LOW: 3% fee                                         │    │
│  │         ├─ MEDIUM: 8% fee                                      │    │
│  │         ├─ HIGH: 15% fee or BLOCKED                           │    │
│  │         └─ CRITICAL: 30% fee or BLOCKED                       │    │
│  │                                                                 │    │
│  │  beforeAddLiquidity() → Block HIGH/CRITICAL risk users        │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Modules

### 1. Reactive Detectors (Reactive Network)

**Location**: [`contracts/src/reactive-contracts/`](./contracts/src/reactive-contracts/)

Real-time exploit detection using a singleton architecture with pluggable detector modules.

**Key Features**:
- 🔌 **Modular Registry**: Hot-swappable detection strategies
- ⚡ **Real-Time Monitoring**: Instant threat detection across multiple chains
- 🎯 **Topic-Based Routing**: Efficient event filtering and delegation
- 🔧 **Pluggable Detectors**: Add new attack vectors without redeploying

**Current Detectors**:
- `LargeTransferDetector` - Flags unusually large token transfers
- `MixerInteractionDetector` - Detects interaction with known mixers (Tornado Cash, etc.)
- `TracePeelChainDetector` - Identifies peel chain patterns (common in fund laundering)

**Documentation**: [Reactive Contracts README](./contracts/src/reactive-contracts/README.md)

---

### 2. Voting Contract (Destination Chain)

**Location**: [`contracts/src/voting-contract/`](./contracts/src/voting-contract/)

Community-driven validation system with stake-based voting and intelligent repeat offender handling.

**Key Features**:
- 🗳️ **Stake-Weighted Voting**: Voting power based on staked tokens + karma
- 🎖️ **Karma System**: Reputation tracking with exponential penalties for bad actors
- ⚖️ **Auto-Classification**: Repeat offenders auto-marked (87% gas savings)
- 💰 **Economic Incentives**: Penalties for wrong votes, rewards for correct votes
- 🛡️ **Self-Voting Prevention**: Users cannot vote on their own addresses
- 🔐 **Role-Based Access Control**: Governance, parameter admin, treasury roles

**Core Mechanics**:
- **First Offense**: Community voting (7 days) → Verdict recorded
- **Repeat Offender**: Auto-marked suspicious (no voting needed)
- **Clean Verdict**: Fresh evaluation with new evidence
- **Voting Power**: `stake + karma_bonus` or `stake - karma_penalty²`

**Documentation**: [Voting Contract README](./contracts/src/voting-contract/README.md)

---

### 3. Risk Engine & Uniswap V4 Hook (Destination Chain)

**Location**: [`contracts/src/risk-engine/`](./contracts/src/risk-engine/) & [`contracts/src/uniswap-v4-hook/`](./contracts/src/uniswap-v4-hook/)

Risk assessment engine and Uniswap V4 integration for dynamic fee management and access control.

**Risk Engine Features**:
- 📊 **Multi-Factor Scoring**: Combines 5 risk factors (0-100 scale)
- 🎯 **Risk Categorization**: SAFE, LOW, MEDIUM, HIGH, CRITICAL
- 🔄 **Real-Time Updates**: Queries voting contract for latest verdicts
- 📈 **Time Decay**: Recent incidents weighted more heavily

**Uniswap V4 Hook Features**:
- 💸 **Dynamic Swap Fees**: 1-30% based on user risk level
- 🚫 **Risk-Based Blocking**: Prevents HIGH/CRITICAL users from swapping
- 🔒 **Liquidity Protection**: Stricter blocking for liquidity provision
- ⚙️ **Configurable Policies**: Owner-controlled fee tiers and blocking rules

**Fee Structure**:
| Risk Level | Score | Swap Fee | Liquidity Access |
|------------|-------|----------|------------------|
| SAFE       | 0     | 1%       | ✅ Full Access   |
| LOW        | 1-29  | 3%       | ✅ Full Access   |
| MEDIUM     | 30-49 | 8%       | ✅ Full Access   |
| HIGH       | 50-69 | 15%      | ❌ Blocked       |
| CRITICAL   | 70+   | 30%      | ❌ Blocked       |

**Documentation**: 
- [Risk Engine README](./contracts/src/risk-engine/README.md)
- [Uniswap V4 Hook README](./contracts/src/uniswap-v4-hook/README.md)

---

### 4. Frontend (Next.js)

**Location**: [`frontend/`](./frontend/)

User interface for interacting with the Vedyx Protocol.

**Features**:
- 📊 Dashboard for viewing active votings and verdicts
- 🗳️ Voting interface for stakers
- 📈 Risk score visualization
- 🔍 Address lookup and history

**Documentation**: [Frontend README](./frontend/README.md)

---

### 5. Indexer (The Graph)

**Location**: [`indexer/`](./indexer/)

Subgraph for indexing voting contract events and providing efficient data queries.

**Indexed Data**:
- Voting history and results
- Staker information and karma scores
- Address verdicts and incident counts
- Reward and penalty distributions

**Documentation**: [Indexer README](./indexer/README.md)

---

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (for Solidity development)
- [Node.js](https://nodejs.org/) v18+ (for frontend and indexer)
- [pnpm](https://pnpm.io/) (for package management)

### Installation

```bash
# Clone the repository
git clone https://github.com/vedyx/vedyx-protocol.git
cd vedyx-protocol

# Install contract dependencies
cd contracts
forge install

# Install frontend dependencies
cd ../frontend
pnpm install

# Install indexer dependencies
cd ../indexer
npm install
```

### Running Tests

```bash
# Run all contract tests
cd contracts
forge test

# Run specific test file
forge test --match-contract VedyxVotingContractTest

# Run with gas reporting
forge test --gas-report

# Run with detailed traces
forge test -vvv
```

### Deployment

```bash
# Deploy to testnet (configure .env first)
cd contracts
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --verify

# Deploy frontend
cd ../frontend
pnpm build
pnpm start
```

---

## 📐 Architecture Diagrams

Detailed visual diagrams are available in the [`docs/diagrams/`](./docs/diagrams/) folder:

- **[Overall Architecture](./docs/diagrams/overall-architecture.md)** - Complete system architecture with all components and data flow
- **[Detection Flow](./docs/diagrams/detection-flow.md)** - Reactive Network detection process and detector interaction
- **[Voting Flow](./docs/diagrams/voting-flow.md)** - Community validation, karma system, and reward distribution
- **[Risk Assessment](./docs/diagrams/risk-assessment.md)** - Multi-factor risk scoring and Uniswap V4 integration
- **[Data Flow](./docs/diagrams/data-flow.md)** - State management, storage patterns, and event emission

All diagrams use Mermaid syntax and can be viewed directly on GitHub or in any Mermaid-compatible viewer.

---

## 🏗️ How It Works

### 1. Detection Phase (Reactive Network)

1. **Event Monitoring**: Reactive Network captures events from origin chains (Ethereum, Polygon, etc.)
2. **Pattern Analysis**: `VedyxExploitDetectorRSC` routes events to registered detectors
3. **Threat Detection**: Detectors analyze patterns (large transfers, mixer usage, peel chains)
4. **Callback Emission**: Suspicious addresses sent to destination chain voting contract

### 2. Validation Phase (Destination Chain)

1. **Callback Reception**: `VedyxVotingContract` receives suspicious address from Reactive Network
2. **Verdict Check**: 
   - **Repeat Offender**: Auto-marked suspicious (no voting)
   - **New/Clean**: Community voting created
3. **Stake-Based Voting**: Community members vote (weighted by stake + karma)
4. **Finalization**: After 7 days, voting finalized and verdict recorded
5. **Rewards/Penalties**: Correct voters rewarded, incorrect voters penalized

### 3. Risk Assessment Phase (Destination Chain)

1. **Risk Calculation**: `VedyxRiskEngine` calculates risk score (0-100) based on:
   - Community verdict (0-40 points)
   - Incident history (0-20 points)
   - Detector severity (0-20 points)
   - Voting consensus (0-10 points)
   - Time recency (0-10 points)
2. **Risk Categorization**: Score mapped to risk level (SAFE → CRITICAL)

### 4. Integration Phase (DeFi Protocols)

1. **Hook Invocation**: Uniswap V4 calls `VedyxRiskHook.beforeSwap()`
2. **Risk Query**: Hook queries `VedyxRiskEngine` for user's risk level
3. **Dynamic Response**:
   - **Fee Adjustment**: Higher fees for riskier users (1-30%)
   - **Blocking**: HIGH/CRITICAL users blocked from swaps/liquidity
4. **Transaction Execution**: User pays dynamic fee or transaction reverts

---

## 🔑 Key Innovations

### 1. Intelligent Repeat Offender Handling
- **87% gas savings** by auto-marking repeat offenders
- No redundant voting for known bad actors
- Fresh evaluation possible for cleared addresses

### 2. Karma-Based Reputation System
- **Linear bonus** for positive karma (+1% per 100 karma)
- **Exponential penalty** for negative karma (karma²)
- **Recovery mechanism** through correct votes
- **Hard threshold** at -50 karma blocks voting

### 3. Modular Detector Architecture
- **Hot-swappable** detection strategies
- **Topic-based routing** for efficient filtering
- **Independent lifecycle** for each detector
- **No redeployment** needed for new attack vectors

### 4. Cross-Chain Security Layer
- **Real-time monitoring** across multiple EVM chains
- **Centralized threat aggregation** on Reactive Network
- **Unified risk scores** across all chains
- **Consistent enforcement** in DeFi protocols

---

## 📊 Testing

The protocol includes comprehensive test coverage:

- **336 total tests** across all modules
- **Unit tests** for individual components
- **Integration tests** for cross-module interactions
- **Fuzz tests** for edge cases and invariants
- **Gas optimization tests** for efficiency

```bash
# Run all tests
forge test

# View test coverage
forge coverage

# Run specific test suite
forge test --match-contract VedyxVotingContractTest
forge test --match-contract VedyxRiskHookTest
forge test --match-contract TracePeelChainDetectorTest
```

---

## 🛠️ Development

### Project Structure

```
vedyx-protocol/
├── contracts/              # Smart contracts (Foundry)
│   ├── src/
│   │   ├── reactive-contracts/    # Reactive Network detectors
│   │   ├── voting-contract/       # Community voting system
│   │   ├── risk-engine/           # Risk assessment engine
│   │   └── uniswap-v4-hook/       # Uniswap V4 integration
│   ├── test/              # Contract tests
│   └── script/            # Deployment scripts
├── frontend/              # Next.js frontend
├── indexer/               # The Graph subgraph
└── README.md             # This file
```

### Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for details.

### Security

For security concerns, please email: security@vedyx.io

**Bug Bounty**: Coming soon

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## 🔗 Links

- **Documentation**: [docs.vedyx.io](https://docs.vedyx.io) (Coming soon)
- **Website**: [vedyx.io](https://vedyx.io) (Coming soon)
- **Twitter**: [@VedyxProtocol](https://twitter.com/VedyxProtocol) (Coming soon)
- **Discord**: [discord.gg/vedyx](https://discord.gg/vedyx) (Coming soon)

---

## 🙏 Acknowledgments

- **Reactive Network** for the reactive smart contract infrastructure
- **Uniswap V4** for the hooks architecture
- **OpenZeppelin** for secure contract libraries
- **Foundry** for the development framework

---

**Built with ❤️ by the Vedyx Team**
