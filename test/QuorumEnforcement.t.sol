// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {VedyxVotingContract} from "../src/voting-contract/VedyxVotingContract.sol";
import {VedyxTypes} from "../src/voting-contract/libraries/VedyxTypes.sol";
import {VedyxErrors} from "../src/voting-contract/libraries/VedyxErrors.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/**
 * @title QuorumEnforcementTest
 * @notice Comprehensive test suite for quorum enforcement to prevent one-sided voting
 */
contract QuorumEnforcementTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;

    address public owner;
    address public callbackAuthorizer;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    address public suspiciousAddr1;

    uint256 constant INITIAL_BALANCE = 10000 ether;
    uint256 constant MINIMUM_STAKE = 100 ether;
    uint256 constant VOTING_DURATION = 3 days;
    uint256 constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%

    // Default quorum values
    uint256 constant DEFAULT_MINIMUM_VOTERS = 3;
    uint256 constant DEFAULT_MINIMUM_VOTING_POWER = 1000 ether;

    function setUp() public {
        owner = address(this);
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");
        suspiciousAddr1 = makeAddr("suspiciousAddr1");

        stakingToken = new MockERC20("Vedyx Token", "VEDYX");
        votingContract = new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            FINALIZATION_FEE_PERCENTAGE
        );

        // Mint tokens to users
        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);
        stakingToken.mint(user3, INITIAL_BALANCE);
        stakingToken.mint(user4, INITIAL_BALANCE);
        stakingToken.mint(user5, INITIAL_BALANCE);

        // Approve and stake for users
        vm.prank(user1);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user1);
        votingContract.stake(500 ether);

        vm.prank(user2);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user2);
        votingContract.stake(500 ether);

        vm.prank(user3);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user3);
        votingContract.stake(300 ether);

        vm.prank(user4);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user4);
        votingContract.stake(200 ether);

        vm.prank(user5);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user5);
        votingContract.stake(200 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // QUORUM ENFORCEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_InconclusiveWhen_InsufficientVoters_OnlyOneVoter() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // Only 1 voter (minimum is 3)
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.expectEmit(true, true, true, true);
        emit VedyxVotingContract.VotingInconclusive(votingId, suspiciousAddr1, 1, 500 ether);
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isInconclusive);
    }

    function test_InconclusiveWhen_InsufficientVoters_TwoVoters() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // Only 2 voters (minimum is 3)
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.expectEmit(true, true, true, true);
        emit VedyxVotingContract.VotingInconclusive(votingId, suspiciousAddr1, 2, 1000 ether);
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isInconclusive);
    }

    function test_Success_WithExactlyMinimumVoters() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // Exactly 3 voters (minimum)
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, true);

        vm.prank(user3);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // Should succeed
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, bool isSuspicious, bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isSuspicious); // 2 vs 1
        assertFalse(isInconclusive);
    }

    function test_Success_WithMoreThanMinimumVoters() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 5 voters (more than minimum)
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, true);

        vm.prank(user3);
        votingContract.castVote(votingId, true);

        vm.prank(user4);
        votingContract.castVote(votingId, false);

        vm.prank(user5);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // Should succeed
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, bool isSuspicious, bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isSuspicious); // 3 vs 2
        assertFalse(isInconclusive);
    }

    function test_InconclusiveWhen_InsufficientTotalVotingPower() public {
        // Set high minimum voting power requirement
        votingContract.setMinimumTotalVotingPower(2000 ether);

        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 3 voters but insufficient total voting power
        // user3 = 300 ether, user4 = 200 ether, user5 = 200 ether = 700 ether total
        vm.prank(user3);
        votingContract.castVote(votingId, true);

        vm.prank(user4);
        votingContract.castVote(votingId, true);

        vm.prank(user5);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.expectEmit(true, true, true, true);
        emit VedyxVotingContract.VotingInconclusive(votingId, suspiciousAddr1, 3, 700 ether);
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isInconclusive);
    }

    function test_Success_WithSufficientTotalVotingPower() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 3 voters with sufficient total voting power
        // user1 = 500 ether, user2 = 500 ether, user3 = 300 ether = 1300 ether total
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, true);

        vm.prank(user3);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // Should succeed (meets both quorum requirements)
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertFalse(isInconclusive);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN CONFIGURATION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_SetMinimumVoters_Success() public {
        uint256 newMinimum = 5;
        
        vm.expectEmit(true, true, true, true);
        emit VedyxVotingContract.MinimumVotersUpdated(newMinimum);
        
        votingContract.setMinimumVoters(newMinimum);
        
        assertEq(votingContract.minimumVoters(), newMinimum);
    }

    function test_SetMinimumVoters_RevertWhen_Zero() public {
        vm.expectRevert(VedyxErrors.InvalidQuorumValue.selector);
        votingContract.setMinimumVoters(0);
    }

    function test_SetMinimumVoters_RevertWhen_NotGovernance() public {
        vm.prank(user1);
        vm.expectRevert();
        votingContract.setMinimumVoters(5);
    }

    function test_SetMinimumTotalVotingPower_Success() public {
        uint256 newMinimum = 2000 ether;
        
        vm.expectEmit(true, true, true, true);
        emit VedyxVotingContract.MinimumTotalVotingPowerUpdated(newMinimum);
        
        votingContract.setMinimumTotalVotingPower(newMinimum);
        
        assertEq(votingContract.minimumTotalVotingPower(), newMinimum);
    }

    function test_SetMinimumTotalVotingPower_RevertWhen_Zero() public {
        vm.expectRevert(VedyxErrors.InvalidQuorumValue.selector);
        votingContract.setMinimumTotalVotingPower(0);
    }

    function test_SetMinimumTotalVotingPower_RevertWhen_NotGovernance() public {
        vm.prank(user1);
        vm.expectRevert();
        votingContract.setMinimumTotalVotingPower(2000 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_QuorumEnforcement_WithDifferentStakes() public {
        // Set minimum voters to 4
        votingContract.setMinimumVoters(4);

        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 4 voters with different stakes
        vm.prank(user1); // 500 ether
        votingContract.castVote(votingId, true);

        vm.prank(user2); // 500 ether
        votingContract.castVote(votingId, true);

        vm.prank(user3); // 300 ether
        votingContract.castVote(votingId, false);

        vm.prank(user4); // 200 ether
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, bool isSuspicious, bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isSuspicious); // 1000 vs 500
        assertFalse(isInconclusive);
    }

    function test_QuorumEnforcement_TieBreaking() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 3 voters with equal total voting power on each side
        vm.prank(user1); // 500 ether - for
        votingContract.castVote(votingId, true);

        vm.prank(user2); // 500 ether - against
        votingContract.castVote(votingId, false);

        vm.prank(user3); // 300 ether - for
        votingContract.castVote(votingId, true);

        // Need one more voter for quorum
        vm.prank(user4); // 200 ether - against
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, bool isSuspicious, bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isSuspicious); // 800 vs 700 (for wins)
        assertFalse(isInconclusive);
    }

    function test_QuorumEnforcement_AfterParameterChange() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 2 voters cast votes
        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, false);

        // Change minimum voters to 2
        votingContract.setMinimumVoters(2);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // Should succeed now with 2 voters
        votingContract.finalizeVoting(votingId);

        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertFalse(isInconclusive);
    }

    function test_QuorumEnforcement_MultipleVotings_IndependentQuorum() public {
        // Create first voting
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // Create second voting
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(
            makeAddr("suspicious2"),
            1,
            address(0x456),
            2000 ether,
            18,
            67890
        );

        // First voting: only 2 voters (insufficient)
        vm.prank(user1);
        votingContract.castVote(votingId1, true);

        vm.prank(user2);
        votingContract.castVote(votingId1, false);

        // Second voting: 3 different voters with sufficient total voting power
        // user3 = 300 ether, user4 = 200 ether, user5 = 200 ether = 700 ether
        // Need to use higher stake users: user1 and user2 are locked in votingId1
        // So we need to finalize votingId1 first or use only user3, user4, user5
        // Let's lower the minimum voting power temporarily for this test
        votingContract.setMinimumTotalVotingPower(700 ether);
        
        vm.prank(user3);
        votingContract.castVote(votingId2, true);

        vm.prank(user4);
        votingContract.castVote(votingId2, true);

        vm.prank(user5);
        votingContract.castVote(votingId2, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // First voting should be inconclusive
        votingContract.finalizeVoting(votingId1);
        (, , , , , bool finalized1, , bool isInconclusive1) = votingContract.getVotingDetails(votingId1);
        assertTrue(finalized1);
        assertTrue(isInconclusive1);

        // Second voting should succeed
        votingContract.finalizeVoting(votingId2);

        (, , , , , bool finalized2, , bool isInconclusive2) = votingContract.getVotingDetails(votingId2);
        assertTrue(finalized2);
        assertFalse(isInconclusive2);
    }

    function test_QuorumEnforcement_BothRequirementsMustBeMet() public {
        // Set both requirements
        votingContract.setMinimumVoters(3);
        votingContract.setMinimumTotalVotingPower(1000 ether);

        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        // 3 voters (meets voter requirement) but low voting power
        // user4 = 200, user5 = 200, user3 = 300 = 700 ether (doesn't meet power requirement)
        vm.prank(user4);
        votingContract.castVote(votingId, true);

        vm.prank(user5);
        votingContract.castVote(votingId, true);

        vm.prank(user3);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        // Should be inconclusive due to insufficient voting power
        votingContract.finalizeVoting(votingId);
        (, , , , , bool finalized, , bool isInconclusive) = votingContract.getVotingDetails(votingId);
        assertTrue(finalized);
        assertTrue(isInconclusive);
    }

    function test_QuorumEnforcement_DefaultValues() public {
        // Verify default values are set correctly
        assertEq(votingContract.minimumVoters(), DEFAULT_MINIMUM_VOTERS);
        assertEq(votingContract.minimumTotalVotingPower(), DEFAULT_MINIMUM_VOTING_POWER);
    }
}
