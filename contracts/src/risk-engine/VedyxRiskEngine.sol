// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IVedyxRiskEngine} from "./interfaces/IVedyxRiskEngine.sol";
import {IVedyxVotingViews} from "../voting-contract/interfaces/IVedyxVotingViews.sol";
import {VedyxTypes} from "../voting-contract/libraries/VedyxTypes.sol";
import {RiskScoringLib} from "./libraries/RiskScoringLib.sol";

/**
 * @title VedyxRiskEngine
 * @notice Multi-factor risk assessment engine for DeFi protocol integration
 * @dev Aggregates voting outcomes and detector data to provide risk scores
 * 
 * ─── Risk Scoring Model ──────────────────────────────────────────────────
 * Total Score (0-100) = Sum of weighted factors:
 * 
 * 1. Verdict Score (0-40):     Community consensus on suspiciousness
 * 2. Incident Score (0-20):    Frequency of being flagged
 * 3. Detector Score (0-20):    Severity of detector that flagged address
 * 4. Consensus Score (0-10):   Strength of voting consensus
 * 5. Recency Score (0-10):     Time decay from verdict timestamp
 * 
 * Risk Levels:
 * - SAFE (0):        No verdict or cleared
 * - LOW (1-29):      Minor concerns, normal operations
 * - MEDIUM (30-49):  Moderate risk, apply restrictions
 * - HIGH (50-69):    Significant risk, heavy restrictions
 * - CRITICAL (70+):  Severe risk, consider blocking
 * ──────────────────────────────────────────────────────────────────────────
 */
