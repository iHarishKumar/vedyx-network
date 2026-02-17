// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {VedyxVotingContract} from "../src/VedyxVotingContract.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

error InvalidAmount();
error InsufficientStake();
error VotingAlreadyEnded();
error InvalidVotingId();
error UnauthorizedCallback();
error InvalidAddress();
error InvalidFeePercentage();
error InvalidTreasury();
error InsufficientVotingPower();
error InsufficientKarma();

contract NegativeKarmaTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;

    address public owner;
    address public callbackAuthorizer;
    address public treasury;
    address public user1;
    address public user2;
    address public suspiciousAddr;

    uint256 public constant MINIMUM_STAKE = 100 ether;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant UNSTAKING_FEE_PERCENTAGE = 100; // 1%
    uint256 public constant INITIAL_BALANCE = 10000 ether;

    function setUp() public {
        owner = address(this);
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        suspiciousAddr = makeAddr("suspiciousAddr");

        stakingToken = new MockERC20("Vedyx Token", "VDX");

        votingContract = new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            UNSTAKING_FEE_PERCENTAGE
        );

        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);

        vm.prank(user1);
        stakingToken.approve(address(votingContract), type(uint256).max);
        vm.prank(user2);
        stakingToken.approve(address(votingContract), type(uint256).max);
    }

    function test_NegativeKarma_ReducesVotingPower() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(800 ether);

        // First vote - user1 votes incorrectly
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(
            suspiciousAddr,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        vm.prank(user1);
        votingContract.castVote(votingId1, false);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);

        // user1 should have negative karma now
        VedyxVotingContract.Staker memory staker = votingContract.getStakerInfo(
            user1
        );
        assertEq(staker.karmaPoints, -5); // Lost 5 karma

        console2.log("Staker information: ----");
        console2.log("Staked Amount:", staker.stakedAmount);
        console2.log("Karma Points:", staker.karmaPoints);
        console2.log("Total Votes:", staker.totalVotes);
        console2.log("Correct Votes:", staker.correctVotes);
        console2.log("Locked Amount:", staker.lockedAmount);

        // Voting power should be reduced with exponential penalty
        // Formula: penalty = stake * (karma^2) / 100000
        // With -5 karma: penalty = 450 * (5^2) / 100000 = 450 * 25 / 100000 = 0.1125 ether
        int256 votingPower = votingContract.getVotingPower(user1);
        
        uint256 expectedPenalty = (staker.stakedAmount * 25) / 100000; // 5^2 = 25
        int256 expectedPower = int256(staker.stakedAmount) - int256(expectedPenalty);
        
        assertEq(votingPower, expectedPower);
        assertLt(votingPower, int256(staker.stakedAmount)); // Less than stake
        assertGt(votingPower, 0); // Still positive with small negative karma
        
        console2.log("Voting Power:", votingPower);
        console2.log("Expected Power:", expectedPower);
    }

    function test_NegativeKarma_MultipleIncorrectVotes() public {
        vm.prank(user1);
        votingContract.stake(500 ether); // Increased stake to handle penalties
        vm.prank(user2);
        votingContract.stake(800 ether);

        // Vote incorrectly multiple times to accumulate negative karma
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(callbackAuthorizer);
            uint256 votingId = votingContract.tagSuspicious(
                makeAddr(string(abi.encodePacked("suspicious", i))),
                1,
                address(0x123),
                1000 ether,
                18,
                12345 + i
            );

            vm.prank(user1);
            votingContract.castVote(votingId, false);
            vm.prank(user2);
            votingContract.castVote(votingId, true);

            vm.warp(block.timestamp + VOTING_DURATION + 1);
            votingContract.finalizeVoting(votingId);
            vm.warp(block.timestamp + 1);
        }

        // user1 should have very negative karma
        // Get actual stake after penalties (500 - 10% * 5 = 500 - 250 = 250 ether)
        VedyxVotingContract.Staker memory staker = votingContract.getStakerInfo(user1);
        assertEq(staker.karmaPoints, -25); // Lost 5 karma per vote * 5 votes

        // Voting power should be reduced significantly with exponential penalty
        // Formula: penalty = stake * (karma^2) / 100000
        // With -25 karma: penalty = stake * (25^2) / 100000 = stake * 625 / 100000
        int256 votingPower = votingContract.getVotingPower(user1);
        
        uint256 expectedPenalty = (staker.stakedAmount * 625) / 100000; // 25^2 = 625
        int256 expectedPower = int256(staker.stakedAmount) - int256(expectedPenalty);
        
        assertEq(votingPower, expectedPower);
        assertLt(votingPower, int256(staker.stakedAmount)); // Reduced from stake
        assertGt(votingPower, 0); // Still positive with -25 karma (not severe enough yet)
    }

    function test_NegativeKarma_CanRecoverWithCorrectVotes() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(800 ether);

        // Vote incorrectly twice
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(callbackAuthorizer);
            uint256 loopVotingId = votingContract.tagSuspicious(
                makeAddr(string(abi.encodePacked("suspicious", i))),
                1,
                address(0x123),
                1000 ether,
                18,
                12345 + i
            );

            vm.prank(user1);
            votingContract.castVote(loopVotingId, false);
            vm.prank(user2);
            votingContract.castVote(loopVotingId, true);

            vm.warp(block.timestamp + VOTING_DURATION + 1);
            votingContract.finalizeVoting(loopVotingId);
            vm.warp(block.timestamp + 1);
        }

        VedyxVotingContract.Staker memory staker = votingContract.getStakerInfo(user1);
        assertEq(staker.karmaPoints, -10);

        // Vote correctly once
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr,
            1,
            address(0x123),
            1000 ether,
            18,
            99999
        );

        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);

        // Karma should improve
        VedyxVotingContract.Staker memory stakeAfter = votingContract.getStakerInfo(user1);
        assertEq(stakeAfter.karmaPoints, 0); // -10 + 10 = 0
    }

    function test_NegativeKarma_BlockedAtThreshold() public {
        vm.prank(user1);
        votingContract.stake(500 ether);
        vm.prank(user2);
        votingContract.stake(800 ether);

        // Vote incorrectly 11 times to reach karma threshold of -55 (11 * -5 = -55)
        for (uint256 i = 0; i < 11; i++) {
            vm.prank(callbackAuthorizer);
            uint256 loopVotingId = votingContract.tagSuspicious(
                makeAddr(string(abi.encodePacked("suspicious", i))),
                1,
                address(0x123),
                1000 ether,
                18,
                12345 + i
            );

            vm.prank(user1);
            votingContract.castVote(loopVotingId, false);
            vm.prank(user2);
            votingContract.castVote(loopVotingId, true);

            vm.warp(block.timestamp + VOTING_DURATION + 1);
            votingContract.finalizeVoting(loopVotingId);
            vm.warp(block.timestamp + 1);
        }

        // user1 should have karma below threshold
        VedyxVotingContract.Staker memory staker = votingContract.getStakerInfo(user1);
        assertEq(staker.karmaPoints, -55); // 11 * -5
        assertLt(staker.karmaPoints, -50); // Below MINIMUM_KARMA_TO_VOTE

        // Try to vote - should revert with InsufficientKarma
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr,
            1,
            address(0x123),
            1000 ether,
            18,
            99999
        );

        vm.expectRevert(InsufficientKarma.selector);
        vm.prank(user1);
        votingContract.castVote(votingId, true);
    }
}
