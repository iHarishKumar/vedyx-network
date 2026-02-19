# Vedyx Voting Contract - Agent Documentation

## Agent Overview

**Agent Name**: VedyxVotingContract  
**Type**: Decentralized Governance Contract  
**Network**: Destination Chain (Ethereum, Polygon, etc.)  
**Pattern**: Stake-Based Voting with Verdict System  
**Purpose**: Community-driven validation of suspicious addresses with intelligent repeat offender handling

## Modular Architecture

The voting contract is built with a modular architecture:

```
src/voting-contract/
├── VedyxVotingContract.sol          # Main contract
├── interfaces/
│   └── IVedyxVoting.sol             # Contract interface
└── libraries/
    ├── VedyxErrors.sol              # Custom errors
    ├── VedyxTypes.sol               # Data structures
    ├── VotingPowerLib.sol           # Voting power calculations
    └── VotingResultsLib.sol         # Results processing
```

**See [voting-contract/README.md](./voting-contract/README.md) for detailed architecture documentation.**

## What This Agent Does

The VedyxVotingContract is a **governance agent** that:

1. **Receives Callbacks**: Accepts suspicious address reports from Reactive Network
2. **Manages Voting**: Creates and manages community voting processes
3. **Tracks Verdicts**: Records historical verdicts for addresses
4. **Auto-Classifies**: Automatically marks repeat offenders without re-voting
5. **Enforces Penalties**: Slashes stakes of incorrect voters
6. **Rewards Accuracy**: Distributes karma and token rewards to correct voters
7. **Prevents Manipulation**: Blocks self-voting and enforces minimum karma thresholds

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Reactive Network Callback                       │
│                       ↓                                      │
└─────────────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              VedyxVotingContract                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  tagSuspicious(address, chainId, ...)             │    │
│  │         ↓                                          │    │
│  │  Check AddressVerdict                              │    │
│  │    ├─ Has Suspicious Verdict → Auto-Mark          │    │
│  │    └─ No/Clean Verdict → Create Voting            │    │
│  └────────────────────────────────────────────────────┘    │
│                       ↓                                      │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Voting Process (if created)                       │    │
│  │    • Stakers cast votes (stake-weighted)           │    │
│  │    • Karma affects voting power                    │    │
│  │    • Self-voting prevented                         │    │
│  │    • Duration: 7 days (configurable)               │    │
│  └────────────────────────────────────────────────────┘    │
│                       ↓                                      │
│  ┌────────────────────────────────────────────────────┐    │
│  │  finalizeVoting(votingId)                          │    │
│  │    • Determine consensus                           │    │
│  │    • Record verdict                                │    │
│  │    • Apply penalties to wrong voters               │    │
│  │    • Distribute rewards to correct voters          │    │
│  │    • Update karma scores                           │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Staking System

**Purpose**: Users stake tokens to gain voting power

```solidity
// Defined in VedyxTypes library
struct Staker {
    uint256 stakedAmount;      // Total staked tokens
    int256 karmaPoints;        // Reputation score (can be negative)
    uint256 totalVotes;        // Total votes cast
    uint256 correctVotes;      // Correct votes count
    uint256 lockedAmount;      // Amount locked in active votes
}
```

**Features**:
- Minimum stake requirement (configurable)
- Locked amounts during active voting
- Unstaking only when no active votes
- No fees on staking/unstaking

### 2. Voting System

**Purpose**: Community votes on suspicious addresses

```solidity
// Defined in VedyxTypes library
struct Voting {
    uint256 votingId;
    SuspiciousReport report;
    uint256 startTime;
    uint256 endTime;
    uint256 votesFor;          // Votes confirming suspicious
    uint256 votesAgainst;      // Votes denying suspicious
    uint256 totalVotingPower;
    bool finalized;
    bool isSuspicious;         // Final verdict
    mapping(address => Vote) votes;
    address[] voters;
}
```

