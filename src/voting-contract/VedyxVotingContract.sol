// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {VedyxTypes} from "./libraries/VedyxTypes.sol";
import {VedyxErrors} from "./libraries/VedyxErrors.sol";
import {VotingPowerLib} from "./libraries/VotingPowerLib.sol";
import {VotingResultsLib} from "./libraries/VotingResultsLib.sol";
import {IVedyxVoting} from "./interfaces/IVedyxVoting.sol";

/**
 * @title VedyxVotingContract
 * @notice Manages decentralized voting on suspicious addresses detected by the Vedyx Exploit Detector
 * @dev Implements staking-based voting with karma tracking and penalty mechanisms
 *
 * ─── Key Features ─────────────────────────────────────────────────────────────
 * • Stake-based voting power with karma effects
 * • Callback integration with Reactive Network
 * • Multi-voting support with concurrent processes
 * • Penalty system with stake slashing
 * • Karma tracking with exponential penalties
 * • Verdict-based auto-classification
 * • Role-based access control (RBAC)
 * ──────────────────────────────────────────────────────────────────────────────
 */
contract VedyxVotingContract is Ownable, ReentrancyGuard, AccessControl, IVedyxVoting {
    using FixedPointMathLib for uint256;
    using VotingPowerLib for uint256;
    using VotingPowerLib for VedyxTypes.Staker;

    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;

    // ─── Role Constants ───────────────────────────────────────────────────
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PARAMETER_ADMIN_ROLE = keccak256("PARAMETER_ADMIN_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // ─── State Variables ──────────────────────────────────────────────────
    IERC20 public immutable stakingToken;
    address public callbackAuthorizer;
    uint256 public minimumStake;
    uint256 public votingDuration;
    uint256 public penaltyPercentage;
    uint256 public karmaReward;
    uint256 public karmaPenalty;
    uint256 public finalizationFeePercentage;
    address public treasury;
    uint256 public totalFeesCollected;
    uint256 public finalizationRewardPercentage;
    int256 public minimumKarmaToVote;
    uint256 private votingIdCounter;

    // ─── Mappings ─────────────────────────────────────────────────────────
    mapping(uint256 => VedyxTypes.Voting) public votings;
    mapping(address => VedyxTypes.Staker) public stakers;
    uint256[] public activeVotingIds;
    mapping(address => uint256[]) public addressVotingHistory;
    mapping(address => VedyxTypes.AddressVerdict) public addressVerdicts;

    // ─── Events ───────────────────────────────────────────────────────────
    event CallbackAuthorizerUpdated(address indexed newAuthorizer);
    event MinimumStakeUpdated(uint256 newMinimum);
    event VotingDurationUpdated(uint256 newDuration);
    event PenaltyPercentageUpdated(uint256 newPercentage);
    event MinimumKarmaToVoteUpdated(int256 newMinimumKarma);
    event FinalizationRewardPercentageUpdated(uint256 newPercentage);

    // ─── Modifiers ────────────────────────────────────────────────────────
    modifier onlyCallbackAuthorizer() {
        if (msg.sender != callbackAuthorizer) revert VedyxErrors.UnauthorizedCallback();
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────
    constructor(
        address _stakingToken,
        address _callbackAuthorizer,
        uint256 _minimumStake,
        uint256 _votingDuration,
        uint256 _penaltyPercentage,
        address _treasury,
        uint256 _finalizationFeePercentage
    ) Ownable() {
        if (_stakingToken == address(0) || _callbackAuthorizer == address(0)) {
            revert VedyxErrors.InvalidAddress();
        }
        if (_treasury == address(0)) revert VedyxErrors.InvalidTreasury();
        if (_finalizationFeePercentage > 1000) revert VedyxErrors.InvalidFeePercentage();

        stakingToken = IERC20(_stakingToken);
        callbackAuthorizer = _callbackAuthorizer;
        minimumStake = _minimumStake;
        votingDuration = _votingDuration;
        penaltyPercentage = _penaltyPercentage;
        treasury = _treasury;
        finalizationFeePercentage = _finalizationFeePercentage;
        finalizationRewardPercentage = 200;
        karmaReward = 10;
        karmaPenalty = 5;
        minimumKarmaToVote = -50;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);
        _grantRole(PARAMETER_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
    }

    // ─── Staking Functions ────────────────────────────────────────────────

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert VedyxErrors.InvalidAmount();

        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakers[msg.sender].stakedAmount += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert VedyxErrors.InvalidAmount();

        VedyxTypes.Staker storage staker = stakers[msg.sender];
        uint256 availableAmount = VotingPowerLib.getAvailableStake(staker);

        if (amount > availableAmount) revert VedyxErrors.InsufficientStake();
        if (staker.lockedAmount > 0) revert VedyxErrors.CannotUnstakeWhenVotingIsActive();

        staker.stakedAmount -= amount;
        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    // ─── Callback Handler ─────────────────────────────────────────────────

    function tagSuspicious(
        address suspiciousAddress,
        uint256 originChainId,
        address originContract,
        uint256 value,
        uint256 decimals,
        uint256 txHash
    ) external onlyCallbackAuthorizer returns (uint256 votingId) {
        if (suspiciousAddress == address(0)) revert VedyxErrors.InvalidAddress();

        VedyxTypes.AddressVerdict storage verdict = addressVerdicts[suspiciousAddress];
        
        bool hasVerdict = verdict.hasVerdict;
        bool isSuspicious = verdict.isSuspicious;

        if (hasVerdict && isSuspicious) {
            uint256 newIncidentCount = verdict.totalIncidents + 1;
            verdict.totalIncidents = newIncidentCount;
            addressVotingHistory[suspiciousAddress].push(0);
            
            emit AddressAutoMarkedSuspicious(
                suspiciousAddress,
                newIncidentCount,
                verdict.lastVotingId,
                txHash
            );
            
            return 0;
        }

        votingId = ++votingIdCounter;

        VedyxTypes.Voting storage voting = votings[votingId];
        voting.votingId = votingId;
        voting.report = VedyxTypes.SuspiciousReport({
            suspiciousAddress: suspiciousAddress,
            originChainId: originChainId,
            originContract: originContract,
            value: value,
            decimals: decimals,
            txHash: txHash,
            detectorId: bytes32(0)
        });
        voting.startTime = block.timestamp;
        voting.endTime = block.timestamp + votingDuration;
        voting.finalized = false;

        activeVotingIds.push(votingId);
        addressVotingHistory[suspiciousAddress].push(votingId);
        verdict.totalIncidents++;

        emit VotingStarted(votingId, suspiciousAddress, voting.endTime);

        return votingId;
    }

    // ─── Voting Functions ─────────────────────────────────────────────────

    function castVote(uint256 votingId, bool voteSuspicious) external nonReentrant {
        VedyxTypes.Voting storage voting = votings[votingId];

        if (voting.startTime == 0) revert VedyxErrors.InvalidVotingId();
        if (block.timestamp >= voting.endTime) revert VedyxErrors.VotingAlreadyEnded();
        if (voting.finalized) revert VedyxErrors.VotingAlreadyEnded();
        if (voting.votes[msg.sender].hasVoted) revert VedyxErrors.AlreadyVoted();
        if (msg.sender == voting.report.suspiciousAddress) {
            revert VedyxErrors.CannotVoteOnOwnAddress();
        }

        VedyxTypes.Staker storage staker = stakers[msg.sender];

        if (!VotingPowerLib.hasSufficientKarma(staker.karmaPoints, minimumKarmaToVote)) {
            revert VedyxErrors.InsufficientKarma();
        }

        uint256 availableStake = VotingPowerLib.getAvailableStake(staker);
        if (availableStake < minimumStake) revert VedyxErrors.InsufficientStake();

        int256 votingPower = VotingPowerLib.calculateVotingPower(
            availableStake,
            staker.karmaPoints
        );

        if (votingPower <= 0) revert VedyxErrors.InsufficientVotingPower();

        voting.votes[msg.sender] = VedyxTypes.Vote({
            hasVoted: true,
            votedFor: voteSuspicious,
            votingPower: uint256(votingPower),
            stakedSnapshot: availableStake
        });

        voting.voters.push(msg.sender);

        uint256 votingPowerUint = uint256(votingPower);

        if (voteSuspicious) {
            voting.votesFor += votingPowerUint;
        } else {
            voting.votesAgainst += votingPowerUint;
        }

        voting.totalVotingPower += votingPowerUint;
        staker.lockedAmount += minimumStake;
        staker.totalVotes += 1;

        emit VoteCast(votingId, msg.sender, voteSuspicious, votingPowerUint);
    }

    function finalizeVoting(uint256 votingId) external nonReentrant {
        VedyxTypes.Voting storage voting = votings[votingId];

        if (voting.startTime == 0) revert VedyxErrors.InvalidVotingId();
        if (block.timestamp < voting.endTime) revert VedyxErrors.VotingStillActive();
        if (voting.finalized) revert VedyxErrors.VotingAlreadyEnded();

        voting.finalized = true;

        bool consensus = voting.votesFor > voting.votesAgainst;
        voting.isSuspicious = consensus;

        address suspiciousAddress = voting.report.suspiciousAddress;
        VedyxTypes.AddressVerdict storage verdict = addressVerdicts[suspiciousAddress];
        verdict.hasVerdict = true;
        verdict.isSuspicious = consensus;
        verdict.lastVotingId = votingId;
        verdict.verdictTimestamp = block.timestamp;

        emit VerdictRecorded(
            suspiciousAddress,
            votingId,
            consensus,
            block.timestamp
        );

        _processVotingResults(votingId, consensus);
        _removeActiveVoting(votingId);

        emit VotingFinalized(
            votingId,
            voting.report.suspiciousAddress,
            consensus,
            voting.votesFor,
            voting.votesAgainst
        );

        uint256 rewardAmount = VotingResultsLib.calculateFinalizationReward(
            totalFeesCollected,
            finalizationRewardPercentage
        );

        if (rewardAmount > 0 && rewardAmount <= totalFeesCollected) {
            totalFeesCollected -= rewardAmount;
            stakingToken.transfer(msg.sender, rewardAmount);
            emit FinalizationRewardPaid(votingId, msg.sender, rewardAmount);
        }
    }

    // ─── Internal Functions ───────────────────────────────────────────────

    function _processVotingResults(uint256 votingId, bool consensus) internal {
        VedyxTypes.Voting storage voting = votings[votingId];

        VotingResultsLib.PenaltyCollectionResult memory result = 
            VotingResultsLib.collectPenalties(
                voting.voters,
                voting.votes,
                stakers,
                consensus,
                votingId,
                penaltyPercentage,
                minimumStake
            );

        (uint256 finalizationFee, uint256 penaltiesForDistribution) = 
            VotingResultsLib.calculateFinalizationFee(
                result.totalPenalties,
                finalizationFeePercentage
            );

        if (finalizationFee > 0) {
            totalFeesCollected += finalizationFee;
            emit FeeCollected(address(this), finalizationFee);
        }

        VotingResultsLib.applyKarmaPenalties(
            voting.voters,
            voting.votes,
            stakers,
            consensus,
            karmaPenalty
        );

        VotingResultsLib.distributeRewards(
            voting.voters,
            voting.votes,
            stakers,
            consensus,
            votingId,
            karmaReward,
            penaltiesForDistribution,
            result.correctVotersTotalPower
        );
    }

    function _removeActiveVoting(uint256 votingId) internal {
        for (uint256 i = 0; i < activeVotingIds.length; i++) {
            if (activeVotingIds[i] == votingId) {
                activeVotingIds[i] = activeVotingIds[activeVotingIds.length - 1];
                activeVotingIds.pop();
                break;
            }
        }
    }

    // ─── Admin Functions ──────────────────────────────────────────────────

    function setCallbackAuthorizer(address newAuthorizer) external onlyRole(GOVERNANCE_ROLE) {
        if (newAuthorizer == address(0)) revert VedyxErrors.InvalidAddress();
        callbackAuthorizer = newAuthorizer;
        emit CallbackAuthorizerUpdated(newAuthorizer);
    }

    function setMinimumStake(uint256 newMinimum) external onlyRole(GOVERNANCE_ROLE) {
        minimumStake = newMinimum;
        emit MinimumStakeUpdated(newMinimum);
    }

    function setVotingDuration(uint256 newDuration) external onlyRole(GOVERNANCE_ROLE) {
        votingDuration = newDuration;
        emit VotingDurationUpdated(newDuration);
    }

    function setPenaltyPercentage(uint256 newPercentage) external onlyRole(GOVERNANCE_ROLE) {
        if (newPercentage > 5000) revert VedyxErrors.InvalidFeePercentage();
        penaltyPercentage = newPercentage;
        emit PenaltyPercentageUpdated(newPercentage);
    }

    function setKarmaReward(uint256 newReward) external onlyRole(PARAMETER_ADMIN_ROLE) {
        karmaReward = newReward;
    }

    function setKarmaPenalty(uint256 newPenalty) external onlyRole(PARAMETER_ADMIN_ROLE) {
        karmaPenalty = newPenalty;
    }

    function setMinimumKarmaToVote(int256 newMinimumKarma) external onlyRole(GOVERNANCE_ROLE) {
        minimumKarmaToVote = newMinimumKarma;
        emit MinimumKarmaToVoteUpdated(newMinimumKarma);
    }

    function clearAddressVerdict(address suspiciousAddress) external onlyRole(GOVERNANCE_ROLE) {
        VedyxTypes.AddressVerdict storage verdict = addressVerdicts[suspiciousAddress];
        
        if (!verdict.hasVerdict) revert VedyxErrors.NoVerdictToClear();
        
        verdict.hasVerdict = false;
        verdict.isSuspicious = false;
        
        emit VerdictCleared(suspiciousAddress, msg.sender);
    }

    function setFinalizationRewardPercentage(
        uint256 newPercentage
    ) external onlyRole(PARAMETER_ADMIN_ROLE) {
        if (newPercentage > 1000) revert VedyxErrors.InvalidFeePercentage();
        if (newPercentage >= finalizationFeePercentage) revert VedyxErrors.InvalidFeePercentage();
        finalizationRewardPercentage = newPercentage;
        emit FinalizationRewardPercentageUpdated(newPercentage);
    }

    function setTreasury(address newTreasury) external onlyRole(TREASURY_ROLE) {
        if (newTreasury == address(0)) revert VedyxErrors.InvalidTreasury();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function setFinalizationFeePercentage(
        uint256 newFeePercentage
    ) external onlyRole(TREASURY_ROLE) {
        if (newFeePercentage > 1000) revert VedyxErrors.InvalidFeePercentage();
        if (newFeePercentage <= finalizationRewardPercentage) revert VedyxErrors.InvalidFeePercentage();
        finalizationFeePercentage = newFeePercentage;
        emit FinalizationFeeUpdated(newFeePercentage);
    }

    function transferFeesToTreasury(uint256 amount) external onlyRole(TREASURY_ROLE) {
        if (amount == 0) revert VedyxErrors.InvalidAmount();
        if (amount > totalFeesCollected) revert VedyxErrors.InvalidAmount();

        totalFeesCollected -= amount;
        stakingToken.transfer(treasury, amount);

        emit FeeCollected(treasury, amount);
    }

    // ─── View Functions ───────────────────────────────────────────────────

    function getVotingDetails(
        uint256 votingId
    )
        external
        view
        returns (
            VedyxTypes.SuspiciousReport memory report,
            uint256 startTime,
            uint256 endTime,
            uint256 votesFor,
            uint256 votesAgainst,
            bool finalized,
            bool isSuspicious
        )
    {
        VedyxTypes.Voting storage voting = votings[votingId];
        return (
            voting.report,
            voting.startTime,
            voting.endTime,
            voting.votesFor,
            voting.votesAgainst,
            voting.finalized,
            voting.isSuspicious
        );
    }

    function getVote(
        uint256 votingId,
        address voter
    ) external view returns (bool hasVoted, bool votedFor, uint256 votingPower) {
        VedyxTypes.Vote memory vote = votings[votingId].votes[voter];
        return (vote.hasVoted, vote.votedFor, vote.votingPower);
    }

    function getStakerInfo(
        address stakerAddress
    ) external view returns (VedyxTypes.Staker memory staker) {
        staker = stakers[stakerAddress];
    }

    function getActiveVotings() external view returns (uint256[] memory) {
        return activeVotingIds;
    }

    function getAddressVotingHistory(
        address suspiciousAddress
    ) external view returns (uint256[] memory) {
        return addressVotingHistory[suspiciousAddress];
    }

    function getVotingPower(address voter) external view returns (int256) {
        VedyxTypes.Staker memory staker = stakers[voter];
        uint256 availableStake = VotingPowerLib.getAvailableStake(staker);
        return VotingPowerLib.calculateVotingPower(availableStake, staker.karmaPoints);
    }

    function getVoterAccuracy(address voter) external view returns (uint256) {
        VedyxTypes.Staker memory staker = stakers[voter];
        if (staker.totalVotes == 0) return 0;
        return staker.correctVotes.mulDivDown(BASIS_POINTS_DIVISOR, staker.totalVotes);
    }

    function getVoters(uint256 votingId) external view returns (address[] memory) {
        return votings[votingId].voters;
    }

    function getAddressVerdict(address addr) external view returns (
        bool hasVerdict,
        bool isSuspicious,
        uint256 lastVotingId,
        uint256 verdictTimestamp,
        uint256 totalIncidents
    ) {
        VedyxTypes.AddressVerdict memory verdict = addressVerdicts[addr];
        return (
            verdict.hasVerdict,
            verdict.isSuspicious,
            verdict.lastVotingId,
            verdict.verdictTimestamp,
            verdict.totalIncidents
        );
    }

    function willAutoMark(address addr) external view returns (bool) {
        VedyxTypes.AddressVerdict memory verdict = addressVerdicts[addr];
        return verdict.hasVerdict && verdict.isSuspicious;
    }
}
