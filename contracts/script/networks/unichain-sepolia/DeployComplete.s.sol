// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxVotingContract} from "../../../src/voting-contract/VedyxVotingContract.sol";
import {VedyxRiskEngine} from "../../../src/risk-engine/VedyxRiskEngine.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockMixer} from "../../../src/mocks/MockMixer.sol";
import {DeployVotingContract} from "./DeployVotingContract.s.sol";

/**
 * @title DeployComplete
 * @notice Complete deployment orchestration for Unichain Sepolia
 * 
 * Deploys all destination chain contracts:
 * 1. Mock ERC20 tokens (USDC, USDT, WETH, DAI) via DeployVotingContract
 * 2. Mock mixers for testing via DeployVotingContract
 * 3. Staking Token (VGT) via DeployVotingContract
 * 4. VedyxVotingContract with Reactive callback proxy (configured by DeployVotingContract)
 * 5. VedyxRiskEngine
 * 
 * Note: VotingContract configuration is handled by DeployVotingContract module.
 * Configuration values are documented below for reference only.
 * 
 * Usage with Forge account:
 *   forge script script/networks/sepolia/DeployComplete.s.sol:DeployComplete \
 *     --rpc-url $UNICHAIN_SEPOLIA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast \
 *     --verify
 */
contract DeployComplete is Script {
    // Voting contract deployment helper
    DeployVotingContract public votingDeployer;
    
    // Deployed contracts
    VedyxVotingContract public votingContract;
    VedyxRiskEngine public riskEngine;

    // Unichain Sepolia chain ID
    uint256 public constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    function run() external {
        address deployer = msg.sender;

        console2.log("========================================");
        console2.log("UNICHAIN SEPOLIA COMPLETE DEPLOYMENT");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        require(block.chainid == UNICHAIN_SEPOLIA_CHAIN_ID, "Wrong network - must be Unichain Sepolia");
        console2.log("========================================\n");

        // Step 1: Deploy VotingContract (includes mocks and configuration)
        deployVotingContractModule();

        vm.startBroadcast();

        // Step 2: Deploy VedyxRiskEngine
        deployRiskEngine();

        vm.stopBroadcast();

        // Step 3: Save deployment
        saveAllDeployments();

        // Final summary
        printDeploymentSummary();
    }

    function deployVotingContractModule() internal {
        console2.log("STEP 1: Deploying VotingContract Module...");
        console2.log("(includes mocks, staking token, and VotingContract configuration)");
        console2.log("");
        
        // Create and run VotingContract deployment
        // This handles: mock tokens, mixers, staking token, VotingContract deployment & configuration
        votingDeployer = new DeployVotingContract();
        votingDeployer.run();
        
        // Get deployed VotingContract reference
        votingContract = votingDeployer.votingContract();
        
        console2.log("VotingContract module deployment complete");
        console2.log("");
    }

    function deployRiskEngine() internal {
        console2.log("STEP 2: Deploying VedyxRiskEngine...");
        
        riskEngine = new VedyxRiskEngine(address(votingContract));
        
        console2.log("VedyxRiskEngine:", address(riskEngine));
        console2.log("");
    }

    function saveAllDeployments() internal {
        console2.log("STEP 3: Saving Deployment Addresses...");
        
        // Build JSON in parts to avoid stack too deep
        string memory part1 = _buildJsonPart1();
        string memory part2 = _buildJsonPart2();
        string memory part3 = _buildJsonPart3();
        
        string memory deploymentInfo = string(abi.encodePacked(part1, part2, part3));

        vm.writeFile("./deployments/unichain-sepolia/deployment.json", deploymentInfo);
        console2.log("Saved to: ./deployments/unichain-sepolia/deployment.json");
        console2.log("");
    }
    
    function _buildJsonPart1() internal view returns (string memory) {
        address stakingToken = address(votingDeployer.stakingToken());
        address callbackProxy = votingDeployer.REACTIVE_CALLBACK_PROXY();
        
        return string(
            abi.encodePacked(
                '{\n',
                '  "network": "unichain-sepolia",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "reactiveCallbackProxy": "', vm.toString(callbackProxy), '",\n',
                '  "contracts": {\n',
                '    "stakingToken": "', vm.toString(stakingToken), '",\n',
                '    "votingContract": "', vm.toString(address(votingContract)), '",\n',
                '    "riskEngine": "', vm.toString(address(riskEngine)), '"\n',
                '  },\n'
            )
        );
    }
    
    function _buildJsonPart2() internal view returns (string memory) {
        address mockUSDC = address(votingDeployer.mockUSDC());
        address mockUSDT = address(votingDeployer.mockUSDT());
        address mockWETH = address(votingDeployer.mockWETH());
        address mockDAI = address(votingDeployer.mockDAI());
        address mixer1 = address(votingDeployer.mixer1());
        address mixer2 = address(votingDeployer.mixer2());
        
        return string(
            abi.encodePacked(
                '  "mockTokens": {\n',
                '    "USDC": "', vm.toString(mockUSDC), '",\n',
                '    "USDT": "', vm.toString(mockUSDT), '",\n',
                '    "WETH": "', vm.toString(mockWETH), '",\n',
                '    "DAI": "', vm.toString(mockDAI), '"\n',
                '  },\n',
                '  "mockMixers": {\n',
                '    "mixer1": "', vm.toString(mixer1), '",\n',
                '    "mixer2": "', vm.toString(mixer2), '"\n',
                '  },\n'
            )
        );
    }
    
    function _buildJsonPart3() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '  "configuration": {\n',
                '    "minimumStake": "', vm.toString(votingContract.minimumStake()), '",\n',
                '    "votingDuration": ', vm.toString(votingContract.votingDuration()), ',\n',
                '    "penaltyPercentage": ', vm.toString(votingContract.penaltyPercentage()), ',\n',
                '    "karmaReward": ', vm.toString(votingContract.karmaReward()), ',\n',
                '    "karmaPenalty": ', vm.toString(votingContract.karmaPenalty()), ',\n',
                '    "minimumVoters": ', vm.toString(votingContract.minimumVoters()), '\n',
                '  },\n',
                '  "timestamp": ', vm.toString(block.timestamp), '\n',
                '}'
            )
        );
    }

    function printDeploymentSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("\nCore Contracts:");
        console2.log("  VedyxVotingContract:", address(votingContract));
        console2.log("  VedyxRiskEngine:", address(riskEngine));
        console2.log("\nConfiguration:");
        console2.log("  Minimum Stake:", votingContract.minimumStake() / 1e18, "tokens");
        console2.log("  Voting Duration:", votingContract.votingDuration() / 1 days, "days");
        console2.log("  Minimum Voters:", votingContract.minimumVoters());
        console2.log("  Karma Reward:", votingContract.karmaReward());
        console2.log("  Karma Penalty:", votingContract.karmaPenalty());
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Deploy Reactive contracts on Reactive Lasna Network");
        console2.log("2. Update VedyxRSC with voting contract address");
        console2.log("3. Subscribe to token Transfer events");
        console2.log("4. Test risk assessment queries");
        console2.log("5. Test complete threat detection flow");
        console2.log("========================================");
        console2.log("\nNote: Mock tokens and mixers deployed by VotingContract module");
        console2.log("See ./deployments/unichain-sepolia/deployment.json for all addresses");
        console2.log("========================================");
    }
}
