// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {VedyxExploitDetectorRSC} from "../src/reactive-contracts/VedyxExploitDetectorRSC.sol";
import {IAttackVectorDetector} from "../src/reactive-contracts/interfaces/IAttackVectorDetector.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

contract TestDetect is Script {
    function run() external {
        VedyxExploitDetectorRSC rsc = VedyxExploitDetectorRSC(payable(0x56211723990ff8AA552Fba1F78d5260959b6cb45));
        
        bytes memory data = abi.encode(uint256(15000));
        
        IReactive.LogRecord memory log = IReactive.LogRecord({
            chain_id: 1301,
            _contract: 0x0A0b85243Dd302eC8e386b5B0C76395961c9CB34,
            topic_0: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
            topic_1: uint256(uint160(0x9302E18849F286bE2C1A76179AdE8E76953F5f4B)),
            topic_2: uint256(uint160(0xEfA074a29cBFe0B700440bbace6A10f306628da5)),
            topic_3: 0x0,
            data: data,
            block_number: 47085441,
            op_code: 3,
            block_hash: uint256(keccak256(abi.encode(uint256(100)))),
            tx_hash: 100,
            log_index: 0
        });
        
        bytes32  LARGE_TRANSFER_DETECTOR_ID = keccak256("LARGE_TRANSFER_DETECTOR_V1");
        bytes32  MIXER_INTERACTION_DETECTOR_ID = keccak256("MIXER_INTERACTION_DETECTOR_V1");
        bytes32  TRACE_PEEL_CHAIN_DETECTOR_ID = keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1");

        console2.log("Large Transfer Detector ID:");
        console2.logBytes32(LARGE_TRANSFER_DETECTOR_ID);
        console2.log("Mixer Interaction Detector ID:");
        console2.logBytes32(MIXER_INTERACTION_DETECTOR_ID);
        console2.log("Trace Peel Chain Detector ID:");
        console2.logBytes32(TRACE_PEEL_CHAIN_DETECTOR_ID);

        console.log("=== Simulating VedyxExploitDetectorRSC.react() Flow ===");
        console.log("RSC Address:", address(rsc));
        console.log("Origin Chain:", log.chain_id);
        console.log("Token:", log._contract);
        console.log("Amount: 2000 USDC (2000000000)");
        console.log("");
        
        IAttackVectorDetector[] memory detectors = rsc.getDetectorsByTopic(log.topic_0);
        console.log("Registered detectors:", detectors.length);
        console.log("Callback address: ", rsc.getCallback());
        
        if (detectors.length == 0) {
            console.log("ERROR: No detectors registered!");
            return;
        }
        
        for (uint256 i = 0; i < detectors.length; i++) {
            IAttackVectorDetector detector = detectors[i];
            console.log("");
            console.log("Testing detector", i + 1, ":", address(detector));
            
            if (!detector.isActive()) {
                console.log("  Status: INACTIVE");
                continue;
            }
            
            (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
            
            console.log("  Status: ACTIVE");
            console.log("  Detected:", detected);
            
            if (detected) {
                console.log("  Suspicious:", suspicious);
                console.log("  Payload length:", payload.length);
                console.log("");
                console.log("SUCCESS! Threat detected - Callback would be emitted to Unichain Sepolia (1301)");
                return;
            }
        }
        
        console.log("");
        console.log("No threats detected");
    }
}
