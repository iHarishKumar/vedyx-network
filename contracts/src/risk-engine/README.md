# Vedyx Risk Engine

Multi-factor risk assessment engine for DeFi protocol integration. Provides granular risk scoring (0-100) based on community voting outcomes and detector severity.

## 🎯 Purpose

The Vedyx Risk Engine aggregates data from the voting system and attack vector detectors to provide **actionable risk scores** that DeFi protocols can use to:

- **Adjust fees dynamically** (Uniswap V4 hooks)
- **Set collateral requirements** (Lending protocols)
- **Filter routes** (DEX aggregators)
- **Apply transaction limits** (Any DeFi protocol)

## 📊 Risk Scoring Model

### Total Score (0-100)

Risk score is calculated from **5 weighted factors**:

| Factor | Weight | Description |
|--------|--------|-------------|
| **Verdict Score** | 40% | Community consensus on suspiciousness |
| **Incident Score** | 20% | Frequency of being flagged by detectors |
| **Detector Score** | 20% | Severity of detector that flagged address |
| **Consensus Score** | 10% | Strength of voting consensus |
| **Recency Score** | 10% | Time decay from verdict timestamp |

### Risk Levels

| Level | Score Range | Description | Recommended Action |
|-------|-------------|-------------|-------------------|
| **SAFE** | 0 | No verdict or cleared | Normal operations |
| **LOW** | 1-29 | Minor concerns | Proceed with warning |
| **MEDIUM** | 30-49 | Moderate risk | Apply restrictions |
| **HIGH** | 50-69 | Significant risk | Heavy restrictions |
| **CRITICAL** | 70-100 | Severe risk | Consider blocking |

## 🏗️ Architecture

```
src/risk-engine/
├── VedyxRiskEngine.sol              # Main risk engine contract
├── RiskIntegrationHelper.sol        # Helper utilities for DeFi protocols
├── interfaces/
│   ├── IVedyxRiskEngine.sol         # Core risk engine interface
│   └── IRiskIntegration.sol         # Integration helper interface
├── libraries/
│   └── RiskScoringLib.sol           # Risk calculation library
└── examples/
    ├── UniswapV4HookExample.sol     # Uniswap V4 integration
    ├── LendingProtocolExample.sol   # Lending protocol integration
    └── DEXAggregatorExample.sol     # DEX aggregator integration
```

## 🚀 Quick Start

### 1. Deploy Risk Engine

```solidity
// Deploy VedyxRiskEngine
VedyxRiskEngine riskEngine = new VedyxRiskEngine(
    votingContractAddress  // Address of VedyxVotingContract
);

// Deploy RiskIntegrationHelper
RiskIntegrationHelper helper = new RiskIntegrationHelper();
```

### 2. Basic Integration

```solidity
import {IVedyxRiskEngine} from "vedyx-protocol/risk-engine/interfaces/IVedyxRiskEngine.sol";

contract MyDeFiProtocol {
    IVedyxRiskEngine public riskEngine;

    constructor(address _riskEngine) {
        riskEngine = IVedyxRiskEngine(_riskEngine);
    }

    function processTransaction(address user, uint256 amount) external {
        // Get risk level
        IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(user);
        
        // Block CRITICAL addresses
        require(level != IVedyxRiskEngine.RiskLevel.CRITICAL, "Address blocked");
        
        // Apply risk-based logic
        if (level == IVedyxRiskEngine.RiskLevel.HIGH) {
            // Apply restrictions
        }
        
        // Process transaction...
    }
}
```

## 📖 Core Functions

### Risk Assessment

```solidity
// Get complete risk assessment
IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(address);
// Returns: totalScore, riskLevel, factors breakdown, hasVerdict, lastUpdated

// Get risk level (simplified)
IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(address);

// Get risk score (0-100)
uint8 score = riskEngine.getRiskScore(address);

// Check if address is safe
bool isSafe = riskEngine.isSafeAddress(address);
// Returns true if SAFE or LOW

// Get factor breakdown
IVedyxRiskEngine.RiskFactors memory factors = riskEngine.getRiskFactors(address);
```

