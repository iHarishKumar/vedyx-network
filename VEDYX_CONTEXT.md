# Vedyx Network - Complete Context for AI Assistants

## 🎯 Core Mission

**Vedyx is NOT an exploit prevention system. Vedyx is a post-exploit address tracking and cashout prevention platform.**

### What We Do
- Track addresses involved in exploits **after the exploit has occurred**
- Flag addresses attempting to cash out stolen funds through DEX pools or mixers
- Provide a one-stop dashboard for understanding exploit addresses and their on-chain activity
- Enable DeFi protocols to make informed decisions about suspicious addresses

### What We DON'T Do
- We do NOT prevent exploits from happening
- We do NOT detect exploits in real-time before they occur
- We do NOT block transactions before they execute

## 🧠 Key Insight: The Cashout Problem

### The Reality
Exploits happen in countless ways:
- Flash loan attacks
- Reentrancy vulnerabilities
- Price manipulation
- Oracle exploits
- Smart contract bugs

**Preventing all these is impossible.** Each exploit is unique.

### The Opportunity
**The real vulnerability is the cashout phase:**
- Attackers need to convert stolen assets to usable currency
- They must interact with DEX pools (Uniswap, etc.) or mixers (Tornado Cash)
- This creates detectable on-chain patterns
- **This is where Vedyx intervenes**

## 🛡️ Anti-Manipulation Design

### The Vote Buying Problem
**Question**: Can't attackers just buy votes to mark themselves as "not suspicious"?

**Answer**: Yes, but it's economically unfeasible:

1. **Stake-Weighted Voting**: More stake = More voting power
   - To manipulate votes, attackers need MASSIVE stake
   - If they acquire that much stake, they've essentially bought into the system
   - They become economically aligned with the protocol's success

2. **Economic Disincentives**:
   - Incorrect voters lose 10% of their stake
   - Penalties distributed to correct voters
   - Karma system tracks accuracy
   - Negative karma exponentially reduces voting power
   - Below -50 karma = blocked from voting

3. **The Cost-Benefit Analysis**:
   - Cost to manipulate: Acquire majority stake + risk 10% penalty + karma damage
   - Benefit: Mark one address as "not suspicious"
   - **Result**: Cheaper to just not exploit in the first place

## 🏗️ Architecture Overview

### Layer 1: Reactive Network (Monitoring)
**VedyxExploitDetectorRSC** - Monitors on-chain activity for suspicious patterns

**Current Detectors**:
- `LargeTransferDetector` - Flags abnormally large ERC20 transfers

**Future Detectors**:
- DEX swap pattern detector (rapid swaps, unusual routes)
- Cross-protocol fund movement tracker
- Mixer interaction detector (Tornado Cash, etc.)

**Important**: These detectors do NOT prevent transactions. They only flag suspicious patterns for community review.

### Layer 2: Destination Chain (Governance)
**VedyxVotingContract** - Modular governance contract

**Components**:
- `VedyxTypes.sol` - Data structures
- `VedyxErrors.sol` - Custom errors
- `VotingPowerLib.sol` - Voting power calculations with karma
- `VotingResultsLib.sol` - Penalty/reward distribution
- `IVedyxVoting.sol` - Contract interface

**Key Features**:
- Stake-weighted voting (not 1-person-1-vote)
- Karma system for voter accuracy tracking
- Economic penalties for incorrect votes
- Role-based access control (Governance, Parameter Admin, Treasury)

### Layer 3: Community Voting
**The Human Layer** - Stakers review evidence and vote

**Workflow**:
1. Suspicious pattern detected → Voting initiated
2. Community reviews on-chain evidence via dashboard
3. Stakers cast votes (weighted by stake × karma)
4. After voting period, consensus determined
5. Incorrect voters penalized, correct voters rewarded
6. Address verdict recorded with risk score

## 📊 Voting Power Calculation

```solidity
// Positive karma: Linear bonus
if (karma > 0) {
    votingPower = stake + (stake * karma / 1000)
}

// Negative karma: Exponential penalty
if (karma < 0) {
    penalty = stake * (karma^2) / 100000
    votingPower = stake - penalty
}

// Below threshold: Blocked
if (karma < -50) {
    votingPower = 0 // Cannot vote
}
```

**Example**:
- User with 1000 tokens, +50 karma: 1050 voting power
- User with 1000 tokens, -25 karma: ~994 voting power (6.25% penalty)
- User with 1000 tokens, -50 karma: 0 voting power (blocked)

## 🔄 Complete Post-Exploit Workflow

