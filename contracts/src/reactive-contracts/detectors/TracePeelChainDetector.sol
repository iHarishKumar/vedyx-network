// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../interfaces/IAttackVectorDetector.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

error InvalidThreshold();
error InvalidTimeWindow();
error InvalidRegistryAddress();
error InvalidPercentageRange();

/**
 * @title TracePeelChainDetector
 * @notice Detects trace peel chain patterns where funds are systematically split
 *         across multiple addresses to obfuscate transaction trails
 * @dev Implements IAttackVectorDetector with STATEFUL pattern tracking
 * 
 * ─── Detection Strategy ──────────────────────────────────────────────────
 * A peel chain is characterized by:
 * 1. Sequential transfers where a portion of funds is "peeled off" to different addresses
 * 2. Remaining funds continue to the next address in the chain
 * 3. Pattern repeats multiple times to obfuscate the trail
 * 
 * Example Peel Chain:
 * Address A: 100 ETH
 *   → Transfer 10 ETH to Address B (peel)
 *   → Transfer 90 ETH to Address C (continue chain)
 * Address C: 90 ETH
 *   → Transfer 10 ETH to Address D (peel)
 *   → Transfer 80 ETH to Address E (continue chain)
 * 
 * ─── State Tracking Approach ─────────────────────────────────────────────
 * This detector maintains on-chain state to track:
 * - Recent outgoing transfers from each address
 * - Transfer amounts and recipients
 * - Block numbers for time-based analysis
 * - Detected peel patterns and chain depth
 * 
 * ─── Storage Cleanup Mechanisms ──────────────────────────────────────────
 * To minimize gas costs:
 * - Transfers older than blockWindow are automatically pruned
 * - Completed chain analysis triggers cleanup
 * - Only suspicious patterns are retained for callback
 * - Non-suspicious addresses are cleaned after analysis
 */