contract VedyxRiskEngine is IVedyxRiskEngine, Ownable, AccessControl {
    using RiskScoringLib for *;

    // ─── Role Constants ───────────────────────────────────────────────────
    bytes32 public constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");

    // ─── State Variables ──────────────────────────────────────────────────
    IVedyxVotingViews public votingView;
    RiskConfig public riskConfig;
    mapping(bytes32 => uint8) public detectorSeverities;
    bytes32[] public registeredDetectors;
    mapping(bytes32 => bool) public isDetectorRegistered;

    // ─── Events ───────────────────────────────────────────────────────────
    event RiskAssessmentQueried(address indexed addr, uint8 score, RiskLevel level);
    event DetectorRegistered(bytes32 indexed detectorId, uint8 severity);
    event DetectorRemoved(bytes32 indexed detectorId);

    // ─── Constructor ──────────────────────────────────────────────────────
    /**
     * @param _votingView Address of VedyxVotingViews contract
     */
    constructor(address _votingView) Ownable() {
        require(_votingView != address(0), "Invalid voting view contract");
        votingView = IVedyxVotingViews(_votingView);

        riskConfig = RiskScoringLib.getDefaultRiskConfig();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RISK_ADMIN_ROLE, msg.sender);

        _initializeDetectorSeverities();
    }

    // ─── Core Risk Assessment Functions ───────────────────────────────────

    /**
     * @notice Get complete risk assessment for an address
     * @param addr Address to assess
     * @return assessment Complete risk assessment with breakdown
     */
    function getRiskAssessment(address addr) external view override returns (RiskAssessment memory assessment) {
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, uint256 verdictTimestamp, uint256 totalIncidents) =
            votingView.getAddressVerdict(addr);

        if (!hasVerdict) {
            return RiskAssessment({
                totalScore: 0,
                riskLevel: RiskLevel.SAFE,
                factors: RiskFactors({
                    verdictScore: 0,
                    incidentScore: 0,
                    detectorScore: 0,
                    consensusScore: 0,
                    recencyScore: 0
                }),
                hasVerdict: false,
                lastUpdated: 0
            });
        }

        RiskFactors memory factors = _calculateRiskFactors(
            hasVerdict, isSuspicious, totalIncidents, lastVotingId, verdictTimestamp
        );

        uint8 totalScore = factors.verdictScore + factors.incidentScore + factors.detectorScore
            + factors.consensusScore + factors.recencyScore;

        RiskLevel level = RiskScoringLib.categorizeRiskLevel(totalScore);

        return RiskAssessment({
            totalScore: totalScore,
            riskLevel: level,
            factors: factors,
            hasVerdict: hasVerdict,
            lastUpdated: verdictTimestamp
        });
    }

    /**
     * @notice Get risk level for an address (simplified)
     * @param addr Address to assess
     * @return level Risk level category
     */
    function getRiskLevel(address addr) external view override returns (RiskLevel level) {
        uint8 score = this.getRiskScore(addr);
        return RiskScoringLib.categorizeRiskLevel(score);
    }

    /**
     * @notice Get total risk score for an address
     * @param addr Address to assess
     * @return score Total risk score (0-100)
     */
    function getRiskScore(address addr) external view override returns (uint8 score) {
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, uint256 verdictTimestamp, uint256 totalIncidents) =
            votingView.getAddressVerdict(addr);

        if (!hasVerdict) return 0;

        RiskFactors memory factors = _calculateRiskFactors(
            hasVerdict, isSuspicious, totalIncidents, lastVotingId, verdictTimestamp
        );

        return factors.verdictScore + factors.incidentScore + factors.detectorScore + factors.consensusScore
            + factors.recencyScore;
    }

    /**
     * @notice Check if address is safe to interact with
     * @param addr Address to check
     * @return isSafe True if risk level is SAFE or LOW
     */
    function isSafeAddress(address addr) external view override returns (bool isSafe) {
        uint8 score = this.getRiskScore(addr);
        RiskLevel level = RiskScoringLib.categorizeRiskLevel(score);
        return level == RiskLevel.SAFE || level == RiskLevel.LOW;
    }

    /**
     * @notice Get risk factor breakdown for an address
     * @param addr Address to assess
     * @return factors Detailed risk factor scores
     */
    function getRiskFactors(address addr) external view override returns (RiskFactors memory factors) {
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, uint256 verdictTimestamp, uint256 totalIncidents) =
            votingView.getAddressVerdict(addr);

        if (!hasVerdict) {
            return RiskFactors({
                verdictScore: 0,
                incidentScore: 0,
                detectorScore: 0,
                consensusScore: 0,
                recencyScore: 0
            });
        }

        return _calculateRiskFactors(hasVerdict, isSuspicious, totalIncidents, lastVotingId, verdictTimestamp);
    }

    // ─── Batch Functions ──────────────────────────────────────────────────

    /**
     * @notice Get risk levels for multiple addresses (gas-optimized)
     * @param addresses Array of addresses to assess
     * @return levels Array of risk levels
     */
    function getBatchRiskLevels(address[] calldata addresses)
        external
        view
        override
        returns (RiskLevel[] memory levels)
    {
        levels = new RiskLevel[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            uint8 score = this.getRiskScore(addresses[i]);
            levels[i] = RiskScoringLib.categorizeRiskLevel(score);
        }
    }

    /**
     * @notice Get risk scores for multiple addresses
     * @param addresses Array of addresses to assess
     * @return scores Array of risk scores
     */
    function getBatchRiskScores(address[] calldata addresses)
        external
        view
        override
        returns (uint8[] memory scores)
    {
        scores = new uint8[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            scores[i] = this.getRiskScore(addresses[i]);
        }
    }

    // ─── Internal Functions ───────────────────────────────────────────────

    /**
     * @notice Calculate all risk factors for an address
     * @param hasVerdict Whether address has a verdict
     * @param isSuspicious Whether verdict is suspicious
     * @param totalIncidents Number of times flagged
     * @param lastVotingId Last voting ID
     * @param verdictTimestamp When verdict was recorded
     * @return factors Calculated risk factors
     */
    function _calculateRiskFactors(
        bool hasVerdict,
        bool isSuspicious,
        uint256 totalIncidents,
        uint256 lastVotingId,
        uint256 verdictTimestamp
    ) internal view returns (RiskFactors memory factors) {
        factors.verdictScore =
            RiskScoringLib.calculateVerdictScore(hasVerdict, isSuspicious, riskConfig.verdictWeight);

        factors.incidentScore = RiskScoringLib.calculateIncidentScore(totalIncidents, riskConfig.incidentWeight);

        bytes32 detectorId = _getDetectorIdFromVoting(lastVotingId);
        factors.detectorScore =
            RiskScoringLib.calculateDetectorScore(detectorId, detectorSeverities, riskConfig.detectorWeight);

        (uint256 votesFor, uint256 votesAgainst) = _getVotingResults(lastVotingId);
        factors.consensusScore =
            RiskScoringLib.calculateConsensusScore(votesFor, votesAgainst, riskConfig.consensusWeight);

        factors.recencyScore = RiskScoringLib.calculateRecencyScore(verdictTimestamp, riskConfig.recencyWeight);
    }

    /**
     * @notice Get detector ID from voting details
     * @param votingId Voting ID
     * @return detectorId Detector identifier
     */
    function _getDetectorIdFromVoting(uint256 votingId) internal view returns (bytes32 detectorId) {
        if (votingId == 0) return bytes32(0);

        try votingView.getVotingDetails(votingId) returns (
            VedyxTypes.SuspiciousReport memory report,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            bool
        ) {
            return report.detectorId;
        } catch {
            return bytes32(0);
        }
    }

    /**
     * @notice Get voting results for consensus calculation
     * @param votingId Voting ID
     * @return votesFor Votes confirming suspicious
     * @return votesAgainst Votes denying suspicious
     */
    function _getVotingResults(uint256 votingId) internal view returns (uint256 votesFor, uint256 votesAgainst) {
        if (votingId == 0) return (0, 0);

        try votingView.getVotingDetails(votingId) returns (
            VedyxTypes.SuspiciousReport memory,
            uint256,
            uint256,
            uint256 _votesFor,
            uint256 _votesAgainst,
            bool,
            bool,
            bool
        ) {
            return (_votesFor, _votesAgainst);
        } catch {
            return (0, 0);
        }
    }

    /**
     * @notice Initialize default detector severities (sum = 100)
     * @dev Only includes implemented detectors: MixerInteraction, TracePeelChain, LargeTransfer
     */
    function _initializeDetectorSeverities() internal {
        bytes32[] memory detectorIds = new bytes32[](3);
        uint8[] memory severities = new uint8[](3);

        // Define detector IDs (only implemented detectors)
        detectorIds[0] = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        detectorIds[1] = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
        detectorIds[2] = keccak256("LARGE_TRANSFER_DETECTOR_V1");

        // Assign severities (must sum to 100)
        severities[0] = 50; // MIXER_INTERACTION: 50% (highest risk - mixer usage)
        severities[1] = 35; // TRACE_PEEL_CHAIN: 35% (high risk - obfuscation pattern)
        severities[2] = 15; // LARGE_TRANSFER: 15% (moderate risk - unusual amounts)

        // Register all detectors
        for (uint256 i = 0; i < detectorIds.length; i++) {
            detectorSeverities[detectorIds[i]] = severities[i];
            registeredDetectors.push(detectorIds[i]);
            isDetectorRegistered[detectorIds[i]] = true;
        }
    }

    // ─── Configuration Functions ──────────────────────────────────────────

    /**
     * @notice Update risk scoring configuration
     * @param config New risk configuration
     */
    function updateRiskConfig(RiskConfig calldata config) external override onlyRole(RISK_ADMIN_ROLE) {
        require(RiskScoringLib.validateRiskConfig(config), "Invalid config: weights must sum to 100");

        riskConfig = config;
        emit RiskConfigUpdated(config);
    }

    /**
     * @notice Update detector severities (batch operation)
     * @dev All detector severities must sum to 100 for proportional risk weighting
     * @param detectorIds Array of detector identifiers
     * @param severities Array of severity scores (must sum to 100)
     */
    function updateDetectorSeverities(bytes32[] calldata detectorIds, uint8[] calldata severities)
        external
        onlyRole(RISK_ADMIN_ROLE)
    {
        require(detectorIds.length == severities.length, "Array length mismatch");
        require(detectorIds.length > 0, "Empty arrays");

        // Validate sum equals 100
        uint256 totalSeverity = 0;
        for (uint256 i = 0; i < severities.length; i++) {
            totalSeverity += severities[i];
        }
        require(totalSeverity == 100, "Severities must sum to 100");

        // Update severities
        for (uint256 i = 0; i < detectorIds.length; i++) {
            bytes32 detectorId = detectorIds[i];
            uint8 severity = severities[i];

            // Register detector if not already registered
            if (!isDetectorRegistered[detectorId]) {
                registeredDetectors.push(detectorId);
                isDetectorRegistered[detectorId] = true;
                emit DetectorRegistered(detectorId, severity);
            }

            detectorSeverities[detectorId] = severity;
        }

        emit DetectorSeveritiesUpdated(detectorIds, severities);
    }

    /**
     * @notice Update voting view contract address
     * @param newVotingView New voting view contract address
     */
    function updateVotingView(address newVotingView) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newVotingView != address(0), "Invalid address");
        votingView = IVedyxVotingViews(newVotingView);
        emit VotingContractUpdated(newVotingView);
    }

    /**
     * @notice Get current risk configuration
     * @return config Current risk configuration
     */
    function getRiskConfig() external view override returns (RiskConfig memory config) {
        return riskConfig;
    }

    /**
     * @notice Get detector severity
     * @param detectorId Detector identifier
     * @return severity Severity score for detector
     */
    function getDetectorSeverity(bytes32 detectorId) external view override returns (uint8 severity) {
        return detectorSeverities[detectorId];
    }

    /**
     * @notice Get all registered detectors
     * @return detectorIds Array of registered detector identifiers
     */
    function getRegisteredDetectors() external view returns (bytes32[] memory detectorIds) {
        return registeredDetectors;
    }

    /**
     * @notice Get all detector severities
     * @return detectorIds Array of detector identifiers
     * @return severities Array of corresponding severities
     */
    function getAllDetectorSeverities()
        external
        view
        returns (bytes32[] memory detectorIds, uint8[] memory severities)
    {
        detectorIds = registeredDetectors;
        severities = new uint8[](registeredDetectors.length);

        for (uint256 i = 0; i < registeredDetectors.length; i++) {
            severities[i] = detectorSeverities[registeredDetectors[i]];
        }
    }

    /**
     * @notice Validate that current detector severities sum to 100
     * @return isValid True if severities sum to 100
     * @return currentSum Current sum of all severities
     */
    function validateDetectorSeverities() external view returns (bool isValid, uint256 currentSum) {
        currentSum = 0;
        for (uint256 i = 0; i < registeredDetectors.length; i++) {
            currentSum += detectorSeverities[registeredDetectors[i]];
        }
        isValid = currentSum == 100;
    }
}
