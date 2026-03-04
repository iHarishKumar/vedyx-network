# Vedyx Protocol - Detector Suite Summary

## Overview

The Vedyx Protocol implements a modular detection system for identifying suspicious blockchain activity patterns. This document provides a comprehensive overview of all available detectors, their configurations, and usage guidelines.

## Architecture

```
VedyxExploitDetectorRSC (Singleton Hub)
    ↓
┌─────────────────────────────────────────────────┐
│  Detector Registry (Topic-Based Routing)        │
├─────────────────────────────────────────────────┤
│  • LargeTransferDetector                        │
│  • TracePeelChainDetector                       │
│  • MixerInteractionDetector                     │
│  • [Future Detectors...]                        │
└─────────────────────────────────────────────────┘
    ↓
TokenRegistry (Shared Configuration)
```

---

## 1. TokenRegistry

**Purpose**: Centralized token configuration storage shared across all detectors

**Location**: `src/reactive-contracts/detectors/TokenRegistry.sol`

### Features
- ✅ Stores token decimals and symbols
- ✅ Provides default decimals (18) for unconfigured tokens
- ✅ Batch configuration support
- ✅ Owner-controlled configuration
- ✅ Gas-optimized lookups
- ✅ Immutable reference pattern for detectors

### Configurable Parameters

| Parameter | Type | Default | Description | Constraints |
|-----------|------|---------|-------------|-------------|
| `decimals` | `uint8` | `18` | Token decimal places | 0-255 (typically 0-18) |
| `symbol` | `string` | `""` | Token symbol | Any string (e.g., "USDC") |

### Configuration

```solidity
// Configure single token
registry.configureToken(
    USDC_ADDRESS,
    6,        // decimals
    "USDC"    // symbol
);

// Configure multiple tokens (batch operation)
address[] memory tokens = [USDC, USDT, DAI];
uint8[] memory decimals = [6, 6, 18];
string[] memory symbols = ["USDC", "USDT", "DAI"];
registry.configureTokens(tokens, decimals, symbols);

// Update existing token configuration
registry.configureToken(USDC_ADDRESS, 6, "USDC.e");  // Overwrites existing

// Remove token configuration (reverts to default)
registry.removeToken(USDC_ADDRESS);
```

### Integration Guide

#### Step 1: Deploy TokenRegistry

```solidity
// Deploy the registry
TokenRegistry registry = new TokenRegistry();

// Transfer ownership if needed
registry.transferOwnership(GOVERNANCE_ADDRESS);
```

#### Step 2: Configure Common Tokens

```solidity
// Configure major stablecoins
registry.configureToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 6, "USDC");
registry.configureToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, 6, "USDT");
registry.configureToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 18, "DAI");

// Configure major tokens
registry.configureToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 18, "WETH");
registry.configureToken(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 8, "WBTC");
```

#### Step 3: Deploy Detectors with Registry Reference

```solidity
// All detectors require registry address in constructor
LargeTransferDetector largeTransfer = new LargeTransferDetector(address(registry));
TracePeelChainDetector peelChain = new TracePeelChainDetector(address(registry));
MixerInteractionDetector mixer = new MixerInteractionDetector(address(registry));
```

#### Step 4: Use Registry in Custom Detectors

```solidity
import {TokenRegistry} from "./TokenRegistry.sol";

contract MyCustomDetector {
    TokenRegistry public immutable registry;
    
    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = TokenRegistry(_registry);
    }
    
    function detect(address token, uint256 amount) external view returns (bool) {
        // Get token decimals from registry
        uint8 decimals = registry.getDecimals(token);
        
        // Convert to human-readable amount
        uint256 humanAmount = amount / (10 ** decimals);
        
        // Your detection logic here
        return humanAmount > 1000;
    }
}
```

#### Step 5: Query Token Information

```solidity
// Check if token is configured
bool isConfigured = registry.isConfigured(USDC_ADDRESS);

// Get decimals (returns 18 if not configured)
uint8 decimals = registry.getDecimals(USDC_ADDRESS);

// Get symbol
string memory symbol = registry.getSymbol(USDC_ADDRESS);

// Batch get decimals for multiple tokens
address[] memory tokens = [USDC, USDT, DAI];
uint8[] memory decimalsList = registry.getDecimalsBatch(tokens);

// Get all configured tokens
address[] memory allTokens = registry.getConfiguredTokens();
```

