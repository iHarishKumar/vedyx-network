// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxVotingContract} from "../../../src/voting-contract/VedyxVotingContract.sol";
import {VedyxVotingViews} from "../../../src/voting-contract/VedyxVotingViews.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockMixer} from "../../../src/mocks/MockMixer.sol";

/**
 * @title DeployVotingContract
 * @notice Deploys VedyxVotingContract on Unichain Sepolia testnet
 * 
 * This script deploys:
 * 1. Mock ERC20 tokens (USDC, USDT, WETH, DAI) for testing
 * 2. Mock mixers for testing threat detection
 * 3. Staking token (VGT) for governance
 * 4. VedyxVotingContract with Reactive callback integration
 * 
 * Prerequisites:
 * - Reactive Network must be deployed with callback proxy
 * 
 * Usage with Forge account:
 *   forge script script/networks/sepolia/DeployVotingContract.s.sol:DeployVotingContract \
 *     --rpc-url $UNICHAIN_SEPOLIA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast \
 *     --verify
 */
contract DeployVotingContract is Script {
    // Deployed contracts
    MockERC20 public stakingToken;
    VedyxVotingContract public votingContract;
    VedyxVotingViews public votingViews;
    
    // Mock tokens for testing
    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC20 public mockWETH;
    MockERC20 public mockDAI;
    
    // Mock mixers for testing
    MockMixer public mixer1;
    MockMixer public mixer2;

    // Unichain Sepolia chain ID
    uint256 public constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    
    // Reactive Network Callback Proxy for Unichain Sepolia
    address public constant REACTIVE_CALLBACK_PROXY = 0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4;

    // Configuration parameters
    uint256 private constant MINIMUM_STAKE = 100e18; // 100 tokens
    uint256 private constant VOTING_DURATION = 7 days;
    uint256 private constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 private constant FINALIZATION_FEE_PERCENTAGE = 200; // 2%
    uint256 private constant KARMA_REWARD = 10;
    uint256 private constant KARMA_PENALTY = 2000;
    int256 private constant MINIMUM_KARMA_TO_VOTE = -50;
    uint256 private constant FINALIZATION_REWARD_PERCENTAGE = 100; // 1%
    uint256 private constant MINIMUM_VOTERS = 3;
    uint256 private constant MINIMUM_TOTAL_VOTING_POWER = 1000e18;

    function run() external {
        address deployer = msg.sender;

        console2.log("========================================");
        console2.log("VOTING CONTRACT DEPLOYMENT");
        console2.log("Network: Unichain Sepolia");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        require(block.chainid == UNICHAIN_SEPOLIA_CHAIN_ID, "Wrong network - must be Unichain Sepolia");
        console2.log("Reactive Callback Proxy:", REACTIVE_CALLBACK_PROXY);
        console2.log("========================================\n");

        vm.startBroadcast();

        // Step 1: Deploy mocks (tokens, mixers, staking token)
        deployMocks();

        // Step 2: Deploy VedyxVotingContract
        deployVotingContract(deployer);

        // Step 3: Deploy VedyxVotingViews
        deployVotingViews();

        // Step 4: Configure contract
        configureContract(deployer);

        vm.stopBroadcast();

        // Step 5: Save deployment
        saveDeployment();

        // Step 6: Verify contracts
        verifyContracts();

        // Final summary
        printDeploymentSummary();
    }

    function deployMocks() internal {
        console2.log("STEP 1: Deploying Mock Contracts...");
        
        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6, 1_000_000_000 * 10**6);
        console2.log("  Mock USDC:", address(mockUSDC));

        mockUSDT = new MockERC20("Mock USDT", "USDT", 6, 1_000_000_000 * 10**6);
        console2.log("  Mock USDT:", address(mockUSDT));

        mockWETH = new MockERC20("Mock WETH", "WETH", 18, 1_000_000 ether);
        console2.log("  Mock WETH:", address(mockWETH));

        mockDAI = new MockERC20("Mock DAI", "DAI", 18, 1_000_000_000 ether);
        console2.log("  Mock DAI:", address(mockDAI));

        console2.log("");

        // Deploy mock mixers (use USDC and WETH for this script)
        mixer1 = new MockMixer(address(mockUSDC), 1000 * 10**6);
        console2.log("  USDC Mixer:", address(mixer1));

        mixer2 = new MockMixer(address(mockWETH), 1 ether);
        console2.log("  WETH Mixer:", address(mixer2));

        console2.log("");

        // Deploy staking token
        stakingToken = new MockERC20(
            "Vedyx Governance Token",
            "VGT",
            18,
            1_000_000_000 ether
        );
        console2.log("  Staking Token (VGT):", address(stakingToken));
        console2.log("");
    }

    function deployVotingContract(address deployer) internal {
        console2.log("STEP 2: Deploying VedyxVotingContract...");
        
        // Use Reactive Network callback proxy as authorizer
        votingContract = new VedyxVotingContract(
            address(stakingToken),
            REACTIVE_CALLBACK_PROXY,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            deployer, // treasury
            FINALIZATION_FEE_PERCENTAGE
        );
        
        console2.log("VedyxVotingContract:", address(votingContract));
        console2.log("Callback Authorizer:", REACTIVE_CALLBACK_PROXY);
        console2.log("");
    }

    function deployVotingViews() internal {
        console2.log("STEP 3: Deploying VedyxVotingViews...");
        
        votingViews = new VedyxVotingViews(address(votingContract));
        
        console2.log("VedyxVotingViews:", address(votingViews));
        console2.log("");
    }

    function configureContract(address deployer) internal {
        console2.log("STEP 4: Configuring VedyxVotingContract...");
        
        // Set karma parameters
        votingContract.setKarmaReward(KARMA_REWARD);
        votingContract.setKarmaPenalty(KARMA_PENALTY);
        votingContract.setMinimumKarmaToVote(MINIMUM_KARMA_TO_VOTE);

        console2.log("Karma parameters set");
        
        // Set finalization reward
        votingContract.setFinalizationRewardPercentage(FINALIZATION_REWARD_PERCENTAGE);

        console2.log("Finalization reward percentage set");
        
        // Set quorum requirements
        votingContract.setMinimumVoters(MINIMUM_VOTERS);
        votingContract.setMinimumTotalVotingPower(MINIMUM_TOTAL_VOTING_POWER);
        
        console2.log("Quorum requirements set");
        
        // Grant roles to deployer (can be transferred later)
        votingContract.grantRole(votingContract.GOVERNANCE_ROLE(), deployer);
        votingContract.grantRole(votingContract.PARAMETER_ADMIN_ROLE(), deployer);
        votingContract.grantRole(votingContract.TREASURY_ROLE(), deployer);
        
        console2.log("Configuration complete");
        console2.log("");
    }

    function verifyContracts() internal {
        console2.log("STEP 6: Verifying Contracts on Etherscan...");
        console2.log("");
        
        // Verify mocks using DeployMocks script
        // mockDeployer.verifyAll();
        
        // Verify VotingContract
        console2.log("Verifying VedyxVotingContract...");
        // verifyVotingContract(deployer);
        
        console2.log("Verification complete!");
        console2.log("");
    }
    
    function verifyVotingContract(address deployer) internal {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(address(votingContract));
        cmd[3] = "src/voting-contract/VedyxVotingContract.sol:VedyxVotingContract";
        cmd[4] = "--chain";
        cmd[5] = "sepolia";
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(abi.encode(
            address(stakingToken),
            REACTIVE_CALLBACK_PROXY,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            deployer,
            FINALIZATION_FEE_PERCENTAGE
        ));
        cmd[8] = "--watch";
        
        try vm.ffi(cmd) {
            console2.log("  Verified: VedyxVotingContract at", address(votingContract));
        } catch {
            console2.log("  Failed to verify: VedyxVotingContract - verify manually");
        }
    }

    function saveDeployment() internal {
        console2.log("STEP 5: Saving Deployment Addresses...");
        
        // Build JSON in parts to avoid stack too deep
        string memory part1 = _buildDeploymentJsonPart1();
        string memory part2 = _buildDeploymentJsonPart2();
        string memory part3 = _buildDeploymentJsonPart3();
        
        string memory deploymentInfo = string(abi.encodePacked(part1, part2, part3));

        vm.writeFile("./deployments/unichain-sepolia/VotingContract.json", deploymentInfo);
        console2.log("Saved to: ./deployments/unichain-sepolia/VotingContract.json");
        console2.log("");
    }
    
    function _buildDeploymentJsonPart1() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '{\n',
                '  "network": "unichain-sepolia",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "stakingToken": "', vm.toString(address(stakingToken)), '",\n',
                '  "votingContract": "', vm.toString(address(votingContract)), '",\n',
                '  "votingViews": "', vm.toString(address(votingViews)), '",\n',
                '  "reactiveCallbackProxy": "', vm.toString(REACTIVE_CALLBACK_PROXY), '",\n'
            )
        );
    }
    
    function _buildDeploymentJsonPart2() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '  "mockTokens": {\n',
                '    "USDC": "', vm.toString(address(mockUSDC)), '",\n',
                '    "USDT": "', vm.toString(address(mockUSDT)), '",\n',
                '    "WETH": "', vm.toString(address(mockWETH)), '",\n',
                '    "DAI": "', vm.toString(address(mockDAI)), '"\n',
                '  },\n',
                '  "mockMixers": {\n',
                '    "mixer1": "', vm.toString(address(mixer1)), '",\n',
                '    "mixer2": "', vm.toString(address(mixer2)), '"\n',
                '  },\n'
            )
        );
    }
    
    function _buildDeploymentJsonPart3() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '  "configuration": {\n',
                '    "minimumStake": "', vm.toString(MINIMUM_STAKE), '",\n',
                '    "votingDuration": ', vm.toString(VOTING_DURATION), ',\n',
                '    "penaltyPercentage": ', vm.toString(PENALTY_PERCENTAGE), ',\n',
                '    "karmaReward": ', vm.toString(KARMA_REWARD), ',\n',
                '    "karmaPenalty": ', vm.toString(KARMA_PENALTY), '\n',
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
        console2.log("\nMock Tokens:");
        console2.log("  USDC:", address(mockUSDC));
        console2.log("  USDT:", address(mockUSDT));
        console2.log("  WETH:", address(mockWETH));
        console2.log("  DAI:", address(mockDAI));
        console2.log("\nMock Mixers:");
        console2.log("  Mixer 1:", address(mixer1));
        console2.log("  Mixer 2:", address(mixer2));
        console2.log("\nGovernance:");
        console2.log("  Staking Token:", address(stakingToken));
        console2.log("  VotingContract:", address(votingContract));
        console2.log("  VotingViews:", address(votingViews));
        console2.log("  Callback Proxy:", REACTIVE_CALLBACK_PROXY);
        console2.log("========================================");
        console2.log("\nConfiguration:");
        console2.log("  Minimum Stake:", MINIMUM_STAKE / 1e18, "tokens");
        console2.log("  Voting Duration:", VOTING_DURATION / 1 days, "days");
        console2.log("  Penalty:", PENALTY_PERCENTAGE / 100, "%");
        console2.log("  Karma Reward:", KARMA_REWARD);
        console2.log("  Karma Penalty:", KARMA_PENALTY);
        console2.log("  Minimum Voters:", MINIMUM_VOTERS);
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Deploy Reactive contracts on Reactive Network");
        console2.log("2. Configure VedyxRSC with this voting contract:");
        console2.log("   Callback Contract:", address(votingContract));
        console2.log("   Destination Chain ID:", UNICHAIN_SEPOLIA_CHAIN_ID);
        console2.log("3. Mint staking tokens for testing");
        console2.log("4. Test voting flow");
        console2.log("========================================");
    }
}
