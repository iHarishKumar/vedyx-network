// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VedyxTypes} from "../libraries/VedyxTypes.sol";

/**
 * @title IVedyxVoting
 * @notice Interface for the Vedyx Voting Contract
 */
interface IVedyxVoting {
    // ─── Events ───────────────────────────────────────────────────────────
    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event FeeCollected(address indexed staker, uint256 feeAmount);
    event TreasuryUpdated(address indexed newTreasury);
    event FinalizationFeeUpdated(uint256 newFeePercentage);
    event VotingStarted(
        uint256 indexed votingId,
        address indexed suspiciousAddress,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed votingId,
        address indexed voter,
        bool votedFor,
        uint256 votingPower
    );
    event VotingFinalized(
        uint256 indexed votingId,
        address indexed suspiciousAddress,
        bool isSuspicious,
        uint256 votesFor,
        uint256 votesAgainst
    );
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
    event VerdictCleared(
        address indexed suspiciousAddress,
        address indexed clearedBy
    );
    event FinalizationRewardPaid(
        uint256 indexed votingId,
        address indexed finalizer,
        uint256 rewardAmount
    );

    // ─── Staking Functions ────────────────────────────────────────────────
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;

    // ─── Voting Functions ─────────────────────────────────────────────────
    function castVote(uint256 votingId, bool voteSuspicious) external;
    function finalizeVoting(uint256 votingId) external;

    // ─── Callback Function ────────────────────────────────────────────────
    function tagSuspicious(
        address suspiciousAddress,
        uint256 originChainId,
        address originContract,
        uint256 value,
        uint256 decimals,
        uint256 txHash
    ) external returns (uint256 votingId);

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
            bool isSuspicious,
            bool isInconclusive
        );

    function getVote(
        uint256 votingId,
        address voter
    ) external view returns (bool hasVoted, bool votedFor, uint256 votingPower);

    function getStakerInfo(
        address staker
    ) external view returns (VedyxTypes.Staker memory);

    function getActiveVotings() external view returns (uint256[] memory);

    function getAddressVotingHistory(
        address suspiciousAddress
    ) external view returns (uint256[] memory);

    function getVotingPower(address voter) external view returns (int256);

    function getVoterAccuracy(address voter) external view returns (uint256);

    function getVoters(uint256 votingId) external view returns (address[] memory);

    function getAddressVerdict(
        address addr
    )
        external
        view
        returns (
            bool hasVerdict,
            bool isSuspicious,
            uint256 lastVotingId,
            uint256 verdictTimestamp,
            uint256 totalIncidents
        );

    function willAutoMark(address addr) external view returns (bool);

    // ─── Admin Functions ──────────────────────────────────────────────────
    function setCallbackAuthorizer(address newAuthorizer) external;
    function setMinimumStake(uint256 newMinimum) external;
    function setVotingDuration(uint256 newDuration) external;
    function setPenaltyPercentage(uint256 newPercentage) external;
    function setKarmaReward(uint256 newReward) external;
    function setKarmaPenalty(uint256 newPenalty) external;
    function setMinimumKarmaToVote(int256 newMinimumKarma) external;
    function clearAddressVerdict(address suspiciousAddress) external;
    function setFinalizationRewardPercentage(uint256 newPercentage) external;
    function setTreasury(address newTreasury) external;
    function setFinalizationFeePercentage(uint256 newFeePercentage) external;
    function transferFeesToTreasury(uint256 amount) external;
}
