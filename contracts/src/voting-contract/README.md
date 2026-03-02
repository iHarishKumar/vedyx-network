# Vedyx Voting Contract - Modular Architecture

## Structure

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

## Components

### Main Contract: `VedyxVotingContract.sol`
State management, access control, and core workflow orchestration.

### Libraries

#### `VedyxErrors.sol`
Centralized custom errors for the entire voting system.

#### `VedyxTypes.sol`
All data structures used in the voting system.

**Structs**:
- `SuspiciousReport` - Report details from Reactive Network
- `Voting` - Voting process state
- `Vote` - Individual vote record
- `Staker` - Staker information with karma
- `AddressVerdict` - Historical verdict tracking
- `VotingConfig` - Configuration parameters
- `FeeConfig` - Fee-related configuration

#### `VotingPowerLib.sol`
Pure functions for voting power calculations.

**Functions**:
- `calculateVotingPower()` - Main voting power calculation
- `calculateKarmaEffect()` - Karma bonus/penalty calculation
- `calculateLinearBonus()` - Positive karma bonus
- `calculateExponentialPenalty()` - Negative karma penalty
- `getAvailableStake()` - Calculate unlocked stake
- `hasSufficientKarma()` - Karma threshold check

#### `VotingResultsLib.sol`
Logic for processing voting results, penalties, and rewards.

**Functions**:
- `collectPenalties()` - Collect penalties from incorrect voters
- `calculatePenalty()` - Calculate individual penalty amount
- `calculateFinalizationFee()` - Calculate fee from penalties
- `applyKarmaPenalties()` - Update karma for incorrect voters
- `distributeRewards()` - Distribute rewards to correct voters
- `calculateFinalizationReward()` - Calculate finalizer reward

### Interface: `IVedyxVoting.sol`
Complete interface for the voting contract.

## Usage

### Imports

```solidity
import "./voting-contract/VedyxVotingContract.sol";
import "./voting-contract/interfaces/IVedyxVoting.sol";
import "./voting-contract/libraries/VedyxTypes.sol";
```

### Type References

```solidity
VedyxTypes.Staker memory staker;
VedyxTypes.SuspiciousReport memory report;
```

### Error Handling

```solidity
import {VedyxErrors} from "./libraries/VedyxErrors.sol";
// ...
revert VedyxErrors.InsufficientStake();
```

## Deployment

```solidity
VedyxVotingContract voting = new VedyxVotingContract(
    stakingToken,
    callbackAuthorizer,
    minimumStake,
    votingDuration,
    penaltyPercentage,
    treasury,
    finalizationFeePercentage
);
```

## Documentation

For detailed documentation:
- **Main contract**: See inline documentation in `VedyxVotingContract.sol`
- **Libraries**: Each library has comprehensive NatSpec comments
- **Interface**: Full API documentation in `IVedyxVoting.sol`
- **Complete guide**: See `../VOTING_CONTRACT_GUIDE.md`