**Voting Power Calculation** (handled by `VotingPowerLib`):
```
Positive Karma: votingPower = stake + (stake × karma / 10000)
Negative Karma: votingPower = stake - (stake × karma² / 100000)
```

### 3. Verdict System

**Purpose**: Track historical verdicts and auto-classify repeat offenders

```solidity
// Defined in VedyxTypes library
struct AddressVerdict {
    bool hasVerdict;           // Has been judged before?
    bool isSuspicious;         // Last verdict (true = suspicious)
    uint256 lastVotingId;      // Most recent voting ID
    uint256 verdictTimestamp;  // When verdict was recorded
    uint256 totalIncidents;    // Total times tagged (never reset)
}
```

**Verdict Logic**:
- **First Offense**: Create voting → Community decides → Record verdict
- **Repeat Offender** (suspicious verdict): Auto-mark → Skip voting → Save gas
- **Clean Address**: Create new voting → Allow re-evaluation with new evidence
- **Cleared Verdict**: Governance override → Fresh evaluation

### 4. Karma System

**Purpose**: Reputation tracking for voter accuracy

**Karma Effects**:
- **Positive Karma**: Linear bonus to voting power (+1% per 100 karma)
- **Negative Karma**: Exponential penalty to voting power (karma²)
- **Minimum Threshold**: -50 karma blocks voting (configurable)
- **Rewards**: +10 karma for correct votes (configurable)
- **Penalties**: -5 karma for incorrect votes (configurable)

**Recovery Path**:
```
-50 karma (blocked) → +6 correct votes → 10 karma (can vote again)
```

### 5. Penalty & Reward System

**Penalties** (Applied to incorrect voters):
- Stake slash: 10% of stake (configurable, max 50%)
- Karma penalty: -5 points
- Locked stake released after finalization

**Rewards** (Distributed to correct voters):
- Proportional share of slashed stakes
- Karma reward: +10 points
- Finalization reward: 2% of collected fees (configurable, max 10%)

### 6. Role-Based Access Control

**Roles**:
- `GOVERNANCE_ROLE`: Critical parameters (voting duration, penalty %, karma threshold)
- `PARAMETER_ADMIN_ROLE`: Operational tuning (karma rewards, finalization rewards)
- `TREASURY_ROLE`: Financial operations (treasury address, fee management)
- `DEFAULT_ADMIN_ROLE`: Role management (grant/revoke roles)

## Agent Capabilities

### ✅ Intelligent Classification
- **Auto-marking**: Repeat offenders marked instantly (87% gas savings)
- **Re-evaluation**: Clean addresses can be re-judged with new evidence
- **Cross-chain consistency**: Same verdict applies across all chains
- **Governance override**: False positives can be cleared

### ✅ Stake-Based Voting
- **Weighted voting**: Voting power = stake + karma effect
- **Minimum stake**: Prevents spam (configurable)
- **Locked stakes**: Prevents manipulation during voting
- **Self-voting prevention**: Users can't vote on own address

### ✅ Reputation System
- **Karma tracking**: Rewards accuracy, penalizes mistakes
- **Exponential penalties**: Chronic bad actors lose power quickly
- **Hard threshold**: -50 karma blocks voting entirely
- **Recovery mechanism**: Correct votes restore reputation

### ✅ Economic Incentives
- **Stake penalties**: Wrong voters lose tokens
- **Reward distribution**: Correct voters earn from penalties
- **Finalization rewards**: Incentivizes timely finalization
- **Fee management**: Treasury collects and manages fees

### ✅ Security Features
- **Reentrancy protection**: All state-changing functions protected
- **Access control**: Role-based permissions
- **Pausable**: Emergency stop mechanism
- **Self-voting prevention**: Conflict of interest protection

## Key Functions

### Callback Handler

```solidity
function tagSuspicious(
    address suspiciousAddress,
    uint256 originChainId,
    address originContract,
    uint256 value,
    uint256 decimals,
    uint256 txHash
) external onlyCallbackAuthorizer returns (uint256 votingId)
```

