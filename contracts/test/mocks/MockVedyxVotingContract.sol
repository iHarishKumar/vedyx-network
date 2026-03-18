// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VedyxTypes} from "../../src/voting-contract/libraries/VedyxTypes.sol";

/**
 * @title MockVedyxVotingContract
 * @notice Mock voting contract for testing
 */
contract MockVedyxVotingContract {
    struct AddressVerdict {
        bool hasVerdict;
        bool isSuspicious;
        uint256 lastVotingId;
        uint256 verdictTimestamp;
        uint256 totalIncidents;
    }
    
    mapping(address => AddressVerdict) public verdicts;
    
    function setVerdict(
        address addr,
        bool isSuspicious,
        uint256 totalIncidents,
        uint256 timestamp
    ) external {
        verdicts[addr] = AddressVerdict({
            hasVerdict: true,
            isSuspicious: isSuspicious,
            lastVotingId: 1,
            verdictTimestamp: timestamp,
            totalIncidents: totalIncidents
        });
    }
    
    function getAddressVerdict(address addr) external view returns (
        bool hasVerdict,
        bool isSuspicious,
        uint256 lastVotingId,
        uint256 verdictTimestamp,
        uint256 totalIncidents
    ) {
        AddressVerdict memory v = verdicts[addr];
        return (v.hasVerdict, v.isSuspicious, v.lastVotingId, v.verdictTimestamp, v.totalIncidents);
    }
    
    function getVotingDetails(uint256 /* votingId */) external pure returns (
        VedyxTypes.SuspiciousReport memory report,
        uint256 startTime,
        uint256 endTime,
        uint256 votesFor,
        uint256 votesAgainst,
        bool finalized,
        bool isSuspicious,
        bool isInconclusive
    ) {
        // Return empty report and zero votes for mock
        report = VedyxTypes.SuspiciousReport({
            suspiciousAddress: address(0),
            originChainId: 0,
            originContract: address(0),
            detectorId: bytes32(0),
            value: 0,
            decimals: 0,
            txHash: 0
        });
        return (report, 0, 0, 0, 0, false, false, false);
    }
}