### Best Practices for Integration

#### 1. Immutable Registry Reference
```solidity
// ✅ GOOD: Immutable reference (gas efficient)
TokenRegistry public immutable registry;

constructor(address _registry) {
    registry = TokenRegistry(_registry);
}

// ❌ BAD: Mutable reference (wastes gas)
TokenRegistry public registry;
```

#### 2. Validate Registry Address
```solidity
// ✅ GOOD: Validate in constructor
constructor(address _registry) {
    if (_registry == address(0)) revert InvalidRegistryAddress();
    registry = TokenRegistry(_registry);
}

// ❌ BAD: No validation
constructor(address _registry) {
    registry = TokenRegistry(_registry);
}
```

#### 3. Handle Unconfigured Tokens
```solidity
// ✅ GOOD: Registry returns default (18) for unconfigured tokens
uint8 decimals = registry.getDecimals(unknownToken);  // Returns 18

// ✅ GOOD: Check if configured first (if you need to know)
if (registry.isConfigured(token)) {
    uint8 decimals = registry.getDecimals(token);
    // Use actual decimals
} else {
    // Use default or skip
}
```

#### 4. Batch Operations for Efficiency
```solidity
// ✅ GOOD: Batch configuration
address[] memory tokens = [token1, token2, token3];
uint8[] memory decimals = [6, 18, 6];
string[] memory symbols = ["USDC", "WETH", "USDT"];
registry.configureTokens(tokens, decimals, symbols);

// ❌ BAD: Multiple individual calls
registry.configureToken(token1, 6, "USDC");
registry.configureToken(token2, 18, "WETH");
registry.configureToken(token3, 6, "USDT");
```

### Common Integration Patterns

#### Pattern 1: Decimal-Aware Amount Comparison
```solidity
function isLargeTransfer(address token, uint256 amount) public view returns (bool) {
    uint8 decimals = registry.getDecimals(token);
    uint256 humanAmount = amount / (10 ** decimals);
    return humanAmount >= 100000;  // 100k tokens
}
```

#### Pattern 2: Multi-Token Detection
```solidity
function detectAcrossTokens(address[] memory tokens, uint256[] memory amounts) 
    public view returns (bool[] memory) 
{
    uint8[] memory decimalsList = registry.getDecimalsBatch(tokens);
    bool[] memory results = new bool[](tokens.length);
    
    for (uint i = 0; i < tokens.length; i++) {
        uint256 humanAmount = amounts[i] / (10 ** decimalsList[i]);
        results[i] = humanAmount > threshold;
    }
    
    return results;
}
```

#### Pattern 3: Token Metadata Display
```solidity
function getTransferInfo(address token, uint256 amount) 
    public view returns (string memory) 
{
    uint8 decimals = registry.getDecimals(token);
    string memory symbol = registry.getSymbol(token);
    uint256 humanAmount = amount / (10 ** decimals);
    
    return string(abi.encodePacked(
        "Transfer of ",
        Strings.toString(humanAmount),
        " ",
        symbol
    ));
}
```

### Key Functions

| Function | Description | Access | Gas Cost |
|----------|-------------|--------|----------|
| `configureToken(address, uint8, string)` | Configure single token | Owner | ~115k |
| `configureTokens(address[], uint8[], string[])` | Batch configure | Owner | ~115k per token |
| `getDecimals(address)` | Get token decimals | Public | ~2.5k |
| `getDecimalsBatch(address[])` | Batch get decimals | Public | ~2.5k per token |
| `getSymbol(address)` | Get token symbol | Public | ~3k |
| `isConfigured(address)` | Check if configured | Public | ~2.4k |
| `removeToken(address)` | Remove configuration | Owner | ~5k |
| `getConfiguredTokens()` | Get all configured tokens | Public | Variable |

### Events
- `TokenConfigured(address indexed token, uint8 decimals, string symbol)`
- `TokenRemoved(address indexed token)`

