// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {VedyxTypes} from "./VedyxTypes.sol";

/**
 * @title VotingResultsLib
 * @notice Library for processing voting results, penalties, and rewards
 */
library VotingResultsLib {
    using FixedPointMathLib for uint256;

    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;

    // ─── Events ───────────────────────────────────────────────────────────
    event PenaltyApplied(
        address indexed voter,
        uint256 indexed votingId,
        uint256 penaltyAmount
    );
    event KarmaUpdated(
        address indexed voter,
        int256 karmaChange,
        int256 newKarma
    );
    event VoterRewarded(
        address indexed voter,
        uint256 indexed votingId,
        uint256 rewardAmount
    );
    event FeeCollected(address indexed collector, uint256 feeAmount);

    /**
     * @notice Result of penalty collection pass
     */
    struct PenaltyCollectionResult {
        uint256 totalPenalties;
        uint256 correctVotersTotalPower;
        uint256 finalizationFee;
        uint256 penaltiesForDistribution;
    }

    /**
     * @notice Calculate penalties for incorrect voters
     * @param voters Array of voter addresses
     * @param votes Mapping of votes
     * @param stakers Mapping of stakers
     * @param consensus Final verdict
     * @param votingId Voting ID
     * @param penaltyPercentage Penalty percentage in basis points
     * @param minimumStake Minimum stake amount
     * @return result Penalty collection results
     */
    function collectPenalties(
        address[] memory voters,
        mapping(address => VedyxTypes.Vote) storage votes,
        mapping(address => VedyxTypes.Staker) storage stakers,
        bool consensus,
        uint256 votingId,
        uint256 penaltyPercentage,
        uint256 minimumStake
    ) internal returns (PenaltyCollectionResult memory result) {
        result.totalPenalties = 0;
        result.correctVotersTotalPower = 0;

        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            VedyxTypes.Vote memory vote = votes[voter];
            VedyxTypes.Staker storage staker = stakers[voter];

            // Unlock the staked amount
            if (staker.lockedAmount >= minimumStake) {
                staker.lockedAmount = staker.lockedAmount - minimumStake;
            } else {
                staker.lockedAmount = 0;
            }

            bool votedCorrectly = vote.votedFor == consensus;

            if (votedCorrectly) {
                result.correctVotersTotalPower += vote.votingPower;
            } else {
                uint256 penalty = calculatePenalty(
                    vote.stakedSnapshot,
                    penaltyPercentage,
                    staker.stakedAmount
                );

                result.totalPenalties += penalty;
                staker.stakedAmount = staker.stakedAmount - penalty;

                emit PenaltyApplied(voter, votingId, penalty);
            }
        }

        return result;
    }

    /**
     * @notice Calculate penalty amount for a voter
     * @param stakedSnapshot Snapshot of stake at vote time
     * @param penaltyPercentage Penalty percentage in basis points
     * @param currentStake Current staked amount
     * @return Penalty amount
     */
    function calculatePenalty(
        uint256 stakedSnapshot,
        uint256 penaltyPercentage,
        uint256 currentStake
    ) internal pure returns (uint256) {
        uint256 penalty = stakedSnapshot.mulDivDown(
            penaltyPercentage,
            BASIS_POINTS_DIVISOR
        );

        if (penalty > currentStake) {
            penalty = currentStake;
        }

        return penalty;
    }

    /**
     * @notice Calculate finalization fee from total penalties
     * @param totalPenalties Total penalties collected
     * @param feePercentage Fee percentage in basis points
     * @return finalizationFee Fee amount
     * @return penaltiesForDistribution Remaining penalties after fee
     */
    function calculateFinalizationFee(
        uint256 totalPenalties,
        uint256 feePercentage
    ) internal pure returns (uint256 finalizationFee, uint256 penaltiesForDistribution) {
        if (totalPenalties > 0 && feePercentage > 0) {
            finalizationFee = totalPenalties.mulDivDown(
                feePercentage,
                BASIS_POINTS_DIVISOR
            );
            penaltiesForDistribution = totalPenalties - finalizationFee;
        } else {
            finalizationFee = 0;
            penaltiesForDistribution = totalPenalties;
        }

        return (finalizationFee, penaltiesForDistribution);
    }

    /**
     * @notice Update karma for incorrect voters
     * @param voters Array of voter addresses
     * @param votes Mapping of votes
     * @param stakers Mapping of stakers
     * @param consensus Final verdict
     * @param karmaPenalty Karma penalty amount
     */
    function applyKarmaPenalties(
        address[] memory voters,
        mapping(address => VedyxTypes.Vote) storage votes,
        mapping(address => VedyxTypes.Staker) storage stakers,
        bool consensus,
        uint256 karmaPenalty
    ) internal {
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            VedyxTypes.Vote memory vote = votes[voter];
            VedyxTypes.Staker storage staker = stakers[voter];

            bool votedCorrectly = vote.votedFor == consensus;

            if (!votedCorrectly) {
                staker.karmaPoints = staker.karmaPoints - int256(karmaPenalty);
                emit KarmaUpdated(
                    voter,
                    -int256(karmaPenalty),
                    staker.karmaPoints
                );
            }
        }
    }

    /**
     * @notice Distribute rewards to correct voters
     * @param voters Array of voter addresses
     * @param votes Mapping of votes
     * @param stakers Mapping of stakers
     * @param consensus Final verdict
     * @param votingId Voting ID
     * @param karmaReward Karma reward amount
     * @param penaltiesForDistribution Total penalties to distribute
     * @param correctVotersTotalPower Total voting power of correct voters
     */
    function distributeRewards(
        address[] memory voters,
        mapping(address => VedyxTypes.Vote) storage votes,
        mapping(address => VedyxTypes.Staker) storage stakers,
        bool consensus,
        uint256 votingId,
        uint256 karmaReward,
        uint256 penaltiesForDistribution,
        uint256 correctVotersTotalPower
    ) internal {
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            VedyxTypes.Vote memory vote = votes[voter];
            VedyxTypes.Staker storage staker = stakers[voter];

            bool votedCorrectly = vote.votedFor == consensus;

            if (votedCorrectly) {
                // Update karma
                staker.karmaPoints = staker.karmaPoints + int256(karmaReward);
                staker.correctVotes = staker.correctVotes + 1;

                emit KarmaUpdated(
                    voter,
                    int256(karmaReward),
                    staker.karmaPoints
                );

                // Distribute proportional reward from penalties
                if (penaltiesForDistribution > 0 && correctVotersTotalPower > 0) {
                    uint256 voterReward = penaltiesForDistribution.mulDivDown(
                        vote.votingPower,
                        correctVotersTotalPower
                    );

                    if (voterReward > 0) {
                        staker.stakedAmount = staker.stakedAmount + voterReward;
                        emit VoterRewarded(voter, votingId, voterReward);
                    }
                }
            }
        }
    }

    /**
     * @notice Calculate finalization reward for the finalizer
     * @param totalFeesCollected Total fees collected
     * @param rewardPercentage Reward percentage in basis points
     * @return Reward amount
     */
    function calculateFinalizationReward(
        uint256 totalFeesCollected,
        uint256 rewardPercentage
    ) internal pure returns (uint256) {
        if (totalFeesCollected == 0 || rewardPercentage == 0) {
            return 0;
        }

        return totalFeesCollected.mulDivDown(
            rewardPercentage,
            BASIS_POINTS_DIVISOR
        );
    }
}
