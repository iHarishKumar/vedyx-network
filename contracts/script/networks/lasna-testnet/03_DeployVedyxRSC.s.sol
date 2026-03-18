// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxExploitDetectorRSC} from "../../../src/reactive-contracts/VedyxExploitDetectorRSC.sol";

/**
 * @title 03_DeployVedyxRSC
 * @notice Step 3: Deploy VedyxExploitDetectorRSC and register detectors
 *
 * Usage:
 *   forge script script/networks/lasna-testnet/03_DeployVedyxRSC.s.sol:DeployVedyxRSC \
 *     --rpc-url https://lasna-rpc.rnk.dev/ \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployVedyxRSC is Script {
    uint256 private constant DESTINATION_CHAIN_ID = 1301; // Unichain Sepolia

    function run() external {
        console2.log("========================================");
        console2.log("STEP 3: Deploy VedyxRSC & Register Detectors");
        console2.log("========================================");

        // Load voting contract address
        address votingContract = getVotingContractAddress();
        console2.log("Voting Contract:", votingContract);

        // Load detector addresses
        (address largeTransfer, address mixerInteraction, address tracePeel) = getDetectors();
        console2.log("LargeTransferDetector:", largeTransfer);
        console2.log("MixerInteractionDetector:", mixerInteraction);
        console2.log("TracePeelChainDetector:", tracePeel);
        console2.log("");

        vm.startBroadcast();

        // Deploy VedyxRSC with 0.1 ETH
        VedyxExploitDetectorRSC vedyxRSC = new VedyxExploitDetectorRSC{value: 0.1 ether}(
            votingContract,
            DESTINATION_CHAIN_ID
        );
        console2.log("VedyxExploitDetectorRSC:", address(vedyxRSC));
        console2.log("Deployed with 0.1 ETH for subscriptions");
        console2.log("");

        // Register detectors
        console2.log("Registering detectors...");
        vedyxRSC.registerDetector(largeTransfer);
        console2.log("  Registered LargeTransferDetector");

        vedyxRSC.registerDetector(mixerInteraction);
        console2.log("  Registered MixerInteractionDetector");

        vedyxRSC.registerDetector(tracePeel);
        console2.log("  Registered TracePeelChainDetector");

        vm.stopBroadcast();

        // Update deployment file
        updateDeploymentFile(address(vedyxRSC));

        console2.log("========================================");
    }

    function getVotingContractAddress() internal view returns (address) {
        try vm.readFile("./deployments/unichain-sepolia/deployment.json") returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            return abi.decode(data, (address));
        } catch {
            return vm.envAddress("VOTING_CONTRACT_ADDRESS");
        }
    }

    function getDetectors() internal view returns (address, address, address) {
        string memory json = vm.readFile("./deployments/lasna-testnet/deployment.json");
        
        bytes memory data1 = vm.parseJson(json, ".contracts.largeTransferDetector");
        bytes memory data2 = vm.parseJson(json, ".contracts.mixerInteractionDetector");
        bytes memory data3 = vm.parseJson(json, ".contracts.tracePeelChainDetector");
        
        return (
            abi.decode(data1, (address)),
            abi.decode(data2, (address)),
            abi.decode(data3, (address))
        );
    }

    function updateDeploymentFile(address vedyxRSC) internal {
        string memory json = vm.readFile("./deployments/lasna-testnet/deployment.json");
        
        bytes memory tokenRegistryData = vm.parseJson(json, ".contracts.tokenRegistry");
        bytes memory largeTransferData = vm.parseJson(json, ".contracts.largeTransferDetector");
        bytes memory mixerInteractionData = vm.parseJson(json, ".contracts.mixerInteractionDetector");
        bytes memory tracePeelData = vm.parseJson(json, ".contracts.tracePeelChainDetector");
        
        address tokenRegistry = abi.decode(tokenRegistryData, (address));
        address largeTransfer = abi.decode(largeTransferData, (address));
        address mixerInteraction = abi.decode(mixerInteractionData, (address));
        address tracePeel = abi.decode(tracePeelData, (address));

        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "lasna-testnet",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "contracts": {\n',
                '    "tokenRegistry": "',
                vm.toString(tokenRegistry),
                '",\n',
                '    "largeTransferDetector": "',
                vm.toString(largeTransfer),
                '",\n',
                '    "mixerInteractionDetector": "',
                vm.toString(mixerInteraction),
                '",\n',
                '    "tracePeelChainDetector": "',
                vm.toString(tracePeel),
                '",\n',
                '    "vedyxExploitDetectorRSC": "',
                vm.toString(vedyxRSC),
                '"\n',
                "  },\n",
                '  "timestamp": ',
                vm.toString(block.timestamp),
                "\n",
                "}"
            )
        );

        vm.writeFile(
            "./deployments/lasna-testnet/deployment.json",
            deploymentInfo
        );
        console2.log("Updated: ./deployments/lasna-testnet/deployment.json");
    }
}
