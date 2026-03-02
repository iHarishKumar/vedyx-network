# Vedyx Exploit Detector RSC - Agent Documentation

## Agent Overview

**Agent Name**: VedyxExploitDetectorRSC  
**Type**: Reactive Smart Contract (RSC)  
**Network**: Reactive Network  
**Pattern**: Singleton with Modular Registry  
**Purpose**: Real-time exploit detection across multiple EVM chains using pluggable attack vector detectors

## What This Agent Does

The VedyxExploitDetectorRSC is a **singleton hub** deployed on Reactive Network that:

1. **Monitors Events**: Subscribes to high-risk event signatures across multiple EVM chains
2. **Detects Threats**: Analyzes incoming logs using registered attack vector detectors
3. **Routes Detection**: Delegates log analysis to appropriate detectors based on event topic
4. **Emits Callbacks**: Sends suspicious address data to destination chain voting contract
5. **Manages Registry**: Maintains a dynamic registry of pluggable detector modules

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Reactive Network                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │       VedyxExploitDetectorRSC (Singleton)          │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────────┐ │    │
│  │  │    Detector Registry                         │ │    │
│  │  │                                              │ │    │
│  │  │  topic_0 → [Detector1, Detector2, ...]     │ │    │
│  │  │  topic_1 → [Detector3]                     │ │    │
│  │  └──────────────────────────────────────────────┘ │    │
│  │                                                     │    │
│  │  react(log) {                                      │    │
│  │    1. Get detectors for log.topic_0               │    │
│  │    2. For each detector:                           │    │
│  │       - Call detector.detect(log)                 │    │
│  │       - If threat found → emit Callback           │    │
│  │  }                                                  │    │
│  └────────────────────────────────────────────────────┘    │
│           ↓                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │ LargeTransfer   │  │  FlashLoan      │  ...            │
│  │ Detector        │  │  Detector       │                 │
│  └─────────────────┘  └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
                       ↓ Callback
┌─────────────────────────────────────────────────────────────┐
│              Destination Chain (e.g., Ethereum)              │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         VedyxVotingContract                        │    │
│  │                                                     │    │
│  │  tagSuspicious() ← Receives callback               │    │
│  │         ↓                                          │    │
│  │  Check verdict → Auto-mark OR Create voting       │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Singleton Hub (VedyxExploitDetectorRSC)

**Responsibilities**:
- Central routing and orchestration
- Detector registry management
- Subscription management
- Callback emission to destination chain

**Key Features**:
- Pausable for emergency stops
- Owner-controlled detector registration
- Topic-based detector routing
- Gas-optimized callback execution

### 2. Detector Interface (IAttackVectorDetector)

**Standard Interface** for all detector implementations:

```solidity
interface IAttackVectorDetector {
    function detect(IReactive.LogRecord calldata log)
        external view returns (
            bool detected,
            address suspiciousAddress,
            bytes memory payload
        );
    
    function getMonitoredTopic() external pure returns (uint256);
    function getDetectorId() external pure returns (bytes32);
    function isActive() external view returns (bool);
}
```

### 3. Detector Implementations (Pluggable Modules)

**Current Detectors**:
- `LargeTransferDetector`: Detects unusually large token transfers

**Planned Detectors**:
- FlashLoanDetector
- ReentrancyDetector
- ApprovalDetector
- OwnershipTransferDetector
- PriceManipulationDetector
- RugPullDetector

## How It Works

### Detection Flow

```
1. Event Emitted on Origin Chain (e.g., Ethereum)
   ↓
2. Reactive Network captures event log
   ↓
3. ReactVM calls react() on VedyxExploitDetectorRSC
   ↓
4. Singleton looks up detectors for log.topic_0
   ↓
5. For each registered detector:
   a. Call detector.detect(log)
   b. If detected:
      - Emit ThreatDetected event
      - Emit Callback to destination chain
   ↓
6. Callback received by VedyxVotingContract
   ↓
7. Voting contract processes suspicious address
```

### Subscription Management