### Error Handling

```solidity
// Custom errors
error InvalidTokenAddress();      // Token address is zero
error InvalidDecimals();          // Decimals > 255 (shouldn't happen with uint8)
error InvalidConfiguration();     // Array length mismatch in batch operations
error TokenNotConfigured();       // Token not found (only in removeToken)
error Unauthorized();             // Caller is not owner

// Example error handling
try registry.configureToken(address(0), 6, "USDC") {
    // Success
} catch Error(string memory reason) {
    // Handle error
} catch {
    // Handle unknown error
}
```

### Gas Optimization Tips

1. **Use Batch Operations**: Configure multiple tokens in one transaction
2. **Immutable References**: Store registry as immutable in detectors
3. **Cache Decimals**: If checking same token multiple times, cache the result
4. **Avoid Redundant Checks**: Don't call `isConfigured()` if you'll call `getDecimals()` anyway

```solidity
// ✅ GOOD: Cache decimals if used multiple times
uint8 decimals = registry.getDecimals(token);
uint256 amount1Human = amount1 / (10 ** decimals);
uint256 amount2Human = amount2 / (10 ** decimals);

// ❌ BAD: Multiple registry calls
uint256 amount1Human = amount1 / (10 ** registry.getDecimals(token));
uint256 amount2Human = amount2 / (10 ** registry.getDecimals(token));
```

---

## 2. LargeTransferDetector

**Purpose**: Detects unusually large token transfers that may indicate exploits or fund movements

**Location**: `src/reactive-contracts/detectors/LargeTransferDetector.sol`

**Detector ID**: `LARGE_TRANSFER_DETECTOR_V1`

**Monitored Event**: `Transfer(address,address,uint256)`

### Detection Logic

Flags transfers where:
```
transferAmount (in human-readable units) >= threshold
```

### Configurable Parameters

| Parameter | Type | Default | Description | Constraints |
|-----------|------|---------|-------------|-------------|
| `defaultThreshold` | `uint256` | `1_000_000e18` | Default threshold for unconfigured tokens | > 0 |
| `tokenThresholds` | `mapping(address => uint256)` | `0` | Token-specific thresholds | > 0 per token |
| `active` | `bool` | `true` | Detector activation state | true/false |

### Configuration

#### Token-Specific Thresholds
```solidity
// Configure USDC: flag transfers >= $100,000
detector.configureTokenThreshold(
    USDC_ADDRESS,
    100_000e6  // 100,000 USDC (6 decimals)
);

// Configure WETH: flag transfers >= 50 ETH
detector.configureTokenThreshold(
    WETH_ADDRESS,
    50e18  // 50 WETH (18 decimals)
);
```

#### Default Threshold
```solidity
// Set default for unconfigured tokens
detector.setDefaultThreshold(1_000_000e18);  // 1M tokens
```

### Key Functions

| Function | Description | Access |
|----------|-------------|--------|
| `configureTokenThreshold(address, uint256)` | Set token threshold | Owner |
| `removeTokenThreshold(address)` | Remove custom threshold | Owner |
| `setDefaultThreshold(uint256)` | Set default threshold | Owner |
| `getEffectiveThreshold(address)` | Get threshold for token | Public |
| `activate()` / `deactivate()` | Control detector state | Owner |

### Use Cases
- **DeFi Protocol Monitoring**: Detect large withdrawals from protocols
- **Treasury Monitoring**: Flag unusual treasury movements
- **Whale Tracking**: Identify large holder movements
- **Exploit Detection**: Catch large fund extractions

### Example Configurations

```solidity
// Stablecoins (high threshold - common for large trades)
detector.configureTokenThreshold(USDC, 500_000e6);   // $500k
detector.configureTokenThreshold(USDT, 500_000e6);   // $500k
detector.configureTokenThreshold(DAI, 500_000e18);   // $500k

// High-value tokens (lower threshold)
detector.configureTokenThreshold(WETH, 100e18);      // 100 ETH
detector.configureTokenThreshold(WBTC, 5e8);         // 5 BTC

// Governance tokens (medium threshold)
detector.configureTokenThreshold(UNI, 50_000e18);    // 50k UNI
detector.configureTokenThreshold(AAVE, 10_000e18);   // 10k AAVE
```

