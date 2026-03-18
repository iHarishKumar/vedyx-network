// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/voting-contract/VedyxVotingContract.sol";

/**
 * @title TagSuspicious Script
 * @notice Script to invoke tagSuspicious function with dummy data for testing
 * @dev Usage: forge script script/TagSuspicious.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
 */
contract TagSuspiciousScript is Script {
    function run() external {
        // Load deployment configuration
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/unichain-sepolia/deployment.json");
        string memory json = vm.readFile(path);
        
        address votingContractAddress = vm.parseJsonAddress(json, ".contracts.votingContract");
        address callbackProxy = vm.parseJsonAddress(json, ".reactiveCallbackProxy");
        
        console.log("=== Tag Suspicious Address Script ===");
        console.log("Voting Contract:", votingContractAddress);
        console.log("Callback Proxy:", callbackProxy);
        
        // Dummy test data
        address suspiciousAddress = 0x1234567890123456789012345678901234567890; // Dummy suspicious address
        uint256 originChainId = 1301; // Unichain Sepolia
        address originContract = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on Ethereum
        uint256 value = 1000000000; // 1000 USDC (6 decimals)
        uint256 decimals = 6;
        uint256 txHash = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        bytes32 detectorId = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        
        console.log("\n=== Test Parameters ===");
        console.log("Suspicious Address:", suspiciousAddress);
        console.log("Origin Chain ID:", originChainId);
        console.log("Origin Contract:", originContract);
        console.log("Value:", value);
        console.log("Decimals:", decimals);
        console.log("Tx Hash:", uint256(txHash));
        console.log("Detector ID:", uint256(detectorId));
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        VedyxVotingContract votingContract = VedyxVotingContract(payable(votingContractAddress));
        
        // Note: This will fail if called from non-authorized address
        // The caller must be the reactiveCallbackProxy
        // For testing, you may need to grant CALLBACK_AUTHORIZER_ROLE to your address first
        
        try votingContract.tagSuspicious(
            suspiciousAddress,
            originChainId,
            originContract,
            value,
            decimals,
            txHash,
            detectorId
        ) returns (uint256 votingId) {
            console.log("\n=== Success ===");
            if (votingId == 0) {
                console.log("Address auto-marked as suspicious (repeat offender)");
            } else {
                console.log("New voting created with ID:", votingId);
            }
        } catch Error(string memory reason) {
            console.log("\n=== Error ===");
            console.log("Reason:", reason);
            console.log("\nNote: If you see 'Unauthorized', you need to grant CALLBACK_AUTHORIZER_ROLE to your address");
            console.log("Run the GrantRole script first or use the callback proxy address");
        } catch (bytes memory lowLevelData) {
            console.log("\n=== Low Level Error ===");
            console.logBytes(lowLevelData);
        }
        
        vm.stopBroadcast();
    }
}
