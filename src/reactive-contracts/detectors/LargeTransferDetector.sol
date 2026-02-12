// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../IAttackVectorDetector.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

error InvalidTokenAddress();
error ThresholdMustBeGreaterThanZero();
error TokenNotConfigured();

/**
 * @title LargeTransferDetector
 * @notice Detects unusually large token transfers that may indicate exploits
 * @dev Implements IAttackVectorDetector to plug into VedyxExploitDetectorRSC
 */
contract LargeTransferDetector is IAttackVectorDetector, Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TOPIC_TRANSFER =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    
    uint256 private constant DEFAULT_THRESHOLD = 1_000;
    
    bytes32 private constant DETECTOR_ID = keccak256("LARGE_TRANSFER_DETECTOR_V1");

    // ─── State ────────────────────────────────────────────────────────
    bool public active;

    struct TokenConfig {
        uint256 threshold;
        uint8 decimals;
        bool isConfigured;
    }

    mapping(address => TokenConfig) private tokenConfigs;

    // ─── Events ───────────────────────────────────────────────────────────
    event TokenConfigured(
        address indexed tokenAddress,
        uint256 threshold,
        uint8 decimals
    );

    event DetectorActivated();
    event DetectorDeactivated();

    // ─── Constructor ──────────────────────────────────────────────────
    constructor() Ownable() {
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

        uint256 threshold = DEFAULT_THRESHOLD;
        TokenConfig memory config = tokenConfigs[tokenContract];

        if (config.isConfigured) {
            threshold = config.threshold;
        }

        if (value >= threshold) {
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256)",
                from,
                log.chain_id,
                tokenContract,
                value,
                config.decimals,
                log.tx_hash
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
     * @param tokenAddress The address of the token contract
     * @param threshold The threshold value in token's native decimals
     * @param decimals The number of decimals the token uses
     */
    function configureToken(
        address tokenAddress,
        uint256 threshold,
        uint8 decimals
    ) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        if (threshold == 0) revert ThresholdMustBeGreaterThanZero();

        tokenConfigs[tokenAddress] = TokenConfig({
            threshold: threshold,
            decimals: decimals,
            isConfigured: true
        });

        emit TokenConfigured(tokenAddress, threshold, decimals);
    }

    /**
     * @notice Removes the configuration for a specific token
     * @param tokenAddress The address of the token to unconfigure
     */
    function removeTokenConfig(address tokenAddress) external onlyOwner {
        if (!tokenConfigs[tokenAddress].isConfigured) {
            revert TokenNotConfigured();
        }
        delete tokenConfigs[tokenAddress];
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
     * @notice Returns the configuration for a specific token
     * @param tokenAddress The address of the token to query
     * @return threshold The configured threshold value
     * @return decimals The token's decimal places
     * @return isConfigured Whether the token has been configured
     */
    function getTokenConfig(
        address tokenAddress
    )
        external
        view
        returns (uint256 threshold, uint8 decimals, bool isConfigured)
    {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        return (config.threshold, config.decimals, config.isConfigured);
    }

    /**
     * @notice Returns the effective threshold for a token
     * @param tokenAddress The address of the token to query
     * @return The threshold that will be used for this token
     */
    function getEffectiveThreshold(
        address tokenAddress
    ) external view returns (uint256) {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        return config.isConfigured ? config.threshold : DEFAULT_THRESHOLD;
    }

    /**
     * @notice Returns the default threshold
     * @return The default threshold value
     */
    function getDefaultThreshold() external pure returns (uint256) {
        return DEFAULT_THRESHOLD;
    }
}