### Batch Operations (Gas-Optimized)

```solidity
// Get risk levels for multiple addresses
address[] memory users = [user1, user2, user3];
IVedyxRiskEngine.RiskLevel[] memory levels = riskEngine.getBatchRiskLevels(users);

// Get risk scores for multiple addresses
uint8[] memory scores = riskEngine.getBatchRiskScores(users);
```

## 🔧 Configuration

### Update Risk Weights

```solidity
// Only RISK_ADMIN_ROLE can update
IVedyxRiskEngine.RiskConfig memory config = IVedyxRiskEngine.RiskConfig({
    verdictWeight: 40,    // 40% weight
    incidentWeight: 20,   // 20% weight
    detectorWeight: 20,   // 20% weight
    consensusWeight: 10,  // 10% weight
    recencyWeight: 10     // 10% weight
});

riskEngine.updateRiskConfig(config);
// Note: Weights must sum to 100
```

### Set Detector Severity

```solidity
// Set severity for specific detector (0-20)
bytes32 detectorId = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
riskEngine.setDetectorSeverity(detectorId, 15);
```

**Default Detector Severities:**
- `MIXER_INTERACTION_DETECTOR_V1`: 20 (highest)
- `REENTRANCY_DETECTOR_V1`: 20
- `FLASH_LOAN_DETECTOR_V1`: 18
- `TRACE_PEEL_CHAIN_DETECTOR_V1`: 15
- `LARGE_TRANSFER_DETECTOR_V1`: 10

## 💡 Integration Examples

### Example 1: Uniswap V4 Hook (Dynamic Fees)

```solidity
import {IVedyxRiskEngine} from "vedyx-protocol/risk-engine/interfaces/IVedyxRiskEngine.sol";
import {RiskIntegrationHelper} from "vedyx-protocol/risk-engine/RiskIntegrationHelper.sol";

contract MyUniswapHook {
    IVedyxRiskEngine public riskEngine;
    RiskIntegrationHelper public helper;
    uint256 public constant BASE_FEE = 3000; // 0.3%

    function beforeSwap(address user) external returns (uint256 fee) {
        // Block CRITICAL addresses
        IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(user);
        require(level != IVedyxRiskEngine.RiskLevel.CRITICAL, "Blocked");
        
        // Calculate risk-adjusted fee
        fee = helper.calculateRiskAdjustedFee(user, BASE_FEE, riskEngine);
        // SAFE: 0.3%, LOW: 0.45%, MEDIUM: 0.6%, HIGH: 1.5%, CRITICAL: 3%
    }
}
```

### Example 2: Lending Protocol (Collateral Requirements)

```solidity
contract MyLendingProtocol {
    IVedyxRiskEngine public riskEngine;
    RiskIntegrationHelper public helper;

    function getRequiredCollateral(address borrower, uint256 loanAmount) 
        external view returns (uint256 collateral) 
    {
        // Get risk-based collateral ratio
        uint256 ratio = helper.getRequiredCollateralRatio(borrower, riskEngine);
        // SAFE: 120%, LOW: 130%, MEDIUM: 150%, HIGH: 200%, CRITICAL: 300%
        
        collateral = (loanAmount * ratio) / 10000;
    }
}
```

### Example 3: DEX Aggregator (Route Filtering)

```solidity
contract MyDEXAggregator {
    IVedyxRiskEngine public riskEngine;

    function getOptimalRoute(address user) external view returns (Route memory) {
        IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(user);
        
        // High risk users: exclude high-value pools
        if (level >= IVedyxRiskEngine.RiskLevel.HIGH) {
            return getRouteExcluding(highValuePools);
        }
        
        return getOptimalRouteAll();
    }
}
```

## 🔍 Risk Factor Details

### 1. Verdict Score (0-40 points)

