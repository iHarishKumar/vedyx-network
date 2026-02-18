// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/voting-contract/VedyxVotingContract.sol";
import {VedyxTypes} from "../src/voting-contract/libraries/VedyxTypes.sol";
import "./mocks/MockERC20.sol";

/**
 * @title AccessControlTest
 * @notice Comprehensive test suite for role-based access control in VedyxVotingContract
 * @dev Tests all three roles: GOVERNANCE_ROLE, PARAMETER_ADMIN_ROLE, TREASURY_ROLE
 */
contract AccessControlTest is Test {
    VedyxVotingContract public votingContract;
    MockERC20 public stakingToken;

    address public owner;
    address public governanceAddress;
    address public parameterAdmin;
    address public treasuryManager;
    address public unauthorizedUser;
    address public callbackAuthorizer;
    address public treasury;

    uint256 constant MINIMUM_STAKE = 100 ether;
    uint256 constant VOTING_DURATION = 7 days;
    uint256 constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%

    // Role constants
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PARAMETER_ADMIN_ROLE =
        keccak256("PARAMETER_ADMIN_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // Events
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event CallbackAuthorizerUpdated(address newAuthorizer);
    event MinimumStakeUpdated(uint256 newMinimum);
    event VotingDurationUpdated(uint256 newDuration);
    event PenaltyPercentageUpdated(uint256 newPercentage);
    event TreasuryUpdated(address newTreasury);
    event FinalizationFeeUpdated(uint256 newFeePercentage);
    event FinalizationRewardPercentageUpdated(uint256 newPercentage);

    function setUp() public {
        owner = address(this);
        governanceAddress = makeAddr("governance");
        parameterAdmin = makeAddr("parameterAdmin");
        treasuryManager = makeAddr("treasuryManager");
        unauthorizedUser = makeAddr("unauthorized");
        callbackAuthorizer = makeAddr("callbackAuthorizer");
        treasury = makeAddr("treasury");

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
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ROLE INITIALIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_Constructor_GrantsAllRolesToDeployer() public view {
        assertTrue(votingContract.hasRole(DEFAULT_ADMIN_ROLE, owner));
        assertTrue(votingContract.hasRole(GOVERNANCE_ROLE, owner));
        assertTrue(votingContract.hasRole(PARAMETER_ADMIN_ROLE, owner));
        assertTrue(votingContract.hasRole(TREASURY_ROLE, owner));
    }

    function test_RoleConstants_AreCorrect() public view {
        assertEq(votingContract.GOVERNANCE_ROLE(), GOVERNANCE_ROLE);
        assertEq(votingContract.PARAMETER_ADMIN_ROLE(), PARAMETER_ADMIN_ROLE);
        assertEq(votingContract.TREASURY_ROLE(), TREASURY_ROLE);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ROLE MANAGEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_GrantRole_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(GOVERNANCE_ROLE, governanceAddress, owner);

        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        assertTrue(votingContract.hasRole(GOVERNANCE_ROLE, governanceAddress));
    }

    function test_GrantRole_RevertWhen_NotAdmin() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
    }

    function test_RevokeRole_Success() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(GOVERNANCE_ROLE, governanceAddress, owner);

        votingContract.revokeRole(GOVERNANCE_ROLE, governanceAddress);

        assertFalse(votingContract.hasRole(GOVERNANCE_ROLE, governanceAddress));
    }

    function test_RevokeRole_RevertWhen_NotAdmin() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.revokeRole(GOVERNANCE_ROLE, governanceAddress);
    }

    function test_RenounceRole_Success() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        vm.prank(governanceAddress);
        votingContract.renounceRole(GOVERNANCE_ROLE, governanceAddress);

        assertFalse(votingContract.hasRole(GOVERNANCE_ROLE, governanceAddress));
    }

    function test_GrantMultipleRoles_ToSameAddress() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, governanceAddress);
        votingContract.grantRole(TREASURY_ROLE, governanceAddress);

        assertTrue(votingContract.hasRole(GOVERNANCE_ROLE, governanceAddress));
        assertTrue(
            votingContract.hasRole(PARAMETER_ADMIN_ROLE, governanceAddress)
        );
        assertTrue(votingContract.hasRole(TREASURY_ROLE, governanceAddress));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // GOVERNANCE_ROLE TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_GovernanceRole_CanSetCallbackAuthorizer() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        address newAuthorizer = makeAddr("newAuthorizer");

        vm.prank(governanceAddress);
        votingContract.setCallbackAuthorizer(newAuthorizer);

        assertEq(votingContract.callbackAuthorizer(), newAuthorizer);
    }

    function test_GovernanceRole_CanSetMinimumStake() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        uint256 newMinimum = 200 ether;

        vm.prank(governanceAddress);
        votingContract.setMinimumStake(newMinimum);

        assertEq(votingContract.minimumStake(), newMinimum);
    }

    function test_GovernanceRole_CanSetVotingDuration() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        uint256 newDuration = 14 days;

        vm.prank(governanceAddress);
        votingContract.setVotingDuration(newDuration);

        assertEq(votingContract.votingDuration(), newDuration);
    }

    function test_GovernanceRole_CanSetPenaltyPercentage() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        uint256 newPercentage = 2000; // 20%

        vm.prank(governanceAddress);
        votingContract.setPenaltyPercentage(newPercentage);

        assertEq(votingContract.penaltyPercentage(), newPercentage);
    }

    function test_GovernanceRole_CanSetMinimumKarmaToVote() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);
        int256 newMinimum = -100;

        vm.prank(governanceAddress);
        votingContract.setMinimumKarmaToVote(newMinimum);

        assertEq(votingContract.minimumKarmaToVote(), newMinimum);
    }

    function test_GovernanceRole_RevertWhen_UnauthorizedCallsSetCallbackAuthorizer()
        public
    {
        address newAuthorizer = makeAddr("newAuthorizer");

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setCallbackAuthorizer(newAuthorizer);
    }

    function test_GovernanceRole_RevertWhen_UnauthorizedCallsSetMinimumStake()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setMinimumStake(200 ether);
    }

    function test_GovernanceRole_RevertWhen_UnauthorizedCallsSetVotingDuration()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setVotingDuration(14 days);
    }

    function test_GovernanceRole_RevertWhen_UnauthorizedCallsSetPenaltyPercentage()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setPenaltyPercentage(2000);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PARAMETER_ADMIN_ROLE TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_ParameterAdminRole_CanSetKarmaReward() public {
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, parameterAdmin);
        uint256 newReward = 20;

        vm.prank(parameterAdmin);
        votingContract.setKarmaReward(newReward);

        assertEq(votingContract.karmaReward(), newReward);
    }

    function test_ParameterAdminRole_CanSetKarmaPenalty() public {
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, parameterAdmin);
        uint256 newPenalty = 10;

        vm.prank(parameterAdmin);
        votingContract.setKarmaPenalty(newPenalty);

        assertEq(votingContract.karmaPenalty(), newPenalty);
    }

    function test_ParameterAdminRole_CanSetFinalizationRewardPercentage()
        public
    {
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, parameterAdmin);
        // First set finalization fee higher to satisfy validation
        votingContract.setFinalizationFeePercentage(600);

        uint256 newPercentage = 500; // 5%

        vm.prank(parameterAdmin);
        votingContract.setFinalizationRewardPercentage(newPercentage);

        assertEq(votingContract.finalizationRewardPercentage(), newPercentage);
    }

    function test_ParameterAdminRole_RevertWhen_UnauthorizedCallsSetKarmaReward()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setKarmaReward(20);
    }

    function test_ParameterAdminRole_RevertWhen_UnauthorizedCallsSetKarmaPenalty()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setKarmaPenalty(10);
    }

    function test_ParameterAdminRole_RevertWhen_UnauthorizedCallsSetFinalizationRewardPercentage()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setFinalizationRewardPercentage(300);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TREASURY_ROLE TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_TreasuryRole_CanSetTreasury() public {
        votingContract.grantRole(TREASURY_ROLE, treasuryManager);
        address newTreasury = makeAddr("newTreasury");

        vm.prank(treasuryManager);
        votingContract.setTreasury(newTreasury);

        assertEq(votingContract.treasury(), newTreasury);
    }

    function test_TreasuryRole_CanSetFinalizationFeePercentage() public {
        votingContract.grantRole(TREASURY_ROLE, treasuryManager);
        uint256 newFee = 300; // 3%

        vm.prank(treasuryManager);
        votingContract.setFinalizationFeePercentage(newFee);

        assertEq(votingContract.finalizationFeePercentage(), newFee);
    }

    function test_TreasuryRole_CanTransferFeesToTreasury() public {
        votingContract.grantRole(TREASURY_ROLE, treasuryManager);

        // Setup: Create a voting scenario to collect fees
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        stakingToken.mint(user1, 1000 ether);
        stakingToken.mint(user2, 1000 ether);

        vm.prank(user1);
        stakingToken.approve(address(votingContract), 1000 ether);
        vm.prank(user1);
        votingContract.stake(500 ether);

        vm.prank(user2);
        stakingToken.approve(address(votingContract), 1000 ether);
        vm.prank(user2);
        votingContract.stake(300 ether);

        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            makeAddr("suspicious"),
            1,
            address(0x123),
            1000 ether,
            18,
            12345
        );

        vm.prank(user1);
        votingContract.castVote(votingId, true);
        vm.prank(user2);
        votingContract.castVote(votingId, false);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);

        uint256 feesCollected = votingContract.totalFeesCollected();
        assertGt(feesCollected, 0);

        vm.prank(treasuryManager);
        votingContract.transferFeesToTreasury(feesCollected);

        assertEq(votingContract.totalFeesCollected(), 0);
    }

    function test_TreasuryRole_RevertWhen_UnauthorizedCallsSetTreasury()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setTreasury(makeAddr("newTreasury"));
    }

    function test_TreasuryRole_RevertWhen_UnauthorizedCallsSetFinalizationFeePercentage()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.setFinalizationFeePercentage(300);
    }

    function test_TreasuryRole_RevertWhen_UnauthorizedCallsTransferFeesToTreasury()
        public
    {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        votingContract.transferFeesToTreasury(100 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CROSS-ROLE PERMISSION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_ParameterAdmin_CannotCallGovernanceFunctions() public {
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, parameterAdmin);

        vm.startPrank(parameterAdmin);

        vm.expectRevert();
        votingContract.setCallbackAuthorizer(makeAddr("newAuthorizer"));

        vm.expectRevert();
        votingContract.setMinimumStake(200 ether);

        vm.expectRevert();
        votingContract.setVotingDuration(14 days);

        vm.expectRevert();
        votingContract.setPenaltyPercentage(2000);

        vm.stopPrank();
    }

    function test_ParameterAdmin_CannotCallTreasuryFunctions() public {
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, parameterAdmin);

        vm.startPrank(parameterAdmin);

        vm.expectRevert();
        votingContract.setTreasury(makeAddr("newTreasury"));

        vm.expectRevert();
        votingContract.setFinalizationFeePercentage(300);

        vm.expectRevert();
        votingContract.transferFeesToTreasury(100 ether);

        vm.stopPrank();
    }

    function test_TreasuryManager_CannotCallGovernanceFunctions() public {
        votingContract.grantRole(TREASURY_ROLE, treasuryManager);

        vm.startPrank(treasuryManager);

        vm.expectRevert();
        votingContract.setCallbackAuthorizer(makeAddr("newAuthorizer"));

        vm.expectRevert();
        votingContract.setMinimumStake(200 ether);

        vm.expectRevert();
        votingContract.setVotingDuration(14 days);

        vm.expectRevert();
        votingContract.setPenaltyPercentage(2000);

        vm.stopPrank();
    }

    function test_TreasuryManager_CannotCallParameterAdminFunctions() public {
        votingContract.grantRole(TREASURY_ROLE, treasuryManager);

        vm.startPrank(treasuryManager);

        vm.expectRevert();
        votingContract.setKarmaReward(20);

        vm.expectRevert();
        votingContract.setKarmaPenalty(10);

        vm.expectRevert();
        votingContract.setFinalizationRewardPercentage(300);

        vm.stopPrank();
    }

    function test_GovernanceRole_CannotCallParameterAdminFunctions() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        vm.startPrank(governanceAddress);

        vm.expectRevert();
        votingContract.setKarmaReward(20);

        vm.expectRevert();
        votingContract.setKarmaPenalty(10);

        vm.expectRevert();
        votingContract.setFinalizationRewardPercentage(300);

        vm.stopPrank();
    }

    function test_GovernanceRole_CannotCallTreasuryFunctions() public {
        votingContract.grantRole(GOVERNANCE_ROLE, governanceAddress);

        vm.startPrank(governanceAddress);

        vm.expectRevert();
        votingContract.setTreasury(makeAddr("newTreasury"));

        vm.expectRevert();
        votingContract.setFinalizationFeePercentage(300);

        vm.expectRevert();
        votingContract.transferFeesToTreasury(100 ether);

        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // OWNER BACKWARD COMPATIBILITY TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_Owner_StillHasAllPermissions() public {
        // Owner should still be able to call all functions since they have all roles
        address newAuthorizer = makeAddr("newAuthorizer");
        votingContract.setCallbackAuthorizer(newAuthorizer);
        assertEq(votingContract.callbackAuthorizer(), newAuthorizer);

        votingContract.setMinimumStake(200 ether);
        assertEq(votingContract.minimumStake(), 200 ether);

        votingContract.setKarmaReward(20);
        assertEq(votingContract.karmaReward(), 20);

        address newTreasury = makeAddr("newTreasury");
        votingContract.setTreasury(newTreasury);
        assertEq(votingContract.treasury(), newTreasury);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ROLE TRANSFER SCENARIO TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_Scenario_TransferGovernanceToDAO() public {
        address daoMultisig = makeAddr("daoMultisig");

        // Grant governance role to DAO
        votingContract.grantRole(GOVERNANCE_ROLE, daoMultisig);

        // Revoke from owner
        votingContract.revokeRole(GOVERNANCE_ROLE, owner);

        // Owner can no longer call governance functions
        vm.expectRevert();
        votingContract.setMinimumStake(200 ether);

        // DAO can call governance functions
        vm.prank(daoMultisig);
        votingContract.setMinimumStake(200 ether);
        assertEq(votingContract.minimumStake(), 200 ether);
    }

    function test_Scenario_SeparateRolesForDifferentTeams() public {
        address daoMultisig = makeAddr("daoMultisig");
        address opsTeam = makeAddr("opsTeam");
        address treasuryMultisig = makeAddr("treasuryMultisig");

        // Grant different roles to different addresses
        votingContract.grantRole(GOVERNANCE_ROLE, daoMultisig);
        votingContract.grantRole(PARAMETER_ADMIN_ROLE, opsTeam);
        votingContract.grantRole(TREASURY_ROLE, treasuryMultisig);

        // Each can only call their respective functions
        vm.prank(daoMultisig);
        votingContract.setMinimumStake(200 ether);

        vm.prank(opsTeam);
        votingContract.setKarmaReward(20);

        vm.prank(treasuryMultisig);
        votingContract.setTreasury(makeAddr("newTreasury"));

        // Cross-role calls should fail
        vm.prank(daoMultisig);
        vm.expectRevert();
        votingContract.setKarmaReward(30);

        vm.prank(opsTeam);
        vm.expectRevert();
        votingContract.setMinimumStake(300 ether);

        vm.prank(treasuryMultisig);
        vm.expectRevert();
        votingContract.setMinimumStake(400 ether);
    }
}
