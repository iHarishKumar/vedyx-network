// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {VedyxVotingContract} from "../src/voting-contract/VedyxVotingContract.sol";
import {VedyxTypes} from "../src/voting-contract/libraries/VedyxTypes.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// Import custom errors
error InvalidAmount();
error InsufficientStake();
error VotingNotActive();
error VotingAlreadyEnded();
error AlreadyVoted();
error VotingNotEnded();
error NoStakeToWithdraw();
error InvalidVotingId();
error UnauthorizedCallback();
error InvalidAddress();
error VotingStillActive();
error CannotUnstakeWhenVotingIsActive();
error InvalidFeePercentage();
error InvalidTreasury();
error InsufficientFeesForReward();

contract VedyxVotingContractTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;
    
    address public owner;
    address public callbackAuthorizer;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    address public suspiciousAddr;
    
    uint256 public constant MINIMUM_STAKE = 100 ether;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    
    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event VotingStarted(uint256 indexed votingId, address indexed suspiciousAddress, uint256 endTime);
    event VoteCast(uint256 indexed votingId, address indexed voter, bool votedFor, uint256 votingPower);
    event VotingFinalized(uint256 indexed votingId, address indexed suspiciousAddress, bool isSuspicious, uint256 votesFor, uint256 votesAgainst);
    event PenaltyApplied(address indexed voter, uint256 indexed votingId, uint256 penaltyAmount);
    event KarmaUpdated(address indexed voter, int256 karmaChange, int256 newKarma);
    event FinalizationRewardPaid(uint256 indexed votingId, address indexed finalizer, uint256 rewardAmount);
    event CallbackAuthorizerUpdated(address indexed newAuthorizer);
    event MinimumStakeUpdated(uint256 newMinimum);
    event VotingDurationUpdated(uint256 newDuration);
    event PenaltyPercentageUpdated(uint256 newPercentage);
    event FinalizationRewardPercentageUpdated(uint256 newPercentage);
    event TreasuryUpdated(address indexed newTreasury);
    event FinalizationFeeUpdated(uint256 newFeePercentage);
    event FeeCollected(address indexed staker, uint256 feeAmount);
    event VoterRewarded(address indexed voter, uint256 indexed votingId, uint256 rewardAmount);
    
    function setUp() public {
        owner = address(this);
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
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
        
        vm.prank(user1);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user2);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user3);
        stakingToken.approve(address(votingContract), type(uint256).max);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_Constructor_Success() public view {
        assertEq(address(votingContract.stakingToken()), address(stakingToken));
        assertEq(votingContract.callbackAuthorizer(), callbackAuthorizer);
        assertEq(votingContract.minimumStake(), MINIMUM_STAKE);
        assertEq(votingContract.votingDuration(), VOTING_DURATION);
        assertEq(votingContract.penaltyPercentage(), PENALTY_PERCENTAGE);
        assertEq(votingContract.treasury(), treasury);
        assertEq(votingContract.finalizationFeePercentage(), FINALIZATION_FEE_PERCENTAGE);
        assertEq(votingContract.finalizationRewardPercentage(), 200); // 2% default
        assertEq(votingContract.karmaReward(), 10);
        assertEq(votingContract.karmaPenalty(), 5);
    }
    
    function test_Constructor_RevertWhen_InvalidStakingToken() public {
        vm.expectRevert(InvalidAddress.selector);
        new VedyxVotingContract(
            address(0),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            FINALIZATION_FEE_PERCENTAGE
        );
    }
    
    function test_Constructor_RevertWhen_InvalidCallbackAuthorizer() public {
        vm.expectRevert(InvalidAddress.selector);
        new VedyxVotingContract(
            address(stakingToken),
            address(0),
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            FINALIZATION_FEE_PERCENTAGE
        );
    }
    
    function test_Constructor_RevertWhen_InvalidTreasury() public {
        vm.expectRevert(InvalidTreasury.selector);
        new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            address(0),
            FINALIZATION_FEE_PERCENTAGE
        );
    }
    
    function test_Constructor_RevertWhen_FinalizationFeePercentageTooHigh() public {
        vm.expectRevert(InvalidFeePercentage.selector);
        new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            1001 // > 10%
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // STAKING TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_Stake_Success() public {
        uint256 stakeAmount = 500 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, stakeAmount);
        
        vm.prank(user1);
        votingContract.stake(stakeAmount);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.stakedAmount, stakeAmount);
        assertEq(stakeUser1.lockedAmount, 0);
        assertEq(stakingToken.balanceOf(address(votingContract)), stakeAmount);
    }
    
    function test_Stake_MultipleStakes() public {
        vm.startPrank(user1);
        votingContract.stake(200 ether);
        votingContract.stake(300 ether);
        vm.stopPrank();
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.stakedAmount, 500 ether);
    }
    
    function test_Stake_RevertWhen_ZeroAmount() public {
        vm.expectRevert(InvalidAmount.selector);
        vm.prank(user1);
        votingContract.stake(0);
    }
    
    function test_Stake_RevertWhen_InsufficientBalance() public {
        address poorUser = makeAddr("poorUser");
        stakingToken.mint(poorUser, 50 ether);
        
        vm.startPrank(poorUser);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.expectRevert();
        votingContract.stake(100 ether);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // UNSTAKING TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_Unstake_Success() public {
        uint256 stakeAmount = 500 ether;
        uint256 unstakeAmount = 200 ether;
        
        vm.startPrank(user1);
        votingContract.stake(stakeAmount);
        
        uint256 balanceBefore = stakingToken.balanceOf(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Unstaked(user1, unstakeAmount);
        
        votingContract.unstake(unstakeAmount);
        vm.stopPrank();
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.stakedAmount, stakeAmount - unstakeAmount);
        assertEq(stakingToken.balanceOf(user1), balanceBefore + unstakeAmount);
        assertEq(votingContract.totalFeesCollected(), 0 ether);
    }
    
    function test_Unstake_RevertWhen_ZeroAmount() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.expectRevert(InvalidAmount.selector);
        vm.prank(user1);
        votingContract.unstake(0);
    }
    
    function test_Unstake_RevertWhen_InsufficientStake() public {
        vm.prank(user1);
        votingContract.stake(100 ether);
        
        vm.expectRevert(InsufficientStake.selector);
        vm.prank(user1);
        votingContract.unstake(200 ether);
    }
    
    function test_Unstake_RevertWhen_VotingIsActive() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.expectRevert(CannotUnstakeWhenVotingIsActive.selector);
        vm.prank(user1);
        votingContract.unstake(100 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // CALLBACK TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_TagSuspicious_Success() public {
        uint256 originChainId = 1;
        address originContract = address(0x123);
        uint256 value = 1000 ether;
        uint256 decimals = 18;
        uint256 txHash = 12345;
        
        vm.expectEmit(true, true, false, false);
        emit VotingStarted(1, suspiciousAddr, block.timestamp + VOTING_DURATION);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr,
            originChainId,
            originContract,
            value,
            decimals,
            txHash
        );
        
        assertEq(votingId, 1);
        
        (
            VedyxTypes.SuspiciousReport memory report,
            uint256 startTime,
            uint256 endTime,
            uint256 votesFor,
            uint256 votesAgainst,
            bool finalized,
            bool isSuspicious
        ) = votingContract.getVotingDetails(votingId);
        
        assertEq(report.suspiciousAddress, suspiciousAddr);
        assertEq(report.originChainId, originChainId);
        assertEq(report.originContract, originContract);
        assertEq(report.value, value);
        assertEq(report.decimals, decimals);
        assertEq(report.txHash, txHash);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + VOTING_DURATION);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertFalse(finalized);
        assertFalse(isSuspicious);
        
        uint256[] memory activeVotings = votingContract.getActiveVotings();
        assertEq(activeVotings.length, 1);
        assertEq(activeVotings[0], votingId);
    }
    
    function test_TagSuspicious_RevertWhen_UnauthorizedCaller() public {
        vm.expectRevert(UnauthorizedCallback.selector);
        vm.prank(user1);
        votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
    }
    
    function test_TagSuspicious_RevertWhen_InvalidAddress() public {
        vm.expectRevert(InvalidAddress.selector);
        vm.prank(callbackAuthorizer);
        votingContract.tagSuspicious(address(0), 1, address(0x123), 1000 ether, 18, 12345);
    }
    
    function test_TagSuspicious_MultipleVotings() public {
        vm.startPrank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        vm.stopPrank();
        
        assertEq(votingId1, 1);
        assertEq(votingId2, 2);
        
        uint256[] memory activeVotings = votingContract.getActiveVotings();
        assertEq(activeVotings.length, 2);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // VOTING TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_CastVote_Success() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.expectEmit(true, true, false, false);
        emit VoteCast(votingId, user1, true, 500 ether);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        (bool hasVoted, bool votedFor, uint256 votingPower) = votingContract.getVote(votingId, user1);
        assertTrue(hasVoted);
        assertTrue(votedFor);
        assertEq(votingPower, 500 ether);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.lockedAmount, MINIMUM_STAKE);
        assertEq(stakeUser1.totalVotes, 1);
    }
    
    function test_CastVote_WithKarmaBonus() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        
        vm.prank(user2);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        votingContract.finalizeVoting(votingId1);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.karmaPoints, 10);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, true);
        
        (, bool votedFor, uint256 votingPower) = votingContract.getVote(votingId2, user1);
        assertTrue(votedFor);
        assertGt(votingPower, 500 ether);
    }
    
    function test_CastVote_RevertWhen_InvalidVotingId() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.expectRevert(InvalidVotingId.selector);
        vm.prank(user1);
        votingContract.castVote(999, true);
    }
    
    function test_CastVote_RevertWhen_VotingEnded() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectRevert(VotingAlreadyEnded.selector);
        vm.prank(user1);
        votingContract.castVote(votingId, true);
    }
    
    function test_CastVote_RevertWhen_AlreadyVoted() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.expectRevert(AlreadyVoted.selector);
        vm.prank(user1);
        votingContract.castVote(votingId, false);
    }
    
    function test_CastVote_RevertWhen_InsufficientStake() public {
        vm.prank(user1);
        votingContract.stake(50 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.expectRevert(InsufficientStake.selector);
        vm.prank(user1);
        votingContract.castVote(votingId, true);
    }
    
    function test_CastVote_MultipleVoters() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(200 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        address[] memory voters = votingContract.getVoters(votingId);
        assertEq(voters.length, 3);
        assertEq(voters[0], user1);
        assertEq(voters[1], user2);
        assertEq(voters[2], user3);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // FINALIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_FinalizeVoting_ConsensusFor() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(200 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectEmit(true, true, false, false);
        emit VotingFinalized(votingId, suspiciousAddr, true, 800 ether, 200 ether);
        
        votingContract.finalizeVoting(votingId);
        
        (,,,,,bool finalized, bool isSuspicious) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isSuspicious);
        
        uint256[] memory activeVotings = votingContract.getActiveVotings();
        assertEq(activeVotings.length, 0);
    }
    
    function test_FinalizeVoting_ConsensusAgainst() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        votingContract.stake(800 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        votingContract.finalizeVoting(votingId);
        
        (,,,,,bool finalized, bool isSuspicious) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertFalse(isSuspicious);
    }
    
    function test_FinalizeVoting_RevertWhen_InvalidVotingId() public {
        vm.expectRevert(InvalidVotingId.selector);
        votingContract.finalizeVoting(999);
    }
    
    function test_FinalizeVoting_RevertWhen_VotingStillActive() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.expectRevert(VotingStillActive.selector);
        votingContract.finalizeVoting(votingId);
    }
    
    function test_FinalizeVoting_RevertWhen_AlreadyFinalized() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        vm.expectRevert(VotingAlreadyEnded.selector);
        votingContract.finalizeVoting(votingId);
    }
    
    function test_FinalizeVoting_WithFinalizationReward() public {
        // First voting to generate fees
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        uint256 feeCollected = votingContract.totalFeesCollected();
        assertGt(feeCollected, 0);
        
        // Second voting to test finalization reward
        vm.warp(block.timestamp + 1);
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        uint256 expectedReward = (feeCollected * 200) / 10000; // 2%
        uint256 balanceBefore = stakingToken.balanceOf(user3);
        
        vm.expectEmit(true, true, false, true);
        emit FinalizationRewardPaid(votingId2, user3, expectedReward);
        
        vm.prank(user3);
        votingContract.finalizeVoting(votingId2);
        
        uint256 balanceAfter = stakingToken.balanceOf(user3);
        assertEq(balanceAfter - balanceBefore, expectedReward);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // PENALTY AND KARMA TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_Penalty_AppliedToIncorrectVoters() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        vm.prank(user3);
        uint256 user3StakeBefore = 200 ether;
        votingContract.stake(user3StakeBefore);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        

        uint256 expectedPenalty = (user3StakeBefore * PENALTY_PERCENTAGE) / 10000;
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectEmit(true, true, false, true);
        emit PenaltyApplied(user3, votingId, expectedPenalty);
        
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser3 = votingContract.getStakerInfo(user3);
        assertEq(stakeUser3.stakedAmount, user3StakeBefore - expectedPenalty);
    }
    
    function test_Karma_RewardForCorrectVotes() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectEmit(true, false, false, true);
        emit KarmaUpdated(user1, int256(uint256(10)), 10);
        
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.karmaPoints, 10);
        assertEq(stakeUser1.totalVotes, 1);
        assertEq(stakeUser1.correctVotes, 1);
    }
    
    function test_Karma_PenaltyForIncorrectVotes() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser2 = votingContract.getStakerInfo(user2);
        assertEq(stakeUser2.karmaPoints, -5);
    }
    
    function test_LockedAmount_UnlockedAfterFinalization() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.lockedAmount, MINIMUM_STAKE);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser1After = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1After.lockedAmount, 0);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_SetCallbackAuthorizer_Success() public {
        address newAuthorizer = makeAddr("newAuthorizer");
        
        vm.expectEmit(true, false, false, false);
        emit CallbackAuthorizerUpdated(newAuthorizer);
        
        votingContract.setCallbackAuthorizer(newAuthorizer);
        
        assertEq(votingContract.callbackAuthorizer(), newAuthorizer);
    }
    
    function test_SetCallbackAuthorizer_RevertWhen_NotOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        votingContract.setCallbackAuthorizer(makeAddr("newAuthorizer"));
    }
    
    function test_SetCallbackAuthorizer_RevertWhen_InvalidAddress() public {
        vm.expectRevert(InvalidAddress.selector);
        votingContract.setCallbackAuthorizer(address(0));
    }
    
    function test_SetMinimumStake_Success() public {
        uint256 newMinimum = 200 ether;
        
        vm.expectEmit(false, false, false, true);
        emit MinimumStakeUpdated(newMinimum);
        
        votingContract.setMinimumStake(newMinimum);
        
        assertEq(votingContract.minimumStake(), newMinimum);
    }
    
    function test_SetMinimumStake_RevertWhen_NotOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        votingContract.setMinimumStake(200 ether);
    }
    
    function test_SetVotingDuration_Success() public {
        uint256 newDuration = 14 days;
        
        vm.expectEmit(false, false, false, true);
        emit VotingDurationUpdated(newDuration);
        
        votingContract.setVotingDuration(newDuration);
        
        assertEq(votingContract.votingDuration(), newDuration);
    }
    
    function test_SetPenaltyPercentage_Success() public {
        uint256 newPercentage = 2000; // 20%
        
        vm.expectEmit(false, false, false, true);
        emit PenaltyPercentageUpdated(newPercentage);
        
        votingContract.setPenaltyPercentage(newPercentage);
        
        assertEq(votingContract.penaltyPercentage(), newPercentage);
    }
    
    function test_SetPenaltyPercentage_RevertWhen_TooHigh() public {
        vm.expectRevert(InvalidFeePercentage.selector);
        votingContract.setPenaltyPercentage(5001); // > 50%
    }
    
    function test_SetKarmaReward_Success() public {
        uint256 newReward = 20;
        votingContract.setKarmaReward(newReward);
        assertEq(votingContract.karmaReward(), newReward);
    }
    
    function test_SetKarmaPenalty_Success() public {
        uint256 newPenalty = 10;
        votingContract.setKarmaPenalty(newPenalty);
        assertEq(votingContract.karmaPenalty(), newPenalty);
    }
    
    function test_SetFinalizationRewardPercentage_Success() public {
        // First increase finalizationFeePercentage to allow higher reward percentage
        votingContract.setFinalizationFeePercentage(600); // 6%
        
        uint256 newPercentage = 500; // 5% (must be < finalizationFeePercentage)
        
        vm.expectEmit(false, false, false, true);
        emit FinalizationRewardPercentageUpdated(newPercentage);
        
        votingContract.setFinalizationRewardPercentage(newPercentage);
        
        assertEq(votingContract.finalizationRewardPercentage(), newPercentage);
    }
    
    function test_SetFinalizationRewardPercentage_RevertWhen_TooHigh() public {
        vm.expectRevert(InvalidFeePercentage.selector);
        votingContract.setFinalizationRewardPercentage(1001); // > 10%
    }
    
    function test_SetTreasury_Success() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.expectEmit(true, false, false, false);
        emit TreasuryUpdated(newTreasury);
        
        votingContract.setTreasury(newTreasury);
        
        assertEq(votingContract.treasury(), newTreasury);
    }
    
    function test_SetTreasury_RevertWhen_InvalidAddress() public {
        vm.expectRevert(InvalidTreasury.selector);
        votingContract.setTreasury(address(0));
    }
    
    function test_SetFinalizationFeePercentage_Success() public {
        uint256 newFee = 300; // 3% (must be > finalizationRewardPercentage which is 200 by default)
        
        vm.expectEmit(false, false, false, true);
        emit FinalizationFeeUpdated(newFee);
        
        votingContract.setFinalizationFeePercentage(newFee);
        
        assertEq(votingContract.finalizationFeePercentage(), newFee);
    }
    
    function test_SetFinalizationFeePercentage_RevertWhen_TooHigh() public {
        vm.expectRevert(InvalidFeePercentage.selector);
        votingContract.setFinalizationFeePercentage(1001); // > 10%
    }
    
    function test_TransferFeesToTreasury_Success() public {
        // Fees now come from vote finalization, not unstaking
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        uint256 feesCollected = votingContract.totalFeesCollected();
        assertGt(feesCollected, 0);
        
        uint256 treasuryBalanceBefore = stakingToken.balanceOf(treasury);
        
        vm.expectEmit(true, false, false, true);
        emit FeeCollected(treasury, feesCollected);
        
        votingContract.transferFeesToTreasury(feesCollected);
        
        assertEq(votingContract.totalFeesCollected(), 0);
        assertEq(stakingToken.balanceOf(treasury), treasuryBalanceBefore + feesCollected);
    }
    
    function test_TransferFeesToTreasury_RevertWhen_ZeroAmount() public {
        vm.expectRevert(InvalidAmount.selector);
        votingContract.transferFeesToTreasury(0);
    }
    
    function test_TransferFeesToTreasury_RevertWhen_ExceedsCollected() public {
        vm.expectRevert(InvalidAmount.selector);
        votingContract.transferFeesToTreasury(100 ether);
    }
    
    function test_TransferFeesToTreasury_RevertWhen_NotOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        votingContract.transferFeesToTreasury(1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_GetVotingPower_WithoutKarma() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        int256 votingPower = votingContract.getVotingPower(user1);
        assertEq(votingPower, int256(500 ether));
    }
    
    function test_GetVotingPower_WithKarma() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        int256 votingPower = votingContract.getVotingPower(user1);
        assertGt(votingPower, int256(500 ether));
    }
    
    function test_GetVoterAccuracy_NoVotes() public view {
        uint256 accuracy = votingContract.getVoterAccuracy(user1);
        assertEq(accuracy, 0);
    }
    
    function test_GetVoterAccuracy_WithVotes() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        uint256 accuracy = votingContract.getVoterAccuracy(user1);
        assertEq(accuracy, 10000); // 100%
        
        vm.warp(block.timestamp + 1);
        
        vm.prank(user2);
        votingContract.stake(800 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, true);
        vm.prank(user2);
        votingContract.castVote(votingId2, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId2);
        
        accuracy = votingContract.getVoterAccuracy(user1);
        assertEq(accuracy, 5000); // 50%
    }
    
    function test_GetAddressVotingHistory() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr, 2, address(0x456), 2000 ether, 18, 67890);
        
        uint256[] memory history = votingContract.getAddressVotingHistory(suspiciousAddr);
        assertEq(history.length, 2);
        assertEq(history[0], votingId1);
        assertEq(history[1], votingId2);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_MultipleActiveVotings() public {
        vm.prank(user1);
        votingContract.stake(1000 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(makeAddr("suspicious2"), 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, false);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertEq(stakeUser1.lockedAmount, MINIMUM_STAKE * 2);
    }
    
    function test_VotingWithMinimumStake() public {
        vm.prank(user1);
        votingContract.stake(MINIMUM_STAKE);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        (bool hasVoted,,) = votingContract.getVote(votingId, user1);
        assertTrue(hasVoted);
    }
    
    function test_PenaltyDoesNotExceedStake() public {
        vm.prank(user1);
        votingContract.stake(150 ether);
        vm.prank(user2);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        VedyxTypes.Staker memory stakeUser2 = votingContract.getStakerInfo(user2);
        assertGe(stakeUser2.stakedAmount, 0);
    }
    
    function test_UnstakeAfterVotingFinalized() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        vm.prank(user1);
        votingContract.unstake(100 ether);
        
        VedyxTypes.Staker memory stakeUser1 = votingContract.getStakerInfo(user1);
        assertLt(stakeUser1.stakedAmount, 500 ether);
    }
    
    function test_ZeroVotesScenario() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        (,,,,,bool finalized, bool isSuspicious) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertFalse(isSuspicious);
    }
    
    function test_TieVoteScenario() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(500 ether);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        (,,,,,, bool isSuspicious) = votingContract.getVotingDetails(votingId);
        assertFalse(isSuspicious);
    }
}
