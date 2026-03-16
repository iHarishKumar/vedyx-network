// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxRiskHook} from "../../../src/uniswap-v4-hook/VedyxRiskHook.sol";
import {IVedyxRiskHook} from "../../../src/uniswap-v4-hook/interfaces/IVedyxRiskHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

/**
 * @title DeployVedyxRiskHook
 * @notice Deployment script for Vedyx Risk Hook on Unichain Sepolia
 * 
 * Usage:
 *   forge script script/networks/unichain-sepolia/DeployVedyxRiskHook.s.sol:DeployVedyxRiskHook \
 *     --rpc-url $UNICHAIN_SEPOLIA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployVedyxRiskHook is Script {
    VedyxRiskHook public hook;
    
    function run() external {
        address deployer = msg.sender;
        
        console2.log("========================================");
        console2.log("VEDYX RISK HOOK DEPLOYMENT");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        
        // Load Risk Engine address from deployment file
        address riskEngine = getRiskEngineAddress();
        
        // Get PoolManager address (required for Uniswap V4 hooks)
        address poolManager = getPoolManagerAddress();
        
        vm.startBroadcast();
        
        // Deploy VedyxRiskHook
        console2.log("Deploying VedyxRiskHook...");
        console2.log("  Pool Manager:", poolManager);
        console2.log("  Risk Engine:", riskEngine);
        hook = new VedyxRiskHook(IPoolManager(poolManager), riskEngine, deployer);
        console2.log("VedyxRiskHook deployed at:", address(hook));
        console2.log("");
        
        // Verify configuration
        console2.log("Verifying configuration...");
        IVedyxRiskHook.FeeConfig memory feeConfig = hook.getFeeConfig();
        IVedyxRiskHook.HookConfig memory hookConfig = hook.getHookConfig();
        
        console2.log("Fee Configuration:");
        console2.log("  SAFE Fee:", feeConfig.safeFee);
        console2.log("  LOW Fee:", feeConfig.lowFee);
        console2.log("  MEDIUM Fee:", feeConfig.mediumFee);
        console2.log("  HIGH Fee:", feeConfig.highFee);
        console2.log("  CRITICAL Fee:", feeConfig.criticalFee);
        console2.log("");
        
        console2.log("Hook Configuration:");
        console2.log("  Block HIGH Risk:", hookConfig.blockHighRisk);
        console2.log("  Block CRITICAL:", hookConfig.blockCritical);
        console2.log("  Dynamic Swap Fees:", hookConfig.dynamicSwapFees);
        console2.log("  Dynamic LP Fees:", hookConfig.dynamicLPFees);
        console2.log("  Max Swap Fee:", hookConfig.maxSwapFee);
        console2.log("  Min Swap Fee:", hookConfig.minSwapFee);
        console2.log("");
        
        vm.stopBroadcast();
        
        // Save deployment
        saveDeployment();
        
        // Print summary
        printSummary();
    }
    
    function getRiskEngineAddress() internal view returns (address) {
        string memory deploymentPath = "./deployments/unichain-sepolia/deployment.json";
        
        if (!vm.exists(deploymentPath)) {
            console2.log("Deployment file not found, using environment variable");
            return vm.envAddress("RISK_ENGINE_ADDRESS");
        }
        
        try vm.readFile(deploymentPath) returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.riskEngine");
            address addr = abi.decode(data, (address));
            console2.log("Loaded Risk Engine from deployment file:", addr);
            return addr;
        } catch {
            console2.log("Reading Risk Engine from environment variable");
            return vm.envAddress("RISK_ENGINE_ADDRESS");
        }
    }
    
    function getPoolManagerAddress() internal view returns (address) {
        // Try environment variable first
        try vm.envAddress("POOL_MANAGER_ADDRESS") returns (address addr) {
            console2.log("Loaded Pool Manager from environment variable:", addr);
            return addr;
        } catch {
            // For Unichain Sepolia, use the official PoolManager address
            // Note: Update this with the actual Unichain Sepolia PoolManager address
            console2.log("WARNING: Using placeholder Pool Manager address");
            console2.log("Please set POOL_MANAGER_ADDRESS environment variable");
            return address(0x0000000000000000000000000000000000000000);
        }
    }
    
    function saveDeployment() internal {
        console2.log("Saving deployment...");
        
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "unichain-sepolia",\n',
                '  "chainId": ', vm.toString(block.chainid), ",\n",
                '  "vedyxRiskHook": "', vm.toString(address(hook)), '",\n',
                '  "riskEngine": "', vm.toString(address(hook.riskEngine())), '",\n',
                '  "timestamp": ', vm.toString(block.timestamp), "\n",
                "}"
            )
        );
        
        vm.writeFile("./deployments/unichain-sepolia/vedyx-risk-hook.json", deploymentInfo);
        console2.log("Saved to: ./deployments/unichain-sepolia/vedyx-risk-hook.json");
        console2.log("");
    }
    
    function printSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("\nVedyx Risk Hook:", address(hook));
        console2.log("Risk Engine:", address(hook.riskEngine()));
        console2.log("Owner:", hook.owner());
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Integrate hook with Uniswap V4 pools");
        console2.log("2. Configure custom fee tiers if needed");
        console2.log("3. Test with different risk levels");
        console2.log("4. Monitor hook performance");
        console2.log("========================================");
    }
}
