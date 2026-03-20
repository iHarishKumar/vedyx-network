// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../interfaces/IAttackVectorDetector.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {TokenRegistry} from "./TokenRegistry.sol";
import {AbstractReactive} from "reactive-lib/abstract-base/AbstractReactive.sol";

error InvalidTokenAddress();
error ThresholdMustBeGreaterThanZero();
error TokenNotConfigured();
error InvalidRegistryAddress();

/**
 * @title LargeTransferDetector
 * @notice Detects unusually large token transfers that may indicate exploits
 * @dev Implements IAttackVectorDetector to plug into VedyxExploitDetectorRSC
 */
contract LargeTransferDetector is AbstractReactive, IAttackVectorDetector, Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TOPIC_TRANSFER =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    uint256 private constant DEFAULT_THRESHOLD = 1_000;

    bytes32 private constant DETECTOR_ID =
        keccak256("LARGE_TRANSFER_DETECTOR_V1");
    /// @notice Gas limit for callback execution on the destination chain
    uint64 private constant GAS_LIMIT = 1000000;

    address public callbackContract; // destination-chain registry address
    uint256 public destinationChainId;

    // ─── State ────────────────────────────────────────────────────────
    bool public active;

    /// @notice Reference to shared TokenRegistry
    TokenRegistry public immutable registry;

    /// @notice Token-specific thresholds (detector-specific config)
    mapping(address => uint256) private tokenThresholds;
    mapping(address => bool) private tokenConfigured;

    // ─── Events ───────────────────────────────────────────────────────────
    event TokenThresholdConfigured(
        address indexed tokenAddress,
        uint256 threshold
    );
    event DetectorActivated();
    event DetectorDeactivated();

    // ─── Constructor ──────────────────────────────────────────────────
    /**
     * @param _registry Address of the shared TokenRegistry
     */
    constructor(
        address _registry,
        address _callbackContract_,
        uint256 _destinationChainId_
    ) payable Ownable() {
        if (_registry == address(0)) revert InvalidRegistryAddress();
        registry = TokenRegistry(_registry);
        active = true;
        callbackContract = _callbackContract_;
        destinationChainId = _destinationChainId_;
    }

    // ─── IAttackVectorDetector Implementation ─────────────────────────────
    /**
     * @notice Analyzes a log record for large transfer patterns
     * @param log The log record to analyze
     */
    function react(IReactive.LogRecord calldata log) external override vmOnly {
        if (!active) {
            return;
        }

        if (log.topic_0 != TOPIC_TRANSFER) {
            return;
        }

        if (log.data.length < 32) {
            return;
        }

        address from = address(uint160(log.topic_1));
        address tokenContract = log._contract;

        bytes memory logData = log.data;
        uint256 value;
        assembly {
            value := mload(add(logData, 0x20))
        }

        // Get threshold (detector-specific)
        uint256 threshold = tokenConfigured[tokenContract]
            ? tokenThresholds[tokenContract]
            : DEFAULT_THRESHOLD;

        if (value >= threshold) {
            // Get decimals from shared registry
            uint8 decimals = registry.getDecimals(tokenContract);

            bytes memory payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256,bytes32)",
                from,
                log.chain_id,
                tokenContract,
                value,
                decimals,
                log.tx_hash,
                DETECTOR_ID
            );

            emit Callback(
                destinationChainId,
                callbackContract,
                GAS_LIMIT,
                payload
            );
        }
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

    // ─── Configuration Management ─────────────────────────────────────────
    /**
     * @notice Configures the threshold for a specific token
     * @dev Decimals are retrieved from shared TokenRegistry
     * @param tokenAddress The address of the token contract
     * @param threshold The threshold value in token's native decimals
     */
    function configureTokenThreshold(
        address tokenAddress,
        uint256 threshold
    ) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        if (threshold == 0) revert ThresholdMustBeGreaterThanZero();

        tokenThresholds[tokenAddress] = threshold;
        tokenConfigured[tokenAddress] = true;

        emit TokenThresholdConfigured(tokenAddress, threshold);
    }

    /**
     * @notice Removes the threshold configuration for a specific token
     * @param tokenAddress The address of the token to unconfigure
     */
    function removeTokenThreshold(address tokenAddress) external onlyOwner {
        if (!tokenConfigured[tokenAddress]) {
            revert TokenNotConfigured();
        }
        delete tokenThresholds[tokenAddress];
        delete tokenConfigured[tokenAddress];
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
     * @notice Returns the threshold for a specific token
     * @param tokenAddress The address of the token to query
     * @return threshold The configured threshold value
     * @return isConfigured Whether the token has a threshold configured
     */
    function getTokenThreshold(
        address tokenAddress
    ) external view returns (uint256 threshold, bool isConfigured) {
        return (tokenThresholds[tokenAddress], tokenConfigured[tokenAddress]);
    }

    /**
     * @notice Returns the effective threshold for a token
     * @param tokenAddress The address of the token to query
     * @return The threshold that will be used for this token
     */
    function getEffectiveThreshold(
        address tokenAddress
    ) external view returns (uint256) {
        return
            tokenConfigured[tokenAddress]
                ? tokenThresholds[tokenAddress]
                : DEFAULT_THRESHOLD;
    }

    // ─── Subscription management ─────────────────────────────────────────
    /**
     * @notice Dynamically subscribes to events from a contract on a specified chain
     * @dev Allows the contract owner to add new event subscriptions at runtime.
     * Restricted to Reactive Network calls only.
     * @param chain_id The chain ID where the contract to monitor is deployed
     * @param contract_address The address of the contract to monitor
     * @param topic_0 The event signature hash to subscribe to
     */
    function subscribe(
        uint256 chain_id,
        address contract_address,
        uint256 topic_0
    ) external rnOnly onlyOwner {
        service.subscribe(
            chain_id,
            contract_address,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /**
     * @notice Dynamically unsubscribes from events for a specific contract and event type
     * @dev Allows the contract owner to remove event subscriptions at runtime.
     * Restricted to Reactive Network calls only.
     * @param chain_id The chain ID of the monitored contract
     * @param contract_address The address of the monitored contract
     * @param topic_0 The event signature hash to unsubscribe from
     */
    function unsubscribe(
        uint256 chain_id,
        address contract_address,
        uint256 topic_0
    ) external rnOnly onlyOwner {
        service.unsubscribe(
            chain_id,
            contract_address,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /**
     * @notice Returns the default threshold
     * @return The default threshold value
     */
    function getDefaultThreshold() external pure returns (uint256) {
        return DEFAULT_THRESHOLD;
    }
}
