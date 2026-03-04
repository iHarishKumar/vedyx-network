// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {LargeTransferDetector} from "../../src/reactive-contracts/detectors/LargeTransferDetector.sol";
import {TokenRegistry} from "../../src/reactive-contracts/detectors/TokenRegistry.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

contract LargeTransferDetectorTest is Test {
    LargeTransferDetector public detector;
    TokenRegistry public registry;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SENDER = address(0x1111);
    address constant RECIPIENT = address(0x2222);
    uint256 constant CHAIN_ID = 1;
    
    event TokenThresholdConfigured(address indexed tokenAddress, uint256 threshold);
    event DetectorActivated();
    event DetectorDeactivated();
    
    function setUp() public {
        registry = new TokenRegistry();
        detector = new LargeTransferDetector(address(registry));
        
        // Configure tokens in registry
        registry.configureToken(USDC, 6, "USDC");
        registry.configureToken(WETH, 18, "WETH");
    }
    
    // ─── Initialization Tests ─────────────────────────────────────────────
    
    function test_Initialization() public {
        assertTrue(detector.isActive());
        assertEq(detector.getDetectorId(), keccak256("LARGE_TRANSFER_DETECTOR_V1"));
        assertEq(detector.getMonitoredTopic(), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        assertEq(detector.getDefaultThreshold(), 1000);
        assertEq(address(detector.registry()), address(registry));
    }
    
    function test_Initialization_RevertInvalidRegistry() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidRegistryAddress()"));
        new LargeTransferDetector(address(0));
    }
    
    // ─── Threshold Configuration Tests ────────────────────────────────────
    
    function test_ConfigureTokenThreshold() public {
        vm.expectEmit(true, false, false, true);
        emit TokenThresholdConfigured(USDC, 100_000e6);
        
        detector.configureTokenThreshold(USDC, 100_000e6);
        
        (uint256 threshold, bool configured) = detector.getTokenThreshold(USDC);
        assertEq(threshold, 100_000e6);
        assertTrue(configured);
        assertEq(detector.getEffectiveThreshold(USDC), 100_000e6);
    }
    
    function test_ConfigureTokenThreshold_Update() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        detector.configureTokenThreshold(USDC, 200_000e6);
        
        (uint256 threshold, bool configured) = detector.getTokenThreshold(USDC);
        assertEq(threshold, 200_000e6);
        assertTrue(configured);
    }
    
    function test_ConfigureTokenThreshold_RevertInvalidAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        detector.configureTokenThreshold(address(0), 100_000e6);
    }
    
    function test_ConfigureTokenThreshold_RevertZeroThreshold() public {
        vm.expectRevert(abi.encodeWithSignature("ThresholdMustBeGreaterThanZero()"));
        detector.configureTokenThreshold(USDC, 0);
    }
    
    function test_RemoveTokenThreshold() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        assertTrue(detector.getEffectiveThreshold(USDC) == 100_000e6);
        
        detector.removeTokenThreshold(USDC);
        
        (uint256 threshold, bool configured) = detector.getTokenThreshold(USDC);
        assertEq(threshold, 0);
        assertFalse(configured);
        assertEq(detector.getEffectiveThreshold(USDC), 1000);
    }
    
    function test_RemoveTokenThreshold_RevertNotConfigured() public {
        vm.expectRevert(abi.encodeWithSignature("TokenNotConfigured()"));
        detector.removeTokenThreshold(USDC);
    }
    
    function test_GetEffectiveThreshold_Default() public {
        assertEq(detector.getEffectiveThreshold(USDC), 1000);
    }
    
    function test_GetEffectiveThreshold_Configured() public {
        detector.configureTokenThreshold(USDC, 50_000e6);
        assertEq(detector.getEffectiveThreshold(USDC), 50_000e6);
    }
    
    // ─── Detection Tests ──────────────────────────────────────────────────
    
    function test_Detect_LargeTransfer_AboveDefaultThreshold() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 2000e6, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, SENDER);
        assertTrue(payload.length > 0);
        
        // Verify payload contains correct data (skip first 4 bytes which is function selector)
        bytes memory payloadData = _skipSelector(payload);
        (address addr, uint256 chainId, address token, uint256 value, uint256 decimals,,) = 
            abi.decode(payloadData, (address, uint256, address, uint256, uint256, uint256, bytes32));
        assertEq(addr, SENDER);
        assertEq(chainId, CHAIN_ID);
        assertEq(token, USDC);
        assertEq(value, 2000e6);
        assertEq(decimals, 6);
    }
    
    function test_Detect_LargeTransfer_AboveConfiguredThreshold() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 150_000e6, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, SENDER);
        assertTrue(payload.length > 0);
    }
    
    function test_Detect_SmallTransfer_BelowThreshold() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 50_000e6, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertFalse(detected);
        assertEq(suspicious, address(0));
        assertEq(payload.length, 0);
    }
    
    function test_Detect_ExactThreshold() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 100_000e6, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertTrue(detected);
    }
    
    function test_Detect_WrongTopic() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 2000e6, 100);
        log.topic_0 = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InsufficientData() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 2000e6, 100);
        log.data = new bytes(16);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InactiveDetector() public {
        detector.deactivate();
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 2000e6, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_UsesRegistryDecimals() public {
        detector.configureTokenThreshold(WETH, 100e18);
        
        IReactive.LogRecord memory log = _createTransferLog(WETH, SENDER, RECIPIENT, 150e18, 100);
        
        (bool detected,, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        
        bytes memory payloadData = _skipSelector(payload);
        (,,,, uint256 decimals,,) = abi.decode(payloadData, (address, uint256, address, uint256, uint256, uint256, bytes32));
        assertEq(decimals, 18);
    }
    
    function test_Detect_UnconfiguredToken_UsesDefaultDecimals() public {
        address unknownToken = address(0x9999);
        
        IReactive.LogRecord memory log = _createTransferLog(unknownToken, SENDER, RECIPIENT, 2000, 100);
        
        (bool detected,, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        
        bytes memory payloadData = _skipSelector(payload);
        (,,,, uint256 decimals,,) = abi.decode(payloadData, (address, uint256, address, uint256, uint256, uint256, bytes32));
        assertEq(decimals, 18);
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
    
    // ─── Edge Cases ───────────────────────────────────────────────────────
    
    function test_Detect_ZeroValue() public {
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, 0, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_MaxUint256() public {
        detector.configureTokenThreshold(USDC, type(uint256).max - 1);
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, type(uint256).max, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertTrue(detected);
    }
    
    function test_ConfigureTokenThreshold_MultipleTokens() public {
        detector.configureTokenThreshold(USDC, 100_000e6);
        detector.configureTokenThreshold(WETH, 50e18);
        
        assertEq(detector.getEffectiveThreshold(USDC), 100_000e6);
        assertEq(detector.getEffectiveThreshold(WETH), 50e18);
    }
    
    // ─── Fuzz Tests ───────────────────────────────────────────────────────
    
    function testFuzz_ConfigureTokenThreshold(address token, uint256 threshold) public {
        vm.assume(token != address(0));
        vm.assume(threshold > 0);
        
        detector.configureTokenThreshold(token, threshold);
        
        assertEq(detector.getEffectiveThreshold(token), threshold);
    }
    
    function testFuzz_Detect_ThresholdComparison(uint256 value, uint256 threshold) public {
        vm.assume(threshold > 0 && threshold < type(uint256).max);
        
        detector.configureTokenThreshold(USDC, threshold);
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, SENDER, RECIPIENT, value, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertEq(detected, value >= threshold);
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
