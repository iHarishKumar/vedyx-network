// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {TracePeelChainDetector} from "../../src/reactive-contracts/detectors/TracePeelChainDetector.sol";
import {TokenRegistry} from "../../src/reactive-contracts/detectors/TokenRegistry.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

/**
 * @title TracePeelChainDetectorTest
 * @notice Comprehensive test suite for stateful peel chain detection
 * @dev Tests pattern tracking, storage cleanup, and gas optimization
 */
contract TracePeelChainDetectorTest is Test {
    TracePeelChainDetector public detector;
    TokenRegistry public registry;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant INITIATOR = address(0x1111);
    address constant PEEL_1 = address(0x2222);
    address constant PEEL_2 = address(0x3333);
    address constant PEEL_3 = address(0x4444);
    address constant CONTINUATION = address(0x5555);
    uint256 constant CHAIN_ID = 1;
    
    event DetectorActivated();
    event DetectorDeactivated();
    event DetectorConfigured(uint64 minPeelPercentage, uint64 maxPeelPercentage, uint64 minPeelCount, uint64 blockWindow);
    event PeelChainDetected(address indexed suspiciousAddress, address indexed token, uint256 chainId, uint256 peelCount, uint256 chainDepth, uint256 averagePeelPercentage);
    event StorageCleanup(address indexed token, address indexed addr, uint256 transfersRemoved);
    
    function setUp() public {
        registry = new TokenRegistry();
        detector = new TracePeelChainDetector(address(registry));
        
        registry.configureToken(USDC, 6, "USDC");
        registry.configureToken(WETH, 18, "WETH");
    }
    
    // ─── Initialization Tests ─────────────────────────────────────────────
    
    function test_Initialization() public view {
        assertTrue(detector.isActive());
        assertEq(detector.getDetectorId(), keccak256("TRACE_PEEL_CHAIN_DETECTOR_V1"));
        assertEq(detector.getMonitoredTopic(), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        assertEq(address(detector.registry()), address(registry));
        
        (uint256 minPeel, uint256 maxPeel, uint256 minCount, uint256 blockWin) = detector.getConfiguration();
        assertEq(minPeel, 500);
        assertEq(maxPeel, 3000);
        assertEq(minCount, 3);
        assertEq(blockWin, 100);
    }
    
    function test_Initialization_RevertInvalidRegistry() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidRegistryAddress()"));
        new TracePeelChainDetector(address(0));
    }
    
    // ─── Configuration Tests ──────────────────────────────────────────────
    
    function test_Configure() public {
        vm.expectEmit(false, false, false, true);
        emit DetectorConfigured(1000, 2000, 5, 200);
        
        detector.configure(1000, 2000, 5, 200);
        
        (uint256 minPeel, uint256 maxPeel, uint256 minCount, uint256 blockWin) = detector.getConfiguration();
        assertEq(minPeel, 1000);
        assertEq(maxPeel, 2000);
        assertEq(minCount, 5);
        assertEq(blockWin, 200);
    }
    
    function test_Configure_RevertMinGreaterThanMax() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidThreshold()"));
        detector.configure(3000, 2000, 3, 100);
    }
    
    function test_Configure_RevertMaxGreaterThan100Percent() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidThreshold()"));
        detector.configure(500, 15000, 3, 100);
    }
    
    function test_Configure_RevertZeroMinCount() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidThreshold()"));
        detector.configure(500, 3000, 0, 100);
    }
    
    function test_Configure_RevertZeroBlockWindow() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidTimeWindow()"));
        detector.configure(500, 3000, 3, 0);
    }
    
    // ─── Activation Tests ─────────────────────────────────────────────────
    
    function test_Activate() public {
        detector.deactivate();
        assertFalse(detector.isActive());
        
        vm.expectEmit(false, false, false, false);
        emit DetectorActivated();
        
        detector.activate();
        assertTrue(detector.isActive());
    }
    
    function test_Deactivate() public {
        assertTrue(detector.isActive());
        
        vm.expectEmit(false, false, false, false);
        emit DetectorDeactivated();
        
        detector.deactivate();
        assertFalse(detector.isActive());
    }
    
    // ─── Stateful Pattern Detection Tests ─────────────────────────────────
    
    function test_Detect_TruePeelChain_ThreePeels() public {
        // Simulate a real peel chain:
        // Address receives 100 USDC
        // Then sends 10 USDC (10%), 10 USDC (10%), 10 USDC (10%) to different addresses
        
        uint256 blockNum = 100;
        
        // Step 1: INITIATOR receives 100 USDC
        IReactive.LogRecord memory log1 = _createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum);
        (bool detected1,,) = detector.detect(log1);
        assertFalse(detected1); // Just receiving, no pattern yet
        
        // Step 2: INITIATOR sends 10 USDC to PEEL_1 (10% peel)
        IReactive.LogRecord memory log2 = _createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1);
        (bool detected2,,) = detector.detect(log2);
        assertFalse(detected2); // Only 1 peel, need 3
        
        // Step 3: INITIATOR sends 10 USDC to PEEL_2 (10% peel)
        IReactive.LogRecord memory log3 = _createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, blockNum + 2);
        (bool detected3,,) = detector.detect(log3);
        assertFalse(detected3); // Only 2 peels, need 3
        
        // Step 4: INITIATOR sends 10 USDC to PEEL_3 (10% peel) - SHOULD TRIGGER
        IReactive.LogRecord memory log4 = _createTransferLog(USDC, INITIATOR, PEEL_3, 10e6, blockNum + 3);
        
        vm.expectEmit(true, true, false, false);
        emit PeelChainDetected(INITIATOR, USDC, CHAIN_ID, 3, 3, 1000);
        
        (bool detected4, address suspicious4,) = detector.detect(log4);
        assertTrue(detected4);
        assertEq(suspicious4, INITIATOR);
    }
    
    function test_Detect_NoPeelChain_OnlyLargeTransfers() public {
        // Address receives and sends large amounts (not peels)
        uint256 blockNum = 100;
        
        // Receive 100 USDC
        IReactive.LogRecord memory log1 = _createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum);
        detector.detect(log1);
        
        // Send 90 USDC (90% - too large to be a peel)
        IReactive.LogRecord memory log2 = _createTransferLog(USDC, INITIATOR, PEEL_1, 90e6, blockNum + 1);
        (bool detected,,) = detector.detect(log2);
        
        assertFalse(detected); // Not a peel pattern
    }
    
    function test_Detect_PeelChain_WithContinuation() public {
        // Realistic peel chain: small peels + large continuation
        uint256 blockNum = 100;
        
        // Receive 1000 USDC
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 1000e6, blockNum));
        
        // Peel 1: 100 USDC (10%)
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 100e6, blockNum + 1));
        
        // Peel 2: 100 USDC (10%)
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 100e6, blockNum + 2));
        
        // Peel 3: 100 USDC (10%) - SHOULD TRIGGER
        (bool detected, address suspicious,) = detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_3, 100e6, blockNum + 3));
        
        assertTrue(detected);
        assertEq(suspicious, INITIATOR);
        
        // Continuation: 700 USDC to next address (not detected, already flagged)
        detector.detect(_createTransferLog(USDC, INITIATOR, CONTINUATION, 700e6, blockNum + 4));
    }
    
    function test_Detect_NoPeelChain_BelowThreshold() public {
        // Only 2 peels, need 3
        uint256 blockNum = 100;
        
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        
        (bool detected,,) = detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, blockNum + 2));
        
        assertFalse(detected); // Only 2 peels
    }
    
    // ─── Edge Cases ───────────────────────────────────────────────────────
    
    function test_Detect_WrongTopic() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, INITIATOR, PEEL_1, 1000e6, 100);
        log.topic_0 = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InsufficientData() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, INITIATOR, PEEL_1, 1000e6, 100);
        log.data = new bytes(16);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InactiveDetector() public {
        detector.deactivate();
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, INITIATOR, PEEL_1, 1000e6, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_ZeroValue() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, INITIATOR, PEEL_1, 0, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    // ─── Storage Cleanup Tests ────────────────────────────────────────────
    
    function test_StorageCleanup_AutomaticCleanup() public {
        uint256 blockNum = 100;
        
        // Create transfers
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        
        // Verify activity tracked
        (uint256 transferCount1,,,) = detector.getAddressActivity(USDC, INITIATOR);
        assertEq(transferCount1, 1);
        
        // Advance past block window (default 100 blocks)
        uint256 futureBlock = blockNum + 150;
        
        // New transfer should trigger cleanup
        vm.expectEmit(true, true, false, true);
        emit StorageCleanup(USDC, INITIATOR, 1);
        
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, futureBlock));
        
        // Old transfer should be cleaned
        (uint256 transferCount2,,,) = detector.getAddressActivity(USDC, INITIATOR);
        assertEq(transferCount2, 1); // Only new transfer
    }
    
    function test_StorageCleanup_AfterDetection() public {
        uint256 blockNum = 100;
        
        // Create peel chain that triggers detection
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, blockNum + 2));
        
        // This should trigger detection AND cleanup
        vm.expectEmit(true, true, false, false);
        emit StorageCleanup(USDC, INITIATOR, 3);
        
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_3, 10e6, blockNum + 3));
        
        // Activity should be cleared
        (uint256 transferCount,,,) = detector.getAddressActivity(USDC, INITIATOR);
        assertEq(transferCount, 0);
    }
    
    function test_ManualCleanup() public {
        uint256 blockNum = 100;
        
        // Create some activity
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        
        (uint256 transferCount1,,,) = detector.getAddressActivity(USDC, INITIATOR);
        assertGt(transferCount1, 0);
        
        // Manual cleanup
        detector.manualCleanup(USDC, INITIATOR);
        
        (uint256 transferCount2,,,) = detector.getAddressActivity(USDC, INITIATOR);
        assertEq(transferCount2, 0);
    }
    
    // ─── Payload Verification Tests ───────────────────────────────────────
    
    function test_Detect_PayloadContainsCorrectData() public {
        uint256 blockNum = 100;
        
        // Create peel chain
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, blockNum + 2));
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, INITIATOR, PEEL_3, 10e6, blockNum + 3);
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, INITIATOR);
        assertTrue(payload.length > 0);
        
        bytes memory payloadData = _skipSelector(payload);
        (address addr, uint256 chainId, address token, uint256 value, uint256 decimals,,) = 
            abi.decode(payloadData, (address, uint256, address, uint256, uint256, uint256, bytes32));
        
        assertEq(addr, INITIATOR);
        assertEq(chainId, CHAIN_ID);
        assertEq(token, USDC);
        assertEq(value, 10e6);
        assertEq(decimals, 6);
    }
    
    // ─── Fuzz Tests ───────────────────────────────────────────────────────
    
    function testFuzz_Configure(uint64 minPeel, uint64 maxPeel, uint64 minCount, uint64 blockWin) public {
        vm.assume(minPeel < maxPeel);
        vm.assume(maxPeel <= 10000);
        vm.assume(minCount > 0 && minCount <= 100);
        vm.assume(blockWin > 0 && blockWin <= 10000);
        
        detector.configure(minPeel, maxPeel, minCount, blockWin);
        
        (uint256 min, uint256 max, uint256 count, uint256 window) = detector.getConfiguration();
        assertEq(min, minPeel);
        assertEq(max, maxPeel);
        assertEq(count, minCount);
        assertEq(window, blockWin);
    }
    
    // ─── Gas Comparison Tests ─────────────────────────────────────────────
    
    function test_Gas_SingleTransferDetection() public {
        uint256 blockNum = 100;
        
        // Measure gas for incoming transfer (records state)
        uint256 gasBefore1 = gasleft();
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        uint256 gasUsed1 = gasBefore1 - gasleft();
        
        // Measure gas for outgoing transfer (analyzes pattern)
        uint256 gasBefore2 = gasleft();
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        uint256 gasUsed2 = gasBefore2 - gasleft();
        
        emit log_named_uint("Gas for incoming transfer", gasUsed1);
        emit log_named_uint("Gas for outgoing transfer", gasUsed2);
    }
    
    function test_Gas_FullPeelChainDetection() public {
        uint256 blockNum = 100;
        
        // Measure total gas for complete peel chain detection
        uint256 gasBefore = gasleft();
        
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, blockNum + 2));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_3, 10e6, blockNum + 3));
        
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Total gas for peel chain detection", gasUsed);
        emit log_string("Stateful pattern tracking with automatic cleanup");
    }
    
    function test_Gas_StorageCleanup() public {
        uint256 blockNum = 100;
        
        // Create old transfers
        detector.detect(_createTransferLog(USDC, address(0x9999), INITIATOR, 100e6, blockNum));
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_1, 10e6, blockNum + 1));
        
        // Measure cleanup gas
        uint256 futureBlock = blockNum + 150;
        uint256 gasBefore = gasleft();
        detector.detect(_createTransferLog(USDC, INITIATOR, PEEL_2, 10e6, futureBlock));
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas with automatic cleanup", gasUsed);
    }
    
    // ─── Helper Functions ─────────────────────────────────────────────────
    
    function _createTransferLog(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 blockNumber
    ) internal pure returns (IReactive.LogRecord memory) {
        bytes memory data = abi.encode(amount);
        
        return IReactive.LogRecord({
            chain_id: CHAIN_ID,
            _contract: token,
            topic_0: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
            topic_1: uint256(uint160(from)),
            topic_2: uint256(uint160(to)),
            topic_3: 0,
            data: data,
            block_number: blockNumber,
            op_code: 0,
            block_hash: uint256(keccak256(abi.encode(blockNumber))),
            tx_hash: uint256(blockNumber),
            log_index: 0
        });
    }
    
    function _skipSelector(bytes memory data) internal pure returns (bytes memory) {
        require(data.length >= 4, "Data too short");
        bytes memory result = new bytes(data.length - 4);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[i + 4];
        }
        return result;
    }
}
