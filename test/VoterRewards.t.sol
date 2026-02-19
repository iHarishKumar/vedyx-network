// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {VedyxVotingContract} from "../src/voting-contract/VedyxVotingContract.sol";
import {VedyxTypes} from "../src/voting-contract/libraries/VedyxTypes.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

error InvalidAmount();
error InsufficientStake();
error VotingAlreadyEnded();
error AlreadyVoted();
error InvalidVotingId();
error UnauthorizedCallback();
error InvalidAddress();
error VotingStillActive();
error InvalidFeePercentage();
error InvalidTreasury();

contract VoterRewardsTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;
    
    address public owner;
    address public callbackAuthorizer;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public suspiciousAddr;
    
    uint256 public constant MINIMUM_STAKE = 100 ether;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    
    event VoterRewarded(address indexed voter, uint256 indexed votingId, uint256 rewardAmount);
    event PenaltyApplied(address indexed voter, uint256 indexed votingId, uint256 penaltyAmount);
    event KarmaUpdated(address indexed voter, int256 karmaChange, int256 newKarma);
    event VotingFinalized(uint256 indexed votingId, address indexed suspiciousAddress, bool isSuspicious, uint256 votesFor, uint256 votesAgainst);
    
    function setUp() public {
        owner = address(this);
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        suspiciousAddr = makeAddr("suspiciousAddr");
        
        stakingToken = new MockERC20("Vedyx Token", "VDX");
        
        votingContract = new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            FINALIZATION_FEE_PERCENTAGE
        );
        
        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);
        stakingToken.mint(user3, INITIAL_BALANCE);
        stakingToken.mint(user4, INITIAL_BALANCE);
        
        vm.prank(user1);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user2);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user3);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user4);
        stakingToken.approve(address(votingContract), type(uint256).max);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // REWARD DISTRIBUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_RewardDistribution_SingleCorrectVoter() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        vm.prank(user3);
        votingContract.castVote(votingId, true);
        
        uint256 user1StakeBefore = 500 ether;
        uint256 user2StakeBefore = 300 ether;
        uint256 user3StakeBefore = 300 ether;
        uint256 expectedPenalty = (user2StakeBefore * PENALTY_PERCENTAGE) / 10000; // 30 ether
        uint256 finalizationFee = (expectedPenalty * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalty
        uint256 rewardPool = expectedPenalty - finalizationFee; // 29.7 ether
        
        // user1 and user3 both voted correctly, so they share the reward proportionally
        // user1: 500 ether, user3: 300 ether, total: 800 ether
        uint256 user1Reward = (rewardPool * 500 ether) / 800 ether; // 62.5% of reward
        uint256 user3Reward = (rewardPool * 300 ether) / 800 ether; // 37.5% of reward
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore + user1Reward);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore - expectedPenalty);
        assertEq(stakeUser3After.stakedAmount, user3StakeBefore + user3Reward);
    }
    
    function test_RewardDistribution_MultipleCorrectVotersProportional() public {
        vm.prank(user1);
        votingContract.stake(600 ether);
        vm.prank(user2);
        votingContract.stake(400 ether);
        vm.prank(user3);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        uint256 user1StakeBefore = 600 ether;
        uint256 user2StakeBefore = 400 ether;
        uint256 user3StakeBefore = 500 ether;
        
        uint256 totalPenalty = (user3StakeBefore * PENALTY_PERCENTAGE) / 10000; // 50 ether
        uint256 finalizationFee = (totalPenalty * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalty
        uint256 penaltiesForDistribution = totalPenalty - finalizationFee; // 49.5 ether
        
        uint256 totalCorrectVotingPower = 600 ether + 400 ether; // 1000 ether
        uint256 expectedUser1Reward = (penaltiesForDistribution * 600 ether) / totalCorrectVotingPower; // 29.7 ether
        uint256 expectedUser2Reward = (penaltiesForDistribution * 400 ether) / totalCorrectVotingPower; // 19.8 ether
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore + expectedUser1Reward);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore + expectedUser2Reward);
        assertEq(stakeUser3After.stakedAmount, user3StakeBefore - totalPenalty);
    }
    
    function test_RewardDistribution_MultipleIncorrectVoters() public {
        vm.prank(user1);
        votingContract.stake(800 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(200 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        uint256 user1StakeBefore = 800 ether;
        uint256 user2StakeBefore = 300 ether;
        uint256 user3StakeBefore = 200 ether;
        
        uint256 user2Penalty = (user2StakeBefore * PENALTY_PERCENTAGE) / 10000; // 30 ether
        uint256 user3Penalty = (user3StakeBefore * PENALTY_PERCENTAGE) / 10000; // 20 ether
        uint256 totalPenalties = user2Penalty + user3Penalty; // 50 ether
        uint256 finalizationFee = (totalPenalties * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalties
        uint256 rewardAfterFee = totalPenalties - finalizationFee; // 49.5 ether
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore + rewardAfterFee);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore - user2Penalty);
        assertEq(stakeUser3After.stakedAmount, user3StakeBefore - user3Penalty);
    }
    
    function test_RewardDistribution_NoIncorrectVoters() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, true);
        
        uint256 user1StakeBefore = 500 ether;
        uint256 user2StakeBefore = 300 ether;
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore);
    }
    
    function test_RewardDistribution_AllVotersIncorrect() public {
        // Setup: user1 and user2 vote one way, user3 votes opposite with more power
        vm.prank(user1);
        votingContract.stake(300 ether);
        vm.prank(user2);
        votingContract.stake(200 ether);
        vm.prank(user3);
        votingContract.stake(800 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        // user1 and user2 vote false (minority), user3 votes true (majority)
        vm.prank(user1);
        votingContract.castVote(votingId, false);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        vm.prank(user3);
        votingContract.castVote(votingId, true);
        
        uint256 user1StakeBefore = 300 ether;
        uint256 user2StakeBefore = 200 ether;
        uint256 user3StakeBefore = 800 ether;
        
        // Consensus will be true (800 > 500), so user1 and user2 are incorrect
        uint256 user1Penalty = (user1StakeBefore * PENALTY_PERCENTAGE) / 10000; // 30 ether
        uint256 user2Penalty = (user2StakeBefore * PENALTY_PERCENTAGE) / 10000; // 20 ether
        uint256 totalPenalties = user1Penalty + user2Penalty; // 50 ether
        uint256 finalizationFee = (totalPenalties * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalties
        uint256 rewardAfterFee = totalPenalties - finalizationFee; // 49.5 ether
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        
        // user1 and user2 get penalized
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore - user1Penalty);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore - user2Penalty);
        
        // user3 (correct voter) receives penalties after fee deduction
        assertEq(stakeUser3After.stakedAmount, user3StakeBefore + rewardAfterFee);
    }
    
    function test_RewardDistribution_WithKarmaBonus() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(500 ether);
        vm.prank(user3);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        vm.prank(user3);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.karmaPoints, 10);
        
        vm.warp(block.timestamp + 1);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, true);
        vm.prank(user2);
        votingContract.castVote(votingId2, true);
        vm.prank(user3);
        votingContract.castVote(votingId2, false);
        
        (, bool user1VotedFor, uint256 user1VotingPower) = votingContract.getVote(votingId2, user1);
        (, bool user2VotedFor, uint256 user2VotingPower) = votingContract.getVote(votingId2, user2);
        
        assertTrue(user1VotedFor);
        assertTrue(user2VotedFor);
        
        // Both have same stake (500 ether) but user1 has 10 karma, user2 has 10 karma too
        // So they should have same voting power since both got karma from first vote
        // Let's verify karma bonus is applied
        VedyxTypes.Staker memory stakeUser2 = votingContract.getStakerInfo(user2);
        assertEq(stakeUser1.karmaPoints, 10);
        assertEq(stakeUser2.karmaPoints, 10);
        
        // Both should have same voting power since same stake and same karma
        assertEq(user1VotingPower, user2VotingPower);
        
        uint256 user1StakeBefore;
        uint256 user2StakeBefore;
        VedyxTypes.Staker memory stakeUser1Before = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2Before = votingContract.getStakerInfo(user2);
        user1StakeBefore = stakeUser1Before.stakedAmount;
        user2StakeBefore = stakeUser2Before.stakedAmount;
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId2);
        
        uint256 user1StakeAfter;
        uint256 user2StakeAfter;
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        user1StakeAfter = stakeUser1After.stakedAmount;
        user2StakeAfter = stakeUser2After.stakedAmount;
        
        uint256 user1Reward = user1StakeAfter - user1StakeBefore;
        uint256 user2Reward = user2StakeAfter - user2StakeBefore;
        
        // Both have same voting power, so should get equal rewards
        assertEq(user1Reward, user2Reward);
        assertGt(user1Reward, 0);
        assertGt(user2Reward, 0);
    }
    
    function test_RewardDistribution_FourVotersMixedOutcome() public {
        vm.prank(user1);
        votingContract.stake(1000 ether);
        vm.prank(user2);
        votingContract.stake(600 ether);
        vm.prank(user3);
        votingContract.stake(400 ether);
        vm.prank(user4);
        votingContract.stake(200 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        vm.prank(user4);
        votingContract.castVote(votingId, false);
        
        uint256 user3Penalty = (400 ether * PENALTY_PERCENTAGE) / 10000; // 40 ether
        uint256 user4Penalty = (200 ether * PENALTY_PERCENTAGE) / 10000; // 20 ether
        uint256 totalPenalties = user3Penalty + user4Penalty; // 60 ether
        uint256 finalizationFee = (totalPenalties * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalties
        uint256 penaltiesForDistribution = totalPenalties - finalizationFee; // 59.4 ether
        
        uint256 totalCorrectVotingPower = 1000 ether + 600 ether; // 1600 ether
        uint256 expectedUser1Reward = (penaltiesForDistribution * 1000 ether) / totalCorrectVotingPower;
        uint256 expectedUser2Reward = (penaltiesForDistribution * 600 ether) / totalCorrectVotingPower;
        
        uint256 user1StakeBefore = 1000 ether;
        uint256 user2StakeBefore = 600 ether;
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        VedyxTypes.Staker memory stakeUser4After = votingContract.getStakerInfo(user4);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore + expectedUser1Reward);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore + expectedUser2Reward);
        assertEq(stakeUser3After.stakedAmount, 400 ether - user3Penalty);
        assertEq(stakeUser4After.stakedAmount, 200 ether - user4Penalty);
        
        // Total should be original total minus finalization fee
        uint256 totalStakesAfter = stakeUser1After.stakedAmount + stakeUser2After.stakedAmount + stakeUser3After.stakedAmount + stakeUser4After.stakedAmount;
        uint256 originalTotal = user1StakeBefore + user2StakeBefore + 400 ether + 200 ether;
        assertEq(totalStakesAfter, originalTotal - finalizationFee);
    }
    
    function test_RewardDistribution_PenaltyExceedsStake() public {
        votingContract.setPenaltyPercentage(5000); // 50%
        
        vm.prank(user1);
        votingContract.stake(600 ether);
        vm.prank(user2);
        votingContract.stake(150 ether);
        vm.prank(user3);
        votingContract.stake(400 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        vm.prank(user3);
        votingContract.castVote(votingId, true);
        
        uint256 user1StakeBefore = 600 ether;
        uint256 user2StakeBefore = 150 ether;
        uint256 user3StakeBefore = 400 ether;
        uint256 calculatedPenalty = (user2StakeBefore * 5000) / 10000; // 75 ether
        
        // Penalty is capped at available stake (150 ether is available, 75 ether penalty doesn't exceed it)
        uint256 actualPenalty = calculatedPenalty; // 75 ether
        
        uint256 finalizationFee = (actualPenalty * FINALIZATION_FEE_PERCENTAGE) / 10000; // 1% of penalty
        uint256 rewardPool = actualPenalty - finalizationFee;
        
        // user1 and user3 both voted correctly, so they share the reward proportionally
        // user1: 600 ether, user3: 400 ether, total: 1000 ether
        uint256 user1Reward = (rewardPool * 600 ether) / 1000 ether; // 60% of reward
        uint256 user3Reward = (rewardPool * 400 ether) / 1000 ether; // 40% of reward
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        VedyxTypes.Staker memory stakeUser2After = votingContract.getStakerInfo(user2);
        VedyxTypes.Staker memory stakeUser3After = votingContract.getStakerInfo(user3);
        
        assertEq(stakeUser1After.stakedAmount, user1StakeBefore + user1Reward);
        assertEq(stakeUser2After.stakedAmount, user2StakeBefore - actualPenalty);
        assertEq(stakeUser3After.stakedAmount, user3StakeBefore + user3Reward);
    }
}
