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
error CannotVoteOnOwnAddress();
error NoVerdictToClear();

/**
 * @title VerdictSystemTest
 * @notice Comprehensive test suite for the verdict-based auto-classification system
 */
contract VerdictSystemTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;
    
    address public owner;
    address public callbackAuthorizer;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    address public suspiciousAddr1;
    address public suspiciousAddr2;
    
    uint256 public constant MINIMUM_STAKE = 100 ether;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    event VotingStarted(uint256 indexed votingId, address indexed suspiciousAddress, uint256 endTime);
    event AddressAutoMarkedSuspicious(
        address indexed suspiciousAddress,
        uint256 indexed incidentNumber,
        uint256 previousVotingId,
        uint256 txHash
    );
    event VerdictRecorded(
        address indexed suspiciousAddress,
        uint256 indexed votingId,
        bool isSuspicious,
        uint256 timestamp
    );
    event VerdictCleared(address indexed suspiciousAddress, address indexed clearedBy);
    event VotingFinalized(
        uint256 indexed votingId,
        address indexed suspiciousAddress,
        bool isSuspicious,
        uint256 votesFor,
        uint256 votesAgainst
    );
    
    function setUp() public {
        owner = address(this);
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        suspiciousAddr1 = makeAddr("suspicious1");
        suspiciousAddr2 = makeAddr("suspicious2");
        
        stakingToken = new MockERC20("Staking Token", "STK");
        
        votingContract = new VedyxVotingContract(
            address(stakingToken),
            callbackAuthorizer,
            MINIMUM_STAKE,
            VOTING_DURATION,
            PENALTY_PERCENTAGE,
            treasury,
            FINALIZATION_FEE_PERCENTAGE
        );
        
        // Setup stakers
        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);
        stakingToken.mint(user3, INITIAL_BALANCE);
        
        vm.prank(user1);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user1);
        votingContract.stake(500 ether);
        
        vm.prank(user2);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user2);
        votingContract.stake(300 ether);
        
        vm.prank(user3);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(user3);
        votingContract.stake(200 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // FIRST OFFENSE TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_FirstOffense_CreatesVoting() public {
        vm.expectEmit(true, true, false, true);
        emit VotingStarted(1, suspiciousAddr1, block.timestamp + VOTING_DURATION);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );
        
        assertEq(votingId, 1);
        
        (bool hasVerdict, , , , uint256 totalIncidents) = votingContract.getAddressVerdict(suspiciousAddr1);
        assertFalse(hasVerdict); // No verdict yet
        assertEq(totalIncidents, 1); // First incident
    }
    
    function test_FirstOffense_VotedSuspicious_RecordsVerdict() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );
        
        // Vote suspicious
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        vm.prank(user3);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectEmit(true, true, false, true);
        emit VerdictRecorded(suspiciousAddr1, votingId, true, block.timestamp);
        
        votingContract.finalizeVoting(votingId);
        
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, , uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertTrue(hasVerdict);
        assertTrue(isSuspicious);
        assertEq(lastVotingId, votingId);
        assertEq(totalIncidents, 1);
    }
    
    function test_FirstOffense_VotedClean_RecordsVerdict() public {
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            suspiciousAddr1,
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );
        
        // Vote clean
        vm.prank(user1);
        votingContract.castVote(votingId, false);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        vm.prank(user3);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        vm.expectEmit(true, true, false, true);
        emit VerdictRecorded(suspiciousAddr1, votingId, false, block.timestamp);
        
        votingContract.finalizeVoting(votingId);
        
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, , uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertTrue(hasVerdict);
        assertFalse(isSuspicious); // Clean
        assertEq(lastVotingId, votingId);
        assertEq(totalIncidents, 1);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // REPEAT OFFENDER TESTS (AUTO-MARKING)
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_RepeatOffender_AutoMarked() public {
        // First offense - voted suspicious
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Second offense - should be auto-marked
        vm.expectEmit(true, true, false, true);
        emit AddressAutoMarkedSuspicious(suspiciousAddr1, 2, votingId1, 67890);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x456), 2000 ether, 18, 67890);
        
        assertEq(votingId2, 0); // No voting created
        
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, , uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertTrue(hasVerdict);
        assertTrue(isSuspicious);
        assertEq(lastVotingId, votingId1); // Still references first voting
        assertEq(totalIncidents, 2); // Incremented
    }
    
    function test_RepeatOffender_MultipleAutoMarks() public {
        // First offense
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Multiple repeat offenses
        for (uint256 i = 2; i <= 5; i++) {
            vm.prank(callbackAuthorizer);
            uint256 votingId = votingContract.tagSuspicious(
                suspiciousAddr1,
                1,
                address(0x456),
                1000 ether,
                18,
                uint256(keccak256(abi.encodePacked(i)))
            );
            
            assertEq(votingId, 0); // All auto-marked
            
            (, , , , uint256 totalIncidents) = votingContract.getAddressVerdict(suspiciousAddr1);
            assertEq(totalIncidents, i);
        }
    }
    
    function test_RepeatOffender_HistoryTracking() public {
        // First offense
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Second offense (auto-marked)
        vm.prank(callbackAuthorizer);
        votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x456), 2000 ether, 18, 67890);
        
        // Check history
        uint256[] memory history = votingContract.getAddressVotingHistory(suspiciousAddr1);
        assertEq(history.length, 2);
        assertEq(history[0], votingId1); // First voting
        assertEq(history[1], 0); // Auto-marked (0 indicates no voting)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // CLEAN ADDRESS RE-EVALUATION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_CleanAddress_AllowsReEvaluation() public {
        // First offense - voted clean
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, false);
        vm.prank(user2);
        votingContract.castVote(votingId1, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Second offense - should create new voting (new evidence)
        vm.expectEmit(true, true, false, true);
        emit VotingStarted(2, suspiciousAddr1, block.timestamp + VOTING_DURATION);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x456), 2000 ether, 18, 67890);
        
        assertEq(votingId2, 2); // New voting created
        
        (, , , , uint256 totalIncidents) = votingContract.getAddressVerdict(suspiciousAddr1);
        assertEq(totalIncidents, 2);
    }
    
    function test_CleanAddress_CanBecomeSuspicious() public {
        // First offense - voted clean
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, false);
        vm.prank(user2);
        votingContract.castVote(votingId1, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Second offense - voted suspicious this time
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, true);
        vm.prank(user2);
        votingContract.castVote(votingId2, true);
        
        vm.warp(block.timestamp + VOTING_DURATION * 2 + 1);
        votingContract.finalizeVoting(votingId2);
        
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, , uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertTrue(hasVerdict);
        assertTrue(isSuspicious); // Now suspicious
        assertEq(lastVotingId, votingId2);
        assertEq(totalIncidents, 2);
        
        // Third offense - should now be auto-marked
        vm.prank(callbackAuthorizer);
        uint256 votingId3 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x789), 3000 ether, 18, 99999);
        
        assertEq(votingId3, 0); // Auto-marked
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // GOVERNANCE OVERRIDE TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_ClearVerdict_Success() public {
        // Create and finalize suspicious verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        // Clear verdict
        vm.expectEmit(true, true, false, false);
        emit VerdictCleared(suspiciousAddr1, owner);
        
        votingContract.clearAddressVerdict(suspiciousAddr1);
        
        (bool hasVerdict, bool isSuspicious, , , uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertFalse(hasVerdict); // Cleared
        assertFalse(isSuspicious);
        assertEq(totalIncidents, 1); // Incident count preserved for audit
    }
    
    function test_ClearVerdict_AllowsFreshEvaluation() public {
        // Create suspicious verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Clear verdict
        votingContract.clearAddressVerdict(suspiciousAddr1);
        
        // Tag again - should create new voting (not auto-mark)
        vm.expectEmit(true, true, false, true);
        emit VotingStarted(2, suspiciousAddr1, block.timestamp + VOTING_DURATION);
        
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x456), 2000 ether, 18, 67890);
        
        assertEq(votingId2, 2); // New voting created
    }
    
    function test_ClearVerdict_RevertWhen_NoVerdict() public {
        vm.expectRevert(NoVerdictToClear.selector);
        votingContract.clearAddressVerdict(suspiciousAddr1);
    }
    
    function test_ClearVerdict_RevertWhen_NotGovernance() public {
        // Create verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        // Try to clear without governance role
        vm.prank(user1);
        vm.expectRevert();
        votingContract.clearAddressVerdict(suspiciousAddr1);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SELF-VOTING PREVENTION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_SelfVoting_Prevented() public {
        // Stake for suspicious address
        stakingToken.mint(suspiciousAddr1, INITIAL_BALANCE);
        vm.prank(suspiciousAddr1);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(suspiciousAddr1);
        votingContract.stake(500 ether);
        
        // Tag suspicious address
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        // Try to vote on own address
        vm.prank(suspiciousAddr1);
        vm.expectRevert(CannotVoteOnOwnAddress.selector);
        votingContract.castVote(votingId, false);
    }
    
    function test_SelfVoting_OthersCanStillVote() public {
        // Stake for suspicious address
        stakingToken.mint(suspiciousAddr1, INITIAL_BALANCE);
        vm.prank(suspiciousAddr1);
        stakingToken.approve(address(votingContract), INITIAL_BALANCE);
        vm.prank(suspiciousAddr1);
        votingContract.stake(500 ether);
        
        // Tag suspicious address
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        // Others can vote
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        // Verify votes were recorded
        (,,, uint256 votesFor, uint256 votesAgainst,,) = votingContract.getVotingDetails(votingId);
        assertGt(votesFor, 0);
        assertGt(votesAgainst, 0);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_WillAutoMark_ReturnsTrueForSuspicious() public {
        // Create suspicious verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        assertTrue(votingContract.willAutoMark(suspiciousAddr1));
    }
    
    function test_WillAutoMark_ReturnsFalseForClean() public {
        // Create clean verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, false);
        vm.prank(user2);
        votingContract.castVote(votingId, false);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
        
        assertFalse(votingContract.willAutoMark(suspiciousAddr1));
    }
    
    function test_WillAutoMark_ReturnsFalseForNoVerdict() public {
        assertFalse(votingContract.willAutoMark(suspiciousAddr1));
    }
    
    function test_GetAddressVerdict_ReturnsCorrectData() public {
        // Create verdict
        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, true);
        
        uint256 finalizeTime = block.timestamp + VOTING_DURATION + 1;
        vm.warp(finalizeTime);
        votingContract.finalizeVoting(votingId);
        
        (bool hasVerdict, bool isSuspicious, uint256 lastVotingId, uint256 verdictTimestamp, uint256 totalIncidents) = 
            votingContract.getAddressVerdict(suspiciousAddr1);
        
        assertTrue(hasVerdict);
        assertTrue(isSuspicious);
        assertEq(lastVotingId, votingId);
        assertEq(verdictTimestamp, finalizeTime);
        assertEq(totalIncidents, 1);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    function test_MultipleAddresses_IndependentVerdicts() public {
        // Address 1 - suspicious
        vm.prank(callbackAuthorizer);
        uint256 votingId1 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x123), 1000 ether, 18, 12345);
        
        vm.prank(user1);
        votingContract.castVote(votingId1, true);
        vm.prank(user2);
        votingContract.castVote(votingId1, true);
        
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId1);
        
        // Address 2 - clean
        vm.prank(callbackAuthorizer);
        uint256 votingId2 = votingContract.tagSuspicious(suspiciousAddr2, 1, address(0x456), 2000 ether, 18, 67890);
        
        vm.prank(user1);
        votingContract.castVote(votingId2, false);
        vm.prank(user2);
        votingContract.castVote(votingId2, false);
        
        vm.warp(block.timestamp + VOTING_DURATION * 2 + 1);
        votingContract.finalizeVoting(votingId2);
        
        // Verify independent verdicts
        (, bool isSuspicious1, , ,) = votingContract.getAddressVerdict(suspiciousAddr1);
        (, bool isSuspicious2, , ,) = votingContract.getAddressVerdict(suspiciousAddr2);
        
        assertTrue(isSuspicious1);
        assertFalse(isSuspicious2);
        
        // Address 1 should auto-mark, Address 2 should create new voting
        vm.prank(callbackAuthorizer);
        uint256 votingId3 = votingContract.tagSuspicious(suspiciousAddr1, 1, address(0x789), 3000 ether, 18, 11111);
        assertEq(votingId3, 0); // Auto-marked
        
        vm.prank(callbackAuthorizer);
        uint256 votingId4 = votingContract.tagSuspicious(suspiciousAddr2, 1, address(0xabc), 4000 ether, 18, 22222);
        assertGt(votingId4, 0); // New voting
    }
}
