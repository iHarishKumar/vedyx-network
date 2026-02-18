// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title VedyxTypes
 * @notice Data structures for the Vedyx Voting system
 */
library VedyxTypes {
    /**
     * @notice Information about a suspicious address report
     */
    struct SuspiciousReport {
        address suspiciousAddress;
        uint256 originChainId;
        address originContract;
        uint256 value;
        uint256 decimals;
        uint256 txHash;
        bytes32 detectorId;
    }

    /**
     * @notice Voting process details
     */
    struct Voting {
        uint256 votingId;
        SuspiciousReport report;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotingPower;
        bool finalized;
        bool isSuspicious;
        mapping(address => Vote) votes;
        address[] voters;
    }

    /**
     * @notice Individual vote details
     */
    struct Vote {
        bool hasVoted;
        bool votedFor;
        uint256 votingPower;
        uint256 stakedSnapshot;
    }

    /**
     * @notice Staker information
     */
    struct Staker {
        uint256 stakedAmount;
        int256 karmaPoints;
        uint256 totalVotes;
        uint256 correctVotes;
        uint256 lockedAmount;
    }

    /**
     * @notice Historical verdict for an address
     */
    struct AddressVerdict {
        bool hasVerdict;
        bool isSuspicious;
        uint256 lastVotingId;
        uint256 verdictTimestamp;
        uint256 totalIncidents;
    }

    /**
     * @notice Configuration parameters for voting
     */
    struct VotingConfig {
        uint256 minimumStake;
        uint256 votingDuration;
        uint256 penaltyPercentage;
        uint256 karmaReward;
        uint256 karmaPenalty;
        int256 minimumKarmaToVote;
    }

    /**
     * @notice Configuration parameters for fees
     */
    struct FeeConfig {
        uint256 finalizationFeePercentage;
        uint256 finalizationRewardPercentage;
        address treasury;
    }
}