---

## 3. TracePeelChainDetector

**Purpose**: Detects peel chain patterns where funds are systematically split across multiple addresses to obfuscate trails

**Location**: `src/reactive-contracts/detectors/TracePeelChainDetector.sol`

**Detector ID**: `TRACE_PEEL_CHAIN_DETECTOR_V1`

**Monitored Event**: `Transfer(address,address,uint256)`

### Detection Logic

Uses **stateless heuristics** to identify suspicious patterns:

1. **Round Number Detection**: Flags transfers with round amounts (10, 100, 1000, etc.)
2. **Base Value Analysis**: Considers the base value (e.g., 50 = base 5)
3. **Address Patterns**: Detects sequential address patterns

### Configurable Parameters

| Parameter | Type | Default | Description | Constraints |
|-----------|------|---------|-------------|-------------|
| `minPeelPercentage` | `uint64` | `500` | Minimum peel percentage (basis points) | < maxPeelPercentage |
| `maxPeelPercentage` | `uint64` | `3000` | Maximum peel percentage (basis points) | ≤ 10000 |
| `minPeelCount` | `uint64` | `3` | Minimum peels to trigger detection | > 0 |
| `blockWindow` | `uint64` | `100` | Block window for peel analysis | > 0 |
| `defaultMinTrailingZeros` | `uint8` | `1` | Default min trailing zeros | 0-255 |
| `defaultMaxBaseForBonus` | `uint8` | `10` | Default max base for bonus detection | 0-255 |
| `tokenRoundnessConfig` | `mapping(address => TokenRoundnessConfig)` | - | Token-specific roundness configs | Per token |
| `active` | `bool` | `true` | Detector activation state | true/false |

### Token-Specific Configuration

**NEW FEATURE**: Different tokens can have different roundness thresholds!

```solidity
// Configure token-specific roundness detection
detector.configureTokenRoundness(
    USDC_ADDRESS,
    1,   // minTrailingZeros: detect 10, 100, 1000, etc.
    10   // maxBaseForBonus: bonus detection for base ≤ 10
);
```

#### Parameters

- **`minTrailingZeros`**: Minimum trailing zeros in whole number to flag
  - `0` = Any whole number (1, 2, 5, 10, etc.)
  - `1` = 10, 20, 50, 100, etc.
  - `2` = 100, 200, 500, 1000, etc.
  - `3` = 1000, 2000, 5000, etc.

- **`maxBaseForBonus`**: Maximum base value for bonus detection
  - `10` = Detect 10, 20, 30, ..., 100 (base ≤ 10)
  - `5` = Detect 10, 20, 30, 40, 50 (base ≤ 5)

### Configuration Examples

```solidity
// Stablecoins: Sensitive detection (common for round dollar amounts)
detector.configureTokenRoundness(USDC, 1, 10);  // Detect $10, $100, $1000
detector.configureTokenRoundness(USDT, 1, 10);
detector.configureTokenRoundness(DAI, 1, 10);

// High-value tokens: Moderate sensitivity
detector.configureTokenRoundness(WETH, 1, 5);   // Detect 10, 20, 30, 40, 50 ETH
detector.configureTokenRoundness(WBTC, 2, 5);   // Detect 100, 200, 300, 400, 500 BTC

// Low-value tokens: Conservative (reduce false positives)
detector.configureTokenRoundness(SHIB, 3, 10);  // Only detect 1000+

// Default for unconfigured tokens
detector.configureDefaultRoundness(1, 10);
```

### Detection Examples

With `USDC` configured as `(minTrailingZeros=1, maxBaseForBonus=10)`:

