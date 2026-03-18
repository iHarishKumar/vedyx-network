// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../interfaces/IAttackVectorDetector.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {TokenRegistry} from "./TokenRegistry.sol";

error InvalidTokenAddress();
error ThresholdMustBeGreaterThanZero();
error TokenNotConfigured();
error InvalidRegistryAddress();

/**
 * @title LargeTransferDetector
 * @notice Detects unusually large token transfers that may indicate exploits
 * @dev Implements IAttackVectorDetector to plug into VedyxExploitDetectorRSC
 */
contract LargeTransferDetector is IAttackVectorDetector, Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TOPIC_TRANSFER = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    uint256 private constant DEFAULT_THRESHOLD = 1_000;

    bytes32 private constant DETECTOR_ID = keccak256("LARGE_TRANSFER_DETECTOR_V1");

    // ─── State ────────────────────────────────────────────────────────
    bool public active;
    
    /// @notice Reference to shared TokenRegistry
    TokenRegistry public immutable registry;

    /// @notice Token-specific thresholds (detector-specific config)
    mapping(address => uint256) private tokenThresholds;
    mapping(address => bool) private tokenConfigured;

    // ─── Events ───────────────────────────────────────────────────────────
    event TokenThresholdConfigured(address indexed tokenAddress, uint256 threshold);
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
    }

    // ─── IAttackVectorDetector Implementation ─────────────────────────────
    /**
     * @notice Analyzes a log record for large transfer patterns
     * @param log The log record to analyze
     * @return detected Whether a threat was detected
     * @return suspiciousAddress The address flagged as suspicious
     * @return payload The encoded callback payload
     */
    function detect(IReactive.LogRecord calldata log)
        external
        view
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
            
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256,bytes32)",
                from,
                log.chain_id,
                tokenContract,
                value,
                decimals,
                log.tx_hash,
                DETECTOR_ID
            );

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

    // ─── Configuration Management ─────────────────────────────────────────
    /**
     * @notice Configures the threshold for a specific token
     * @dev Decimals are retrieved from shared TokenRegistry
     * @param tokenAddress The address of the token contract
     * @param threshold The threshold value in token's native decimals
     */
    function configureTokenThreshold(address tokenAddress, uint256 threshold) external onlyOwner {
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
    function getTokenThreshold(address tokenAddress)
        external
        view
        returns (uint256 threshold, bool isConfigured)
    {
        return (tokenThresholds[tokenAddress], tokenConfigured[tokenAddress]);
    }

    /**
     * @notice Returns the effective threshold for a token
     * @param tokenAddress The address of the token to query
     * @return The threshold that will be used for this token
     */
    function getEffectiveThreshold(address tokenAddress) external view returns (uint256) {
        return tokenConfigured[tokenAddress] ? tokenThresholds[tokenAddress] : DEFAULT_THRESHOLD;
    }

    /**
     * @notice Returns the default threshold
     * @return The default threshold value
     */
    function getDefaultThreshold() external pure returns (uint256) {
        return DEFAULT_THRESHOLD;
    }
}