**Purpose**: Receives suspicious address reports from Reactive Network  
**Flow**:
1. Check if address has previous verdict
2. If suspicious verdict exists → Auto-mark (return 0)
3. Otherwise → Create new voting (return votingId)
4. Increment incident counter
5. Emit appropriate event

**Gas Optimization**:
- Cached verdict reads (reduces SLOADs)
- Early exit for auto-marking
- No voting creation overhead for repeat offenders

**Returns**:
- `0`: Address auto-marked (no voting created)
- `votingId > 0`: New voting created

### Staking Functions

```solidity
function stake(uint256 amount) external nonReentrant
```
**Purpose**: Stake tokens to participate in voting  
**Requirements**: Amount > 0, sufficient token balance

```solidity
function unstake(uint256 amount) external nonReentrant
```
**Purpose**: Withdraw staked tokens  
**Requirements**: No active votes, sufficient unlocked stake

### Voting Functions

```solidity
function castVote(uint256 votingId, bool voteSuspicious) external nonReentrant
```

**Purpose**: Cast vote on suspicious address  
**Validations**:
- Voting must be active
- User hasn't voted already
- User has sufficient karma (≥ -50)
- User has sufficient unlocked stake
- User is not the suspicious address (self-voting prevention)

**Voting Power**:
```solidity
if (karma >= 0) {
    votingPower = stake + (stake × karma / 10000);
} else {
    penalty = stake × (karma² / 100000);
    votingPower = stake - penalty;
}
```

```solidity
function finalizeVoting(uint256 votingId) external nonReentrant
```

**Purpose**: Finalize voting after duration ends  
**Process**:
1. Determine consensus (votesFor > votesAgainst)
2. Record verdict for address
3. Process penalties for incorrect voters
4. Distribute rewards to correct voters
5. Update karma scores
6. Pay finalization reward to caller
7. Remove from active votings

### Verdict Management

```solidity
function clearAddressVerdict(address suspiciousAddress) external onlyRole(GOVERNANCE_ROLE)
```

**Purpose**: Clear false positive verdicts  
**Effect**: Resets verdict (allows fresh evaluation), preserves incident count

### View Functions

```solidity
function getAddressVerdict(address addr) external view returns (
    bool hasVerdict,
    bool isSuspicious,
    uint256 lastVotingId,
    uint256 verdictTimestamp,
    uint256 totalIncidents
)
```

**Purpose**: Get complete verdict history for an address

```solidity
function willAutoMark(address addr) external view returns (bool)
```

**Purpose**: Check if address would be auto-marked on next tag  
**Returns**: `true` if address has suspicious verdict

```solidity
function getVotingPower(address voter) external view returns (int256)
```

**Purpose**: Calculate current voting power for a user  
**Includes**: Stake + karma effect

```solidity
function getVoterAccuracy(address voter) external view returns (uint256)
```

**Purpose**: Get voter's accuracy percentage  
**Returns**: Basis points (10000 = 100%)

## State Variables

### Core Configuration

```solidity
IERC20 public immutable stakingToken;        // Token used for staking
address public callbackAuthorizer;           // Reactive Network bridge
uint256 public minimumStake;                 // Min stake to vote
uint256 public votingDuration;               // Voting period (seconds)
uint256 public penaltyPercentage;            // Stake penalty (basis points)
uint256 public karmaReward;                  // Karma for correct votes
uint256 public karmaPenalty;                 // Karma lost for wrong votes
int256 public minimumKarmaToVote;            // Karma threshold (-50 default)
```

### Financial Configuration

```solidity
address public treasury;                     // Fee collection address
uint256 public finalizationFeePercentage;    // Fee % on finalization
uint256 public finalizationRewardPercentage; // Reward % for finalizer
uint256 public totalFeesCollected;           // Accumulated fees
```