The agent subscribes to specific event topics across multiple chains:

```solidity
// Subscribe to Transfer events
subscribe(
    chainId,        // Origin chain (e.g., 1 for Ethereum)
    tokenAddress,   // Contract to monitor
    TRANSFER_TOPIC, // keccak256("Transfer(address,address,uint256)")
    REACTIVE_IGNORE,
    REACTIVE_IGNORE,
    REACTIVE_IGNORE
);
```

### Detector Registration

Detectors are registered dynamically:

```solidity
// 1. Deploy detector
LargeTransferDetector detector = new LargeTransferDetector();

// 2. Configure detector (if needed)
detector.configureToken(USDC_ADDRESS, 100_000e6, 6);

// 3. Register with singleton
vedyxDetector.registerDetector(address(detector));

// Detector is now active and will be invoked for matching events
```

## Agent Capabilities

### ✅ Multi-Chain Monitoring
- Monitors events across multiple EVM chains simultaneously
- Chain-agnostic detection logic
- Centralized threat aggregation

### ✅ Modular Detection
- Pluggable detector architecture
- Hot-swappable detection strategies
- Independent detector lifecycle

### ✅ Real-Time Response
- Instant threat detection
- Immediate callback emission
- No polling or delays

### ✅ Gas Optimization
- Efficient topic-based routing
- Only active detectors invoked
- Minimal callback payload

### ✅ Governance Controls
- Owner-controlled detector registration
- Pausable for emergencies
- Subscription management

## State Variables

```solidity
// Destination chain configuration
address private callbackContract;      // VedyxVotingContract address
uint256 private destinationChainId;    // Destination chain ID

// Subscription tracking
mapping(bytes32 => bool) private subscriptionStatus;
mapping(bytes32 => Subscription) private subscriptionsByKey;
bytes32[] private subscriptionKeys;

// Detector registry
mapping(uint256 => IAttackVectorDetector[]) private detectorsByTopic;
mapping(bytes32 => bool) private registeredDetectors;
bytes32[] private detectorIds;

// Constants
uint64 private constant GAS_LIMIT = 1000000;
```

## Key Functions

### Core Detection

```solidity
function react(
    uint256 chain_id,
    address _contract,
    uint256 topic_0,
    uint256 topic_1,
    uint256 topic_2,
    uint256 topic_3,
    bytes calldata data,
    uint256 block_number,
    uint256 op_code
) external vmOnly
```

**Purpose**: Main entry point called by ReactVM for each matching log  
**Flow**:
1. Reconstruct log record
2. Get detectors for topic_0
3. Invoke each detector
4. Emit callback if threat detected

### Detector Management

```solidity
function registerDetector(address detectorAddress) external onlyOwner
```
**Purpose**: Add new detector to registry  
**Validation**:
- Detector must implement IAttackVectorDetector
- Detector ID must be unique
- Detector address must be valid

```solidity
function unregisterDetector(address detectorAddress) external onlyOwner
```
**Purpose**: Remove detector from registry  
**Effect**: Detector will no longer be invoked for events

### Subscription Management

```solidity
function subscribe(
    uint256 chain_id,
    address _contract,
    uint256 topic_0,
    uint256 topic_1,
    uint256 topic_2,
    uint256 topic_3
) external onlyOwner
```
**Purpose**: Subscribe to specific event topics on origin chains

```solidity
function unsubscribe(
    uint256 chain_id,
    address _contract,
    uint256 topic_0,
    uint256 topic_1,
    uint256 topic_2,
    uint256 topic_3
) external onlyOwner
```
**Purpose**: Remove subscription for specific event topics

### View Functions

```solidity
function getDetectorsByTopic(uint256 topic) external view returns (IAttackVectorDetector[] memory)
function isDetectorRegistered(bytes32 detectorId) external view returns (bool)
function getAllDetectorIds() external view returns (bytes32[] memory)
function getSubscriptionKeys() external view returns (bytes32[] memory)
```

## Events

