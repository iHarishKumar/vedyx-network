# Vedyx Risk Hook for Uniswap V4

A sophisticated Uniswap V4 hook that integrates with the Vedyx Risk Engine to provide dynamic fees and risk-based access control for DeFi protocols.

## Features

### 🎯 Dynamic Swap Fees (1-30%)
- **Risk-Based Pricing**: Fees automatically adjust based on user risk scores
- **Tiered Structure**: Five risk levels with configurable fee tiers
- **Linear Scaling**: Smooth fee progression from 1% (SAFE) to 30% (CRITICAL)
- **Configurable Bounds**: Min/max fee caps to prevent extreme pricing

### 🛡️ Risk-Based Blocking
- **HIGH Risk Blocking**: Automatically blocks HIGH risk addresses from swapping
- **CRITICAL Risk Blocking**: Blocks CRITICAL risk addresses from all operations
- **Configurable Policies**: Enable/disable blocking per risk level
- **Liquidity Protection**: More restrictive blocking for liquidity provision

### 💧 Liquidity Protection
- **Risk-Based Blocking**: Prevents high-risk addresses from adding liquidity
- **Stricter Controls**: More restrictive blocking for liquidity provision than swaps
- **Exit Flexibility**: Less restrictive for removing liquidity (allow users to exit)
- **Future Enhancement**: Dynamic LP fees planned for future versions (requires pool initialization with DYNAMIC_FEE_FLAG)

### 📊 Risk Assessment Integration
- **Real-Time Risk Scores**: Queries Vedyx Risk Engine for up-to-date assessments
- **Multi-Factor Analysis**: Considers verdicts, incidents, detectors, consensus, recency
- **Transparent Scoring**: Users can query their own risk assessments
- **Cross-Chain Consistency**: Same risk score applies across all chains

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Uniswap V4 Pool                           │
│                         ↓                                    │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   VedyxRiskHook                              │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  beforeSwap(sender, swapper)                       │    │
│  │    1. Query Risk Engine for user risk              │    │
│  │    2. Check if user should be blocked              │    │
│  │    3. Calculate dynamic fee based on risk          │    │
│  │    4. Return fee to pool                           │    │
│  └────────────────────────────────────────────────────┘    │
│                         ↓                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │  FeeCalculator Library                             │    │
│  │    • Tiered fee calculation                        │    │
│  │    • Linear interpolation                          │    │
│  │    • Fee caps and floors                           │    │
│  └────────────────────────────────────────────────────┘    │
│                         ↓                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │  RiskValidator Library                             │    │
│  │    • Risk level validation                         │    │
│  │    • Blocking logic                                │    │
│  │    • Risk descriptions                             │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  Vedyx Risk Engine                           │
│                                                              │
│  • Community verdicts (0-40 points)                         │
│  • Incident history (0-20 points)                           │
│  • Detector severity (0-20 points)                          │
│  • Voting consensus (0-10 points)                           │
│  • Time recency (0-10 points)                               │
│                                                              │
│  Total Score: 0-100 → Risk Level: SAFE/LOW/MEDIUM/HIGH/CRITICAL │
└─────────────────────────────────────────────────────────────┘
```

## Fee Structure

### Default Swap Fees

| Risk Level | Risk Score | Default Fee | Description |
|------------|------------|-------------|-------------|
| SAFE       | 0          | 1%          | No verdict or cleared |
| LOW        | 1-29       | 3%          | Minor concerns |
| MEDIUM     | 30-49      | 8%          | Moderate risk |
| HIGH       | 50-69      | 15%         | Significant risk |
| CRITICAL   | 70-100     | 30%         | Severe risk |

### Liquidity Blocking Policy

Liquidity operations have stricter blocking policies than swaps:

| Risk Level | Add Liquidity | Remove Liquidity | Rationale |
|------------|---------------|------------------|------------|
| SAFE       | ✅ Allowed    | ✅ Allowed       | No risk |
| LOW        | ✅ Allowed    | ✅ Allowed       | Minimal risk |
| MEDIUM     | ✅ Allowed    | ✅ Allowed       | Acceptable risk |
| HIGH       | ❌ Blocked    | ✅ Allowed       | Longer exposure risk |
| CRITICAL   | ❌ Blocked    | ⚠️ Configurable  | Severe risk |

**Note**: Dynamic LP fee adjustments are not currently implemented. The hook focuses on blocking high-risk liquidity provision while allowing safe exit paths.

## Blocking Policies

### Swap Blocking
- **HIGH Risk**: Blocked by default (configurable)
- **CRITICAL Risk**: Blocked by default (configurable)
- **MEDIUM and below**: Allowed with dynamic fees

### Liquidity Blocking
More restrictive than swap blocking:
- **HIGH Risk**: Blocked from adding liquidity
- **CRITICAL Risk**: Blocked from adding liquidity (remove is configurable)
- **MEDIUM and below**: Allowed to add/remove liquidity
- **Exit Path**: Removing liquidity is always less restrictive to allow users to exit positions

## Usage

### Deployment

```solidity
// Deploy VedyxRiskHook
VedyxRiskHook hook = new VedyxRiskHook(
    riskEngineAddress,  // Address of Vedyx Risk Engine
    owner               // Hook owner address
);
```

### Integration with Uniswap V4

```solidity
// Pool manager calls hook before swap
uint24 dynamicFee = hook.beforeSwap(msg.sender, swapper);

