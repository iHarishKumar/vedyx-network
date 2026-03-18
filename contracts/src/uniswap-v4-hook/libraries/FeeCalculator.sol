// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVedyxRiskEngine} from "../../risk-engine/interfaces/IVedyxRiskEngine.sol";

/**
 * @title FeeCalculator
 * @notice Library for calculating dynamic fees based on risk scores
 * @dev Provides linear interpolation between min and max fees based on risk score
 */
library FeeCalculator {
    
    error InvalidFeeRange();
    error FeeExceeds100Percent();
    error LPFeeExceeds100Percent();
    uint256 private constant MAX_RISK_SCORE = 100;
    uint256 private constant BASIS_POINTS = 1000000; // 100% = 1000000 bps

    /**
     * @notice Calculate dynamic fee based on risk score
     * @dev Linear interpolation: fee = minFee + (riskScore / 100) * (maxFee - minFee)
     * @param riskScore Risk score (0-100)
     * @param minFee Minimum fee in basis points (e.g., 10000 = 1%)
     * @param maxFee Maximum fee in basis points (e.g., 300000 = 30%)
     * @return fee Calculated fee in basis points
     */
    function calculateDynamicFee(
        uint8 riskScore,
        uint24 minFee,
        uint24 maxFee
    ) internal pure returns (uint24 fee) {
        if (minFee > maxFee) revert InvalidFeeRange();
        if (maxFee > BASIS_POINTS) revert FeeExceeds100Percent();

        if (riskScore == 0) {
            return minFee;
        }

        if (riskScore >= MAX_RISK_SCORE) {
            return maxFee;
        }

        // Linear interpolation
        uint256 feeRange = uint256(maxFee) - uint256(minFee);
        uint256 dynamicFee = uint256(minFee) + (feeRange * uint256(riskScore)) / MAX_RISK_SCORE;

        return uint24(dynamicFee);
    }

    /**
     * @notice Calculate fee based on risk level (tiered approach)
     * @param riskLevel Risk level category
     * @param safeFee Fee for SAFE addresses
     * @param lowFee Fee for LOW risk addresses
     * @param mediumFee Fee for MEDIUM risk addresses
     * @param highFee Fee for HIGH risk addresses
     * @param criticalFee Fee for CRITICAL risk addresses
     * @return fee Calculated fee in basis points
     */
    function calculateTieredFee(
        IVedyxRiskEngine.RiskLevel riskLevel,
        uint24 safeFee,
        uint24 lowFee,
        uint24 mediumFee,
        uint24 highFee,
        uint24 criticalFee
    ) internal pure returns (uint24 fee) {
        if (riskLevel == IVedyxRiskEngine.RiskLevel.SAFE) return safeFee;
        if (riskLevel == IVedyxRiskEngine.RiskLevel.LOW) return lowFee;
        if (riskLevel == IVedyxRiskEngine.RiskLevel.MEDIUM) return mediumFee;
        if (riskLevel == IVedyxRiskEngine.RiskLevel.HIGH) return highFee;
        return criticalFee; // CRITICAL
    }

    /**
     * @notice Calculate liquidity provision fee with additional risk premium
     * @dev LP fees are typically higher than swap fees due to longer exposure
     * @param baseFee Base fee calculated from risk
     * @param premiumBps Additional premium in basis points (e.g., 5000 = 0.5%)
     * @return fee Adjusted fee in basis points
     */
    function calculateLPFee(
        uint24 baseFee,
        uint24 premiumBps
    ) internal pure returns (uint24 fee) {
        uint256 adjustedFee = uint256(baseFee) + uint256(premiumBps);
        if (adjustedFee > BASIS_POINTS) revert LPFeeExceeds100Percent();
        return uint24(adjustedFee);
    }

    /**
     * @notice Apply fee cap to ensure it doesn't exceed maximum
     * @param fee Calculated fee
     * @param maxFee Maximum allowed fee
     * @return cappedFee Fee capped at maximum
     */
    function capFee(uint24 fee, uint24 maxFee) internal pure returns (uint24 cappedFee) {
        return fee > maxFee ? maxFee : fee;
    }

    /**
     * @notice Apply fee floor to ensure it meets minimum
     * @param fee Calculated fee
     * @param minFee Minimum allowed fee
     * @return flooredFee Fee floored at minimum
     */
    function floorFee(uint24 fee, uint24 minFee) internal pure returns (uint24 flooredFee) {
        return fee < minFee ? minFee : fee;
    }
}
