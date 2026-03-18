// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/**
 * @title MockPoolManager
 * @notice Simplified mock PoolManager for testing Uniswap V4 hooks
 * @dev Only implements the functions needed for hook testing
 */
contract MockPoolManager {
    mapping(bytes32 => uint24) public poolDynamicFees;
    
    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external {
        bytes32 poolId = keccak256(abi.encode(key));
        poolDynamicFees[poolId] = newDynamicLPFee;
    }
    
    function getDynamicLPFee(PoolKey memory key) external view returns (uint24) {
        bytes32 poolId = keccak256(abi.encode(key));
        return poolDynamicFees[poolId];
    }
}
