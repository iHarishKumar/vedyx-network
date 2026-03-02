// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {VedyxTypes} from "./VedyxTypes.sol";

/**
 * @title VotingPowerLib
 * @notice Library for calculating voting power with karma effects
 */
library VotingPowerLib {
    using FixedPointMathLib for uint256;

    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant KARMA_BONUS_DIVISOR = 10000;
    uint256 private constant KARMA_PENALTY_DIVISOR = 100000;
    uint256 private constant KARMA_OVERFLOW_THRESHOLD = 10000;
    uint256 private constant MAX_SQUARED_KARMA = 100000000;

    /**
     * @notice Calculate voting power based on available stake and karma
     * @param availableStake Available (unlocked) stake amount
     * @param karmaPoints Current karma points
     * @return Voting power as signed integer (can be negative)
     */
    function calculateVotingPower(
        uint256 availableStake,
        int256 karmaPoints
    ) internal pure returns (int256) {
        int256 basePower = int256(availableStake);
        int256 karmaEffect = calculateKarmaEffect(availableStake, karmaPoints);
        return basePower + karmaEffect;
    }

    /**
     * @notice Calculate karma effect on voting power
     * @param stakeAmount Stake amount to apply karma to
     * @param karmaPoints Current karma points
     * @return Karma effect (positive for bonus, negative for penalty)
     */
    function calculateKarmaEffect(
        uint256 stakeAmount,
        int256 karmaPoints
    ) internal pure returns (int256) {
        if (karmaPoints >= 0) {
            return calculateLinearBonus(stakeAmount, karmaPoints);
        } else {
            return calculateExponentialPenalty(stakeAmount, karmaPoints);
        }
    }

    /**
     * @notice Calculate linear bonus for positive karma
     * @param stakeAmount Stake amount
     * @param karmaPoints Positive karma points
     * @return Bonus amount
     */
    function calculateLinearBonus(
        uint256 stakeAmount,
        int256 karmaPoints
    ) internal pure returns (int256) {
        return int256(
            stakeAmount.mulDivDown(uint256(karmaPoints), KARMA_BONUS_DIVISOR)
        );
    }

    /**
     * @notice Calculate exponential penalty for negative karma
     * @param stakeAmount Stake amount
     * @param karmaPoints Negative karma points
     * @return Penalty amount (negative)
     */
    function calculateExponentialPenalty(
        uint256 stakeAmount,
        int256 karmaPoints
    ) internal pure returns (int256) {
        uint256 absKarma = uint256(-karmaPoints);

        uint256 squaredKarma = absKarma > KARMA_OVERFLOW_THRESHOLD
            ? MAX_SQUARED_KARMA
            : (absKarma * absKarma);

        uint256 penaltyAmount = stakeAmount.mulDivDown(
            squaredKarma,
            KARMA_PENALTY_DIVISOR
        );

        return -int256(penaltyAmount);
    }

    /**
     * @notice Get available stake for a staker
     * @param staker Staker information
     * @return Available (unlocked) stake amount
     */
    function getAvailableStake(
        VedyxTypes.Staker memory staker
    ) internal pure returns (uint256) {
        return staker.stakedAmount > staker.lockedAmount
            ? staker.stakedAmount - staker.lockedAmount
            : 0;
    }

    /**
     * @notice Check if staker has sufficient karma to vote
     * @param karmaPoints Current karma points
     * @param minimumKarma Minimum required karma
     * @return True if karma is sufficient
     */
    function hasSufficientKarma(
        int256 karmaPoints,
        int256 minimumKarma
    ) internal pure returns (bool) {
        return karmaPoints >= minimumKarma;
    }
}