| Amount | Whole Part | Trailing Zeros | Base | Detected? | Reason |
|--------|------------|----------------|------|-----------|--------|
| 5 USDC | 5 | 0 | 5 | ❌ | No trailing zeros |
| 10 USDC | 10 | 1 | 1 | ✅ | 1 zero, base=1 ≤ 10 |
| 25 USDC | 25 | 0 | 25 | ❌ | No trailing zeros |
| 50 USDC | 50 | 1 | 5 | ✅ | 1 zero, base=5 ≤ 10 |
| 60 USDC | 60 | 1 | 6 | ✅ | 1 zero, base=6 ≤ 10 |
| 100 USDC | 100 | 2 | 1 | ✅ | 2 zeros > 1 |
| 250 USDC | 250 | 1 | 25 | ❌ | 1 zero but base=25 > 10 |
| 1000 USDC | 1000 | 3 | 1 | ✅ | 3 zeros > 1 |

### Key Functions

| Function | Description | Access |
|----------|-------------|--------|
| `configureTokenRoundness(address, uint8, uint8)` | Set token-specific thresholds | Owner |
| `configureDefaultRoundness(uint8, uint8)` | Set default thresholds | Owner |
| `getTokenRoundnessConfig(address)` | Get token configuration | Public |
| `configure(uint64, uint64, uint64, uint64)` | Configure peel chain params | Owner |
| `activate()` / `deactivate()` | Control detector state | Owner |

### Peel Chain Configuration

```solidity
// Configure peel chain detection parameters
detector.configure(
    500,   // minPeelPercentage: 5% (in basis points)
    3000,  // maxPeelPercentage: 30%
    3,     // minPeelCount: minimum 3 peels to trigger
    100    // blockWindow: within 100 blocks
);
```

### Use Cases
- **Money Laundering Detection**: Identify systematic fund splitting
- **Mixer Detection**: Catch pre-mixer obfuscation patterns
- **Exploit Tracking**: Follow stolen fund movements
- **Compliance Monitoring**: Flag suspicious transaction patterns

---

## 4. MixerInteractionDetector

**Purpose**: Detects interactions with known cryptocurrency mixer services (e.g., Tornado Cash)

**Location**: `src/reactive-contracts/detectors/MixerInteractionDetector.sol`

**Detector ID**: `MIXER_INTERACTION_DETECTOR_V1`

**Monitored Event**: `Transfer(address,address,uint256)`

### Detection Logic

Flags transfers where:
- **Withdrawal**: `from` is a known mixer → flags `to` address
- **Deposit**: `to` is a known mixer → flags `from` address

### Configurable Parameters

| Parameter | Type | Default | Description | Constraints |
|-----------|------|---------|-------------|-------------|
| `mixerAddresses` | `address[]` | 12 pre-registered | List of known mixer addresses | Valid addresses |
| `mixers` | `mapping(address => MixerInfo)` | - | Mixer metadata (name, timestamp) | Per mixer |
| `active` | `bool` | `true` | Detector activation state | true/false |

**Note**: The detector comes pre-configured with 12 Tornado Cash mixers. Additional mixers can be registered dynamically.

### Pre-Registered Mixers

The detector comes with **12 default Tornado Cash mixers** pre-registered:

| Mixer | Address |
|-------|---------|
| Tornado Cash 0.1 ETH | `0x12D66f87A04A9E220743712cE6d9bB1B5616B8Fc` |
| Tornado Cash 1 ETH | `0x47CE0C6eD5B0Ce3d3A51fdb1C52DC66a7c3c2936` |
| Tornado Cash 10 ETH | `0x910Cbd523D972eb0a6f4cAe4618aD62622b39DbF` |
| Tornado Cash 100 ETH | `0xA160cdAB225685dA1d56aa342Ad8841c3b53f291` |
| Tornado Cash 100 DAI | `0xD4B88Df4D29F5CedD6857912842cff3b20C8Cfa3` |
| Tornado Cash 1000 DAI | `0xFD8610d20aA15b7B2E3Be39B396a1bC3516c7144` |
| Tornado Cash 10000 DAI | `0xF60dD140cFf0706bAE9Cd734Ac3ae76AD9eBC32A` |
| Tornado Cash 100000 DAI | `0x22aaA7720ddd5388A3c0A3333430953C68f1849b` |
| Tornado Cash 100 USDC | `0xBA214C1c1928a32Bffe790263E38B4Af9bFCD659` |
| Tornado Cash 1000 USDC | `0xb1C8094B234DcE6e03f10a5b673c1d8C69739A00` |
| Tornado Cash 100 USDT | `0x527653eA119F3E6a1F5BD18fbF4714081D7B31ce` |
| Tornado Cash 1000 USDT | `0x0836222F2B2B24A3F36f98668Ed8F0B38D1a872f` |