Based on community voting outcome:
- **Suspicious verdict**: 40 points
- **Clean verdict**: 0 points
- **No verdict**: 0 points

### 2. Incident Score (0-20 points)

Based on number of times flagged:
- **1 incident**: 5 points (25%)
- **2 incidents**: 10 points (50%)
- **3+ incidents**: 20 points (100%)

### 3. Detector Score (0-20 points)

Based on severity of detector that flagged address:
- Scaled from detector severity (0-20)
- Default: 10 points if detector not configured

### 4. Consensus Score (0-10 points)

Based on voting consensus strength:
- **>80% consensus**: 10 points (strong)
- **60-80% consensus**: 7 points (moderate)
- **<60% consensus**: 5 points (weak)

### 5. Recency Score (0-10 points)

Time decay from verdict:
- **<7 days**: 10 points (very recent)
- **7-30 days**: 7 points (recent)
- **30-90 days**: 5 points (somewhat recent)
- **>90 days**: 2 points (old)

## 🎨 Custom Integration Patterns

### Pattern 1: Transaction Limits

```solidity
function getTransactionLimit(address user) external view returns (uint256) {
    uint256[5] memory limits = [
        1000000e18,  // SAFE: 1M
        750000e18,   // LOW: 750K
        500000e18,   // MEDIUM: 500K
        250000e18,   // HIGH: 250K
        0            // CRITICAL: blocked
    ];
    
    return helper.getTransactionLimit(user, limits, riskEngine);
}
```

### Pattern 2: Custom Fee Multipliers

```solidity
IRiskIntegration.FeeMultiplier memory customFees = IRiskIntegration.FeeMultiplier({
    safeFee: 100,      // 1x
    lowFee: 120,       // 1.2x
    mediumFee: 150,    // 1.5x
    highFee: 300,      // 3x
    criticalFee: 1000  // 10x or block
});

uint256 fee = helper.calculateRiskAdjustedFeeWithMultiplier(
    user, baseFee, riskEngine, customFees
);
```

### Pattern 3: Conditional Blocking

```solidity
function shouldBlock(address user) external view returns (bool) {
    // Block only CRITICAL addresses
    return helper.shouldBlockAddress(
        user, 
        riskEngine, 
        IVedyxRiskEngine.RiskLevel.CRITICAL
    );
}
```

## 🧪 Testing

```bash
# Run risk engine tests
forge test --match-contract VedyxRiskEngine

# Run integration tests
forge test --match-contract RiskIntegration

# Run example tests
forge test --match-path test/risk-engine/examples/*
```

## 📝 Events

```solidity
// Emitted when risk configuration is updated
event RiskConfigUpdated(RiskConfig newConfig);

// Emitted when detector severity is updated
event DetectorSeverityUpdated(bytes32 indexed detectorId, uint8 severity);

// Emitted when voting contract is updated
event VotingContractUpdated(address indexed newVotingContract);
```

## 🔐 Access Control

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke roles, update voting contract |
| `RISK_ADMIN_ROLE` | Update risk config, set detector severities |

## 🚨 Important Notes

1. **Gas Costs**: Batch functions are optimized for multiple address queries
2. **Time Decay**: Risk scores decrease over time (recency factor)
3. **Configurable**: All weights and severities are adjustable
4. **Composable**: Works with any DeFi protocol
5. **Transparent**: All scoring logic is on-chain and auditable

## 📚 Additional Resources

- [Voting Contract Documentation](../voting-contract/README.md)
- [Detector Documentation](../reactive-contracts/AGENTS.md)
- [Integration Examples](./examples/)
- [Vedyx Context](../../VEDYX_CONTEXT.md)

## 🤝 Integration Support

For integration assistance:
1. Review example contracts in `/examples`
2. Check integration patterns above
3. Test with your protocol's specific requirements
4. Adjust risk weights and thresholds as needed

---

**Built for DeFi protocols to make informed decisions about address risk.**
