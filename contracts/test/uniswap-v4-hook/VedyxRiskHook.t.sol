// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Deployers} from "../../lib/v4-core/test/utils/Deployers.sol";
import {VedyxRiskHook} from "../../src/uniswap-v4-hook/VedyxRiskHook.sol";
import {IVedyxRiskHook} from "../../src/uniswap-v4-hook/interfaces/IVedyxRiskHook.sol";
import {IVedyxRiskEngine} from "../../src/risk-engine/interfaces/IVedyxRiskEngine.sol";
import {VedyxRiskEngine} from "../../src/risk-engine/VedyxRiskEngine.sol";
import {MockVedyxVotingContract} from "../mocks/MockVedyxVotingContract.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/**
 * @title StakingToken
 * @notice Mock staking token for testing
 */
contract StakingToken is ERC20 {
    constructor() ERC20("Vedyx Staking Token", "vVDX") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VedyxRiskHookTest
 * @notice Comprehensive tests for VedyxRiskHook with full beforeSwap, beforeAddLiquidity, beforeRemoveLiquidity coverage
 */
contract VedyxRiskHookTest is Test, Deployers {
    using CurrencyLibrary for Currency;
    
    VedyxRiskHook public hook;
    VedyxRiskEngine public riskEngine;
    MockVedyxVotingContract public votingContract;
    
    // Tokens
    StakingToken public stakingToken;
    Currency public ethCurrency;
    Currency public stakingCurrency;
    
    address public owner = address(0x9999);
    address public safeUser = address(0x100);
    address public lowRiskUser = address(0x200);
    address public mediumRiskUser = address(0x300);
    address public highRiskUser = address(0x400);
    address public criticalRiskUser = address(0x500);
    
    // Fee constants (basis points)
    uint24 constant SAFE_FEE = 10000;      // 1%
    uint24 constant LOW_FEE = 30000;       // 3%
    uint24 constant MEDIUM_FEE = 80000;    // 8%
    uint24 constant HIGH_FEE = 150000;     // 15%
    uint24 constant CRITICAL_FEE = 300000; // 30%
    
    // Test pool key (ETH/StakingToken)
    PoolKey public testPoolKey;
    PoolKey public poolKey;
    
    // Events to test
    event SwapBlocked(address indexed user, IVedyxRiskEngine.RiskLevel riskLevel, uint8 riskScore);
    event DynamicFeeApplied(address indexed user, uint24 fee, IVedyxRiskEngine.RiskLevel riskLevel, uint8 riskScore);
    event LiquidityBlocked(address indexed user, bool isAddLiquidity, IVedyxRiskEngine.RiskLevel riskLevel);
    event FeeConfigUpdated(IVedyxRiskHook.FeeConfig newConfig);
    event HookConfigUpdated(IVedyxRiskHook.HookConfig newConfig);
    event RiskEngineUpdated(address indexed newRiskEngine);
    
    function setUp() public {
        // Deploy Uniswap V4 core contracts (PoolManager, routers, etc.)
        deployFreshManagerAndRouters();
        
        // Deploy voting contract
        votingContract = new MockVedyxVotingContract();
        
        // Deploy risk engine
        riskEngine = new VedyxRiskEngine(address(votingContract));
        
        // Deploy staking token
        stakingToken = new StakingToken();
        
        // Setup currencies (ETH as token0, StakingToken as token1)
        ethCurrency = Currency.wrap(address(0));
        stakingCurrency = Currency.wrap(address(stakingToken));
        
        // Ensure proper ordering (currency0 < currency1)
        (Currency currency0, Currency currency1) = ethCurrency < stakingCurrency 
            ? (ethCurrency, stakingCurrency) 
            : (stakingCurrency, ethCurrency);
        
        // Deploy hook to an address that has the proper flags set
        // Flags needed: beforeSwap, beforeAddLiquidity, beforeRemoveLiquidity
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | 
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        
        deployCodeTo(
            "VedyxRiskHook.sol",
            abi.encode(manager, address(riskEngine), owner),
            address(flags)
        );
        
        hook = VedyxRiskHook(address(flags));
        
        // Setup test pool key with ETH and StakingToken
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(flags))
        });
        
        testPoolKey = poolKey;
        
        // Initialize the pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);
        
        // Setup test users with different risk levels
        _setupTestUsers();
        
        // Mint tokens to test users
        _mintTokensToUsers();
    }
    
    function _mintTokensToUsers() internal {
        // Mint staking tokens to test users
        stakingToken.mint(safeUser, 1000 ether);
        stakingToken.mint(lowRiskUser, 1000 ether);
        stakingToken.mint(mediumRiskUser, 1000 ether);
        stakingToken.mint(highRiskUser, 1000 ether);
        stakingToken.mint(criticalRiskUser, 1000 ether);
        
        // Give ETH to test users
        vm.deal(safeUser, 100 ether);
        vm.deal(lowRiskUser, 100 ether);
        vm.deal(mediumRiskUser, 100 ether);
        vm.deal(highRiskUser, 100 ether);
        vm.deal(criticalRiskUser, 100 ether);
    }
    
    function _setupTestUsers() internal {
        // SAFE user - no verdict
        // (default state)
        
        // LOW risk user - 1 incident, suspicious verdict
        votingContract.setVerdict(lowRiskUser, true, 1, block.timestamp);
        
        // MEDIUM risk user - 3 incidents, suspicious verdict
        votingContract.setVerdict(mediumRiskUser, true, 3, block.timestamp);
        
        // HIGH risk user - 5 incidents, suspicious verdict
        votingContract.setVerdict(highRiskUser, true, 5, block.timestamp);
        
        // CRITICAL risk user - 10 incidents, suspicious verdict
        votingContract.setVerdict(criticalRiskUser, true, 10, block.timestamp);
    }
    
    // ─── Deployment Tests ─────────────────────────────────────────────────
    
    function test_Deployment() public view {
        assertEq(address(hook.poolManager()), address(manager));
        assertEq(address(hook.riskEngine()), address(riskEngine));
        assertEq(hook.owner(), owner);
        
        IVedyxRiskHook.FeeConfig memory feeConfig = hook.getFeeConfig();
        assertEq(feeConfig.safeFee, SAFE_FEE);
        assertEq(feeConfig.lowFee, LOW_FEE);
        assertEq(feeConfig.mediumFee, MEDIUM_FEE);
        assertEq(feeConfig.highFee, HIGH_FEE);
        assertEq(feeConfig.criticalFee, CRITICAL_FEE);
        
        IVedyxRiskHook.HookConfig memory hookConfig = hook.getHookConfig();
        assertTrue(hookConfig.blockHighRisk);
        assertTrue(hookConfig.blockCritical);
        assertTrue(hookConfig.dynamicSwapFees);
        assertTrue(hookConfig.dynamicLPFees);
    }
    
    function test_Deployment_RevertsOnZeroPoolManager() public {
        vm.expectRevert(VedyxRiskHook.ZeroPoolManager.selector);
        new VedyxRiskHook(IPoolManager(address(0)), address(riskEngine), owner);
    }
    
    function test_Deployment_RevertsOnZeroRiskEngine() public {
        vm.expectRevert(VedyxRiskHook.ZeroRiskEngine.selector);
        new VedyxRiskHook(manager, address(0), owner);
    }
    
    function test_Deployment_RevertsOnZeroOwner() public {
        vm.expectRevert(VedyxRiskHook.ZeroOwner.selector);
        new VedyxRiskHook(manager, address(riskEngine), address(0));
    }
    
    function test_PoolConfiguration() public view {
        // Verify pool is configured with ETH and StakingToken
        assertTrue(Currency.unwrap(poolKey.currency0) == address(0) || Currency.unwrap(poolKey.currency0) == address(stakingToken));
        assertTrue(Currency.unwrap(poolKey.currency1) == address(0) || Currency.unwrap(poolKey.currency1) == address(stakingToken));
        assertEq(poolKey.fee, 3000);
        assertEq(poolKey.tickSpacing, 60);
    }
    
    // ─── Swap Fee Tests ───────────────────────────────────────────────────
    
    function test_GetSwapFee_SafeUser() public view {
        uint24 fee = hook.getSwapFee(safeUser);
        assertEq(fee, SAFE_FEE, "SAFE user should pay 1% fee");
    }
    
    function test_GetSwapFee_LowRiskUser() public view{
        uint24 fee = hook.getSwapFee(lowRiskUser);
        assertEq(fee, HIGH_FEE, "User with 1 incident gets HIGH risk (score 65)");
    }
    
    function test_GetSwapFee_MediumRiskUser() public view{
        uint24 fee = hook.getSwapFee(mediumRiskUser);
        assertEq(fee, CRITICAL_FEE, "User with 3 incidents gets CRITICAL risk (score 80)");
    }
    
    function test_GetSwapFee_HighRiskUser() public view{
        uint24 fee = hook.getSwapFee(highRiskUser);
        assertEq(fee, CRITICAL_FEE, "User with 5 incidents gets CRITICAL risk (score 90)");
    }
    
    function test_GetSwapFee_CriticalRiskUser() public view{
        uint24 fee = hook.getSwapFee(criticalRiskUser);
        assertEq(fee, CRITICAL_FEE, "CRITICAL risk user should pay 30% fee");
    }
    
    function test_GetSwapFee_WithDynamicFeesDisabled() public {
        // Disable dynamic fees
        IVedyxRiskHook.HookConfig memory config = hook.getHookConfig();
        config.dynamicSwapFees = false;
        vm.prank(owner);
        hook.updateHookConfig(config);
        
        // All users should pay SAFE fee when dynamic fees disabled
        assertEq(hook.getSwapFee(safeUser), SAFE_FEE);
        assertEq(hook.getSwapFee(lowRiskUser), SAFE_FEE);
        assertEq(hook.getSwapFee(mediumRiskUser), SAFE_FEE);
        assertEq(hook.getSwapFee(highRiskUser), SAFE_FEE);
        assertEq(hook.getSwapFee(criticalRiskUser), SAFE_FEE);
    }
    
    // ─── Blocking Tests ───────────────────────────────────────────────────
    
    function test_ShouldBlockSwap_SafeUser() public view {
        (bool blocked,) = hook.shouldBlockSwap(safeUser);
        assertFalse(blocked, "SAFE user should not be blocked");
    }
    
    function test_ShouldBlockSwap_LowRiskUser() public view {
        (bool blocked,) = hook.shouldBlockSwap(lowRiskUser);
        assertTrue(blocked, "User with 1 incident gets HIGH risk and is blocked");
    }
    
    function test_ShouldBlockSwap_MediumRiskUser() public view{
        (bool blocked,) = hook.shouldBlockSwap(mediumRiskUser);
        assertTrue(blocked, "User with 3 incidents gets CRITICAL risk and is blocked");
    }
    
    function test_ShouldBlockSwap_HighRiskUser() public view{
        (bool blocked, string memory reason) = hook.shouldBlockSwap(highRiskUser);
        assertTrue(blocked, "User with 5 incidents gets CRITICAL risk and is blocked");
        assertEq(reason, "CRITICAL risk level - address blocked");
    }
    
    function test_ShouldBlockSwap_CriticalRiskUser() public view{
        (bool blocked, string memory reason) = hook.shouldBlockSwap(criticalRiskUser);
        assertTrue(blocked, "CRITICAL risk user should be blocked");
        assertEq(reason, "CRITICAL risk level - address blocked");
    }
    
    function test_ShouldBlockSwap_WithBlockingDisabled() public {
        // Disable blocking
        IVedyxRiskHook.HookConfig memory config = hook.getHookConfig();
        config.blockHighRisk = false;
        config.blockCritical = false;
        vm.prank(owner);
        hook.updateHookConfig(config);
        
        // No users should be blocked
        (bool blocked1,) = hook.shouldBlockSwap(highRiskUser);
        (bool blocked2,) = hook.shouldBlockSwap(criticalRiskUser);
        assertFalse(blocked1, "HIGH risk user should not be blocked");
        assertFalse(blocked2, "CRITICAL risk user should not be blocked");
    }
    
    // ─── Liquidity Fee Tests ──────────────────────────────────────────────
    
    function test_GetLiquidityFee_AddLiquidity_SafeUser() public view {
        uint24 fee = hook.getLiquidityFee(safeUser, true);
        // SAFE fee (10000) + add liquidity premium (5000) = 15000 (1.5%)
        assertEq(fee, 15000, "SAFE user should pay 1.5% for adding liquidity");
    }
    
    function test_GetLiquidityFee_RemoveLiquidity_SafeUser() public view {
        uint24 fee = hook.getLiquidityFee(safeUser, false);
        // SAFE fee (10000) + remove liquidity premium (2500) = 12500 (1.25%)
        assertEq(fee, 12500, "SAFE user should pay 1.25% for removing liquidity");
    }
    
    function test_GetLiquidityFee_AddLiquidity_HighRiskUser() public view{
        uint24 fee = hook.getLiquidityFee(highRiskUser, true);
        // CRITICAL fee (300000) capped at maxSwapFee (300000)
        assertEq(fee, 300000, "User with 5 incidents gets CRITICAL risk fee");
    }
    
    function test_ShouldBlockLiquidity_AddLiquidity_MediumRiskUser() public view{
        bool blocked = hook.shouldBlockLiquidity(mediumRiskUser, true);
        assertTrue(blocked, "MEDIUM risk user should be blocked from adding liquidity");
    }
    
    function test_ShouldBlockLiquidity_RemoveLiquidity_MediumRiskUser() public view{
        bool blocked = hook.shouldBlockLiquidity(mediumRiskUser, false);
        assertTrue(blocked, "User with 3 incidents gets CRITICAL risk and is blocked from removing");
    }
    
    function test_ShouldBlockLiquidity_AddLiquidity_HighRiskUser() public view{
        bool blocked = hook.shouldBlockLiquidity(highRiskUser, true);
        assertTrue(blocked, "HIGH risk user should be blocked from adding liquidity");
    }
    
    function test_ShouldBlockLiquidity_RemoveLiquidity_HighRiskUser() public view{
        bool blocked = hook.shouldBlockLiquidity(highRiskUser, false);
        assertTrue(blocked, "HIGH risk user should be blocked from removing liquidity");
    }
    
    // ─── BeforeSwap Hook Tests ────────────────────────────────────────────
    
    function test_BeforeSwap_SafeUser_Success() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeApplied(safeUser, SAFE_FEE, IVedyxRiskEngine.RiskLevel.SAFE, 0);
        
        vm.prank(address(manager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            safeUser,
            testPoolKey,
            params,
            ""
        );
        
        assertEq(selector, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(delta), 0);
        assertEq(fee, SAFE_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
    
    function test_BeforeSwap_LowRiskUser_Blocked() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(address(manager));
        vm.expectRevert("HIGH risk level - address blocked");
        hook.beforeSwap(lowRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeSwap_MediumRiskUser_Blocked() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(address(manager));
        vm.expectRevert("CRITICAL risk level - address blocked");
        hook.beforeSwap(mediumRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeSwap_HighRiskUser_Blocked() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.expectEmit(true, true, true, true);
        IVedyxRiskEngine.RiskAssessment memory assessment = riskEngine.getRiskAssessment(highRiskUser);
        emit SwapBlocked(highRiskUser, IVedyxRiskEngine.RiskLevel.CRITICAL, assessment.totalScore);
        
        vm.prank(address(manager));
        vm.expectRevert("CRITICAL risk level - address blocked");
        hook.beforeSwap(highRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeSwap_CriticalRiskUser_Blocked() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(address(manager));
        vm.expectRevert("CRITICAL risk level - address blocked");
        hook.beforeSwap(criticalRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeSwap_OnlyPoolManager() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.expectRevert(VedyxRiskHook.OnlyPoolManager.selector);
        hook.beforeSwap(safeUser, testPoolKey, params, "");
    }
    
    function test_BeforeSwap_DynamicFeesDisabled() public {
        // Disable dynamic fees
        IVedyxRiskHook.HookConfig memory config = hook.getHookConfig();
        config.dynamicSwapFees = false;
        vm.prank(owner);
        hook.updateHookConfig(config);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(address(manager));
        (,, uint24 fee) = hook.beforeSwap(safeUser, testPoolKey, params, "");
        
        // Should return 0 (no override) when dynamic fees disabled
        assertEq(fee, 0);
    }
    
    // ─── BeforeAddLiquidity Hook Tests ────────────────────────────────────
    
    function test_BeforeAddLiquidity_SafeUser_Success() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        bytes4 selector = hook.beforeAddLiquidity(safeUser, testPoolKey, params, "");
        
        assertEq(selector, IHooks.beforeAddLiquidity.selector);
        
        // Check LP fee was updated
    }
    
    function test_BeforeAddLiquidity_LowRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from adding liquidity");
        hook.beforeAddLiquidity(lowRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeAddLiquidity_MediumRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.expectEmit(true, true, true, true);
        emit LiquidityBlocked(mediumRiskUser, true, IVedyxRiskEngine.RiskLevel.CRITICAL);
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from adding liquidity");
        hook.beforeAddLiquidity(mediumRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeAddLiquidity_HighRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from adding liquidity");
        hook.beforeAddLiquidity(highRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeAddLiquidity_OnlyPoolManager() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.expectRevert(VedyxRiskHook.OnlyPoolManager.selector);
        hook.beforeAddLiquidity(safeUser, testPoolKey, params, "");
    }
    
    function test_BeforeAddLiquidity_DynamicLPFeesDisabled() public {
        // Disable dynamic LP fees
        IVedyxRiskHook.HookConfig memory config = hook.getHookConfig();
        config.dynamicLPFees = false;
        vm.prank(owner);
        hook.updateHookConfig(config);
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        hook.beforeAddLiquidity(safeUser, testPoolKey, params, "");
        
        // LP fee should not be updated when disabled
    }
    
    // ─── BeforeRemoveLiquidity Hook Tests ─────────────────────────────────
    
    function test_BeforeRemoveLiquidity_SafeUser_Success() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        bytes4 selector = hook.beforeRemoveLiquidity(safeUser, testPoolKey, params, "");
        
        assertEq(selector, IHooks.beforeRemoveLiquidity.selector);
        
    }
    
    function test_BeforeRemoveLiquidity_LowRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from removing liquidity");
        hook.beforeRemoveLiquidity(lowRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeRemoveLiquidity_MediumRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from removing liquidity");
        hook.beforeRemoveLiquidity(mediumRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeRemoveLiquidity_HighRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.expectEmit(true, true, true, true);
        emit LiquidityBlocked(highRiskUser, false, IVedyxRiskEngine.RiskLevel.CRITICAL);
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from removing liquidity");
        hook.beforeRemoveLiquidity(highRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeRemoveLiquidity_CriticalRiskUser_Blocked() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from removing liquidity");
        hook.beforeRemoveLiquidity(criticalRiskUser, testPoolKey, params, "");
    }
    
    function test_BeforeRemoveLiquidity_OnlyPoolManager() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        vm.expectRevert(VedyxRiskHook.OnlyPoolManager.selector);
        hook.beforeRemoveLiquidity(safeUser, testPoolKey, params, "");
    }
    
    // ─── Configuration Tests ──────────────────────────────────────────────
    
    function test_UpdateFeeConfig() public {
        IVedyxRiskHook.FeeConfig memory newConfig = IVedyxRiskHook.FeeConfig({
            safeFee: 5000,      // 0.5%
            lowFee: 15000,      // 1.5%
            mediumFee: 40000,   // 4%
            highFee: 100000,    // 10%
            criticalFee: 200000 // 20%
        });
        
        vm.prank(owner);
        hook.updateFeeConfig(newConfig);
        
        IVedyxRiskHook.FeeConfig memory updated = hook.getFeeConfig();
        assertEq(updated.safeFee, 5000);
        assertEq(updated.lowFee, 15000);
        assertEq(updated.mediumFee, 40000);
        assertEq(updated.highFee, 100000);
        assertEq(updated.criticalFee, 200000);
    }
    
    function test_UpdateFeeConfig_RevertsOnNonAscending() public {
        IVedyxRiskHook.FeeConfig memory invalidConfig = IVedyxRiskHook.FeeConfig({
            safeFee: 10000,
            lowFee: 5000,  // Lower than safe fee
            mediumFee: 80000,
            highFee: 150000,
            criticalFee: 300000
        });
        
        vm.prank(owner);
        vm.expectRevert(VedyxRiskHook.FeesNotAscending.selector);
        hook.updateFeeConfig(invalidConfig);
    }
    
    function test_UpdateFeeConfig_RevertsOnExcessive() public {
        IVedyxRiskHook.FeeConfig memory invalidConfig = IVedyxRiskHook.FeeConfig({
            safeFee: 10000,
            lowFee: 30000,
            mediumFee: 80000,
            highFee: 150000,
            criticalFee: 1100000  // > 100%
        });
        
        vm.prank(owner);
        vm.expectRevert(VedyxRiskHook.FeeExceeds100Percent.selector);
        hook.updateFeeConfig(invalidConfig);
    }
    
    function test_UpdateFeeConfig_RevertsOnNonOwner() public {
        IVedyxRiskHook.FeeConfig memory newConfig = hook.getFeeConfig();
        
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.updateFeeConfig(newConfig);
    }
    
    function test_UpdateHookConfig() public {
        IVedyxRiskHook.HookConfig memory newConfig = IVedyxRiskHook.HookConfig({
            blockHighRisk: false,
            blockCritical: true,
            dynamicSwapFees: false,
            dynamicLPFees: false,
            maxSwapFee: 500000,
            minSwapFee: 5000
        });
        
        vm.prank(owner);
        hook.updateHookConfig(newConfig);
        
        IVedyxRiskHook.HookConfig memory updated = hook.getHookConfig();
        assertFalse(updated.blockHighRisk);
        assertTrue(updated.blockCritical);
        assertFalse(updated.dynamicSwapFees);
        assertFalse(updated.dynamicLPFees);
        assertEq(updated.maxSwapFee, 500000);
        assertEq(updated.minSwapFee, 5000);
    }
    
    function test_UpdateRiskEngine() public {
        VedyxRiskEngine newEngine = new VedyxRiskEngine(address(votingContract));
        
        vm.prank(owner);
        hook.updateRiskEngine(address(newEngine));
        
        assertEq(address(hook.riskEngine()), address(newEngine));
    }
    
    function test_UpdateRiskEngine_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(VedyxRiskHook.ZeroAddress.selector);
        hook.updateRiskEngine(address(0));
    }
    
    function test_UpdateHookConfig_RevertsOnInvalidFeeRange() public {
        IVedyxRiskHook.HookConfig memory invalidConfig = IVedyxRiskHook.HookConfig({
            blockHighRisk: true,
            blockCritical: true,
            dynamicSwapFees: true,
            dynamicLPFees: true,
            maxSwapFee: 10000,
            minSwapFee: 50000  // min > max
        });
        
        vm.prank(owner);
        vm.expectRevert(VedyxRiskHook.InvalidFeeRange.selector);
        hook.updateHookConfig(invalidConfig);
    }
    
    function test_UpdateLPFeeAdjustment_RevertsOnExcessiveFee() public {
        IVedyxRiskHook.LPFeeAdjustment memory invalidAdjustment = IVedyxRiskHook.LPFeeAdjustment({
            addLiquidityFee: 1100000,  // > 100%
            removeLiquidityFee: 5000
        });
        
        vm.prank(owner);
        vm.expectRevert(VedyxRiskHook.FeeExceeds100Percent.selector);
        hook.updateLPFeeAdjustment(IVedyxRiskEngine.RiskLevel.SAFE, invalidAdjustment);
    }
    
    function test_UpdateLPFeeAdjustment() public {
        IVedyxRiskHook.LPFeeAdjustment memory newAdjustment = IVedyxRiskHook.LPFeeAdjustment({
            addLiquidityFee: 10000,   // 1%
            removeLiquidityFee: 5000  // 0.5%
        });
        
        vm.prank(owner);
        hook.updateLPFeeAdjustment(IVedyxRiskEngine.RiskLevel.SAFE, newAdjustment);
        
        IVedyxRiskHook.LPFeeAdjustment memory updated = hook.getLPFeeAdjustment(IVedyxRiskEngine.RiskLevel.SAFE);
        assertEq(updated.addLiquidityFee, 10000);
        assertEq(updated.removeLiquidityFee, 5000);
    }
    
    // ─── Risk Assessment Tests ────────────────────────────────────────────
    
    function test_GetUserRiskAssessment_SafeUser() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(safeUser);
        assertEq(uint8(assessment.riskLevel), uint8(IVedyxRiskEngine.RiskLevel.SAFE));
        assertEq(assessment.totalScore, 0);
    }
    
    function test_GetUserRiskAssessment_LowRiskUser() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(lowRiskUser);
        assertEq(uint8(assessment.riskLevel), uint8(IVedyxRiskEngine.RiskLevel.HIGH));
        assertEq(assessment.totalScore, 65);
    }
    
    function test_GetUserRiskAssessment_MediumRiskUser() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(mediumRiskUser);
        assertEq(uint8(assessment.riskLevel), uint8(IVedyxRiskEngine.RiskLevel.CRITICAL));
        assertEq(assessment.totalScore, 80);
    }
    
    function test_GetUserRiskAssessment_HighRiskUser() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(highRiskUser);
        assertEq(uint8(assessment.riskLevel), uint8(IVedyxRiskEngine.RiskLevel.CRITICAL));
        assertEq(assessment.totalScore, 80);
    }
    
    function test_GetUserRiskAssessment_CriticalRiskUser() public view{
        IVedyxRiskEngine.RiskAssessment memory assessment = hook.getUserRiskAssessment(criticalRiskUser);
        assertEq(uint8(assessment.riskLevel), uint8(IVedyxRiskEngine.RiskLevel.CRITICAL));
        assertTrue(assessment.totalScore >= 70);
    }
    
    // ─── Integration Tests ────────────────────────────────────────────────
    
    function test_Integration_FullSwapWorkflow() public {
        // Test complete swap workflow for different risk levels
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        // Safe user can swap with low fee
        vm.prank(address(manager));
        (,, uint24 safeFee) = hook.beforeSwap(safeUser, testPoolKey, params, "");
        assertEq(safeFee, SAFE_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG);
        
        // Low risk user is blocked (HIGH risk with 1 incident)
        vm.prank(address(manager));
        vm.expectRevert("HIGH risk level - address blocked");
        hook.beforeSwap(lowRiskUser, testPoolKey, params, "");
        
        // High risk user is blocked (CRITICAL with 5 incidents)
        vm.prank(address(manager));
        vm.expectRevert("CRITICAL risk level - address blocked");
        hook.beforeSwap(highRiskUser, testPoolKey, params, "");
    }
    
    function test_Integration_FullLiquidityWorkflow() public {
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });
        
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1e18,
            salt: bytes32(0)
        });
        
        // Safe user can add liquidity
        vm.prank(address(manager));
        hook.beforeAddLiquidity(safeUser, testPoolKey, addParams, "");
        
        // Safe user can remove liquidity
        vm.prank(address(manager));
        hook.beforeRemoveLiquidity(safeUser, testPoolKey, removeParams, "");
        
        // Medium risk user blocked from adding (CRITICAL with 3 incidents)
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from adding liquidity");
        hook.beforeAddLiquidity(mediumRiskUser, testPoolKey, addParams, "");
        
        // Also blocked from removing (CRITICAL risk)
        vm.prank(address(manager));
        vm.expectRevert("VedyxRiskHook: Address blocked from removing liquidity");
        hook.beforeRemoveLiquidity(mediumRiskUser, testPoolKey, removeParams, "");
    }
    
    function test_Integration_ConfigurationChangesAffectBehavior() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        // Initially CRITICAL risk user is blocked
        vm.prank(address(manager));
        vm.expectRevert("CRITICAL risk level - address blocked");
        hook.beforeSwap(highRiskUser, testPoolKey, params, "");
        
        // Disable blocking for CRITICAL risk
        IVedyxRiskHook.HookConfig memory config = hook.getHookConfig();
        config.blockCritical = false;
        vm.prank(owner);
        hook.updateHookConfig(config);
        
        // Now CRITICAL risk user can swap (but pays critical fee)
        vm.prank(address(manager));
        (,, uint24 fee) = hook.beforeSwap(highRiskUser, testPoolKey, params, "");
        assertEq(fee, CRITICAL_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
    
    // ─── Gas Optimization Tests ───────────────────────────────────────────
    
    function test_Gas_GetSwapFee() public view{
        uint256 gasBefore = gasleft();
        hook.getSwapFee(safeUser);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for getSwapFee:", gasUsed);
        assertTrue(gasUsed < 50000, "getSwapFee should use less than 50k gas");
    }
    
    function test_Gas_ShouldBlockSwap() public view{
        uint256 gasBefore = gasleft();
        hook.shouldBlockSwap(safeUser);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for shouldBlockSwap:", gasUsed);
        assertTrue(gasUsed < 50000, "shouldBlockSwap should use less than 50k gas");
    }
    
    function test_Gas_BeforeSwap() public{
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        uint256 gasBefore = gasleft();
        vm.prank(address(manager));
        hook.beforeSwap(safeUser, testPoolKey, params, "");
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for beforeSwap:", gasUsed);
        assertTrue(gasUsed < 100000, "beforeSwap should use less than 100k gas");
    }
}
