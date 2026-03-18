// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TokenRegistry} from "../../../src/reactive-contracts/detectors/TokenRegistry.sol";

/**
 * @title 01_DeployRegistry
 * @notice Step 1: Deploy TokenRegistry
 *
 * Usage:
 *   forge script script/networks/lasna-testnet/01_DeployRegistry.s.sol:DeployRegistry \
 *     --rpc-url https://lasna-rpc.rnk.dev/ \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployRegistry is Script {
    function run() external {
        console2.log("========================================");
        console2.log("STEP 1: Deploy TokenRegistry");
        console2.log("========================================");
        console2.log("Deployer:", msg.sender);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        vm.startBroadcast();

        TokenRegistry tokenRegistry = new TokenRegistry();
        console2.log("TokenRegistry deployed:", address(tokenRegistry));

        vm.stopBroadcast();

        // Save deployment
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "lasna-testnet",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "contracts": {\n',
                '    "tokenRegistry": "',
                vm.toString(address(tokenRegistry)),
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
        console2.log("Saved to: ./deployments/lasna-testnet/deployment.json");
        console2.log("========================================");
    }
}
