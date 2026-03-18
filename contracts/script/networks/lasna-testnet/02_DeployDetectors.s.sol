// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {LargeTransferDetector} from "../../../src/reactive-contracts/detectors/LargeTransferDetector.sol";
import {MixerInteractionDetector} from "../../../src/reactive-contracts/detectors/MixerInteractionDetector.sol";
import {TracePeelChainDetector} from "../../../src/reactive-contracts/detectors/TracePeelChainDetector.sol";

/**
 * @title 02_DeployDetectors
 * @notice Step 2: Deploy all detector contracts
 *
 * Usage:
 *   forge script script/networks/lasna-testnet/02_DeployDetectors.s.sol:DeployDetectors \
 *     --rpc-url https://lasna-rpc.rnk.dev/ \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployDetectors is Script {
    function run() external {
        console2.log("========================================");
        console2.log("STEP 2: Deploy Detectors");
        console2.log("========================================");

        // Load TokenRegistry address
        address tokenRegistry = getTokenRegistry();
        console2.log("TokenRegistry:", tokenRegistry);
        console2.log("");

        vm.startBroadcast();

        LargeTransferDetector largeTransferDetector = new LargeTransferDetector(
            tokenRegistry
        );
        console2.log("LargeTransferDetector:", address(largeTransferDetector));

        MixerInteractionDetector mixerInteractionDetector = new MixerInteractionDetector(
            tokenRegistry
        );
        console2.log("MixerInteractionDetector:", address(mixerInteractionDetector));

        TracePeelChainDetector tracePeelChainDetector = new TracePeelChainDetector(
            tokenRegistry
        );
        console2.log("TracePeelChainDetector:", address(tracePeelChainDetector));

        vm.stopBroadcast();

        // Update deployment file
        updateDeploymentFile(
            tokenRegistry,
            address(largeTransferDetector),
            address(mixerInteractionDetector),
            address(tracePeelChainDetector)
        );

        console2.log("========================================");
    }

    function getTokenRegistry() internal view returns (address) {
        string memory json = vm.readFile("./deployments/lasna-testnet/deployment.json");
        bytes memory data = vm.parseJson(json, ".contracts.tokenRegistry");
        return abi.decode(data, (address));
    }

    function updateDeploymentFile(
        address tokenRegistry,
        address largeTransferDetector,
        address mixerInteractionDetector,
        address tracePeelChainDetector
    ) internal {
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
                vm.toString(largeTransferDetector),
                '",\n',
                '    "mixerInteractionDetector": "',
                vm.toString(mixerInteractionDetector),
                '",\n',
                '    "tracePeelChainDetector": "',
                vm.toString(tracePeelChainDetector),
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
