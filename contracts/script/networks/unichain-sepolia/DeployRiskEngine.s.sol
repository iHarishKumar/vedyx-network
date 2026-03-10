// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxRiskEngine} from "../../../src/risk-engine/VedyxRiskEngine.sol";

/**
 * @title DeployRiskEngine
 * @notice Deploys VedyxRiskEngine on Unichain Sepolia testnet
 * 
 * VedyxRiskEngine provides multi-factor risk assessment for addresses based on:
 * - Historical voting verdicts (0-40 points)
 * - Incident frequency (0-20 points)
 * - Detector severity (0-20 points)
 * - Voting consensus strength (0-10 points)
 * - Recency of incidents (0-10 points)
 * 
 * Total Risk Score: 0-100
 * Risk Levels: SAFE (0), LOW (1-29), MEDIUM (30-49), HIGH (50-69), CRITICAL (70+)
 * 
 * Prerequisites:
 * - VedyxVotingContract must be deployed on Unichain Sepolia
 * 
 * Usage with Forge account:
 *   forge script script/networks/sepolia/DeployRiskEngine.s.sol:DeployRiskEngine \
 *     --rpc-url $UNICHAIN_SEPOLIA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast \
 *     --verify
 */
contract DeployRiskEngine is Script {
    // Unichain Sepolia chain ID
    uint256 public constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    
    VedyxRiskEngine public riskEngine;
    address public votingContract;

    function run() external {
        address deployer = msg.sender;

        console2.log("========================================");
        console2.log("VEDYX RISK ENGINE DEPLOYMENT");
        console2.log("Network: Unichain Sepolia");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        require(block.chainid == UNICHAIN_SEPOLIA_CHAIN_ID, "Wrong network - must be Unichain Sepolia");
        console2.log("========================================\n");

        // Load VotingContract address from deployment file
        votingContract = getVotingContractAddress();
        console2.log("VotingContract:", votingContract);
        console2.log("");

        vm.startBroadcast();

        // Step 1: Deploy RiskEngine
        deployRiskEngine();

        vm.stopBroadcast();

        // Step 2: Save deployment
        saveDeployment();

        // Step 3: Verify contract
        verifyContract();

        // Final summary
        printDeploymentSummary();
    }

    function deployRiskEngine() internal {
        console2.log("STEP 1: Deploying VedyxRiskEngine...");
        
        riskEngine = new VedyxRiskEngine(votingContract);
        
        console2.log("VedyxRiskEngine:", address(riskEngine));
        console2.log("");
    }

    function verifyContract() internal {
        console2.log("STEP 3: Verifying Contract on Etherscan...");
        
        // Check if Etherscan API key is set
        try vm.envString("ETHERSCAN_API_KEY") returns (string memory apiKey) {
            if (bytes(apiKey).length == 0) {
                console2.log("WARNING: ETHERSCAN_API_KEY not set, skipping verification");
                console2.log("Set ETHERSCAN_API_KEY to verify contract");
                console2.log("");
                return;
            }
        } catch {
            console2.log("WARNING: ETHERSCAN_API_KEY not set, skipping verification");
            console2.log("Set ETHERSCAN_API_KEY to verify contract");
            console2.log("");
            return;
        }
        
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(address(riskEngine));
        cmd[3] = "src/risk-engine/VedyxRiskEngine.sol:VedyxRiskEngine";
        cmd[4] = "--chain";
        cmd[5] = "1301";
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(abi.encode(votingContract));
        cmd[8] = "--watch";
        
        try vm.ffi(cmd) {
            console2.log("Contract verified successfully!");
        } catch {
            console2.log("Verification failed - verify manually with:");
            console2.log("forge verify-contract", vm.toString(address(riskEngine)));
            console2.log("  src/risk-engine/VedyxRiskEngine.sol:VedyxRiskEngine");
            console2.log("  --chain sepolia");
            console2.log("  --constructor-args", vm.toString(abi.encode(votingContract)));
        }
        console2.log("");
    }

    function saveDeployment() internal {
        console2.log("STEP 2: Saving Deployment Address...");
        
        string memory deploymentInfo = string(
            abi.encodePacked(
                '{\n',
                '  "network": "unichain-sepolia",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "riskEngine": "', vm.toString(address(riskEngine)), '",\n',
                '  "votingContract": "', vm.toString(votingContract), '",\n',
                '  "timestamp": ', vm.toString(block.timestamp), '\n',
                '}'
            )
        );

        vm.writeFile("./deployments/sepolia/RiskEngine.json", deploymentInfo);
        console2.log("Saved to: ./deployments/sepolia/RiskEngine.json");
        console2.log("");
    }

    function printDeploymentSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("\nDeployed Contracts:");
        console2.log("  VedyxRiskEngine:", address(riskEngine));
        console2.log("  VotingContract:", votingContract);
        
        console2.log("\nRisk Scoring Model:");
        console2.log("  Verdict Score:   0-40 points");
        console2.log("  Incident Score:  0-20 points");
        console2.log("  Detector Score:  0-20 points");
        console2.log("  Consensus Score: 0-10 points");
        console2.log("  Recency Score:   0-10 points");
        console2.log("  Total:           0-100 points");
        
        console2.log("\nRisk Levels:");
        console2.log("  SAFE:     0 points");
        console2.log("  LOW:      1-29 points");
        console2.log("  MEDIUM:   30-49 points");
        console2.log("  HIGH:     50-69 points");
        console2.log("  CRITICAL: 70+ points");
        
        console2.log("\nRegistered Detectors:");
        console2.log("  MIXER_INTERACTION: 50% severity");
        console2.log("  TRACE_PEEL_CHAIN:  35% severity");
        console2.log("  LARGE_TRANSFER:    15% severity");
        
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Verify contract on Etherscan");
        console2.log("2. Test risk assessment queries");
        console2.log("3. Integrate with frontend/protocols");
        console2.log("4. Monitor risk scores for flagged addresses");
        console2.log("========================================");
    }

    function getVotingContractAddress() internal view returns (address) {
        // Try to read from Sepolia deployment file first
        try vm.readFile("./deployments/sepolia/deployment.json") returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            address addr = abi.decode(data, (address));
            console2.log("Loaded VotingContract from deployment file:", addr);
            return addr;
        } catch {
            // Fall back to environment variable
            console2.log("Reading VotingContract from environment variable");
            return vm.envAddress("VOTING_CONTRACT_ADDRESS");
        }
    }
}