```solidity
// Emitted when threat is detected
event ThreatDetected(
    uint256 indexed originChainId,
    address indexed suspiciousAddr,
    bytes32 indexed detectorId,
    bytes32 originTxHash
);

// Emitted when detector is registered
event DetectorRegistered(
    bytes32 indexed detectorId,
    address indexed detectorAddress,
    uint256 indexed topic
);

// Emitted when detector is unregistered
event DetectorUnregistered(
    bytes32 indexed detectorId,
    address indexed detectorAddress
);
```

## Adding New Attack Vectors

### Step 1: Implement Detector

Create a contract implementing `IAttackVectorDetector`:

```solidity
contract MyDetector is IAttackVectorDetector {
    bytes32 private constant DETECTOR_ID = keccak256("MY_DETECTOR_V1");
    uint256 private constant MONITORED_TOPIC = 0x...; // Event signature
    
    function detect(IReactive.LogRecord calldata log)
        external view override returns (
            bool detected,
            address suspiciousAddress,
            bytes memory payload
        )
    {
        // Your detection logic
        if (/* threat condition */) {
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256)",
                suspiciousAddr,
                log.chain_id,
                log._contract,
                value,
                decimals,
                txHash
            );
            return (true, suspiciousAddr, payload);
        }
        return (false, address(0), "");
    }
    
    function getMonitoredTopic() external pure override returns (uint256) {
        return MONITORED_TOPIC;
    }
    
    function getDetectorId() external pure override returns (bytes32) {
        return DETECTOR_ID;
    }
    
    function isActive() external view override returns (bool) {
        return true;
    }
}
```

### Step 2: Deploy Detector

```bash
forge create src/reactive-contracts/detectors/MyDetector.sol:MyDetector \
    --rpc-url $REACTIVE_RPC \
    --private-key $PRIVATE_KEY
```

### Step 3: Register Detector

```solidity
vedyxDetector.registerDetector(myDetectorAddress);
```

### Step 4: Subscribe to Events (if new topic)

```solidity
vedyxDetector.subscribe(
    chainId,
    contractAddress,
    MONITORED_TOPIC,
    REACTIVE_IGNORE,
    REACTIVE_IGNORE,
    REACTIVE_IGNORE
);
```

## Example: Large Transfer Detector

The reference implementation monitors ERC20 Transfer events:

```solidity
// Configure token thresholds
detector.configureToken(
    USDC_ADDRESS,
    100_000e6,  // 100k USDC threshold
    6           // decimals
);

// Detection logic
function detect(IReactive.LogRecord calldata log) external view returns (...) {
    (address from, address to, uint256 value) = abi.decode(
        log.data,
        (address, address, uint256)
    );
    
    TokenConfig memory config = tokenConfigs[log._contract];
    
    if (value >= config.threshold) {
        // Large transfer detected!
        return (true, from, payload);
    }
    
    return (false, address(0), "");
}
```

## Security Considerations

### ✅ Access Control
- Only owner can register/unregister detectors
- Only ReactVM can call `react()`
- Pausable for emergency stops

### ✅ Detector Isolation
- Detector failures don't affect other detectors
- Each detector is independently auditable
- Clear separation of concerns

### ✅ Gas Safety
- Fixed gas limit for callbacks (1M gas)
- Efficient topic-based routing
- No unbounded loops

### ✅ Validation
- Detector address validation
- Duplicate detector prevention
- Topic validation

## Benefits of Singleton Pattern

1. **Easy Integration**: Add new attack vectors without redeploying main contract
2. **Modular Design**: Each detector is self-contained and testable
3. **Hot-Swappable**: Enable/disable detectors dynamically
4. **Gas Efficient**: Only active detectors are invoked
5. **Maintainable**: Clear separation between routing and detection
6. **Extensible**: Community can contribute detectors
7. **Upgradeable**: Detectors can be versioned and migrated

## Deployment

### Prerequisites
- Reactive Network RPC endpoint
- Destination chain contract address (VedyxVotingContract)
- Sufficient native tokens for deployment