### Configuration

```solidity
// Register additional mixer
detector.registerMixer(
    MIXER_ADDRESS,
    "Custom Mixer Name"
);

// Batch register mixers
address[] memory mixers = [mixer1, mixer2, mixer3];
string[] memory names = ["Mixer 1", "Mixer 2", "Mixer 3"];
detector.registerMixerBatch(mixers, names);
```

### Key Functions

| Function | Description | Access |
|----------|-------------|--------|
| `registerMixer(address, string)` | Register single mixer | Owner |
| `registerMixerBatch(address[], string[])` | Batch register | Owner |
| `isMixer(address)` | Check if address is mixer | Public |
| `getMixerCount()` | Get total mixer count | Public |
| `getAllMixers()` | Get all mixer addresses | Public |
| `getMixerInfo(address)` | Get mixer details | Public |
| `activate()` / `deactivate()` | Control detector state | Owner |

### Use Cases
- **Compliance Monitoring**: Track mixer usage for regulatory compliance
- **Exploit Tracking**: Identify stolen funds being laundered
- **Risk Assessment**: Flag addresses interacting with mixers
- **Chain Analysis**: Map fund flows through privacy services

### Events
- `MixerRegistered(address indexed mixer, string name, uint256 timestamp)`

---

## Detector Comparison

| Feature | LargeTransfer | TracePeelChain | MixerInteraction |
|---------|---------------|----------------|------------------|
| **Detection Type** | Amount-based | Pattern-based | Address-based |
| **Configuration Complexity** | Low | Medium | Low |
| **False Positive Risk** | Low | Medium | Very Low |
| **Token-Specific Config** | ✅ Yes | ✅ Yes | ❌ No |
| **Default Config** | ✅ Yes | ✅ Yes | ✅ Yes (12 mixers) |
| **Batch Operations** | ❌ No | ❌ No | ✅ Yes |
| **Real-time Detection** | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Common Configuration Patterns

### 1. DeFi Protocol Monitoring

```solidity
// Large transfers
largeTransferDetector.configureTokenThreshold(USDC, 1_000_000e6);
largeTransferDetector.configureTokenThreshold(WETH, 500e18);

// Peel chains (sensitive)
peelChainDetector.configureTokenRoundness(USDC, 1, 10);
peelChainDetector.configureTokenRoundness(WETH, 1, 10);

// Mixer interactions (default config sufficient)
```

### 2. High-Security Treasury

```solidity
// Large transfers (very sensitive)
largeTransferDetector.configureTokenThreshold(USDC, 50_000e6);
largeTransferDetector.configureTokenThreshold(WETH, 10e18);

// Peel chains (very sensitive)
peelChainDetector.configureTokenRoundness(USDC, 1, 5);
peelChainDetector.configureTokenRoundness(WETH, 1, 5);

// Mixer interactions (add custom mixers if needed)
mixerDetector.registerMixer(CUSTOM_MIXER, "Custom Privacy Service");
```

### 3. Public Protocol (Reduce False Positives)

```solidity
// Large transfers (less sensitive)
largeTransferDetector.configureTokenThreshold(USDC, 5_000_000e6);
largeTransferDetector.configureTokenThreshold(WETH, 1000e18);

// Peel chains (conservative)
peelChainDetector.configureTokenRoundness(USDC, 2, 10);
peelChainDetector.configureTokenRoundness(WETH, 2, 10);

// Mixer interactions (default only)
```

---

## Best Practices

### 1. Configuration Strategy
- ✅ Start conservative (higher thresholds) and adjust based on false positive rates
- ✅ Configure high-volume tokens individually
- ✅ Use sensible defaults for long-tail tokens
- ✅ Review and update configurations quarterly

