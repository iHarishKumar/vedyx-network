// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVedyxRiskEngine} from "../../risk-engine/interfaces/IVedyxRiskEngine.sol";

/**
 * @title IVedyxRiskHook
 * @notice Interface for Vedyx Risk-Based Uniswap V4 Hook
 * @dev Provides dynamic fees and risk-based blocking for Uniswap V4 pools
 */
interface IVedyxRiskHook {
    /**
     * @notice Fee tier configuration for different risk levels
     */
    struct FeeConfig {
        uint24 safeFee;        // Fee for SAFE addresses (basis points)
        uint24 lowFee;         // Fee for LOW risk addresses
        uint24 mediumFee;      // Fee for MEDIUM risk addresses
        uint24 highFee;        // Fee for HIGH risk addresses
        uint24 criticalFee;    // Fee for CRITICAL risk addresses
    }

    /**
     * @notice Hook configuration
     */
    struct HookConfig {
        bool blockHighRisk;           // Block HIGH risk addresses
        bool blockCritical;           // Block CRITICAL risk addresses
        bool dynamicSwapFees;         // Enable dynamic swap fees
        bool dynamicLPFees;           // Enable dynamic LP fees
        uint24 maxSwapFee;            // Maximum swap fee (30% = 300000 bps)
        uint24 minSwapFee;            // Minimum swap fee (1% = 10000 bps)
    }

    /**
     * @notice Liquidity provision fee adjustment
     */
    struct LPFeeAdjustment {
        uint24 addLiquidityFee;       // Fee for adding liquidity
        uint24 removeLiquidityFee;    // Fee for removing liquidity
    }

    // ─── Events ───────────────────────────────────────────────────────────

    event SwapBlocked(
        address indexed user,
        IVedyxRiskEngine.RiskLevel riskLevel,
        uint8 riskScore
    );

    event DynamicFeeApplied(
        address indexed user,
        uint24 fee,
        IVedyxRiskEngine.RiskLevel riskLevel,
        uint8 riskScore
    );

    event LiquidityBlocked(
        address indexed user,
        bool isAddLiquidity,
        IVedyxRiskEngine.RiskLevel riskLevel
    );

    event FeeConfigUpdated(FeeConfig newConfig);
    event HookConfigUpdated(HookConfig newConfig);
    event RiskEngineUpdated(address indexed newRiskEngine);

    // ─── Core Functions ───────────────────────────────────────────────────

    /**
     * @notice Calculate dynamic swap fee based on user risk
     * @param user Address performing the swap
     * @return fee Dynamic fee in basis points
     */
    function getSwapFee(address user) external view returns (uint24 fee);

    /**
     * @notice Check if user should be blocked from swapping
     * @param user Address to check
     * @return blocked True if user should be blocked
     * @return reason Reason for blocking
     */
    function shouldBlockSwap(address user) external view returns (bool blocked, string memory reason);

    /**
     * @notice Calculate liquidity provision fee based on user risk
     * @param user Address providing liquidity
     * @param isAddLiquidity True for add, false for remove
     * @return fee Dynamic fee in basis points
     */
    function getLiquidityFee(address user, bool isAddLiquidity) external view returns (uint24 fee);

    /**
     * @notice Check if user should be blocked from liquidity operations
     * @param user Address to check
     * @param isAddLiquidity True for add, false for remove
     * @return blocked True if user should be blocked
     */
    function shouldBlockLiquidity(address user, bool isAddLiquidity) external view returns (bool blocked);

    /**
     * @notice Get user's risk assessment
     * @param user Address to assess
     * @return assessment Complete risk assessment
     */
    function getUserRiskAssessment(address user) external view returns (IVedyxRiskEngine.RiskAssessment memory assessment);

    // ─── Configuration Functions ──────────────────────────────────────────

    /**
     * @notice Update fee configuration
     * @param config New fee configuration
     */
    function updateFeeConfig(FeeConfig calldata config) external;

    /**
     * @notice Update hook configuration
     * @param config New hook configuration
     */
    function updateHookConfig(HookConfig calldata config) external;

    /**
     * @notice Update risk engine address
     * @param newRiskEngine New risk engine address
     */
    function updateRiskEngine(address newRiskEngine) external;

    /**
     * @notice Get current fee configuration
     * @return config Current fee configuration
     */
    function getFeeConfig() external view returns (FeeConfig memory config);

    /**
     * @notice Get current hook configuration
     * @return config Current hook configuration
     */
    function getHookConfig() external view returns (HookConfig memory config);
}
