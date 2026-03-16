// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VedyxExploitDetectorRSC} from "../../../src/reactive-contracts/VedyxExploitDetectorRSC.sol";

/**
 * @title UpdateVedyxRSC
 * @notice Updates VedyxExploitDetectorRSC on Lasna testnet and subscribes to transfer events
 * 
 * This script:
 * 1. Reads VedyxRSC address from Lasna testnet deployment
 * 2. Updates the callback address to the deployed VotingContract on Sepolia
 * 3. Updates the destination chain ID to Sepolia (11155111)
 * 4. Subscribes to ERC20 Transfer events for mock tokens on Sepolia
 * 
 * Prerequisites:
 * - VedyxExploitDetectorRSC must be deployed on Lasna testnet
 * - VedyxVotingContract must be deployed on Sepolia
 * - Mock tokens must be deployed on Sepolia
 * 
 * Usage with Forge account:
 *   forge script script/networks/lasna-testnet/UpdateVedyxRSC.s.sol:UpdateVedyxRSC \
 *     --rpc-url $LASNA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast
 * 
 * The script automatically reads addresses from deployment files:
 *   - VedyxRSC from: ./deployments/lasna-testnet/deployment.json
 *   - VotingContract from: ./deployments/sepolia/deployment.json
 *   - Mock tokens from: ./deployments/sepolia/deployment.json
 * 
 * Environment Variables (Optional - overrides deployment files):
 *   VEDYX_RSC_ADDRESS - Address of deployed VedyxExploitDetectorRSC
 *   VOTING_CONTRACT_ADDRESS - Address of deployed VedyxVotingContract on Sepolia
 *   ORIGIN_CHAIN_ID - Chain ID of origin chain to monitor (default: 11155111 Sepolia)
 */
