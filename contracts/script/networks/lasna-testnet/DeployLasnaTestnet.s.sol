// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TokenRegistry} from "../../../src/reactive-contracts/detectors/TokenRegistry.sol";
import {LargeTransferDetector} from "../../../src/reactive-contracts/detectors/LargeTransferDetector.sol";
import {MixerInteractionDetector} from "../../../src/reactive-contracts/detectors/MixerInteractionDetector.sol";
import {TracePeelChainDetector} from "../../../src/reactive-contracts/detectors/TracePeelChainDetector.sol";
import {VedyxExploitDetectorRSC} from "../../../src/reactive-contracts/VedyxExploitDetectorRSC.sol";

/**
 * @title DeployLasnaTestnet
 * @notice Deployment for Lasna testnet - Reactive contracts only
 * 
 * This script deploys:
 * 1. TokenRegistry
 * 2. All attack vector detectors
 * 3. VedyxExploitDetectorRSC
 * 
 * Note: Mock tokens and mixers should be deployed on Sepolia (origin/destination chain)
 * 
 * Usage with Forge account:
 *   forge script script/networks/lasna-testnet/DeployLasnaTestnet.s.sol:DeployLasnaTestnet \
 *     --rpc-url $LASNA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployLasnaTestnet is Script {
    // Deployed contracts
    TokenRegistry public tokenRegistry;
    LargeTransferDetector public largeTransferDetector;
    MixerInteractionDetector public mixerInteractionDetector;
    TracePeelChainDetector public tracePeelChainDetector;
    VedyxExploitDetectorRSC public vedyxRSC;

    // Configuration
    uint256 private constant TRANSFER_TOPIC = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    uint256 private constant DESTINATION_CHAIN_ID = 1301; // Unichain Seploia chain id

    function run() external {
        address deployer = msg.sender;

        console2.log("========================================");
        console2.log("VEDYX LASNA TESTNET DEPLOYMENT");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("========================================\n");

        vm.startBroadcast();

        // Step 1: Deploy TokenRegistry
        deployTokenRegistry();

        // Step 2: Deploy Detectors
        deployDetectors();

        // Step 3: Deploy VedyxExploitDetectorRSC
        deployVedyxRSC();

        // Step 4: Register Detectors
        registerDetectors();

        // Step 5: Setup Subscriptions (requires token addresses from Sepolia)
        setupSubscriptions();

        vm.stopBroadcast();

        // Step 6: Save Deployments
        saveDeployments();

        // Final Summary
        printDeploymentSummary();
    }


    function deployTokenRegistry() internal {
        console2.log("STEP 1: Deploying TokenRegistry...");
        
        tokenRegistry = new TokenRegistry();
        console2.log("TokenRegistry:", address(tokenRegistry));
        console2.log("NOTE: Configure tokens after deployment using token addresses from Sepolia");
        console2.log("");
    }

    function deployDetectors() internal {
        console2.log("STEP 2: Deploying Attack Vector Detectors...");
        
        largeTransferDetector = new LargeTransferDetector(address(tokenRegistry));
        console2.log("LargeTransferDetector:", address(largeTransferDetector));

        mixerInteractionDetector = new MixerInteractionDetector(address(tokenRegistry));
        console2.log("MixerInteractionDetector:", address(mixerInteractionDetector));

        tracePeelChainDetector = new TracePeelChainDetector(address(tokenRegistry));
        console2.log("TracePeelChainDetector:", address(tracePeelChainDetector));
        
        console2.log("NOTE: Configure detector thresholds and mixers after deployment");
        console2.log("");
    }

    function deployVedyxRSC() internal {
        console2.log("STEP 3: Deploying VedyxExploitDetectorRSC...");
        
        // Load callback contract and chain ID from Unichain Sepolia deployment
        address callbackContract = getCallbackContractAddress();
        uint256 destinationChainId = DESTINATION_CHAIN_ID;
        
        vedyxRSC = new VedyxExploitDetectorRSC(callbackContract, destinationChainId);
        console2.log("VedyxExploitDetectorRSC:", address(vedyxRSC));
        console2.log("Callback Contract:", callbackContract);
        console2.log("Destination Chain ID:", destinationChainId);
        console2.log("");
    }
    
    function getCallbackContractAddress() internal view returns (address) {
        // Try to read from Unichain Sepolia deployment file first
        try vm.readFile("./deployments/unichain-sepolia/deployment.json") returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            address addr = abi.decode(data, (address));
            console2.log("Loaded VotingContract from Unichain Sepolia deployment:", addr);
            return addr;
        } catch {
            // Fall back to environment variable
            try vm.envAddress("CALLBACK_CONTRACT") returns (address addr) {
                console2.log("Loaded VotingContract from environment variable:", addr);
                return addr;
            } catch {
                revert("VotingContract address not found in deployment.json or CALLBACK_CONTRACT env var");
            }
        }
    }

    function registerDetectors() internal {
        console2.log("STEP 4: Registering Detectors...");
        
        vedyxRSC.registerDetector(address(largeTransferDetector));
        console2.log("Registered LargeTransferDetector");

        vedyxRSC.registerDetector(address(mixerInteractionDetector));
        console2.log("Registered MixerInteractionDetector");

        vedyxRSC.registerDetector(address(tracePeelChainDetector));
        console2.log("Registered TracePeelChainDetector");
        
        console2.log("");
    }

    function setupSubscriptions() internal {
        console2.log("STEP 5: Setting up Subscriptions...");
        console2.log("NOTE: Subscriptions should be configured after deployment");
        console2.log("Use UpdateVedyxRSC script to subscribe to token events from Sepolia");
        console2.log("");
    }

    function saveDeployments() internal {
        console2.log("STEP 6: Saving Deployment Addresses...");
        
        string memory deploymentInfo = string(
            abi.encodePacked(
                '{\n',
                '  "network": "lasna-testnet",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "reactiveContracts": {\n',
                '    "tokenRegistry": "', vm.toString(address(tokenRegistry)), '",\n',
                '    "largeTransferDetector": "', vm.toString(address(largeTransferDetector)), '",\n',
                '    "mixerInteractionDetector": "', vm.toString(address(mixerInteractionDetector)), '",\n',
                '    "tracePeelChainDetector": "', vm.toString(address(tracePeelChainDetector)), '",\n',
                '    "vedyxExploitDetectorRSC": "', vm.toString(address(vedyxRSC)), '"\n',
                '  },\n',
                '  "timestamp": ', vm.toString(block.timestamp), '\n',
                '}'
            )
        );

        vm.writeFile("./deployments/lasna-testnet/deployment.json", deploymentInfo);
        console2.log("Saved to: ./deployments/lasna-testnet/deployment.json");
        console2.log("");
    }

    function printDeploymentSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("\nReactive Contracts:");
        console2.log("  TokenRegistry:", address(tokenRegistry));
        console2.log("  LargeTransferDetector:", address(largeTransferDetector));
        console2.log("  MixerInteractionDetector:", address(mixerInteractionDetector));
        console2.log("  TracePeelChainDetector:", address(tracePeelChainDetector));
        console2.log("  VedyxExploitDetectorRSC:", address(vedyxRSC));
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Configure TokenRegistry with token addresses from Sepolia");
        console2.log("2. Configure detector thresholds");
        console2.log("3. Register mixer addresses from Sepolia");
        console2.log("4. Use UpdateVedyxRSC script to subscribe to Sepolia events");
        console2.log("========================================");
    }
}
