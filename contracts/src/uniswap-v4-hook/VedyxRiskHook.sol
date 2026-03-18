// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTestHooks} from "v4-core/test/BaseTestHooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {IVedyxRiskEngine} from "../risk-engine/interfaces/IVedyxRiskEngine.sol";
import {IVedyxRiskHook} from "./interfaces/IVedyxRiskHook.sol";
import {FeeCalculator} from "./libraries/FeeCalculator.sol";
import {RiskValidator} from "./libraries/RiskValidator.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/**
 * @title VedyxRiskHook
 * @notice Uniswap V4 Hook with dynamic fees and risk-based blocking
 * @dev Extends BaseTestHooks and integrates with Vedyx Risk Engine to provide:
 *      - Dynamic swap fees (1-30% based on risk score)
 *      - Dynamic liquidity provision fees
 *      - Risk-based blocking for HIGH/CRITICAL risk addresses
 *      - Configurable fee tiers and blocking policies
 * 
 * @custom:security-contact security@vedyx.io
 */
contract VedyxRiskHook is BaseTestHooks, IVedyxRiskHook, Ownable {
    
    error ZeroPoolManager();
    error ZeroRiskEngine();
    error ZeroOwner();
    error OnlyPoolManager();
    error ZeroAddress();
    error InvalidFeeConfig();
    error InvalidHookConfig();
    error AddressBlockedFromSwap(address user, string reason);
    error AddressBlockedFromAddingLiquidity(address user);
    error AddressBlockedFromRemovingLiquidity(address user);
    error FeeExceeds100Percent();
    error FeesNotAscending();
    error InvalidFeeRange();
    using FeeCalculator for uint8;
    using RiskValidator for IVedyxRiskEngine.RiskLevel;

    // ─── State Variables ──────────────────────────────────────────────────

    IPoolManager public immutable poolManager;
    IVedyxRiskEngine public riskEngine;
    FeeConfig public feeConfig;
    HookConfig public hookConfig;
    
    // LP fee adjustments
    mapping(IVedyxRiskEngine.RiskLevel => LPFeeAdjustment) public lpFeeAdjustments;

    // ─── Constants ────────────────────────────────────────────────────────

    uint24 private constant DEFAULT_MIN_FEE = 10000;      // 1% = 10000 bps
    uint24 private constant DEFAULT_MAX_FEE = 300000;     // 30% = 300000 bps
    uint24 private constant BASIS_POINTS_100 = 1000000;   // 100% = 1000000 bps
    
    // Default fee tiers (basis points)
    uint24 private constant DEFAULT_SAFE_FEE = 10000;     // 1%
    uint24 private constant DEFAULT_LOW_FEE = 30000;      // 3%
    uint24 private constant DEFAULT_MEDIUM_FEE = 80000;   // 8%
    uint24 private constant DEFAULT_HIGH_FEE = 150000;    // 15%
    uint24 private constant DEFAULT_CRITICAL_FEE = 300000; // 30%

    // ─── Constructor ──────────────────────────────────────────────────────

    /**
     * @notice Initialize the Vedyx Risk Hook
     * @param _poolManager Address of the Uniswap V4 PoolManager
     * @param _riskEngine Address of the Vedyx Risk Engine
     * @param _owner Address of the contract owner
     */
    constructor(
        IPoolManager _poolManager,
        address _riskEngine,
        address _owner
    ) Ownable() {
        if (address(_poolManager) == address(0)) revert ZeroPoolManager();
        if (_riskEngine == address(0)) revert ZeroRiskEngine();
        if (_owner == address(0)) revert ZeroOwner();
        
        poolManager = _poolManager;
        riskEngine = IVedyxRiskEngine(_riskEngine);
        
        // Transfer ownership to specified owner if not deployer
        if (_owner != msg.sender) {
            _transferOwnership(_owner);
        }
        
        // Initialize default fee configuration
        feeConfig = FeeConfig({
            safeFee: DEFAULT_SAFE_FEE,
            lowFee: DEFAULT_LOW_FEE,
            mediumFee: DEFAULT_MEDIUM_FEE,
            highFee: DEFAULT_HIGH_FEE,
            criticalFee: DEFAULT_CRITICAL_FEE
        });
        
        // Initialize default hook configuration
        hookConfig = HookConfig({
            blockHighRisk: true,
            blockCritical: true,
            dynamicSwapFees: true,
            dynamicLPFees: true,
            maxSwapFee: DEFAULT_MAX_FEE,
            minSwapFee: DEFAULT_MIN_FEE
        });
        
        // Initialize LP fee adjustments
        _initializeLPFeeAdjustments();
    }
    
    /**
     * @notice Returns the hook permissions
     * @return permissions The hook permissions struct
     */
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ─── Uniswap V4 Hook Functions ────────────────────────────────────────

    /**
     * @notice Hook called before a swap
     * @param sender The address initiating the swap
     * @param key The pool key
     * @param params The swap parameters
     * @param hookData Additional data passed to the hook
     * @return selector The function selector
     * @return delta The before swap delta (unused)
     * @return lpFeeOverride The dynamic LP fee override
     */
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        
        // Get user address (sender is the actual user)
        address user = sender;
        
        // Check if user should be blocked
        IVedyxRiskEngine.RiskLevel riskLevel = riskEngine.getRiskLevel(user);
        (bool blocked, string memory reason) = RiskValidator.shouldBlock(
            riskLevel,
            hookConfig.blockHighRisk,
            hookConfig.blockCritical
        );
        
        if (blocked) {
            emit SwapBlocked(user, riskLevel, riskEngine.getRiskScore(user));
            revert AddressBlockedFromSwap(user, reason);
        }
        
        // Calculate dynamic fee if enabled
        uint24 lpFeeOverride = 0;
        if (hookConfig.dynamicSwapFees) {
            IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(user);
            
            uint24 dynamicFee = FeeCalculator.calculateTieredFee(
                assessment.riskLevel,
                feeConfig.safeFee,
                feeConfig.lowFee,
                feeConfig.mediumFee,
                feeConfig.highFee,
                feeConfig.criticalFee
            );
            
            // Apply min/max caps
            dynamicFee = FeeCalculator.capFee(dynamicFee, hookConfig.maxSwapFee);
            dynamicFee = FeeCalculator.floorFee(dynamicFee, hookConfig.minSwapFee);
            
            // Set OVERRIDE_FEE_FLAG to signal pool manager to use this fee instead of static fee
            lpFeeOverride = dynamicFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
            
            emit DynamicFeeApplied(user, dynamicFee, assessment.riskLevel, assessment.totalScore);
        }
        // If dynamic fees disabled, return 0 (no override flag) so pool uses its static fee
        
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, lpFeeOverride);
    }

    /**
     * @notice Hook called before adding liquidity
     * @param sender The address initiating the add liquidity
     * @param key The pool key
     * @param params The modify liquidity parameters
     * @param hookData Additional data passed to the hook
     * @return selector The function selector
     */
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        
        address user = sender;
        IVedyxRiskEngine.RiskLevel riskLevel = riskEngine.getRiskLevel(user);
        
        // Check if blocked from adding liquidity (more restrictive)
        bool blocked = RiskValidator.shouldBlockLiquidity(
            riskLevel,
            hookConfig.blockHighRisk,
            hookConfig.blockCritical
        );
        
        if (blocked) {
            emit LiquidityBlocked(user, true, riskLevel);
            revert AddressBlockedFromAddingLiquidity(user);
        }
        
        // Note: Dynamic LP fees would require pool initialization with DYNAMIC_FEE_FLAG
        // For now, we only enforce blocking logic for liquidity operations
        
        return IHooks.beforeAddLiquidity.selector;
    }

    /**
     * @notice Hook called before removing liquidity
     * @param sender The address initiating the remove liquidity
     * @param key The pool key
     * @param params The modify liquidity parameters
     * @param hookData Additional data passed to the hook
     * @return selector The function selector
     */
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        if (msg.sender != address(poolManager)) revert OnlyPoolManager();
        
        address user = sender;
        IVedyxRiskEngine.RiskLevel riskLevel = riskEngine.getRiskLevel(user);
        
        // Less restrictive for removing liquidity (allow users to exit)
        (bool blocked,) = RiskValidator.shouldBlock(
            riskLevel,
            hookConfig.blockHighRisk,
            hookConfig.blockCritical
        );
        
        if (blocked) {
            emit LiquidityBlocked(user, false, riskLevel);
            revert AddressBlockedFromRemovingLiquidity(user);
        }
        
        // Note: Dynamic LP fees would require pool initialization with DYNAMIC_FEE_FLAG
        // For now, we only enforce blocking logic for liquidity operations
        
        return IHooks.beforeRemoveLiquidity.selector;
    }

    // ─── View Functions ───────────────────────────────────────────────────

    /**
     * @notice Calculate dynamic swap fee based on user risk
     * @param user Address performing the swap
     * @return fee Dynamic fee in basis points
     */
    function getSwapFee(address user) external view override returns (uint24 fee) {
        if (!hookConfig.dynamicSwapFees) {
            return feeConfig.safeFee;
        }

        IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(user);
        
        fee = FeeCalculator.calculateTieredFee(
            assessment.riskLevel,
            feeConfig.safeFee,
            feeConfig.lowFee,
            feeConfig.mediumFee,
            feeConfig.highFee,
            feeConfig.criticalFee
        );
        
        fee = FeeCalculator.capFee(fee, hookConfig.maxSwapFee);
        fee = FeeCalculator.floorFee(fee, hookConfig.minSwapFee);
        
        return fee;
    }

    /**
     * @notice Check if user should be blocked from swapping
     * @param user Address to check
     * @return blocked True if user should be blocked
     * @return reason Reason for blocking
     */
    function shouldBlockSwap(address user) external view override returns (bool blocked, string memory reason) {
        IVedyxRiskEngine.RiskLevel riskLevel = riskEngine.getRiskLevel(user);
        return RiskValidator.shouldBlock(riskLevel, hookConfig.blockHighRisk, hookConfig.blockCritical);
    }

    /**
     * @notice Calculate liquidity provision fee based on user risk
     * @param user Address providing liquidity
     * @param isAddLiquidity True for add, false for remove
     * @return fee Dynamic fee in basis points
     */
    function getLiquidityFee(
        address user,
        bool isAddLiquidity
    ) external view override returns (uint24 fee) {
        if (!hookConfig.dynamicLPFees) {
            return feeConfig.safeFee;
        }

        IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(user);
        
        uint24 baseFee = FeeCalculator.calculateTieredFee(
            assessment.riskLevel,
            feeConfig.safeFee,
            feeConfig.lowFee,
            feeConfig.mediumFee,
            feeConfig.highFee,
            feeConfig.criticalFee
        );
        
        LPFeeAdjustment memory adjustment = lpFeeAdjustments[assessment.riskLevel];
        uint24 lpPremium = isAddLiquidity ? adjustment.addLiquidityFee : adjustment.removeLiquidityFee;
        
        fee = FeeCalculator.calculateLPFee(baseFee, lpPremium);
        fee = FeeCalculator.capFee(fee, hookConfig.maxSwapFee);
        fee = FeeCalculator.floorFee(fee, hookConfig.minSwapFee);
        
        return fee;
    }

    /**
     * @notice Check if user should be blocked from liquidity operations
     * @param user Address to check
     * @param isAddLiquidity True for add, false for remove
     * @return blocked True if user should be blocked
     */
    function shouldBlockLiquidity(
        address user,
        bool isAddLiquidity
    ) external view override returns (bool blocked) {
        IVedyxRiskEngine.RiskLevel riskLevel = riskEngine.getRiskLevel(user);
        
        if (isAddLiquidity) {
            return RiskValidator.shouldBlockLiquidity(
                riskLevel,
                hookConfig.blockHighRisk,
                hookConfig.blockCritical
            );
        }
        
        (bool shouldBlock,) = RiskValidator.shouldBlock(
            riskLevel,
            hookConfig.blockHighRisk,
            hookConfig.blockCritical
        );
        return shouldBlock;
    }

    /**
     * @notice Get user's complete risk assessment
     * @param user Address to assess
     * @return assessment Complete risk assessment from risk engine
     */
    function getUserRiskAssessment(
        address user
    ) external view override returns (IVedyxRiskEngine.RiskAssessment memory assessment) {
        return riskEngine.getRiskAssessment(user);
    }

    // ─── Configuration Functions ──────────────────────────────────────────

    /**
     * @notice Update fee configuration
     * @param config New fee configuration
     */
    function updateFeeConfig(FeeConfig calldata config) external override onlyOwner {
        _validateFeeConfig(config);
        feeConfig = config;
        emit FeeConfigUpdated(config);
    }

    /**
     * @notice Update hook configuration
     * @param config New hook configuration
     */
    function updateHookConfig(HookConfig calldata config) external override onlyOwner {
        _validateHookConfig(config);
        hookConfig = config;
        emit HookConfigUpdated(config);
    }

    /**
     * @notice Update risk engine address
     * @param newRiskEngine New risk engine address
     */
    function updateRiskEngine(address newRiskEngine) external override onlyOwner {
        if (newRiskEngine == address(0)) revert ZeroAddress();
        riskEngine = IVedyxRiskEngine(newRiskEngine);
        emit RiskEngineUpdated(newRiskEngine);
    }

    /**
     * @notice Update LP fee adjustments for a specific risk level
     * @param riskLevel Risk level to update
     * @param adjustment New LP fee adjustment
     */
    function updateLPFeeAdjustment(
        IVedyxRiskEngine.RiskLevel riskLevel,
        LPFeeAdjustment calldata adjustment
    ) external onlyOwner {
        if (adjustment.addLiquidityFee > BASIS_POINTS_100 || adjustment.removeLiquidityFee > BASIS_POINTS_100) {
            revert FeeExceeds100Percent();
        }
        lpFeeAdjustments[riskLevel] = adjustment;
    }

    /**
     * @notice Get current fee configuration
     * @return config Current fee configuration
     */
    function getFeeConfig() external view override returns (FeeConfig memory config) {
        return feeConfig;
    }

    /**
     * @notice Get current hook configuration
     * @return config Current hook configuration
     */
    function getHookConfig() external view override returns (HookConfig memory config) {
        return hookConfig;
    }

    /**
     * @notice Get LP fee adjustment for a risk level
     * @param riskLevel Risk level to query
     * @return adjustment LP fee adjustment
     */
    function getLPFeeAdjustment(
        IVedyxRiskEngine.RiskLevel riskLevel
    ) external view returns (LPFeeAdjustment memory adjustment) {
        return lpFeeAdjustments[riskLevel];
    }

    // ─── Internal Functions ───────────────────────────────────────────────

    /**
     * @notice Initialize default LP fee adjustments
     */
    function _initializeLPFeeAdjustments() private {
        lpFeeAdjustments[IVedyxRiskEngine.RiskLevel.SAFE] = LPFeeAdjustment({
            addLiquidityFee: 5000,
            removeLiquidityFee: 2500
        });
        
        lpFeeAdjustments[IVedyxRiskEngine.RiskLevel.LOW] = LPFeeAdjustment({
            addLiquidityFee: 10000,
            removeLiquidityFee: 5000
        });
        
        lpFeeAdjustments[IVedyxRiskEngine.RiskLevel.MEDIUM] = LPFeeAdjustment({
            addLiquidityFee: 20000,
            removeLiquidityFee: 10000
        });
        
        lpFeeAdjustments[IVedyxRiskEngine.RiskLevel.HIGH] = LPFeeAdjustment({
            addLiquidityFee: 50000,
            removeLiquidityFee: 25000
        });
        
        lpFeeAdjustments[IVedyxRiskEngine.RiskLevel.CRITICAL] = LPFeeAdjustment({
            addLiquidityFee: 100000,
            removeLiquidityFee: 50000
        });
    }

    /**
     * @notice Validate fee configuration
     * @param config Fee configuration to validate
     */
    function _validateFeeConfig(FeeConfig calldata config) private pure {
        if (
            config.safeFee > config.lowFee ||
            config.lowFee > config.mediumFee ||
            config.mediumFee > config.highFee ||
            config.highFee > config.criticalFee
        ) {
            revert FeesNotAscending();
        }
        
        if (config.criticalFee > BASIS_POINTS_100) {
            revert FeeExceeds100Percent();
        }
    }

    /**
     * @notice Validate hook configuration
     * @param config Hook configuration to validate
     */
    function _validateHookConfig(HookConfig calldata config) private pure {
        if (config.minSwapFee > config.maxSwapFee) {
            revert InvalidFeeRange();
        }
        
        if (config.maxSwapFee > BASIS_POINTS_100) {
            revert FeeExceeds100Percent();
        }
    }
}
