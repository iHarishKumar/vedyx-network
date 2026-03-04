// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVedyxRiskEngine} from "../interfaces/IVedyxRiskEngine.sol";

/**
 * @title RiskScoringLib
 * @notice Library for calculating risk scores from various factors
 */
library RiskScoringLib {
    /**
     * @notice Calculate verdict-based risk score
     * @param hasVerdict Whether address has a verdict
     * @param isSuspicious Whether verdict is suspicious
     * @param weight Weight for this factor (0-40)
     * @return score Verdict risk score
     */
    function calculateVerdictScore(bool hasVerdict, bool isSuspicious, uint8 weight)
        internal
        pure
        returns (uint8 score)
    {
        if (!hasVerdict) return 0;
        if (isSuspicious) return weight;
        return 0;
    }

    /**
     * @notice Calculate incident-based risk score
     * @param totalIncidents Number of times address was flagged
     * @param weight Weight for this factor (0-20)
     * @return score Incident risk score
     */
    function calculateIncidentScore(uint256 totalIncidents, uint8 weight) internal pure returns (uint8 score) {
        if (totalIncidents == 0) return 0;
        if (totalIncidents == 1) return weight / 4; // 25% of weight
        if (totalIncidents == 2) return weight / 2; // 50% of weight
        return weight; // 100% of weight for 3+ incidents
    }

    /**
     * @notice Calculate detector severity score
     * @param detectorId Detector that flagged the address
     * @param detectorSeverities Mapping of detector severities
     * @param weight Weight for this factor (0-20)
     * @return score Detector severity score
     */
    function calculateDetectorScore(
        bytes32 detectorId,
        mapping(bytes32 => uint8) storage detectorSeverities,
        uint8 weight
    ) internal view returns (uint8 score) {
        uint8 severity = detectorSeverities[detectorId];
        if (severity == 0) return weight / 2; // Default medium severity
        return uint8((uint256(severity) * uint256(weight)) / 20); // Scale to weight
    }

    /**
     * @notice Calculate consensus strength score
     * @param votesFor Votes confirming suspicious
     * @param votesAgainst Votes denying suspicious
     * @param weight Weight for this factor (0-10)
     * @return score Consensus strength score
     */
    function calculateConsensusScore(uint256 votesFor, uint256 votesAgainst, uint8 weight)
        internal
        pure
        returns (uint8 score)
    {
        if (votesFor == 0 && votesAgainst == 0) return 0;

        uint256 totalVotes = votesFor + votesAgainst;
        uint256 consensusStrength = (votesFor * 100) / totalVotes;

        if (consensusStrength > 80) return weight; // Strong consensus (>80%)
        if (consensusStrength > 60) return (weight * 7) / 10; // Moderate consensus (60-80%)
        return weight / 2; // Weak consensus (<60%)
    }

    /**
     * @notice Calculate recency score (time decay)
     * @param verdictTimestamp When verdict was recorded
     * @param weight Weight for this factor (0-10)
     * @return score Recency score
     */
    function calculateRecencyScore(uint256 verdictTimestamp, uint8 weight) internal view returns (uint8 score) {
        if (verdictTimestamp == 0) return 0;

        uint256 daysSinceVerdict = (block.timestamp - verdictTimestamp) / 1 days;

        if (daysSinceVerdict < 7) return weight; // Very recent (<7 days)
        if (daysSinceVerdict < 30) return (weight * 7) / 10; // Recent (<30 days)
        if (daysSinceVerdict < 90) return weight / 2; // Somewhat recent (<90 days)
        return (weight * 2) / 10; // Old (>90 days)
    }

    /**
     * @notice Categorize total risk score into risk level
     * @param totalScore Total risk score (0-100)
     * @return level Risk level category
     */
    function categorizeRiskLevel(uint8 totalScore) internal pure returns (IVedyxRiskEngine.RiskLevel level) {
        if (totalScore == 0) return IVedyxRiskEngine.RiskLevel.SAFE;
        if (totalScore < 30) return IVedyxRiskEngine.RiskLevel.LOW;
        if (totalScore < 50) return IVedyxRiskEngine.RiskLevel.MEDIUM;
        if (totalScore < 70) return IVedyxRiskEngine.RiskLevel.HIGH;
        return IVedyxRiskEngine.RiskLevel.CRITICAL;
    }

    /**
     * @notice Validate risk configuration weights
     * @param config Risk configuration to validate
     * @return valid True if configuration is valid
     */
    function validateRiskConfig(IVedyxRiskEngine.RiskConfig memory config) internal pure returns (bool valid) {
        uint256 totalWeight =
            uint256(config.verdictWeight) + uint256(config.incidentWeight) + uint256(config.detectorWeight)
                + uint256(config.consensusWeight) + uint256(config.recencyWeight);

        return totalWeight == 100;
    }

    /**
     * @notice Get default risk configuration
     * @return config Default risk configuration
     */
    function getDefaultRiskConfig() internal pure returns (IVedyxRiskEngine.RiskConfig memory config) {
        return IVedyxRiskEngine.RiskConfig({
            verdictWeight: 40,
            incidentWeight: 20,
            detectorWeight: 20,
            consensusWeight: 10,
            recencyWeight: 10
        });
    }
}
