// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VedyxRiskHook} from "./VedyxRiskHook.sol";
import {IVedyxRiskHook} from "./interfaces/IVedyxRiskHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/**
 * @title VedyxRiskHookFactory
 * @notice Factory contract for deploying VedyxRiskHook instances
 * @dev Allows protocols to easily deploy their own risk hooks with custom configurations
 */
contract VedyxRiskHookFactory is Ownable {
    
    error ZeroPoolManager();
    error ZeroRiskEngine();
    error ZeroOwner();
    error ZeroAddress();
    error InvalidRange();
    error EndOutOfBounds();
    // ─── Events ───────────────────────────────────────────────────────────

    event HookDeployed(
        address indexed hook,
        address indexed riskEngine,
        address indexed owner,
        uint256 timestamp
    );

    event DefaultRiskEngineUpdated(address indexed newRiskEngine);

    // ─── State Variables ──────────────────────────────────────────────────

    IPoolManager public immutable poolManager;
    address public defaultRiskEngine;
    address[] public deployedHooks;
    mapping(address => bool) public isDeployedHook;

    // ─── Constructor ──────────────────────────────────────────────────────

    constructor(
        IPoolManager _poolManager,
        address _defaultRiskEngine,
        address _owner
    ) Ownable() {
        if (address(_poolManager) == address(0)) revert ZeroPoolManager();
        if (_defaultRiskEngine == address(0)) revert ZeroRiskEngine();
        // Transfer ownership to specified owner if not deployer
        if (_owner != msg.sender) {
            _transferOwnership(_owner);
        }
        poolManager = _poolManager;
        defaultRiskEngine = _defaultRiskEngine;
    }

    // ─── Deployment Functions ─────────────────────────────────────────────

    /**
     * @notice Deploy a new VedyxRiskHook with default configuration
     * @param hookOwner Owner of the new hook
     * @return hook Address of deployed hook
     */
    function deployHook(address hookOwner) external returns (address hook) {
        return deployHookWithRiskEngine(defaultRiskEngine, hookOwner);
    }

    /**
     * @notice Deploy a new VedyxRiskHook with custom risk engine
     * @param riskEngine Address of risk engine to use
     * @param hookOwner Owner of the new hook
     * @return hook Address of deployed hook
     */
    function deployHookWithRiskEngine(
        address riskEngine,
        address hookOwner
    ) public returns (address hook) {
        if (riskEngine == address(0)) revert ZeroRiskEngine();
        if (hookOwner == address(0)) revert ZeroOwner();

        VedyxRiskHook newHook = new VedyxRiskHook(
            poolManager,
            riskEngine,
            hookOwner
        );
        hook = address(newHook);

        deployedHooks.push(hook);
        isDeployedHook[hook] = true;

        emit HookDeployed(hook, riskEngine, hookOwner, block.timestamp);

        return hook;
    }

    /**
     * @notice Deploy a new VedyxRiskHook with custom configuration
     * @param riskEngine Address of risk engine to use
     * @param hookOwner Owner of the new hook
     * @param feeConfig Custom fee configuration
     * @param hookConfig Custom hook configuration
     * @return hook Address of deployed hook
     */
    function deployHookWithConfig(
        address riskEngine,
        address hookOwner,
        IVedyxRiskHook.FeeConfig calldata feeConfig,
        IVedyxRiskHook.HookConfig calldata hookConfig
    ) external returns (address hook) {
        hook = deployHookWithRiskEngine(riskEngine, hookOwner);

        // Configure the hook (caller must be owner)
        VedyxRiskHook(hook).updateFeeConfig(feeConfig);
        VedyxRiskHook(hook).updateHookConfig(hookConfig);

        return hook;
    }

    // ─── View Functions ───────────────────────────────────────────────────

    /**
     * @notice Get total number of deployed hooks
     * @return count Number of deployed hooks
     */
    function getDeployedHooksCount() external view returns (uint256 count) {
        return deployedHooks.length;
    }

    /**
     * @notice Get all deployed hooks
     * @return hooks Array of deployed hook addresses
     */
    function getDeployedHooks() external view returns (address[] memory hooks) {
        return deployedHooks;
    }

    /**
     * @notice Get deployed hooks in a range
     * @param start Start index
     * @param end End index (exclusive)
     * @return hooks Array of deployed hook addresses
     */
    function getDeployedHooksRange(
        uint256 start,
        uint256 end
    ) external view returns (address[] memory hooks) {
        if (start >= end) revert InvalidRange();
        if (end > deployedHooks.length) revert EndOutOfBounds();

        hooks = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            hooks[i - start] = deployedHooks[i];
        }

        return hooks;
    }

    // ─── Admin Functions ──────────────────────────────────────────────────

    /**
     * @notice Update default risk engine
     * @param newRiskEngine New default risk engine address
     */
    function updateDefaultRiskEngine(address newRiskEngine) external onlyOwner {
        if (newRiskEngine == address(0)) revert ZeroAddress();
        defaultRiskEngine = newRiskEngine;
        emit DefaultRiskEngineUpdated(newRiskEngine);
    }
}
