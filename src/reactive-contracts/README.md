# Vedyx Exploit Detector - Singleton Architecture

## Overview

The `VedyxExploitDetectorRSC` contract implements a **singleton pattern** with a modular registry system for **post-exploit cashout pattern detection**. This architecture monitors on-chain activity **after exploits occur** to identify addresses attempting to cash out stolen funds.

**Important**: This system does NOT prevent exploits. It monitors suspicious patterns (large transfers, unusual swaps, rapid fund movements) that typically occur when attackers try to convert stolen assets through DEX pools or mixers.

## Architecture

### Core Components

1. **VedyxExploitDetectorRSC** (Singleton Hub)
   - Central contract deployed on Reactive Network
   - Manages a registry of attack vector detectors
   - Routes incoming logs to appropriate detectors
   - Emits callbacks to destination chain when suspicious patterns detected

2. **IAttackVectorDetector** (Interface)
   - Standard interface for all detector implementations
   - Defines the contract for detection logic
   - Ensures compatibility with the singleton hub

3. **Detector Implementations** (Pluggable Modules)
   - Self-contained pattern detection logic
   - Can be registered/unregistered dynamically
   - Examples: `LargeTransferDetector` (flags large transfers that may indicate fund movement)

## How It Works

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
│  │  └──────────────────────────────────────────────┘ │    │
│  │                                                     │    │
│  │  react(log) {                                      │    │
│  │    detectors = registry[log.topic_0]              │    │
│  │    for each detector:                              │    │
│  │      if detector.detect(log) → emit Callback      │    │
│  │  }                                                  │    │
│  └────────────────────────────────────────────────────┘    │
│           ↓                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │ LargeTransfer   │  │  DEX Swap       │  ...            │
│  │ Detector        │  │  Detector       │                 │
│  └─────────────────┘  └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Adding New Attack Vectors

### Step 1: Implement IAttackVectorDetector

Create a new detector contract that implements the interface:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../IAttackVectorDetector.sol";

contract MyCustomDetector is IAttackVectorDetector {
    // Unique identifier for this detector
    bytes32 private constant DETECTOR_ID = keccak256("MY_CUSTOM_DETECTOR_V1");
    
    // Event topic you want to monitor
    uint256 private constant MONITORED_TOPIC = 0x...; // Your event signature
    
    bool public active = true;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function detect(
        IReactive.LogRecord calldata log
    )
        external
        view
        override
        returns (
            bool detected,
            address suspiciousAddress,
            bytes memory payload
        )
    {
        // Your detection logic here
        // Return true if threat detected, along with suspicious address and payload
        
        if (/* your condition */) {
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,...)",
                suspiciousAddr,
                log.chain_id,
                log._contract
                // ... additional parameters
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
        return active;
    }
}
```

### Step 2: Deploy Your Detector

Deploy your detector contract to the Reactive Network:

```bash
forge create src/reactive-contracts/detectors/MyCustomDetector.sol:MyCustomDetector \
    --rpc-url $REACTIVE_RPC \
    --private-key $PRIVATE_KEY
```

### Step 3: Register the Detector

Call `registerDetector()` on the VedyxExploitDetectorRSC singleton:

```solidity
// From your deployment script or manually
vedyxDetector.registerDetector(myCustomDetectorAddress);
```

That's it! Your detector is now active and will be invoked for matching events.

## Example: Large Transfer Detector

The `LargeTransferDetector` is a reference implementation that detects unusually large token transfers:

```solidity
// Deploy the detector
LargeTransferDetector detector = new LargeTransferDetector();

// Configure token-specific thresholds
detector.configureToken(
    USDC_ADDRESS,
    100_000e6,  // 100,000 USDC threshold
    6           // USDC decimals
);

// Register with the singleton
vedyxDetector.registerDetector(address(detector));
```

## Management Functions

### Registering Detectors

```solidity
function registerDetector(address detectorAddress) external onlyOwner
```

Adds a new detector to the registry. The detector will be automatically invoked for logs matching its monitored topic.

### Unregistering Detectors

```solidity
function unregisterDetector(address detectorAddress) external onlyOwner
```

Removes a detector from the registry. Useful for deprecating old detection strategies.

### Querying Detectors

```solidity
// Get all detectors for a specific topic
function getDetectorsByTopic(uint256 topic) external view returns (IAttackVectorDetector[] memory)

// Check if a detector is registered
function isDetectorRegistered(bytes32 detectorId) external view returns (bool)

// Get all registered detector IDs
function getAllDetectorIds() external view returns (bytes32[] memory)
```

## Benefits of Singleton Pattern

1. **Easy Integration**: Add new attack vectors without redeploying the main contract
2. **Modular Design**: Each detector is self-contained and independently testable
3. **Hot-Swappable**: Enable/disable detectors dynamically
4. **Gas Efficient**: Only active detectors are invoked
5. **Maintainable**: Clear separation of concerns between routing and detection logic
6. **Extensible**: Community can contribute new detectors

## Example Attack Vectors to Implement

Here are some ideas for additional detectors:

- **FlashLoanDetector**: Monitors flash loan events and tracks suspicious patterns
- **ReentrancyDetector**: Detects potential reentrancy attacks
- **ApprovalDetector**: Flags unlimited token approvals
- **OwnershipTransferDetector**: Monitors suspicious ownership changes
- **PriceManipulationDetector**: Detects abnormal price movements
- **RugPullDetector**: Identifies liquidity removal patterns

## Testing

Each detector should have comprehensive unit tests:

```solidity
// test/detectors/MyCustomDetector.t.sol
contract MyCustomDetectorTest is Test {
    MyCustomDetector detector;
    
    function setUp() public {
        detector = new MyCustomDetector();
    }
    
    function testDetection() public {
        // Create mock log record
        IReactive.LogRecord memory log = ...;
        
        // Test detection logic
        (bool detected, address suspect, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspect, expectedAddress);
    }
}
```

## Security Considerations

1. **Detector Validation**: Always audit detector implementations before registration
2. **Gas Limits**: Ensure detectors don't consume excessive gas
3. **Access Control**: Only trusted addresses should register detectors
4. **Detector Isolation**: Failures in one detector shouldn't affect others
5. **Upgrade Path**: Plan for detector versioning and migration

## Migration from Legacy Code

If you have existing detection logic in the main contract:

1. Extract the logic into a new detector contract
2. Deploy the detector
3. Register it with the singleton
4. Test thoroughly before removing old code
5. Deprecate the old implementation

## Support

For questions or contributions, please refer to the main project documentation or open an issue on GitHub.