1. **Exploit Occurs** (Various attack vectors - we don't prevent this)
2. **Attacker Attempts Cashout** (DEX swaps, large transfers)
3. **Pattern Detection** (Reactive Network flags suspicious activity)
4. **Voting Initiated** (Address + evidence submitted to VedyxVotingContract)
5. **Community Analysis** (Stakers review on-chain data via dashboard)
6. **Stake-Weighted Voting** (Community votes on suspiciousness)
7. **Consensus Reached** (Voting power determines outcome, not vote count)
8. **Penalties Applied** (Incorrect voters lose 10% stake)
9. **Rewards Distributed** (Penalties go to correct voters minus 1% fee)
10. **Karma Updated** (Correct: +10, Incorrect: -5)
11. **Verdict Recorded** (Address flagged with risk score)
12. **Protocol Integration** (DeFi protocols query verdict and apply measures)

## 🎯 Use Cases for DeFi Protocols

### Uniswap V4 Hook Integration (Planned)
Protocols can query Vedyx verdicts and:

1. **Proportional Penalties**:
   - Low risk (1-3): Normal fees
   - Medium risk (4-6): 2x fees
   - High risk (7-10): 5x fees

2. **Complete Blocks**:
   - Addresses with high suspiciousness score blocked from certain pools
   - Especially important for high-value liquidity pools

3. **Dynamic Slippage**:
   - Suspicious addresses get worse slippage
   - Makes cashout more expensive and less efficient

4. **Circuit Breakers**:
   - Pause pools if flagged address attempts large swap
   - Give community time to review

## 📋 Key Data Structures

```solidity
struct Staker {
    uint256 stakedAmount;      // Total tokens staked
    uint256 lockedAmount;      // Locked during active votes
    int256 karmaPoints;        // Accuracy tracking
    uint256 totalVotes;        // Participation count
    uint256 correctVotes;      // Accuracy count
}

struct Voting {
    SuspiciousReport report;   // Address + evidence
    uint256 startTime;
    uint256 endTime;
    uint256 votesFor;          // Voting power for "suspicious"
    uint256 votesAgainst;      // Voting power for "not suspicious"
    bool finalized;
    bool isSuspicious;         // Consensus result
    address[] voters;
}

struct AddressVerdict {
    bool hasVerdict;
    bool isSuspicious;
    uint256 totalVotings;      // How many times voted on
    uint256 suspiciousCount;   // How many times marked suspicious
    uint256 lastVotingTime;
}
```

## 🎨 The Vedyx Dashboard (Planned)

**One-stop interface for address reputation:**

1. **Address Search**:
   - Enter any Ethereum address
   - See complete reputation history
   - View all voting sessions involving this address

2. **On-chain Evidence**:
   - Transaction history visualization
   - Large transfer timeline
   - DEX interaction patterns
   - Cross-protocol fund flows

3. **Voting History**:
   - All votes cast on this address
   - Voter distribution (stake-weighted)
   - Evidence submitted by community
   - Final verdict and risk score

4. **Risk Score Breakdown**:
   - Multiple factors (transfer patterns, voting consensus, etc.)
   - Historical behavior
   - Cross-chain activity
   - Mixer interactions

## 🔧 Configurable Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MINIMUM_STAKE` | 100 tokens | Required to vote |
| `VOTING_DURATION` | 3 days | Voting period length |
| `PENALTY_PERCENTAGE` | 10% | Stake loss for incorrect votes |
| `FINALIZATION_FEE_PERCENTAGE` | 1% | Treasury fee from penalties |
| `KARMA_REWARD` | +10 | Karma for correct vote |
| `KARMA_PENALTY` | -5 | Karma for incorrect vote |
| `MINIMUM_KARMA_TO_VOTE` | -50 | Karma threshold to participate |
| `AUTO_MARK_THRESHOLD` | 3 | Auto-flag after N suspicious verdicts |

## 🚀 Development Roadmap

### ✅ Phase 1: Core Infrastructure (COMPLETE)
- Modular voting contract architecture
- Stake-weighted voting with karma system
- Reactive Network monitoring (LargeTransferDetector)
- Economic disincentives for manipulation
- 134 tests passing

### 🔄 Phase 2: Dashboard & Detection (IN PROGRESS)
- **Vedyx Dashboard**:
  - Address reputation interface
  - On-chain activity visualization
  - Voting history and evidence display
  - Risk score calculation
- **Additional Detectors**:
  - DEX swap pattern detector
  - Cross-protocol fund movement tracker
  - Mixer interaction detector

### 📋 Phase 3: Protocol Integration (PLANNED)
- **Uniswap V4 Hooks**:
  - Risk-based fee adjustments
  - Pool access controls
  - Circuit breaker mechanisms
- **Advanced Risk Scoring**:
  - Multi-factor analysis
  - Machine learning patterns
  - Cross-chain aggregation

## 💡 Differentiators

1. **Post-Exploit Focus**: We don't compete with exploit prevention tools
2. **Community Consensus**: Not centralized blacklists
3. **Economic Security**: Vote manipulation is economically unfeasible
4. **Transparency**: All evidence and votes are on-chain
5. **Composability**: Any protocol can integrate our verdicts
6. **Cross-Chain**: Track addresses across multiple EVM chains
7. **One-Stop Dashboard**: Complete address reputation in one place

## ⚠️ Common Misconceptions

### ❌ "Vedyx prevents exploits"
**✅ Reality**: We track addresses AFTER exploits occur and prevent cashout

### ❌ "Vedyx detects exploits in real-time"
**✅ Reality**: We detect suspicious cashout patterns, not the exploit itself

### ❌ "Attackers can buy votes"
**✅ Reality**: Vote manipulation requires massive stake + risks penalties + karma damage

### ❌ "Vedyx is a security audit tool"
**✅ Reality**: We're an address reputation and cashout prevention platform

### ❌ "One person, one vote"
**✅ Reality**: Stake-weighted voting (more stake = more power)

## 📝 Important Notes for AI Assistants

When working on Vedyx:

1. **Always emphasize post-exploit focus** - We don't prevent exploits
2. **Highlight the cashout problem** - This is our unique angle
3. **Explain economic security** - Vote manipulation is too expensive
4. **Focus on the dashboard** - One-stop address reputation interface
5. **Emphasize composability** - Protocols can integrate our verdicts
6. **Don't oversell prevention** - We track and flag, not prevent

## 🔗 Key Files

- `/src/voting-contract/VedyxVotingContract.sol` - Main governance contract
- `/src/voting-contract/libraries/` - Modular libraries
- `/src/reactive-contracts/VedyxExploitDetectorRSC.sol` - Monitoring hub
- `/src/reactive-contracts/detectors/` - Pattern detectors
- `/test/` - 134 comprehensive tests
- `/README.md` - Updated with correct positioning

---

**Remember**: Vedyx is about **tracking exploit addresses and preventing cashout**, not preventing exploits themselves.