### Role Constants

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
bytes32 public constant PARAMETER_ADMIN_ROLE = keccak256("PARAMETER_ADMIN_ROLE");
bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
```

## Events

### Staking Events

```solidity
event Staked(address indexed staker, uint256 amount);
event Unstaked(address indexed staker, uint256 amount);
event FeeCollected(address indexed staker, uint256 feeAmount);
```

### Voting Events

```solidity
event VotingStarted(uint256 indexed votingId, address indexed suspiciousAddress, uint256 endTime);
event VoteCast(uint256 indexed votingId, address indexed voter, bool votedFor, uint256 votingPower);
event VotingFinalized(uint256 indexed votingId, address indexed suspiciousAddress, bool isSuspicious, uint256 votesFor, uint256 votesAgainst);
```

### Verdict Events

```solidity
event AddressAutoMarkedSuspicious(
    address indexed suspiciousAddress,
    uint256 indexed incidentNumber,
    uint256 previousVotingId,
    uint256 txHash
);

event VerdictRecorded(
    address indexed suspiciousAddress,
    uint256 indexed votingId,
    bool isSuspicious,
    uint256 timestamp
);

event VerdictCleared(
    address indexed suspiciousAddress,
    address indexed clearedBy
);
```

### Penalty & Reward Events

```solidity
event PenaltyApplied(address indexed voter, uint256 indexed votingId, uint256 penaltyAmount);
event KarmaUpdated(address indexed voter, int256 karmaChange, int256 newKarma);
event VoterRewarded(address indexed voter, uint256 indexed votingId, uint256 rewardAmount);
event FinalizationRewardPaid(uint256 indexed votingId, address indexed finalizer, uint256 rewardAmount);
```

## Usage Examples

### Example 1: First Offense Flow

```solidity
// 1. Reactive Network detects suspicious activity
// 2. Callback received
vm.prank(reactiveNetwork);
uint256 votingId = votingContract.tagSuspicious(
    0xBAD_ADDRESS,
    1,           // Ethereum
    0x123,       // Suspicious contract
    1000 ether,
    18,
    12345
);
// votingId = 1 (voting created)

// 3. Community votes
vm.prank(voter1);
votingContract.castVote(votingId, true);  // Suspicious

vm.prank(voter2);
votingContract.castVote(votingId, true);  // Suspicious

vm.prank(voter3);
votingContract.castVote(votingId, false); // Not suspicious

// 4. Wait for voting period
vm.warp(block.timestamp + 7 days);

// 5. Anyone can finalize
votingContract.finalizeVoting(votingId);

// Result: Consensus = SUSPICIOUS (2 vs 1)
// - Verdict recorded: isSuspicious = true
// - voter1 & voter2: +10 karma, receive rewards
// - voter3: -5 karma, 10% stake slashed
```

### Example 2: Repeat Offender (Auto-Marked)

```solidity
// Address already has suspicious verdict from Example 1

// New incident detected
vm.prank(reactiveNetwork);
uint256 votingId2 = votingContract.tagSuspicious(
    0xBAD_ADDRESS,  // Same address
    1,
    0x456,
    2000 ether,
    18,
    67890
);
// votingId2 = 0 (AUTO-MARKED, no voting)

// Event emitted:
// AddressAutoMarkedSuspicious(0xBAD_ADDRESS, 2, 1, 67890)

// Gas saved: ~325,000 gas (87% reduction)
// No voting needed, instant classification
```

### Example 3: Self-Voting Prevention

```solidity
// Suspicious address tries to vote on own case
vm.prank(0xBAD_ADDRESS);
vm.expectRevert(CannotVoteOnOwnAddress.selector);
votingContract.castVote(votingId, false);

// ❌ Reverts - cannot vote on own address
```

### Example 4: Governance Override

```solidity
// False positive detected
vm.prank(governanceMultisig);
votingContract.clearAddressVerdict(0xFALSE_POSITIVE);

