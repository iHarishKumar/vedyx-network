// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

/**
 * @title IAttackVectorDetector
 * @notice Interface for modular attack vector detection strategies
 * @dev Implement this interface to create new attack vector detectors that can be
 *      plugged into the VedyxExploitDetectorRSC singleton contract
 */
interface IAttackVectorDetector {
    /**
     * @notice Analyzes a log record and returns detection results
     * @param log The log record to analyze
     * @return detected Whether a threat was detected
     * @return suspiciousAddress The address flagged as suspicious (if detected)
     * @return payload The encoded callback payload to send to the destination chain
     */
    function detect(
        IReactive.LogRecord calldata log
    )
        external
        view
        returns (
            bool detected,
            address suspiciousAddress,
            bytes memory payload
        );

    /**
     * @notice Returns the event topic_0 that this detector monitors
     * @return The topic_0 hash this detector is interested in
     */
    function getMonitoredTopic() external view returns (uint256);

    /**
     * @notice Returns a unique identifier for this detector
     * @return The detector's unique identifier
     */
    function getDetectorId() external view returns (bytes32);

    /**
     * @notice Returns whether this detector is active
     * @return True if the detector is active, false otherwise
     */
    function isActive() external view returns (bool);
}
