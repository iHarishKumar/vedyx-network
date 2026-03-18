// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVedyxRiskEngine} from "../../risk-engine/interfaces/IVedyxRiskEngine.sol";

/**
 * @title RiskValidator
 * @notice Library for validating user risk levels and blocking decisions
 * @dev Provides centralized logic for risk-based access control
 */
library RiskValidator {
    /**
     * @notice Check if user should be blocked based on risk level
     * @param riskLevel User's risk level
     * @param blockHighRisk Whether to block HIGH risk users
     * @param blockCritical Whether to block CRITICAL risk users
     * @return blocked True if user should be blocked
     * @return reason Human-readable reason for blocking
     */
    function shouldBlock(
        IVedyxRiskEngine.RiskLevel riskLevel,
        bool blockHighRisk,
        bool blockCritical
    ) internal pure returns (bool blocked, string memory reason) {
        if (riskLevel == IVedyxRiskEngine.RiskLevel.CRITICAL && blockCritical) {
            return (true, "CRITICAL risk level - address blocked");
        }
        
        if (riskLevel == IVedyxRiskEngine.RiskLevel.HIGH && blockHighRisk) {
            return (true, "HIGH risk level - address blocked");
        }
        
        return (false, "");
    }

    /**
     * @notice Check if user should be blocked from liquidity operations
     * @dev More restrictive than swap blocking - blocks MEDIUM and above
     * @param riskLevel User's risk level
     * @param blockHighRisk Whether to block HIGH risk users
     * @param blockCritical Whether to block CRITICAL risk users
     * @return blocked True if user should be blocked
     */
    function shouldBlockLiquidity(
        IVedyxRiskEngine.RiskLevel riskLevel,
        bool blockHighRisk,
        bool blockCritical
    ) internal pure returns (bool blocked) {
        // Always block CRITICAL
        if (riskLevel == IVedyxRiskEngine.RiskLevel.CRITICAL && blockCritical) {
            return true;
        }
        
        // Block HIGH if configured
        if (riskLevel == IVedyxRiskEngine.RiskLevel.HIGH && blockHighRisk) {
            return true;
        }
        
        // Also block MEDIUM for liquidity (more restrictive)
        if (riskLevel == IVedyxRiskEngine.RiskLevel.MEDIUM) {
            return true;
        }
        
        return false;
    }

    /**
     * @notice Validate risk level is within acceptable range for operation
     * @param riskLevel User's risk level
     * @param maxAcceptableLevel Maximum acceptable risk level
     * @return valid True if risk level is acceptable
     */
    function isRiskAcceptable(
        IVedyxRiskEngine.RiskLevel riskLevel,
        IVedyxRiskEngine.RiskLevel maxAcceptableLevel
    ) internal pure returns (bool valid) {
        return uint8(riskLevel) <= uint8(maxAcceptableLevel);
    }

    /**
     * @notice Get human-readable risk level description
     * @param riskLevel Risk level to describe
     * @return description Human-readable description
     */
    function getRiskDescription(
        IVedyxRiskEngine.RiskLevel riskLevel
    ) internal pure returns (string memory description) {
        if (riskLevel == IVedyxRiskEngine.RiskLevel.SAFE) return "SAFE";
        if (riskLevel == IVedyxRiskEngine.RiskLevel.LOW) return "LOW";
        if (riskLevel == IVedyxRiskEngine.RiskLevel.MEDIUM) return "MEDIUM";
        if (riskLevel == IVedyxRiskEngine.RiskLevel.HIGH) return "HIGH";
        return "CRITICAL";
    }
}
