// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title VedyxErrors
 * @notice Custom errors for the Vedyx Voting system
 */
library VedyxErrors {
    // ─── Staking Errors ───────────────────────────────────────────────────
    error InvalidAmount();
    error InsufficientStake();
    error NoStakeToWithdraw();
    error CannotUnstakeWhenVotingIsActive();

    // ─── Voting Errors ────────────────────────────────────────────────────
    error VotingNotActive();
    error VotingAlreadyEnded();
    error VotingStillActive();
    error AlreadyVoted();
    error InvalidVotingId();
    error InsufficientVotingPower();
    error CannotVoteOnOwnAddress();

    // ─── Access Control Errors ────────────────────────────────────────────
    error UnauthorizedCallback();
    error InvalidAddress();

    // ─── Fee & Treasury Errors ────────────────────────────────────────────
    error InvalidFeePercentage();
    error InvalidTreasury();
    error InsufficientFeesForReward();

    // ─── Karma Errors ─────────────────────────────────────────────────────
    error InsufficientKarma();

    // ─── Verdict Errors ───────────────────────────────────────────────────
    error NoVerdictToClear();
}
