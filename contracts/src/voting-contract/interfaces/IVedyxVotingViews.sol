// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VedyxTypes} from "../libraries/VedyxTypes.sol";

/// @notice Extended view interface for Vedyx voting analytics and queries
interface IVedyxVotingViews {
    // Core voting views
    function getVotingDetails(uint256 votingId)
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

    function getVote(uint256 votingId, address voter)
        external
        view
        returns (bool hasVoted, bool votedFor, uint256 votingPower);

    // Staker analytics
    function getStakerInfo(address staker) external view returns (VedyxTypes.Staker memory);

    function getVotingPower(address voter) external view returns (int256);

    function getVoterAccuracy(address voter) external view returns (uint256);

    // Collections
    function getActiveVotings() external view returns (uint256[] memory);

    function getAddressVotingHistory(address suspiciousAddress) external view returns (uint256[] memory);

    function getVoters(uint256 votingId) external view returns (address[] memory);

    // Verdict views
    function getAddressVerdict(address addr)
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
}
