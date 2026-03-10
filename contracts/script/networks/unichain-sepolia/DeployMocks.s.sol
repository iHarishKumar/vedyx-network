// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockMixer} from "../../../src/mocks/MockMixer.sol";

/**
 * @title DeployMocks
 * @notice Deploys mock tokens and mixers for testing on Unichain Sepolia
 * 
 * This script can be used standalone or imported by other deployment scripts.
 * Deploys:
 * - Mock ERC20 tokens (USDC, USDT, WETH, DAI)
 * - Mock mixers for each token
 * - Staking token (VGT)
 */
contract DeployMocks is Script {
    // Mock tokens
    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC20 public mockWETH;
    MockERC20 public mockDAI;
    MockERC20 public stakingToken;
    
    // Mock mixers
    MockMixer public usdcMixer;
    MockMixer public usdtMixer;
    MockMixer public wethMixer;
    MockMixer public daiMixer;

    /**
     * @notice Deploy all mock tokens
     */
    function deployMockTokens() public {
        console2.log("Deploying Mock ERC20 Tokens...");
        
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6, 1_000_000_000 * 10**6);
        console2.log("  Mock USDC:", address(mockUSDC));
        
        mockUSDT = new MockERC20("Mock USDT", "USDT", 6, 1_000_000_000 * 10**6);
        console2.log("  Mock USDT:", address(mockUSDT));
        
        mockWETH = new MockERC20("Mock WETH", "WETH", 18, 1_000_000 ether);
        console2.log("  Mock WETH:", address(mockWETH));
        
        mockDAI = new MockERC20("Mock DAI", "DAI", 18, 1_000_000_000 ether);
        console2.log("  Mock DAI:", address(mockDAI));
        
        console2.log("");
    }

    /**
     * @notice Deploy all mock mixers
     */
    function deployMockMixers() public {
        console2.log("Deploying Mock Mixers...");
        
        usdcMixer = new MockMixer(address(mockUSDC), 1000 * 10**6);
        console2.log("  USDC Mixer:", address(usdcMixer));
        
        usdtMixer = new MockMixer(address(mockUSDT), 1000 * 10**6);
        console2.log("  USDT Mixer:", address(usdtMixer));
        
        wethMixer = new MockMixer(address(mockWETH), 1 ether);
        console2.log("  WETH Mixer:", address(wethMixer));
        
        daiMixer = new MockMixer(address(mockDAI), 1000 ether);
        console2.log("  DAI Mixer:", address(daiMixer));
        
        console2.log("");
    }

    /**
     * @notice Deploy staking token
     */
    function deployStakingToken() public {
        console2.log("Deploying Staking Token...");
        
        stakingToken = new MockERC20(
            "Vedyx Governance Token",
            "VGT",
            18,
            1_000_000_000 ether
        );
        console2.log("  Staking Token (VGT):", address(stakingToken));
        console2.log("");
    }

    /**
     * @notice Deploy all mocks (tokens, mixers, and staking token)
     */
    function deployAll() public {
        deployMockTokens();
        deployMockMixers();
        deployStakingToken();
    }

    /**
     * @notice Verify all mock contracts on Etherscan
     */
    function verifyAll() public {
        console2.log("Verifying Mock Contracts...");
        
        // Check if Etherscan API key is set
        try vm.envString("ETHERSCAN_API_KEY") returns (string memory apiKey) {
            if (bytes(apiKey).length == 0) {
                console2.log("WARNING: ETHERSCAN_API_KEY not set, skipping verification");
                console2.log("");
                return;
            }
        } catch {
            console2.log("WARNING: ETHERSCAN_API_KEY not set, skipping verification");
            console2.log("");
            return;
        }
        
        // Verify mock tokens
        verifyMockToken(address(mockUSDC), "Mock USDC", "USDC", 6, 1_000_000_000 * 10**6);
        verifyMockToken(address(mockUSDT), "Mock USDT", "USDT", 6, 1_000_000_000 * 10**6);
        verifyMockToken(address(mockWETH), "Mock WETH", "WETH", 18, 1_000_000 ether);
        verifyMockToken(address(mockDAI), "Mock DAI", "DAI", 18, 1_000_000_000 ether);
        verifyMockToken(address(stakingToken), "Vedyx Governance Token", "VGT", 18, 1_000_000_000 ether);
        
        // Verify mock mixers
        verifyMockMixer(address(usdcMixer), address(mockUSDC), 1000 * 10**6);
        verifyMockMixer(address(usdtMixer), address(mockUSDT), 1000 * 10**6);
        verifyMockMixer(address(wethMixer), address(mockWETH), 1 ether);
        verifyMockMixer(address(daiMixer), address(mockDAI), 1000 ether);
        
        console2.log("Mock contract verification complete!");
        console2.log("");
    }

    /**
     * @notice Verify a single mock token
     */
    function verifyMockToken(
        address token,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) internal {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(token);
        cmd[3] = "src/mocks/MockERC20.sol:MockERC20";
        cmd[4] = "--chain";
        cmd[5] = "1301";
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(abi.encode(name, symbol, decimals, initialSupply));
        cmd[8] = "--watch";
        
        try vm.ffi(cmd) {
            console2.log("  Verified:", symbol, "at", token);
        } catch {
            console2.log("  Failed to verify:", symbol, "- verify manually");
        }
    }

    /**
     * @notice Verify a single mock mixer
     */
    function verifyMockMixer(address mixer, address token, uint256 denomination) internal {
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(mixer);
        cmd[3] = "src/mocks/MockMixer.sol:MockMixer";
        cmd[4] = "--chain";
        cmd[5] = "1301";
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(abi.encode(token, denomination));
        cmd[8] = "--watch";
        
        try vm.ffi(cmd) {
            console2.log("  Verified: Mixer at", mixer);
        } catch {
            console2.log("  Failed to verify: Mixer - verify manually");
        }
    }
}