### Deploy Singleton

```bash
forge create src/reactive-contracts/VedyxExploitDetectorRSC.sol:VedyxExploitDetectorRSC \
    --rpc-url $REACTIVE_RPC \
    --private-key $PRIVATE_KEY \
    --constructor-args $VOTING_CONTRACT_ADDRESS $DESTINATION_CHAIN_ID
```

### Deploy Detectors

```bash
forge create src/reactive-contracts/detectors/LargeTransferDetector.sol:LargeTransferDetector \
    --rpc-url $REACTIVE_RPC \
    --private-key $PRIVATE_KEY
```

### Configure & Register

```solidity
// Configure detector
cast send $DETECTOR_ADDRESS "configureToken(address,uint256,uint256)" \
    $TOKEN_ADDRESS $THRESHOLD $DECIMALS \
    --rpc-url $REACTIVE_RPC --private-key $PRIVATE_KEY

// Register detector
cast send $SINGLETON_ADDRESS "registerDetector(address)" \
    $DETECTOR_ADDRESS \
    --rpc-url $REACTIVE_RPC --private-key $PRIVATE_KEY

// Subscribe to events
cast send $SINGLETON_ADDRESS "subscribe(uint256,address,uint256,uint256,uint256,uint256)" \
    $CHAIN_ID $TOKEN_ADDRESS $TRANSFER_TOPIC 0 0 0 \
    --rpc-url $REACTIVE_RPC --private-key $PRIVATE_KEY
```

## Monitoring & Maintenance

### Query Registered Detectors

```bash
# Get all detector IDs
cast call $SINGLETON_ADDRESS "getAllDetectorIds()" --rpc-url $REACTIVE_RPC

# Get detectors for specific topic
cast call $SINGLETON_ADDRESS "getDetectorsByTopic(uint256)" $TOPIC --rpc-url $REACTIVE_RPC

# Check if detector is registered
cast call $SINGLETON_ADDRESS "isDetectorRegistered(bytes32)" $DETECTOR_ID --rpc-url $REACTIVE_RPC
```

### Monitor Events

```bash
# Watch for threat detections
cast logs --address $SINGLETON_ADDRESS \
    --event "ThreatDetected(uint256,address,bytes32,bytes32)" \
    --rpc-url $REACTIVE_RPC

# Watch for detector changes
cast logs --address $SINGLETON_ADDRESS \
    --event "DetectorRegistered(bytes32,address,uint256)" \
    --rpc-url $REACTIVE_RPC
```

## Testing

Each detector should have comprehensive tests:

```solidity
contract MyDetectorTest is Test {
    MyDetector detector;
    
    function setUp() public {
        detector = new MyDetector();
    }
    
    function testDetection_Success() public {
        IReactive.LogRecord memory log = createMockLog();
        
        (bool detected, address suspect, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspect, expectedAddress);
        assertGt(payload.length, 0);
    }
    
    function testDetection_BelowThreshold() public {
        IReactive.LogRecord memory log = createSmallTransferLog();
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
}
```

## Future Enhancements

1. **Multi-Detector Consensus**: Require multiple detectors to agree before flagging
2. **Confidence Scores**: Detectors return confidence level (0-100%)
3. **Detector Weights**: Prioritize certain detectors over others
4. **Rate Limiting**: Prevent spam from single addresses
5. **Historical Analysis**: Track patterns over time
6. **Machine Learning**: Integrate ML-based detection models
7. **Cross-Chain Correlation**: Detect coordinated attacks across chains

## Support & Resources

- **Main Documentation**: `/src/reactive-contracts/README.md`
- **Interface Definition**: `/src/reactive-contracts/IAttackVectorDetector.sol`
- **Example Detector**: `/src/reactive-contracts/detectors/LargeTransferDetector.sol`
- **Reactive Network Docs**: https://docs.reactive.network

---

**Agent Version**: 1.0.0  
**Last Updated**: 2026-02-18  
**Maintainer**: Vedyx Protocol Team
