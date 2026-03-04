// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {MixerInteractionDetector} from "../../src/reactive-contracts/detectors/MixerInteractionDetector.sol";
import {TokenRegistry} from "../../src/reactive-contracts/detectors/TokenRegistry.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";

contract MixerInteractionDetectorTest is Test {
    MixerInteractionDetector public detector;
    TokenRegistry public registry;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // Use addresses not in the default list for testing
    address constant TORNADO_CASH = 0x47CE0C6eD5B0Ce3d3A51fdb1C52DC66a7c3c2936; // Already in default list
    address constant MIXER_2 = 0x910Cbd523D972eb0a6f4cAe4618aD62622b39DbF; // Already in default list
    address constant NEW_MIXER = address(0x9999); // Not in default list
    address constant REGULAR_USER = address(0x1111);
    address constant RECIPIENT = address(0x2222);
    uint256 constant CHAIN_ID = 1;
    
    event MixerRegistered(address indexed mixerAddress, string name, uint256 timestamp);
    event MixerRemoved(address indexed mixerAddress);
    event DetectorActivated();
    event DetectorDeactivated();
    
    function setUp() public {
        registry = new TokenRegistry();
        detector = new MixerInteractionDetector(address(registry));
        
        registry.configureToken(USDC, 6, "USDC");
        registry.configureToken(WETH, 18, "WETH");
    }
    
    // ─── Initialization Tests ─────────────────────────────────────────────
    
    function test_Initialization() public view {
        assertTrue(detector.isActive());
        assertEq(detector.getDetectorId(), keccak256("MIXER_INTERACTION_DETECTOR_V1"));
        assertEq(detector.getMonitoredTopic(), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        assertEq(address(detector.registry()), address(registry));
        // 12 default Tornado Cash mixers are pre-registered
        assertEq(detector.getMixerCount(), 12);
    }
    
    function test_Initialization_RevertInvalidRegistry() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidRegistryAddress()"));
        new MixerInteractionDetector(address(0));
    }
    
    // ─── Mixer Registration Tests ─────────────────────────────────────────
    
    function test_RegisterMixer() public {
        vm.expectEmit(true, false, false, true);
        emit MixerRegistered(NEW_MIXER, "New Mixer", block.timestamp);
        
        detector.registerMixer(NEW_MIXER, "New Mixer");
        
        assertTrue(detector.isMixer(NEW_MIXER));
        assertEq(detector.getMixerCount(), 13); // 12 default + 1 new
        
        (bool isRegistered, string memory name, uint256 timestamp) = detector.getMixerInfo(NEW_MIXER);
        assertTrue(isRegistered);
        assertEq(name, "New Mixer");
        assertEq(timestamp, block.timestamp);
    }
    
    function test_RegisterMixer_Multiple() public {
        address mixer3 = address(0x8888);
        detector.registerMixer(NEW_MIXER, "New Mixer");
        detector.registerMixer(mixer3, "Mixer 3");
        
        assertEq(detector.getMixerCount(), 14); // 12 default + 2 new
        assertTrue(detector.isMixer(NEW_MIXER));
        assertTrue(detector.isMixer(mixer3));
    }
    
    function test_RegisterMixer_RevertAlreadyRegistered() public {
        detector.registerMixer(NEW_MIXER, "New Mixer");
        
        // Trying to register again should revert
        vm.expectRevert(abi.encodeWithSignature("MixerAlreadyRegistered()"));
        detector.registerMixer(NEW_MIXER, "New Mixer Updated");
    }
    
    function test_RegisterMixer_RevertInvalidAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidMixerAddress()"));
        detector.registerMixer(address(0), "Zero Address");
    }
    
    function test_RegisterMixer_EmptyName() public {
        detector.registerMixer(NEW_MIXER, "");
        
        (bool isRegistered, string memory name,) = detector.getMixerInfo(NEW_MIXER);
        assertTrue(isRegistered);
        assertEq(name, "");
    }
    
    function test_RegisterMixerBatch() public {
        address[] memory mixers = new address[](2);
        mixers[0] = NEW_MIXER;
        mixers[1] = address(0x8888);
        
        string[] memory names = new string[](2);
        names[0] = "New Mixer";
        names[1] = "Mixer 3";
        
        detector.registerMixerBatch(mixers, names);
        
        assertEq(detector.getMixerCount(), 14); // 12 default + 2 new
        assertTrue(detector.isMixer(NEW_MIXER));
        assertTrue(detector.isMixer(address(0x8888)));
    }
    
    function test_RegisterMixerBatch_RevertMismatchedArrays() public {
        address[] memory mixers = new address[](2);
        mixers[0] = NEW_MIXER;
        mixers[1] = address(0x8888);
        
        string[] memory names = new string[](1);
        names[0] = "Tornado Cash";
        
        vm.expectRevert("Array length mismatch");
        detector.registerMixerBatch(mixers, names);
    }
    
    function test_GetAllMixers() public {
        address[] memory mixers = detector.getAllMixers();
        // Should have 12 default mixers
        assertEq(mixers.length, 12);
        // First mixer should be the first default Tornado Cash instance
        assertEq(mixers[0], 0x12D66f87A04A9E220743712cE6d9bB1B5616B8Fc);
    }
    
    // ─── Detection Tests: Withdrawal from Mixer ───────────────────────────
    
    function test_Detect_WithdrawalFromMixer() public view {
        // TORNADO_CASH is already in default list, no need to register
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, RECIPIENT);
        assertTrue(payload.length > 0);
    }
    
    // ─── Detection Tests: Deposit to Mixer ────────────────────────────────
    
    function test_Detect_DepositToMixer() public view {
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(WETH, REGULAR_USER, TORNADO_CASH, 10e18, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, REGULAR_USER);
        assertTrue(payload.length > 0);
    }
    
    // ─── Detection Tests: No Mixer Interaction ────────────────────────────
    
    function test_Detect_NoMixerInteraction() public view {
        // TORNADO_CASH is already in default list, but this transfer doesn't involve it
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, REGULAR_USER, RECIPIENT, 100e6, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertFalse(detected);
        assertEq(suspicious, address(0));
        assertEq(payload.length, 0);
    }
    
    function test_Detect_WithDefaultMixers() public view {
        // TORNADO_CASH is in the default list, so it should detect
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        
        (bool detected, address suspicious,) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, RECIPIENT);
    }
    
    // ─── Detection Tests: Edge Cases ──────────────────────────────────────
    
    function test_Detect_WrongTopic() public view {
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        log.topic_0 = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InsufficientData() public view {
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        log.data = new bytes(16);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_InactiveDetector() public {
        // TORNADO_CASH is already in default list
        detector.deactivate();
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        
        (bool detected,,) = detector.detect(log);
        
        assertFalse(detected);
    }
    
    function test_Detect_ZeroValue() public view {
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 0, 100);
        
        (bool detected, address suspicious,) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, RECIPIENT);
    }
    
    function test_Detect_UnconfiguredToken_UsesDefaultDecimals() public view {
        // TORNADO_CASH is already in default list
        address unknownToken = address(0x9999);
        
        IReactive.LogRecord memory log = _createTransferLog(unknownToken, TORNADO_CASH, RECIPIENT, 100e18, 100);
        
        (bool detected, address suspicious, bytes memory payload) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, RECIPIENT);
        assertTrue(payload.length > 0);
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
    
    // ─── Multiple Mixer Scenarios ─────────────────────────────────────────
    
    function test_Detect_MultipleMixers_DifferentInteractions() public view {
        // Both TORNADO_CASH and MIXER_2 are already in default list
        
        IReactive.LogRecord memory log1 = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, 100e6, 100);
        (bool detected1, address suspicious1,) = detector.detect(log1);
        assertTrue(detected1);
        assertEq(suspicious1, RECIPIENT);
        
        IReactive.LogRecord memory log2 = _createTransferLog(WETH, REGULAR_USER, MIXER_2, 5e18, 101);
        (bool detected2, address suspicious2,) = detector.detect(log2);
        assertTrue(detected2);
        assertEq(suspicious2, REGULAR_USER);
    }
    
    function test_Detect_MixerToMixer() public view {
        // Both TORNADO_CASH and MIXER_2 are already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, MIXER_2, 100e6, 100);
        
        (bool detected, address suspicious,) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, MIXER_2);
    }
    
    // ─── Fuzz Tests ───────────────────────────────────────────────────────
    
    function testFuzz_RegisterMixer(address mixer, string memory name) public {
        vm.assume(mixer != address(0));
        vm.assume(!detector.isMixer(mixer)); // Skip if already registered
        
        uint256 countBefore = detector.getMixerCount();
        detector.registerMixer(mixer, name);
        
        assertTrue(detector.isMixer(mixer));
        assertEq(detector.getMixerCount(), countBefore + 1);
    }
    
    function testFuzz_Detect_Withdrawal(uint256 amount) public view {
        vm.assume(amount > 0);
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, TORNADO_CASH, RECIPIENT, amount, 100);
        
        (bool detected, address suspicious,) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, RECIPIENT);
    }
    
    function testFuzz_Detect_Deposit(uint256 amount) public view {
        vm.assume(amount > 0);
        // TORNADO_CASH is already in default list
        
        IReactive.LogRecord memory log = _createTransferLog(USDC, REGULAR_USER, TORNADO_CASH, amount, 100);
        
        (bool detected, address suspicious,) = detector.detect(log);
        
        assertTrue(detected);
        assertEq(suspicious, REGULAR_USER);
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
