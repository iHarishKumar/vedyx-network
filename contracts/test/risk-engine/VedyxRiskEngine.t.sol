// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VedyxRiskEngine} from "../../src/risk-engine/VedyxRiskEngine.sol";
import {IVedyxRiskEngine} from "../../src/risk-engine/interfaces/IVedyxRiskEngine.sol";
import {VedyxVotingContract} from "../../src/voting-contract/VedyxVotingContract.sol";
import {VedyxVotingViews} from "../../src/voting-contract/VedyxVotingViews.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract VedyxRiskEngineTest is Test {
    VedyxRiskEngine public riskEngine;
    VedyxVotingContract public votingContract;
    VedyxVotingViews public votingViews;
    MockERC20 public stakingToken;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public suspiciousAddr = address(0xBAD);
    address public callbackAuthorizer = address(0x999);
    address public treasury = address(0x888);

    uint256 public constant MINIMUM_STAKE = 100 ether;
    uint256 public constant VOTING_DURATION = 3 days;
    uint256 public constant PENALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant FINALIZATION_FEE_PERCENTAGE = 100; // 1%

    function setUp() public {
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

        votingViews = new VedyxVotingViews(address(votingContract));

        riskEngine = new VedyxRiskEngine(address(votingViews));

        stakingToken.mint(user1, 10000 ether);
        stakingToken.mint(user2, 10000 ether);
    }

    // ─── Risk Assessment Tests ────────────────────────────────────────────

    function test_GetRiskAssessment_NoVerdict() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(user1);

        assertEq(assessment.totalScore, 0);
        assertEq(uint256(assessment.riskLevel), uint256(IVedyxRiskEngine.RiskLevel.SAFE));
        assertFalse(assessment.hasVerdict);
        assertEq(assessment.lastUpdated, 0);
    }

    function test_GetRiskLevel_NoVerdict() public view{
        IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(user1);
        assertEq(uint256(level), uint256(IVedyxRiskEngine.RiskLevel.SAFE));
    }

    function test_GetRiskScore_NoVerdict() public view{
        uint8 score = riskEngine.getRiskScore(user1);
        assertEq(score, 0);
    }

    function test_IsSafeAddress_NoVerdict() public view{
        bool isSafe = riskEngine.isSafeAddress(user1);
        assertTrue(isSafe);
    }

    function test_GetRiskAssessment_WithSuspiciousVerdict() public {
        _createSuspiciousVerdict(suspiciousAddr);

        IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(suspiciousAddr);

        assertTrue(assessment.totalScore > 0);
        assertTrue(assessment.hasVerdict);
        assertTrue(uint256(assessment.riskLevel) > uint256(IVedyxRiskEngine.RiskLevel.SAFE));
    }

    function test_GetRiskLevel_SuspiciousVerdict() public {
        _createSuspiciousVerdict(suspiciousAddr);

        IVedyxRiskEngine.RiskLevel level = riskEngine.getRiskLevel(suspiciousAddr);
        assertTrue(uint256(level) >= uint256(IVedyxRiskEngine.RiskLevel.MEDIUM));
    }

    function test_IsSafeAddress_SuspiciousVerdict() public {
        _createSuspiciousVerdict(suspiciousAddr);

        bool isSafe = riskEngine.isSafeAddress(suspiciousAddr);
        assertFalse(isSafe);
    }

    // ─── Batch Operations Tests ───────────────────────────────────────────

    function test_GetBatchRiskLevels() public {
        _createSuspiciousVerdict(suspiciousAddr);

        address[] memory addresses = new address[](3);
        addresses[0] = user1;
        addresses[1] = suspiciousAddr;
        addresses[2] = user2;

        IVedyxRiskEngine.RiskLevel[] memory levels = riskEngine.getBatchRiskLevels(addresses);

        assertEq(levels.length, 3);
        assertEq(uint256(levels[0]), uint256(IVedyxRiskEngine.RiskLevel.SAFE));
        assertTrue(uint256(levels[1]) > uint256(IVedyxRiskEngine.RiskLevel.SAFE));
        assertEq(uint256(levels[2]), uint256(IVedyxRiskEngine.RiskLevel.SAFE));
    }

    function test_GetBatchRiskScores() public {
        _createSuspiciousVerdict(suspiciousAddr);

        address[] memory addresses = new address[](3);
        addresses[0] = user1;
        addresses[1] = suspiciousAddr;
        addresses[2] = user2;

        uint8[] memory scores = riskEngine.getBatchRiskScores(addresses);

        assertEq(scores.length, 3);
        assertEq(scores[0], 0);
        assertTrue(scores[1] > 0);
        assertEq(scores[2], 0);
    }

    // ─── Configuration Tests ──────────────────────────────────────────────

    function test_UpdateRiskConfig() public {
        IVedyxRiskEngine.RiskConfig memory newConfig = IVedyxRiskEngine.RiskConfig({
            verdictWeight: 50,
            incidentWeight: 15,
            detectorWeight: 15,
            consensusWeight: 10,
            recencyWeight: 10
        });

        riskEngine.updateRiskConfig(newConfig);

        IVedyxRiskEngine.RiskConfig memory config = riskEngine.getRiskConfig();
        assertEq(config.verdictWeight, 50);
        assertEq(config.incidentWeight, 15);
    }

    function test_UpdateRiskConfig_InvalidWeights() public {
        IVedyxRiskEngine.RiskConfig memory invalidConfig = IVedyxRiskEngine.RiskConfig({
            verdictWeight: 50,
            incidentWeight: 50,
            detectorWeight: 50,
            consensusWeight: 10,
            recencyWeight: 10
        });

        vm.expectRevert("Invalid config: weights must sum to 100");
        riskEngine.updateRiskConfig(invalidConfig);
    }

    function test_UpdateDetectorSeverities() public {
        bytes32[] memory detectorIds = new bytes32[](3);
        uint8[] memory severities = new uint8[](3);

        detectorIds[0] = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        detectorIds[1] = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
        detectorIds[2] = keccak256("LARGE_TRANSFER_DETECTOR_V1");

        severities[0] = 40;
        severities[1] = 40;
        severities[2] = 20;

        riskEngine.updateDetectorSeverities(detectorIds, severities);
        
        assertEq(riskEngine.getDetectorSeverity(detectorIds[0]), 40);
        assertEq(riskEngine.getDetectorSeverity(detectorIds[1]), 40);
        assertEq(riskEngine.getDetectorSeverity(detectorIds[2]), 20);
    }

    function test_UpdateDetectorSeverities_InvalidSum() public {
        bytes32[] memory detectorIds = new bytes32[](3);
        uint8[] memory severities = new uint8[](3);

        detectorIds[0] = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        detectorIds[1] = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
        detectorIds[2] = keccak256("LARGE_TRANSFER_DETECTOR_V1");

        severities[0] = 50;
        severities[1] = 30;
        severities[2] = 30; // Sum = 110, not 100

        vm.expectRevert("Severities must sum to 100");
        riskEngine.updateDetectorSeverities(detectorIds, severities);
    }

    // ─── Access Control Tests ─────────────────────────────────────────────

    function test_UpdateRiskConfig_OnlyRiskAdmin() public {
        IVedyxRiskEngine.RiskConfig memory newConfig = IVedyxRiskEngine.RiskConfig({
            verdictWeight: 50,
            incidentWeight: 15,
            detectorWeight: 15,
            consensusWeight: 10,
            recencyWeight: 10
        });

        vm.prank(user1);
        vm.expectRevert();
        riskEngine.updateRiskConfig(newConfig);
    }

    function test_UpdateDetectorSeverities_OnlyRiskAdmin() public {
        bytes32[] memory detectorIds = new bytes32[](3);
        uint8[] memory severities = new uint8[](3);

        detectorIds[0] = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        detectorIds[1] = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");
        detectorIds[2] = keccak256("LARGE_TRANSFER_DETECTOR_V1");

        severities[0] = 50;
        severities[1] = 35;
        severities[2] = 15;
        
        vm.prank(user1);
        vm.expectRevert();
        riskEngine.updateDetectorSeverities(detectorIds, severities);
    }

    // ─── Helper Functions ─────────────────────────────────────────────────

    function _createSuspiciousVerdict(address addr) internal {
        vm.startPrank(user1);
        stakingToken.approve(address(votingContract), MINIMUM_STAKE * 2);
        votingContract.stake(MINIMUM_STAKE * 2);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(votingContract), MINIMUM_STAKE * 2);
        votingContract.stake(MINIMUM_STAKE * 2);
        vm.stopPrank();

        vm.prank(callbackAuthorizer);
        uint256 votingId = votingContract.tagSuspicious(
            addr,
            1,
            address(0x123),
            1000 ether,
            18,
            uint256(keccak256("txhash")),
            keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1")
        );

        vm.prank(user1);
        votingContract.castVote(votingId, true);

        vm.prank(user2);
        votingContract.castVote(votingId, true);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
    }

    function _createCriticalVerdict(address addr) internal {
        // Create multiple incidents to increase risk score
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(callbackAuthorizer);
            votingContract.tagSuspicious(
                addr,
                1,
                address(0x123),
                1000 ether,
                18,
                uint256(keccak256(abi.encodePacked("txhash", i))),
                keccak256("MIXER_INTERACTION_DETECTOR_V1")
            );
        }

        // Vote on first incident
        uint256 votingId = 1;

        vm.startPrank(user1);
        stakingToken.approve(address(votingContract), MINIMUM_STAKE * 2);
        votingContract.stake(MINIMUM_STAKE * 2);
        votingContract.castVote(votingId, true);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(votingContract), MINIMUM_STAKE * 2);
        votingContract.stake(MINIMUM_STAKE * 2);
        votingContract.castVote(votingId, true);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        votingContract.finalizeVoting(votingId);
    }
}
