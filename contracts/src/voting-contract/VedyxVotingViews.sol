// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VedyxTypes} from "./libraries/VedyxTypes.sol";
import {VotingPowerLib} from "./libraries/VotingPowerLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {VedyxVotingContract} from "./VedyxVotingContract.sol";
import {IVedyxVotingViews} from "./interfaces/IVedyxVotingViews.sol";

/// @notice Separate view helper contract for VedyxVotingContract analytics
contract VedyxVotingViews is IVedyxVotingViews {
    using VotingPowerLib for VedyxTypes.Staker;
    using FixedPointMathLib for uint256;

    uint256 private constant BASIS_POINTS_DIVISOR = 10000;

    VedyxVotingContract public immutable voting;

    constructor(address _voting) {
        require(_voting != address(0), "Invalid voting contract");
        voting = VedyxVotingContract(payable(_voting));
    }

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
        )
    {
        (,report, startTime, endTime, votesFor, votesAgainst,, finalized, isSuspicious, isInconclusive) = voting.votings(votingId);
    }

    function getVote(uint256 votingId, address voter)
        external
        view
        returns (bool hasVoted, bool votedFor, uint256 votingPower)
    {
        (bool _hasVoted, bool _votedFor, uint256 _votingPower,) = voting.voteInfo(votingId, voter);
        return (_hasVoted, _votedFor, _votingPower);
    }

    function getStakerInfo(address stakerAddress) external view returns (VedyxTypes.Staker memory staker) {
        (uint256 stakedAmount, int256 karmaPoints, uint256 totalVotes, uint256 correctVotes, uint256 lockedAmount) =
            voting.stakers(stakerAddress);

        staker = VedyxTypes.Staker({
            stakedAmount: stakedAmount,
            karmaPoints: karmaPoints,
            totalVotes: totalVotes,
            correctVotes: correctVotes,
            lockedAmount: lockedAmount
        });
    }

    function getVotingPower(address voter) external view returns (int256) {
        (uint256 stakedAmount, int256 karmaPoints, uint256 totalVotes, uint256 correctVotes, uint256 lockedAmount) =
            voting.stakers(voter);

        VedyxTypes.Staker memory staker = VedyxTypes.Staker({
            stakedAmount: stakedAmount,
            karmaPoints: karmaPoints,
            totalVotes: totalVotes,
            correctVotes: correctVotes,
            lockedAmount: lockedAmount
        });

        uint256 availableStake = VotingPowerLib.getAvailableStake(staker);
        return VotingPowerLib.calculateVotingPower(availableStake, staker.karmaPoints);
    }

    function getVoterAccuracy(address voter) external view returns (uint256) {
        (,, uint256 totalVotes, uint256 correctVotes,) = voting.stakers(voter);

        if (totalVotes == 0) return 0;
        return correctVotes.mulDivDown(BASIS_POINTS_DIVISOR, totalVotes);
    }

    function getActiveVotings() external view returns (uint256[] memory) {
        uint256 count = voting.activeVotingCount();
        uint256[] memory activeVotings = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            activeVotings[i] = voting.activeVotingIds(i);
        }

        return activeVotings;
    }

    function getAddressVotingHistory(address suspiciousAddress) external view returns (uint256[] memory) {
        uint256 length = voting.addressVotingHistoryLength(suspiciousAddress);
        uint256[] memory history = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            history[i] = voting.addressVotingHistory(suspiciousAddress, i);
        }

        return history;
    }

    function getVoters(uint256 votingId) external view returns (address[] memory) {
        uint256 length = voting.votingVotersLength(votingId);
        address[] memory voters = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            voters[i] = voting.votingVoterAt(votingId, i);
        }

        return voters;
    }

    function getAddressVerdict(address addr)
        external
        view
        returns (
            bool hasVerdict,
            bool isSuspicious,
            uint256 lastVotingId,
            uint256 verdictTimestamp,
            uint256 totalIncidents
        )
    {
        (bool _hasVerdict, bool _isSuspicious, uint256 _lastVotingId, uint256 _verdictTimestamp, uint256 _totalIncidents)
        = voting.addressVerdicts(addr);

        return (_hasVerdict, _isSuspicious, _lastVotingId, _verdictTimestamp, _totalIncidents);
    }

    function willAutoMark(address addr) external view returns (bool) {
        (bool hasVerdict, bool isSuspicious,,,) = voting.addressVerdicts(addr);
        return hasVerdict && isSuspicious;
    }
}