// Pool manager calls hook before adding liquidity (blocking only, no fee returned)
hook.beforeAddLiquidity(msg.sender, key, params, hookData);

// Pool manager calls hook before removing liquidity (blocking only, no fee returned)
hook.beforeRemoveLiquidity(msg.sender, key, params, hookData);
```

### Query User Risk

```solidity
// Get user's swap fee
uint24 fee = hook.getSwapFee(userAddress);

// Check if user is blocked
(bool blocked, string memory reason) = hook.shouldBlockSwap(userAddress);

// Get complete risk assessment
IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(userAddress);
```

### Configuration

```solidity
// Update fee configuration
IVedyxRiskHook.FeeConfig memory newFees = IVedyxRiskHook.FeeConfig({
    safeFee: 10000,      // 1%
    lowFee: 30000,       // 3%
    mediumFee: 80000,    // 8%
    highFee: 150000,     // 15%
    criticalFee: 300000  // 30%
});
hook.updateFeeConfig(newFees);

// Update hook configuration
IVedyxRiskHook.HookConfig memory newConfig = IVedyxRiskHook.HookConfig({
    blockHighRisk: true,
    blockCritical: true,
    dynamicSwapFees: true,
    dynamicLPFees: false,  // Not currently implemented
    maxSwapFee: 300000,    // 30%
    minSwapFee: 10000      // 1%
});
hook.updateHookConfig(newConfig);
```

## Additional Features

### 1. Configurable Fee Tiers
- Customize fees for each risk level
- Set min/max fee bounds
- Enable/disable dynamic fees

### 2. Flexible Blocking Policies
- Configure which risk levels to block
- Different policies for swaps vs liquidity
- Emergency pause functionality

### 3. Liquidity Risk Management
- Risk-based blocking for liquidity provision
- Stricter controls for adding vs removing liquidity
- Safe exit paths for all users

### 4. Gas Optimization
- Cached risk assessments
- Efficient fee calculations
- Minimal external calls

### 5. Transparent Risk Scoring
- Users can query their risk scores
- Detailed factor breakdown
- Real-time updates

## Security Considerations

### ✅ Implemented
- **Reentrancy Protection**: All state-changing functions protected
- **Access Control**: Owner-only configuration functions
- **Input Validation**: All parameters validated
- **Fee Bounds**: Min/max caps prevent extreme fees
- **Zero Address Checks**: Prevents invalid addresses

### ⚠️ Important Notes
- Hook relies on Risk Engine accuracy
- Fee changes affect existing positions
- Blocking can prevent user exits (use carefully)
- Test thoroughly before mainnet deployment

## Testing

```bash
# Run hook tests
forge test --match-contract VedyxRiskHookTest -vvv

# Run with gas reporting
forge test --match-contract VedyxRiskHookTest --gas-report

# Run specific test
forge test --match-test test_DynamicSwapFee -vvv
```

## Events

```solidity
// Emitted when swap is blocked
event SwapBlocked(address indexed user, RiskLevel riskLevel, uint8 riskScore);

// Emitted when dynamic fee is applied
event DynamicFeeApplied(address indexed user, uint24 fee, RiskLevel riskLevel, uint8 riskScore);

// Emitted when liquidity operation is blocked
event LiquidityBlocked(address indexed user, bool isAddLiquidity, RiskLevel riskLevel);

// Emitted when configuration is updated
event FeeConfigUpdated(FeeConfig newConfig);
event HookConfigUpdated(HookConfig newConfig);
event RiskEngineUpdated(address indexed newRiskEngine);
```

## License

MIT

## Contact

- **Security**: security@vedyx.io
- **Support**: support@vedyx.io
- **Documentation**: https://docs.vedyx.io