// Verdict cleared, incident count preserved
// Next tag will create fresh voting
```

## Admin Functions

### Governance Role

```solidity
function setCallbackAuthorizer(address newAuthorizer) external onlyRole(GOVERNANCE_ROLE)
function setMinimumStake(uint256 newMinimum) external onlyRole(GOVERNANCE_ROLE)
function setVotingDuration(uint256 newDuration) external onlyRole(GOVERNANCE_ROLE)
function setPenaltyPercentage(uint256 newPercentage) external onlyRole(GOVERNANCE_ROLE)
function setMinimumKarmaToVote(int256 newMinimumKarma) external onlyRole(GOVERNANCE_ROLE)
function clearAddressVerdict(address suspiciousAddress) external onlyRole(GOVERNANCE_ROLE)
```

### Parameter Admin Role

```solidity
function setKarmaReward(uint256 newReward) external onlyRole(PARAMETER_ADMIN_ROLE)
function setKarmaPenalty(uint256 newPenalty) external onlyRole(PARAMETER_ADMIN_ROLE)
function setFinalizationRewardPercentage(uint256 newPercentage) external onlyRole(PARAMETER_ADMIN_ROLE)
```

### Treasury Role

```solidity
function setTreasury(address newTreasury) external onlyRole(TREASURY_ROLE)
function setFinalizationFeePercentage(uint256 newPercentage) external onlyRole(TREASURY_ROLE)
function transferFeesToTreasury(uint256 amount) external onlyRole(TREASURY_ROLE)
```

## Security Features

### ✅ Reentrancy Protection
All state-changing functions use `nonReentrant` modifier

### ✅ Access Control
- Role-based permissions via OpenZeppelin AccessControl
- Callback authorizer validation
- Owner-only admin functions

### ✅ Input Validation
- Zero address checks
- Amount validations
- Percentage bounds (max 50% penalty, max 10% fees)

### ✅ Economic Security
- Locked stakes during voting
- Minimum stake requirements
- Karma threshold enforcement
- Self-voting prevention

### ✅ Pausability
Inherits from AbstractPausableReactive for emergency stops

## Gas Optimizations

### ✅ Verdict Lookups
```solidity
// Cache verdict flags to reduce SLOADs
bool hasVerdict = verdict.hasVerdict;
bool isSuspicious = verdict.isSuspicious;
```

### ✅ Auto-Marking Path
- Early exit for repeat offenders
- No voting struct creation
- Minimal storage writes
- **Savings**: ~325,000 gas per repeat offense (87% reduction)

### ✅ Efficient Calculations
- Karma calculations cached in voting power
- Batch operations where possible
- Minimal storage reads

## Deployment

### Prerequisites
- Staking token contract address
- Reactive Network callback authorizer address
- Initial configuration parameters

### Deploy Contract

```bash
forge create src/voting-contract/VedyxVotingContract.sol:VedyxVotingContract \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args \
        $STAKING_TOKEN \
        $CALLBACK_AUTHORIZER \
        $MINIMUM_STAKE \
        $VOTING_DURATION \
        $PENALTY_PERCENTAGE \
        $TREASURY \
        $FINALIZATION_FEE_PERCENTAGE
```

### Initial Configuration

```bash
# Set karma parameters
cast send $CONTRACT "setKarmaReward(uint256)" 10 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $CONTRACT "setKarmaPenalty(uint256)" 5 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $CONTRACT "setMinimumKarmaToVote(int256)" -- -50 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Set finalization reward
cast send $CONTRACT "setFinalizationRewardPercentage(uint256)" 200 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Grant roles (if decentralizing)
cast send $CONTRACT "grantRole(bytes32,address)" $GOVERNANCE_ROLE $DAO_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Monitoring & Maintenance

### Query Contract State

```bash
# Check verdict for address
cast call $CONTRACT "getAddressVerdict(address)" $ADDRESS --rpc-url $RPC_URL

# Check if address will auto-mark
cast call $CONTRACT "willAutoMark(address)" $ADDRESS --rpc-url $RPC_URL

# Get voter stats
cast call $CONTRACT "getVotingPower(address)" $VOTER --rpc-url $RPC_URL
cast call $CONTRACT "getVoterAccuracy(address)" $VOTER --rpc-url $RPC_URL

# Get active votings
cast call $CONTRACT "getActiveVotings()" --rpc-url $RPC_URL
```