### 2. Token-Specific Tuning
- ✅ **Stablecoins**: Lower thresholds (common for round amounts)
- ✅ **High-value tokens**: Moderate thresholds (even small amounts matter)
- ✅ **Low-value tokens**: Higher thresholds (reduce noise)
- ✅ **Governance tokens**: Context-dependent (consider voting patterns)

### 3. Monitoring & Maintenance
- ✅ Monitor detection rates and false positive percentages
- ✅ Analyze flagged transactions to refine thresholds
- ✅ Keep mixer lists updated with new services
- ✅ Document configuration changes and rationale

### 4. Integration
- ✅ All detectors share the same `TokenRegistry`
- ✅ Detectors can be activated/deactivated independently
- ✅ Configuration changes take effect immediately
- ✅ Use batch operations for efficiency

---

## Testing

All detectors have comprehensive test coverage:

| Test Suite | Tests | Coverage |
|------------|-------|----------|
| TokenRegistry | 25 | 100% |
| LargeTransferDetector | 26 | 100% |
| TracePeelChainDetector | 37 | 100% |
| MixerInteractionDetector | 26 | 100% |
| **TOTAL** | **114** | **100%** |

Run tests:
```bash
# All detector tests
forge test --match-path "test/detectors/*.t.sol"

# Specific detector
forge test --match-path "test/detectors/LargeTransferDetector.t.sol"

# With gas reporting
forge test --match-path "test/detectors/*.t.sol" --gas-report
```

---

## Gas Optimization

All detectors are optimized for gas efficiency:

- ✅ **Immutable registry reference**: Saves ~2,100 gas per detection
- ✅ **Packed storage**: Configuration parameters use minimal slots
- ✅ **View functions**: Detection logic doesn't modify state
- ✅ **Efficient lookups**: O(1) configuration retrieval
- ✅ **Minimal payload**: Only essential data in callbacks

---

## Deployment Checklist

### 1. Deploy TokenRegistry
```solidity
TokenRegistry registry = new TokenRegistry();
```

### 2. Configure Common Tokens
```solidity
registry.configureToken(USDC, 6, "USDC");
registry.configureToken(USDT, 6, "USDT");
registry.configureToken(DAI, 18, "DAI");
registry.configureToken(WETH, 18, "WETH");
registry.configureToken(WBTC, 8, "WBTC");
```

### 3. Deploy Detectors
```solidity
LargeTransferDetector largeTransfer = new LargeTransferDetector(address(registry));
TracePeelChainDetector peelChain = new TracePeelChainDetector(address(registry));
MixerInteractionDetector mixer = new MixerInteractionDetector(address(registry));
```

### 4. Configure Detectors
```solidity
// Set thresholds based on your risk profile
largeTransfer.configureTokenThreshold(USDC, 100_000e6);
peelChain.configureTokenRoundness(USDC, 1, 10);
// Mixer detector comes pre-configured with 12 Tornado Cash mixers
```

### 5. Register with Singleton Hub
```solidity
vedyxDetector.registerDetector(address(largeTransfer));
vedyxDetector.registerDetector(address(peelChain));
vedyxDetector.registerDetector(address(mixer));
```

### 6. Activate Detectors
```solidity
largeTransfer.activate();
peelChain.activate();
mixer.activate();
```

---

## Support & Documentation

- **Main Documentation**: `DETECTOR_CONFIGURATION.md`
- **Architecture**: `src/AGENTS.md`
- **Test Examples**: `test/detectors/`
- **Source Code**: `src/reactive-contracts/detectors/`

---

## Version History

- **v1.0.0** (2026-03-03)
  - Initial release with 3 detectors
  - Token-specific configuration for TracePeelChainDetector
  - Shared TokenRegistry architecture
  - 100% test coverage (114 tests)

---

## Future Enhancements

Planned detector additions:
- 🔜 **FlashLoanDetector**: Detect flash loan attacks
- 🔜 **ReentrancyDetector**: Identify reentrancy patterns
- 🔜 **ApprovalDetector**: Monitor suspicious approvals
- 🔜 **PriceManipulationDetector**: Detect oracle manipulation
- 🔜 **RugPullDetector**: Identify rug pull patterns

---

*Last Updated: March 3, 2026*
*Protocol Version: 1.0.0*
