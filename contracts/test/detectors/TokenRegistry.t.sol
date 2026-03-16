// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {TokenRegistry} from "../../src/reactive-contracts/detectors/TokenRegistry.sol";

contract TokenRegistryTest is Test {
    TokenRegistry public registry;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    
    address owner;
    address nonOwner = address(0x999);
    
    event TokenConfigured(address indexed tokenAddress, uint8 decimals, string symbol);
    event TokensConfiguredBatch(uint256 count);
    event TokenRemoved(address indexed tokenAddress);
    
    function setUp() public {
        owner = address(this);
        registry = new TokenRegistry();
    }
    
    // ─── Initialization Tests ─────────────────────────────────────────────
    
    function test_Initialization() public view{
        assertEq(registry.DEFAULT_DECIMALS(), 18);
        assertEq(registry.owner(), owner);
        assertEq(registry.getConfiguredTokenCount(), 0);
    }
    
    // ─── Single Token Configuration Tests ────────────────────────────────
    
    function test_ConfigureToken() public {
        vm.expectEmit(true, false, false, true);
        emit TokenConfigured(USDC, 6, "USDC");
        
        registry.configureToken(USDC, 6, "USDC");
        
        (uint8 decimals, bool configured, string memory symbol, uint256 timestamp) = registry.getTokenConfig(USDC);
        assertEq(decimals, 6);
        assertTrue(configured);
        assertEq(symbol, "USDC");
        assertEq(timestamp, block.timestamp);
        assertEq(registry.getConfiguredTokenCount(), 1);
    }
    
    function test_ConfigureToken_UpdateExisting() public {
        registry.configureToken(USDC, 6, "USDC");
        
        vm.expectEmit(true, false, false, true);
        emit TokenConfigured(USDC, 18, "USDC_V2");
        
        registry.configureToken(USDC, 18, "USDC_V2");
        
        (uint8 decimals, bool configured, string memory symbol,) = registry.getTokenConfig(USDC);
        assertEq(decimals, 18);
        assertTrue(configured);
        assertEq(symbol, "USDC_V2");
        assertEq(registry.getConfiguredTokenCount(), 1);
    }
    
    function test_ConfigureToken_EmptySymbol() public {
        registry.configureToken(USDC, 6, "");
        
        (uint8 decimals, bool configured, string memory symbol,) = registry.getTokenConfig(USDC);
        assertEq(decimals, 6);
        assertTrue(configured);
        assertEq(symbol, "");
    }
    
    function test_ConfigureToken_RevertInvalidAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        registry.configureToken(address(0), 6, "ZERO");
    }
    
    function test_ConfigureToken_RevertInvalidDecimals() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidDecimals()"));
        registry.configureToken(USDC, 78, "USDC");
    }
    
    function test_ConfigureToken_RevertNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.configureToken(USDC, 6, "USDC");
    }
    
    // ─── Batch Configuration Tests ────────────────────────────────────────
    
    function test_ConfigureTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = USDT;
        
        uint8[] memory decimals = new uint8[](3);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        
        string[] memory symbols = new string[](3);
        symbols[0] = "USDC";
        symbols[1] = "WETH";
        symbols[2] = "USDT";
        
        vm.expectEmit(true, false, false, true);
        emit TokensConfiguredBatch(3);
        
        registry.configureTokens(tokens, decimals, symbols);
        
        assertEq(registry.getConfiguredTokenCount(), 3);
        
        (uint8 usdcDecimals, bool usdcConfigured, string memory usdcSymbol,) = registry.getTokenConfig(USDC);
        assertEq(usdcDecimals, 6);
        assertTrue(usdcConfigured);
        assertEq(usdcSymbol, "USDC");
        
        (uint8 wethDecimals, bool wethConfigured, string memory wethSymbol,) = registry.getTokenConfig(WETH);
        assertEq(wethDecimals, 18);
        assertTrue(wethConfigured);
        assertEq(wethSymbol, "WETH");
    }
    
    function test_ConfigureTokens_RevertMismatchedArrays() public {
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        
        uint8[] memory decimals = new uint8[](3);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        
        string[] memory symbols = new string[](2);
        symbols[0] = "USDC";
        symbols[1] = "WETH";
        
        vm.expectRevert(abi.encodeWithSignature("InvalidConfiguration()"));
        registry.configureTokens(tokens, decimals, symbols);
    }
    
    function test_ConfigureTokensSimple() public {
        address[] memory tokens = new address[](4);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = USDT;
        tokens[3] = DAI;
        
        uint8[] memory decimals = new uint8[](4);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        decimals[3] = 18;
        
        vm.expectEmit(true, false, false, true);
        emit TokensConfiguredBatch(4);
        
        registry.configureTokensSimple(tokens, decimals);
        
        assertEq(registry.getConfiguredTokenCount(), 4);
        
        (uint8 daiDecimals, bool daiConfigured, string memory daiSymbol,) = registry.getTokenConfig(DAI);
        assertEq(daiDecimals, 18);
        assertTrue(daiConfigured);
        assertEq(daiSymbol, "");
    }
    
    function test_ConfigureTokensSimple_RevertMismatchedArrays() public {
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        
        uint8[] memory decimals = new uint8[](3);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        
        vm.expectRevert(abi.encodeWithSignature("InvalidConfiguration()"));
        registry.configureTokensSimple(tokens, decimals);
    }
    
    // ─── Token Removal Tests ──────────────────────────────────────────────
    
    function test_RemoveToken() public {
        registry.configureToken(USDC, 6, "USDC");
        assertTrue(registry.isConfigured(USDC));
        
        vm.expectEmit(true, false, false, false);
        emit TokenRemoved(USDC);
        
        registry.removeToken(USDC);
        
        assertFalse(registry.isConfigured(USDC));
        (uint8 decimals, bool configured,,) = registry.getTokenConfig(USDC);
        assertEq(decimals, 0);
        assertFalse(configured);
    }
    
    function test_RemoveToken_RevertNotConfigured() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidTokenAddress()"));
        registry.removeToken(USDC);
    }
    
    // ─── Query Tests ──────────────────────────────────────────────────────
    
    function test_GetDecimals_Configured() public {
        registry.configureToken(USDC, 6, "USDC");
        assertEq(registry.getDecimals(USDC), 6);
    }
    
    function test_GetDecimals_Unconfigured() public view{
        assertEq(registry.getDecimals(USDC), 18);
    }
    
    function test_IsConfigured() public {
        assertFalse(registry.isConfigured(USDC));
        
        registry.configureToken(USDC, 6, "USDC");
        assertTrue(registry.isConfigured(USDC));
        
        registry.removeToken(USDC);
        assertFalse(registry.isConfigured(USDC));
    }
    
    function test_GetSymbol() public {
        registry.configureToken(USDC, 6, "USDC");
        assertEq(registry.getSymbol(USDC), "USDC");
        
        assertEq(registry.getSymbol(WETH), "");
    }
    
    function test_GetConfiguredTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = USDT;
        
        uint8[] memory decimals = new uint8[](3);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        
        registry.configureTokensSimple(tokens, decimals);
        
        address[] memory configured = registry.getConfiguredTokens();
        assertEq(configured.length, 3);
        assertEq(configured[0], USDC);
        assertEq(configured[1], WETH);
        assertEq(configured[2], USDT);
    }
    
    function test_GetDecimalsBatch() public {
        address[] memory tokens = new address[](4);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = USDT;
        tokens[3] = DAI;
        
        uint8[] memory decimals = new uint8[](4);
        decimals[0] = 6;
        decimals[1] = 18;
        decimals[2] = 6;
        decimals[3] = 18;
        
        registry.configureTokensSimple(tokens, decimals);
        
        uint8[] memory result = registry.getDecimalsBatch(tokens);
        assertEq(result.length, 4);
        assertEq(result[0], 6);
        assertEq(result[1], 18);
        assertEq(result[2], 6);
        assertEq(result[3], 18);
    }
    
    // ─── Edge Cases ───────────────────────────────────────────────────────
    
    function test_ConfigureToken_MaxDecimals() public {
        registry.configureToken(USDC, 77, "USDC");
        assertEq(registry.getDecimals(USDC), 77);
    }
    
    function test_ConfigureToken_ZeroDecimals() public {
        registry.configureToken(USDC, 0, "USDC");
        assertEq(registry.getDecimals(USDC), 0);
    }
    
    function test_ConfigureTokens_EmptyArrays() public {
        address[] memory tokens = new address[](0);
        uint8[] memory decimals = new uint8[](0);
        string[] memory symbols = new string[](0);
        
        registry.configureTokens(tokens, decimals, symbols);
        assertEq(registry.getConfiguredTokenCount(), 0);
    }
    
    function test_GetDecimalsBatch_EmptyArray() public view{
        address[] memory tokens = new address[](0);
        uint8[] memory result = registry.getDecimalsBatch(tokens);
        assertEq(result.length, 0);
    }
    
    // ─── Fuzz Tests ───────────────────────────────────────────────────────
    
    function testFuzz_ConfigureToken(address token, uint8 decimals, string memory symbol) public {
        vm.assume(token != address(0));
        vm.assume(decimals <= 77);
        
        registry.configureToken(token, decimals, symbol);
        
        assertEq(registry.getDecimals(token), decimals);
        assertTrue(registry.isConfigured(token));
        assertEq(registry.getSymbol(token), symbol);
    }
    
    function testFuzz_GetDecimals_Unconfigured(address token) public view{
        assertEq(registry.getDecimals(token), 18);
    }
}