### Monitor Events

```bash
# Watch for new votings
cast logs --address $CONTRACT \
    --event "VotingStarted(uint256,address,uint256)" \
    --rpc-url $RPC_URL

# Watch for auto-markings
cast logs --address $CONTRACT \
    --event "AddressAutoMarkedSuspicious(address,uint256,uint256,uint256)" \
    --rpc-url $RPC_URL

# Watch for verdicts
cast logs --address $CONTRACT \
    --event "VerdictRecorded(address,uint256,bool,uint256)" \
    --rpc-url $RPC_URL
```

## Testing

Comprehensive test suite with 134 tests covering:
- Core functionality (65 tests)
- Access control (38 tests)
- Voter rewards (8 tests)
- Negative karma (4 tests)
- Verdict system (19 tests)

```bash
# Run all tests
forge test

# Run verdict system tests
forge test --match-path test/VerdictSystem.t.sol -vv

# Run with gas report
forge test --gas-report
```

## Integration Guide

### For Frontend Developers

```typescript
// Check if address will be auto-marked
const willAutoMark = await votingContract.willAutoMark(address);

if (willAutoMark) {
  // Show "Known bad actor" badge
  // No voting UI needed
} else {
  // Show voting UI
  // Allow users to cast votes
}

// Get verdict history
const [hasVerdict, isSuspicious, lastVotingId, timestamp, incidents] = 
  await votingContract.getAddressVerdict(address);

// Display reputation
console.log(`Incidents: ${incidents}`);
console.log(`Status: ${isSuspicious ? 'Suspicious' : 'Clean'}`);
```

### For Reactive Network Integration

```solidity
// Callback from Reactive Network
function react(...) external vmOnly {
    // Detect threat
    if (threatDetected) {
        bytes memory payload = abi.encodeWithSignature(
            "tagSuspicious(address,uint256,address,uint256,uint256,uint256)",
            suspiciousAddr,
            chainId,
            contractAddr,
            value,
            decimals,
            txHash
        );
        
        // Emit callback to voting contract
        emit Callback(
            destinationChainId,
            votingContractAddress,
            GAS_LIMIT,
            payload
        );
    }
}
```

## Best Practices

1. **Staking**: Stake enough to participate meaningfully (consider minimum stake)
2. **Voting**: Vote carefully - wrong votes cost karma and stake
3. **Karma**: Monitor your karma - below -50 blocks voting
4. **Finalization**: Finalize votings promptly to earn rewards
5. **Governance**: Use multi-sig for governance role
6. **Monitoring**: Track verdict events for suspicious patterns

## Future Enhancements

1. **Delegated Voting**: Allow vote delegation to trusted addresses
2. **Quadratic Voting**: Implement quadratic voting for fairer representation
3. **Appeal System**: Allow addresses to appeal verdicts
4. **Reputation NFTs**: Mint NFTs for high-karma voters
5. **Cross-Chain Verdicts**: Sync verdicts across multiple chains
6. **ML Integration**: Incorporate ML confidence scores
7. **Slashing Insurance**: Optional insurance for voters

## Support & Resources

- **Complete Guide**: `/src/VOTING_CONTRACT_GUIDE.md`
- **Architecture**: `/src/voting-contract/README.md`
- **Main Contract**: `/src/voting-contract/VedyxVotingContract.sol`
- **Libraries**: `/src/voting-contract/libraries/`
- **Interface**: `/src/voting-contract/interfaces/IVedyxVoting.sol`
- **Test Suite**: `/test/VerdictSystem.t.sol`
- **Access Control Tests**: `/test/AccessControl.t.sol`

---

**Agent Version**: 1.0.0  
**Last Updated**: 2026-02-18  
**Maintainer**: Vedyx Protocol Team
