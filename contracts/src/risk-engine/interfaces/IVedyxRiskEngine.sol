// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IVedyxRiskEngine
 * @notice Interface for the Vedyx Risk Assessment Engine
 * @dev DeFi protocols integrate with this interface to assess address risk
 */
interface IVedyxRiskEngine {
    /**
     * @notice Risk level categories
     */
    enum RiskLevel {
        SAFE,      // 0 points - No verdict or cleared
        LOW,       // 1-29 points - Minor concerns
        MEDIUM,    // 30-49 points - Moderate risk
        HIGH,      // 50-69 points - Significant risk
        CRITICAL   // 70-100 points - Severe risk
    }

    /**
     * @notice Detailed risk factor breakdown
     */
    struct RiskFactors {
        uint8 verdictScore;        // 0-40 points (community verdict)
        uint8 incidentScore;       // 0-20 points (repeat offenses)
        uint8 detectorScore;       // 0-20 points (detector severity)
        uint8 consensusScore;      // 0-10 points (voting strength)
        uint8 recencyScore;        // 0-10 points (time decay)
    }

    /**
     * @notice Complete risk assessment result
     */
    struct RiskAssessment {
        uint8 totalScore;          // 0-100 total risk score
        RiskLevel riskLevel;       // Categorized risk level
        RiskFactors factors;       // Detailed factor breakdown
        bool hasVerdict;           // Whether address has been judged
        uint256 lastUpdated;       // Timestamp of last verdict
    }

    /**
     * @notice Risk scoring configuration
     */
    struct RiskConfig {
        uint8 verdictWeight;       // Weight for verdict score (default: 40)
        uint8 incidentWeight;      // Weight for incident score (default: 20)
        uint8 detectorWeight;      // Weight for detector score (default: 20)
        uint8 consensusWeight;     // Weight for consensus score (default: 10)
        uint8 recencyWeight;       // Weight for recency score (default: 10)
    }

    // ─── Events ───────────────────────────────────────────────────────────

    event RiskConfigUpdated(RiskConfig newConfig);
    event DetectorSeverityUpdated(bytes32 indexed detectorId, uint8 severity);
    event DetectorSeveritiesUpdated(bytes32[] detectorIds, uint8[] severities);
    event VotingContractUpdated(address indexed newVotingContract);

    // ─── Core Functions ───────────────────────────────────────────────────

    /**
     * @notice Get complete risk assessment for an address
     * @param addr Address to assess
     * @return assessment Complete risk assessment with breakdown
     */
    function getRiskAssessment(address addr) external view returns (RiskAssessment memory assessment);

    /**
     * @notice Get risk level for an address (simplified)
     * @param addr Address to assess
     * @return level Risk level category
     */
    function getRiskLevel(address addr) external view returns (RiskLevel level);

    /**
     * @notice Get total risk score for an address
     * @param addr Address to assess
     * @return score Total risk score (0-100)
     */
    function getRiskScore(address addr) external view returns (uint8 score);

    /**
     * @notice Check if address is safe to interact with
     * @param addr Address to check
     * @return isSafe True if risk level is SAFE or LOW
     */
    function isSafeAddress(address addr) external view returns (bool isSafe);

    /**
     * @notice Get risk factor breakdown for an address
     * @param addr Address to assess
     * @return factors Detailed risk factor scores
     */
    function getRiskFactors(address addr) external view returns (RiskFactors memory factors);

    // ─── Batch Functions ──────────────────────────────────────────────────

    /**
     * @notice Get risk levels for multiple addresses (gas-optimized)
     * @param addresses Array of addresses to assess
     * @return levels Array of risk levels
     */
    function getBatchRiskLevels(address[] calldata addresses) external view returns (RiskLevel[] memory levels);

    /**
     * @notice Get risk scores for multiple addresses
     * @param addresses Array of addresses to assess
     * @return scores Array of risk scores
     */
    function getBatchRiskScores(address[] calldata addresses) external view returns (uint8[] memory scores);

    // ─── Configuration Functions ──────────────────────────────────────────

    /**
     * @notice Update risk scoring configuration
     * @param config New risk configuration
     */
    function updateRiskConfig(RiskConfig calldata config) external;

    /**
     * @notice Update detector severities (batch operation)
     * @dev All detector severities must sum to 100 for proportional risk weighting
     * @param detectorIds Array of detector identifiers
     * @param severities Array of severity scores (must sum to 100)
     */
    function updateDetectorSeverities(bytes32[] calldata detectorIds, uint8[] calldata severities) external;

    /**
     * @notice Get current risk configuration
     * @return config Current risk configuration
     */
    function getRiskConfig() external view returns (RiskConfig memory config);

    /**
     * @notice Get detector severity
     * @param detectorId Detector identifier
     * @return severity Severity score for detector
     */
    function getDetectorSeverity(bytes32 detectorId) external view returns (uint8 severity);
}