contract UpdateVedyxRSC is Script {
    // ERC20 Transfer event signature
    uint256 private constant TRANSFER_TOPIC = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    
    // Sepolia chain ID (destination)
    uint256 private constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    
    // Lasna testnet chain ID
    uint256 private constant LASNA_CHAIN_ID = 5318007;

    VedyxExploitDetectorRSC public vedyxRSC;
    address public votingContract;
    uint256 public originChainId;

    function run() external {
        // Load addresses from deployment files or environment
        address vedyxRSCAddress = getVedyxRSCAddress();
        votingContract = getVotingContractAddress();
        originChainId = getOriginChainId();

        vedyxRSC = VedyxExploitDetectorRSC(payable(vedyxRSCAddress));

        console2.log("========================================");
        console2.log("UPDATE VEDYX RSC CONFIGURATION");
        console2.log("========================================");
        console2.log("VedyxRSC:", address(vedyxRSC));
        console2.log("Voting Contract:", votingContract);
        console2.log("Origin Chain ID:", originChainId);
        console2.log("Destination Chain ID:", UNICHAIN_SEPOLIA_CHAIN_ID);
        console2.log("Chain ID:", block.chainid);
        console2.log("NOTE: Running on Lasna testnet");
        console2.log("========================================\n");

        vm.startBroadcast();

        // Step 1: Update callback address
        updateCallbackAddress();

        // Step 2: Update destination chain ID
        updateDestinationChainId();

        // Step 3: Subscribe to transfer events
        subscribeToTransferEvents();

        vm.stopBroadcast();

        // Print summary
        printSummary();
    }

    function updateCallbackAddress() internal {
        console2.log("STEP 1: Updating Callback Address...");
        
        vedyxRSC.setCallback(votingContract);
        
        console2.log("Callback address updated to:", votingContract);
        console2.log("");
    }

    function updateDestinationChainId() internal {
        console2.log("STEP 2: Updating Destination Chain ID...");
        
        vedyxRSC.setDestinationChainId(UNICHAIN_SEPOLIA_CHAIN_ID);
        
        console2.log("Destination chain ID updated to:", UNICHAIN_SEPOLIA_CHAIN_ID);
        console2.log("");
    }

    function subscribeToTransferEvents() internal {
        console2.log("STEP 3: Subscribing to Transfer Events...");
        
        // Get token addresses from environment or use defaults
        address[] memory tokens = getTokensToMonitor();
        
        console2.log("Subscribing to", tokens.length, "tokens on chain", originChainId);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("  Subscribing to token:", tokens[i]);
            
            // Subscribe to Transfer events
            // subscriber = address(0) means monitor all transfers
            vedyxRSC.subscribe(
                originChainId,
                tokens[i],
                TRANSFER_TOPIC
            );
            
            console2.log("    Subscribed to Transfer events");
        }
        
        console2.log("");
    }

    function getVedyxRSCAddress() internal view returns (address) {
        // Try to read from Lasna testnet deployment file first
        try vm.readFile("./deployments/lasna-testnet/deployment.json") returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".reactiveContracts.vedyxExploitDetectorRSC");
            address addr = abi.decode(data, (address));
            console2.log("Loaded VedyxRSC from Lasna testnet deployment file:", addr);
            return addr;
        } catch {
            // Fall back to environment variable
            console2.log("Reading VedyxRSC from environment variable");
            return vm.envAddress("VEDYX_RSC_ADDRESS");
        }
    }

    function getVotingContractAddress() internal view returns (address) {
        // Try to read from Sepolia deployment file first
        try vm.readFile("./deployments/unichain-sepolia/deployment.json") returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            address addr = abi.decode(data, (address));
            console2.log("Loaded VotingContract from Unichain Sepolia deployment file:", addr);
            return addr;
        } catch {
            // Fall back to environment variable
            console2.log("Reading VotingContract from environment variable");
            return vm.envAddress("VOTING_CONTRACT_ADDRESS");
        }
    }

    function getOriginChainId() internal view returns (uint256) {
        // Try environment first, default to Sepolia
        try vm.envUint("ORIGIN_CHAIN_ID") returns (uint256 chainId) {
            console2.log("Using origin chain ID from environment:", chainId);
            return chainId;
        } catch {
            console2.log("Using default origin chain ID: 11155111 (Sepolia)");
            return UNICHAIN_SEPOLIA_CHAIN_ID;
        }
    }

    function getTokensToMonitor() internal view returns (address[] memory) {
        // Try to load from Sepolia deployment file (where mocks are deployed)
        try vm.readFile("./deployments/unichain-sepolia/deployment.json") returns (string memory json) {
            console2.log("  Loading tokens from Unichain Sepolia deployment file");
            
            // Parse token addresses from deployment file
            address[] memory tokens = new address[](4);
            uint256 count = 0;
            
            try vm.parseJson(json, ".mockTokens.USDC") returns (bytes memory data) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}
            
            try vm.parseJson(json, ".mockTokens.USDT") returns (bytes memory data) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}
            
            try vm.parseJson(json, ".mockTokens.WETH") returns (bytes memory data) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}
            
            try vm.parseJson(json, ".mockTokens.DAI") returns (bytes memory data) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}
            
            // Resize array to actual count
            if (count > 0) {
                address[] memory result = new address[](count);
                for (uint256 i = 0; i < count; i++) {
                    result[i] = tokens[i];
                }
                console2.log("  Loaded", count, "tokens from deployment file");
                return result;
            }
        } catch {}
        
        // Fallback: Try environment variables
        try vm.envAddress("TOKEN_1") returns (address token1) {
            console2.log("  Loading tokens from environment variables");
            address[] memory tokens = new address[](6);
            uint256 count = 0;
            
            tokens[count++] = token1;
            
            try vm.envAddress("TOKEN_2") returns (address token2) {
                tokens[count++] = token2;
            } catch {}
            
            try vm.envAddress("TOKEN_3") returns (address token3) {
                tokens[count++] = token3;
            } catch {}
            
            try vm.envAddress("TOKEN_4") returns (address token4) {
                tokens[count++] = token4;
            } catch {}
            
            try vm.envAddress("TOKEN_5") returns (address token5) {
                tokens[count++] = token5;
            } catch {}
            
            try vm.envAddress("TOKEN_6") returns (address token6) {
                tokens[count++] = token6;
            } catch {}
            
            // Resize array to actual count
            address[] memory result = new address[](count);
            for (uint256 i = 0; i < count; i++) {
                result[i] = tokens[i];
            }
            return result;
        } catch {
            console2.log("  WARNING: No tokens found in deployment file or environment");
            console2.log("  Please deploy mock tokens first or set TOKEN_1, TOKEN_2, etc.");
            revert("No tokens to monitor");
        }
    }

    function printSummary() internal view {
        console2.log("========================================");
        console2.log("UPDATE COMPLETE");
        console2.log("========================================");
        console2.log("\nConfiguration:");
        console2.log("  VedyxRSC:", address(vedyxRSC));
        console2.log("  Callback Contract:", votingContract);
        console2.log("  Destination Chain:", UNICHAIN_SEPOLIA_CHAIN_ID, "(Sepolia)");
        console2.log("  Origin Chain:", originChainId);
        console2.log("========================================");
        console2.log("\nVerification Commands:");
        console2.log("# Check callback address");
        console2.log("cast call", address(vedyxRSC), '"getCallback()"');
        console2.log("\n# Check subscription keys");
        console2.log("cast call", address(vedyxRSC), '"getSubscriptionKeys()"');
        console2.log("\n# Check active subscriptions count");
        console2.log("cast call", address(vedyxRSC), '"getActiveSubscriptionsCount()"');
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Verify configuration with commands above");
        console2.log("2. Test threat detection on origin chain");
        console2.log("3. Monitor ThreatDetected events on Reactive Network");
        console2.log("4. Monitor ThreatTagged events on Sepolia");
        console2.log("========================================");
    }
}