contract TracePeelChainDetector is IAttackVectorDetector, Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TOPIC_TRANSFER = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    
    bytes32 private constant DETECTOR_ID = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
    
    // Default: 5-30% peel range (typical obfuscation pattern)
    uint256 private constant DEFAULT_MIN_PEEL_PERCENTAGE = 500;  // 5%
    uint256 private constant DEFAULT_MAX_PEEL_PERCENTAGE = 3000; // 30%
    uint256 private constant PERCENTAGE_DENOMINATOR = 10000;     // 100%
    
    // Default: detect if 3+ peels occur within 100 blocks
    uint256 private constant DEFAULT_MIN_PEEL_COUNT = 3;
    uint256 private constant DEFAULT_BLOCK_WINDOW = 100;
    
    // Maximum transfers to track per address (prevent DoS)
    uint256 private constant MAX_TRANSFERS_PER_ADDRESS = 20;
    
    // ─── State Tracking Structures ────────────────────────────────────────
    
    /// @notice Represents a single outgoing transfer from an address
    struct Transfer {
        address recipient;      // Where funds went
        uint256 amount;         // Transfer amount
        uint256 blockNumber;    // When it occurred
        bool isPeel;            // True if this is a small peel, false if continuation
    }
    
    /// @notice Tracks transfer activity for an address
    struct AddressActivity {
        Transfer[] outgoingTransfers;  // Recent outgoing transfers
        uint256 lastIncomingAmount;    // Last received amount (to calculate peel %)
        uint256 lastIncomingBlock;     // Block of last incoming transfer
        uint256 totalOutgoing;         // Sum of outgoing transfers
        uint8 peelCount;               // Number of detected peels
        bool hasPattern;               // True if peel pattern detected
    }
    
    // ─── State Variables ──────────────────────────────────────────────────
    bool public active;
    
    /// @notice Reference to shared TokenRegistry
    TokenRegistry public immutable registry;
    
    // Packed configuration parameters
    uint64 public minPeelPercentage;
    uint64 public maxPeelPercentage;
    uint64 public minPeelCount;
    uint64 public blockWindow;
    
    /// @notice Tracks transfer activity per address per token
    /// @dev Mapping: token => address => activity
    mapping(address => mapping(address => AddressActivity)) private addressActivity;
    
    // ─── Events ───────────────────────────────────────────────────────────
    event PeelChainDetected(
        address indexed suspiciousAddress,
        address indexed token,
        uint256 chainId,
        uint256 peelCount,
        uint256 chainDepth,
        uint256 averagePeelPercentage
    );
    
    event DetectorConfigured(
        uint64 minPeelPercentage,
        uint64 maxPeelPercentage,
        uint64 minPeelCount,
        uint64 blockWindow
    );
    
    event StorageCleanup(
        address indexed token,
        address indexed addr,
        uint256 transfersRemoved
    );
    
    event DetectorActivated();
    event DetectorDeactivated();
    
    // ─── Constructor ──────────────────────────────────────────────────
    /**
     * @param _registry Address of the shared TokenRegistry
     */
    constructor(address _registry) Ownable() {
        if (_registry == address(0)) revert InvalidRegistryAddress();
        registry = TokenRegistry(_registry);
        active = true;
        minPeelPercentage = uint64(DEFAULT_MIN_PEEL_PERCENTAGE);
        maxPeelPercentage = uint64(DEFAULT_MAX_PEEL_PERCENTAGE);
        minPeelCount = uint64(DEFAULT_MIN_PEEL_COUNT);
        blockWindow = uint64(DEFAULT_BLOCK_WINDOW);
    }
    
    // ─── IAttackVectorDetector Implementation ─────────────────────────────
    /**
     * @notice Analyzes a log record for trace peel chain patterns
     * @dev STATEFUL detection - tracks transfer patterns over time
     * @param log The log record to analyze
     * @return detected Whether a threat was detected
     * @return suspiciousAddress The address flagged as suspicious
     * @return payload The encoded callback payload
     */
    function detect(IReactive.LogRecord calldata log)
        external
        override
        returns (bool detected, address suspiciousAddress, bytes memory payload)
    {
        if (!active) {
            return (false, address(0), "");
        }
        
        if (log.topic_0 != TOPIC_TRANSFER) {
            return (false, address(0), "");
        }
        
        if (log.data.length < 32) {
            return (false, address(0), "");
        }
        
        address from = address(uint160(log.topic_1));
        address to = address(uint160(log.topic_2));
        uint256 value = abi.decode(log.data, (uint256));
        address token = log._contract;
        
        if (value == 0 || from == address(0) || to == address(0)) {
            return (false, address(0), "");
        }
        
        // Step 1: Update incoming transfer for recipient
        _recordIncomingTransfer(token, to, value, log.block_number);
        
        // Step 2: Analyze sender's outgoing pattern
        bool isPattern = _analyzeAndRecordOutgoing(token, from, to, value, log.block_number);
        
        // Step 3: Cleanup old data
        _cleanupOldTransfers(token, from, log.block_number);
        
        if (isPattern) {
            payload = _createPayload(from, token, value, log.chain_id, log.tx_hash);
            _emitDetectionEvent(token, from, log.chain_id);
            // Lets not cleanup the address as we need it for tracing in the FE
            // _cleanupAddress(token, from);
            return (true, from, payload);
        }
        
        return (false, address(0), "");
    }
    
    /**
     * @notice Returns the event topic_0 that this detector monitors
     * @return The Transfer event signature hash
     */
    function getMonitoredTopic() external pure override returns (uint256) {
        return TOPIC_TRANSFER;
    }
    
    /**
     * @notice Returns a unique identifier for this detector
     * @return The detector's unique identifier
     */
    function getDetectorId() external pure override returns (bytes32) {
        return DETECTOR_ID;
    }
    
    
    /**
     * @notice Returns whether this detector is active
     * @return True if the detector is active
     */
    function isActive() external view override returns (bool) {
        return active;
    }
    
    // ─── Internal State Management Functions ──────────────────────────────
    
    /**
     * @notice Records an incoming transfer for an address
     * @dev Updates the lastIncomingAmount to calculate peel percentages
     */
    function _recordIncomingTransfer(
        address token,
        address recipient,
        uint256 amount,
        uint256 blockNumber
    ) internal {
        AddressActivity storage activity = addressActivity[token][recipient];
        activity.lastIncomingAmount = amount;
        activity.lastIncomingBlock = blockNumber;
    }
    
    /**
     * @notice Analyzes outgoing transfer and detects peel chain patterns
     * @dev Core pattern detection logic - checks for multiple peels
     * @return True if peel chain pattern detected
     */
    function _analyzeAndRecordOutgoing(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 blockNumber
    ) internal returns (bool) {
        AddressActivity storage activity = addressActivity[token][from];
        
        // Check if we have incoming amount to calculate percentage
        if (activity.lastIncomingAmount == 0) {
            // First outgoing transfer, just record it
            _addTransfer(activity, to, amount, blockNumber, false);
            return false;
        }
        
        // Calculate what percentage of incoming amount this transfer represents
        uint256 percentage = (amount * PERCENTAGE_DENOMINATOR) / activity.lastIncomingAmount;
        
        // Determine if this is a peel or continuation
        bool isPeel = (percentage >= minPeelPercentage && percentage <= maxPeelPercentage);
        
        // Add transfer to history
        _addTransfer(activity, to, amount, blockNumber, isPeel);
        
        if (isPeel) {
            activity.peelCount++;
        }
        
        activity.totalOutgoing += amount;
        
        // Check if pattern threshold reached
        if (activity.peelCount >= minPeelCount) {
            // Check if all peels occurred within block window
            if (_isWithinBlockWindow(activity)) {
                activity.hasPattern = true;
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @notice Adds a transfer to address activity history
     * @dev Prevents DoS by limiting max transfers tracked
     */
    function _addTransfer(
        AddressActivity storage activity,
        address recipient,
        uint256 amount,
        uint256 blockNumber,
        bool isPeel
    ) internal {
        // Prevent DoS: limit number of tracked transfers
        if (activity.outgoingTransfers.length >= MAX_TRANSFERS_PER_ADDRESS) {
            // Remove oldest transfer
            _removeOldestTransfer(activity);
        }
        
        activity.outgoingTransfers.push(Transfer({
            recipient: recipient,
            amount: amount,
            blockNumber: blockNumber,
            isPeel: isPeel
        }));
    }
    
    /**
     * @notice Removes the oldest transfer from history
     * @dev Used to prevent DoS and manage storage costs
     */
    function _removeOldestTransfer(AddressActivity storage activity) internal {
        if (activity.outgoingTransfers.length == 0) return;
        
        // Shift all elements left by one
        for (uint256 i = 0; i < activity.outgoingTransfers.length - 1; i++) {
            activity.outgoingTransfers[i] = activity.outgoingTransfers[i + 1];
        }
        activity.outgoingTransfers.pop();
    }
    
    /**
     * @notice Checks if all peels occurred within the configured block window
     * @dev Temporal analysis to confirm pattern timing
     */
    function _isWithinBlockWindow(
        AddressActivity storage activity
    ) internal view returns (bool) {
        if (activity.outgoingTransfers.length == 0) return false;
        
        uint256 oldestBlock = type(uint256).max;
        uint256 newestBlock = 0;
        
        // Find the block range of peel transfers
        for (uint256 i = 0; i < activity.outgoingTransfers.length; i++) {
            if (activity.outgoingTransfers[i].isPeel) {
                uint256 blockNum = activity.outgoingTransfers[i].blockNumber;
                if (blockNum < oldestBlock) oldestBlock = blockNum;
                if (blockNum > newestBlock) newestBlock = blockNum;
            }
        }
        
        // Check if peels span within block window
        return (newestBlock - oldestBlock) <= blockWindow;
    }
    
    /**
     * @notice Cleans up old transfers outside the block window
     * @dev Automatic storage cleanup to minimize gas costs
     */
    function _cleanupOldTransfers(
        address token,
        address addr,
        uint256 currentBlock
    ) internal {
        AddressActivity storage activity = addressActivity[token][addr];
        
        if (activity.outgoingTransfers.length == 0) return;
        
        uint256 cutoffBlock = currentBlock > blockWindow ? currentBlock - blockWindow : 0;
        uint256 removeCount = 0;
        
        // Count how many old transfers to remove
        for (uint256 i = 0; i < activity.outgoingTransfers.length; i++) {
            if (activity.outgoingTransfers[i].blockNumber < cutoffBlock) {
                removeCount++;
            } else {
                break; // Transfers are ordered by time
            }
        }
        
        if (removeCount > 0) {
            // Shift remaining transfers
            for (uint256 i = 0; i < activity.outgoingTransfers.length - removeCount; i++) {
                activity.outgoingTransfers[i] = activity.outgoingTransfers[i + removeCount];
            }
            
            // Remove old entries
            for (uint256 i = 0; i < removeCount; i++) {
                activity.outgoingTransfers.pop();
            }
            
            emit StorageCleanup(token, addr, removeCount);
        }
    }
    
    /**
     * @notice Completely cleans up address activity after detection
     * @dev Called after pattern is detected and reported
     */
    function _cleanupAddress(address token, address addr) internal {
        AddressActivity storage activity = addressActivity[token][addr];
        
        uint256 transferCount = activity.outgoingTransfers.length;
        
        // Clear all transfers
        delete addressActivity[token][addr];
        
        if (transferCount > 0) {
            emit StorageCleanup(token, addr, transferCount);
        }
    }
    
    /**
     * @notice Calculates average peel percentage from activity
     * @dev Used for reporting in events
     */
    function _calculateAveragePeelPercentage(
        AddressActivity storage activity
    ) internal view returns (uint256) {
        if (activity.peelCount == 0 || activity.lastIncomingAmount == 0) return 0;
        
        uint256 totalPeelAmount = 0;
        uint256 peelCount = 0;
        
        for (uint256 i = 0; i < activity.outgoingTransfers.length; i++) {
            if (activity.outgoingTransfers[i].isPeel) {
                totalPeelAmount += activity.outgoingTransfers[i].amount;
                peelCount++;
            }
        }
        
        if (peelCount == 0) return 0;
        
        uint256 avgPeelAmount = totalPeelAmount / peelCount;
        return (avgPeelAmount * PERCENTAGE_DENOMINATOR) / activity.lastIncomingAmount;
    }
    
    /**
     * @notice Creates the callback payload for detected peel chains
     * @dev Extracted to separate function to avoid stack too deep errors
     */
    function _createPayload(
        address from,
        address token,
        uint256 value,
        uint256 chainId,
        uint256 txHash
    ) internal view returns (bytes memory) {
        uint8 decimals = registry.getDecimals(token);
        
        return abi.encodeWithSignature(
            "tagSuspicious(address,uint256,address,uint256,uint256,uint256,bytes32)",
            from,
            chainId,
            token,
            value,
            decimals,
            txHash,
            DETECTOR_ID
        );
    }
    
    /**
     * @notice Emits the PeelChainDetected event
     * @dev Extracted to separate function to avoid stack too deep errors
     */
    function _emitDetectionEvent(
        address token,
        address from,
        uint256 chainId
    ) internal {
        AddressActivity storage activity = addressActivity[token][from];
        uint256 avgPeelPercentage = _calculateAveragePeelPercentage(activity);
        
        emit PeelChainDetected(
            from,
            token,
            chainId,
            activity.peelCount,
            activity.outgoingTransfers.length,
            avgPeelPercentage
        );
    }
    
    // ─── Configuration Management ─────────────────────────────────────────
    /**
     * @notice Configures the peel chain detection parameters
     * @param _minPeelPercentage Minimum peel percentage (in basis points, e.g., 500 = 5%)
     * @param _maxPeelPercentage Maximum peel percentage (in basis points, e.g., 3000 = 30%)
     * @param _minPeelCount Minimum number of peels to trigger detection
     * @param _blockWindow Block window to analyze for peel patterns
     */
    function configure(
        uint64 _minPeelPercentage,
        uint64 _maxPeelPercentage,
        uint64 _minPeelCount,
        uint64 _blockWindow
    ) external onlyOwner {
        if (_minPeelPercentage >= _maxPeelPercentage) revert InvalidThreshold();
        if (_maxPeelPercentage > PERCENTAGE_DENOMINATOR) revert InvalidThreshold();
        if (_minPeelCount == 0) revert InvalidThreshold();
        if (_blockWindow == 0) revert InvalidTimeWindow();
        
        minPeelPercentage = _minPeelPercentage;
        maxPeelPercentage = _maxPeelPercentage;
        minPeelCount = _minPeelCount;
        blockWindow = _blockWindow;
        
        emit DetectorConfigured(_minPeelPercentage, _maxPeelPercentage, _minPeelCount, _blockWindow);
    }
    
    
    /**
     * @notice Manual cleanup function for gas optimization
     * @dev Allows owner to cleanup specific addresses
     */
    function manualCleanup(address token, address addr) external onlyOwner {
        _cleanupAddress(token, addr);
    }
    
    /**
     * @notice Returns activity data for an address (for testing/debugging)
     * @param token Token address
     * @param addr Address to query
     * @return transferCount Number of tracked transfers
     * @return peelCount Number of detected peels
     * @return hasPattern Whether pattern was detected
     * @return lastIncomingAmount Last incoming transfer amount
     */
    function getAddressActivity(address token, address addr) external view returns (
        uint256 transferCount,
        uint8 peelCount,
        bool hasPattern,
        uint256 lastIncomingAmount
    ) {
        AddressActivity storage activity = addressActivity[token][addr];
        return (
            activity.outgoingTransfers.length,
            activity.peelCount,
            activity.hasPattern,
            activity.lastIncomingAmount
        );
    }
    
    /**
     * @notice Activates the detector
     */
    function activate() external onlyOwner {
        active = true;
        emit DetectorActivated();
    }
    
    /**
     * @notice Deactivates the detector
     */
    function deactivate() external onlyOwner {
        active = false;
        emit DetectorDeactivated();
    }
    
    // ─── Getters ──────────────────────────────────────────────────────────
    /**
     * @notice Returns the detector configuration
     * @return _minPeelPercentage Minimum peel percentage
     * @return _maxPeelPercentage Maximum peel percentage
     * @return _minPeelCount Minimum peel count
     * @return _blockWindow Block window
     */
    function getConfiguration() external view returns (
        uint256 _minPeelPercentage,
        uint256 _maxPeelPercentage,
        uint256 _minPeelCount,
        uint256 _blockWindow
    ) {
        return (minPeelPercentage, maxPeelPercentage, minPeelCount, blockWindow);
    }
    
    
}
