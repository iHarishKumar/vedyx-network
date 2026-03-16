// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TokenRegistry} from "../../../src/reactive-contracts/detectors/TokenRegistry.sol";
import {LargeTransferDetector} from "../../../src/reactive-contracts/detectors/LargeTransferDetector.sol";
import {MixerInteractionDetector} from "../../../src/reactive-contracts/detectors/MixerInteractionDetector.sol";
import {TracePeelChainDetector} from "../../../src/reactive-contracts/detectors/TracePeelChainDetector.sol";
import {VedyxExploitDetectorRSC} from "../../../src/reactive-contracts/VedyxExploitDetectorRSC.sol";

/**
 * @title DeployLasnaTestnet
 * @notice Deployment for Lasna testnet - Reactive contracts only
 *
 * This script deploys:
 * 1. TokenRegistry
 * 2. All attack vector detectors
 * 3. VedyxExploitDetectorRSC
 *
 * Note: Mock tokens and mixers should be deployed on Sepolia (origin/destination chain)
 *
 * Usage with Forge account:
 *   forge script script/networks/lasna-testnet/DeployLasnaTestnet.s.sol:DeployLasnaTestnet \
 *     --rpc-url $LASNA_RPC_URL \
 *     --account <account-name> \
 *     --broadcast
 */
contract DeployLasnaTestnet is Script {
    // Deployed contracts
    TokenRegistry public tokenRegistry;
    LargeTransferDetector public largeTransferDetector;
    MixerInteractionDetector public mixerInteractionDetector;
    TracePeelChainDetector public tracePeelChainDetector;
    VedyxExploitDetectorRSC public vedyxRSC;

    // Configuration
    uint256 private constant TRANSFER_TOPIC =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    uint256 private constant DESTINATION_CHAIN_ID = 1301; // Unichain Seploia chain id

    address public votingContract;
    uint256 public originChainId;

    string private constant DEPLOYMENT_PATH = "./deployments/unichain-sepolia/deployment.json";

    function run() external {
        address deployer = msg.sender;
        votingContract = getVotingContractAddress();
        originChainId = getOriginChainId();

        console2.log("========================================");
        console2.log("VEDYX LASNA TESTNET DEPLOYMENT");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("========================================\n");

        vm.startBroadcast();

        // Step 1: Deploy TokenRegistry
        deployTokenRegistry();

        // Step 2: Deploy Detectors
        deployDetectors();

        // Step 3: Deploy VedyxExploitDetectorRSC
        deployVedyxRSC();

        // Step 4: Register Detectors
        registerDetectors();

        // Step 5: Setup Subscriptions (requires token addresses from Sepolia)
        subscribeToTransferEvents();

        // Step 6: Update the callback address
        updateCallbackAddress();

        vm.stopBroadcast();

        // Step 7: Save Deployments
        saveDeployments();

        // Final Summary
        printDeploymentSummary();
    }

    function deployTokenRegistry() internal {
        console2.log("STEP 1: Deploying TokenRegistry...");

        tokenRegistry = new TokenRegistry();
        console2.log("TokenRegistry:", address(tokenRegistry));
        console2.log(
            "NOTE: Configure tokens after deployment using token addresses from Sepolia"
        );
        console2.log("");
    }

    function updateCallbackAddress() internal {
        console2.log("STEP 6: Updating Callback Address...");

        vedyxRSC.setCallback(votingContract);

        console2.log("Callback address updated to:", votingContract);
        console2.log("");
    }

    function getVotingContractAddress() internal view returns (address) {
        // Try to read from Sepolia deployment file first
        
        if (!vm.exists(DEPLOYMENT_PATH)) {
            console2.log("Deployment file not found, using environment variable");
            return vm.envAddress("VOTING_CONTRACT_ADDRESS");
        }
        
        try vm.readFile(DEPLOYMENT_PATH) returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            address addr = abi.decode(data, (address));
            console2.log(
                "Loaded VotingContract from Unichain Sepolia deployment file:",
                addr
            );
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
            return DESTINATION_CHAIN_ID;
        }
    }

    function deployDetectors() internal {
        console2.log("STEP 2: Deploying Attack Vector Detectors...");

        largeTransferDetector = new LargeTransferDetector(
            address(tokenRegistry)
        );
        console2.log("LargeTransferDetector:", address(largeTransferDetector));

        mixerInteractionDetector = new MixerInteractionDetector(
            address(tokenRegistry)
        );
        console2.log(
            "MixerInteractionDetector:",
            address(mixerInteractionDetector)
        );

        tracePeelChainDetector = new TracePeelChainDetector(
            address(tokenRegistry)
        );
        console2.log(
            "TracePeelChainDetector:",
            address(tracePeelChainDetector)
        );

        console2.log(
            "NOTE: Configure detector thresholds and mixers after deployment"
        );
        console2.log("");
    }

    function deployVedyxRSC() internal {
        console2.log("STEP 3: Deploying VedyxExploitDetectorRSC...");

        // Load callback contract and chain ID from Unichain Sepolia deployment
        address callbackContract = getCallbackContractAddress();
        uint256 destinationChainId = DESTINATION_CHAIN_ID;

        // Deploy with 0.1 ETH for Reactive Network subscriptions
        vedyxRSC = new VedyxExploitDetectorRSC{value: 0.1 ether}(
            callbackContract,
            destinationChainId
        );
        console2.log("VedyxExploitDetectorRSC:", address(vedyxRSC));
        console2.log("Callback Contract:", callbackContract);
        console2.log("Destination Chain ID:", destinationChainId);
        console2.log("Deployed with 0.1 ETH for subscriptions");
        console2.log("");
    }

    function getCallbackContractAddress() internal view returns (address) {
        // Try to read from Unichain Sepolia deployment file first
        try
            vm.readFile("./deployments/unichain-sepolia/deployment.json")
        returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".contracts.votingContract");
            address addr = abi.decode(data, (address));
            console2.log(
                "Loaded VotingContract from Unichain Sepolia deployment:",
                addr
            );
            return addr;
        } catch {
            // Fall back to environment variable
            try vm.envAddress("CALLBACK_CONTRACT") returns (address addr) {
                console2.log(
                    "Loaded VotingContract from environment variable:",
                    addr
                );
                return addr;
            } catch {
                revert(
                    "VotingContract address not found in deployment.json or CALLBACK_CONTRACT env var"
                );
            }
        }
    }

    function registerDetectors() internal {
        console2.log("STEP 4: Registering Detectors...");

        vedyxRSC.registerDetector(address(largeTransferDetector));
        console2.log("Registered LargeTransferDetector");

        vedyxRSC.registerDetector(address(mixerInteractionDetector));
        console2.log("Registered MixerInteractionDetector");

        vedyxRSC.registerDetector(address(tracePeelChainDetector));
        console2.log("Registered TracePeelChainDetector");

        console2.log("");
    }

    function subscribeToTransferEvents() internal {
        console2.log("STEP 5: Subscribing to Transfer Events...");

        // Note: Reactive Network uses a debt-based payment model
        // The system service will automatically request payment via the pay() callback
        // The contract has 0.1 ETH to cover subscription fees
        console2.log("Contract balance:", address(vedyxRSC).balance);
        console2.log("");

        // Get token addresses from environment or use defaults
        address[] memory tokens = getTokensToMonitor();

        console2.log(
            "Subscribing to",
            tokens.length,
            "tokens on chain",
            originChainId
        );

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

    function getTokensToMonitor() internal view returns (address[] memory) {
        // Try to load from Unichain Sepolia deployment file (where mocks are deployed)        
        try vm.readFile(DEPLOYMENT_PATH) returns (
            string memory json
        ) {
            console2.log("  Loading tokens from Unichain Sepolia deployment file");

            // Parse token addresses from deployment file
            address[] memory tokens = new address[](4);
            uint256 count = 0;

            try vm.parseJson(json, ".mockTokens.USDC") returns (
                bytes memory data
            ) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}

            try vm.parseJson(json, ".mockTokens.USDT") returns (
                bytes memory data
            ) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}

            try vm.parseJson(json, ".mockTokens.WETH") returns (
                bytes memory data
            ) {
                tokens[count++] = abi.decode(data, (address));
            } catch {}

            try vm.parseJson(json, ".mockTokens.DAI") returns (
                bytes memory data
            ) {
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
        } catch(bytes memory ee) {
            console2.log("Unable to load the deployment files. Skipping to default env variables");
            string memory errStr = abi.decode(ee, (string));
            console2.log(errStr);
        }

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
            console2.log(
                "  WARNING: No tokens found in deployment file or environment"
            );
            console2.log(
                "  Please deploy mock tokens first or set TOKEN_1, TOKEN_2, etc."
            );
            revert("No tokens to monitor");
        }
    }

    function saveDeployments() internal {
        console2.log("STEP 7: Saving Deployment Addresses...");

        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "lasna-testnet",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "reactiveContracts": {\n',
                '    "tokenRegistry": "',
                vm.toString(address(tokenRegistry)),
                '",\n',
                '    "largeTransferDetector": "',
                vm.toString(address(largeTransferDetector)),
                '",\n',
                '    "mixerInteractionDetector": "',
                vm.toString(address(mixerInteractionDetector)),
                '",\n',
                '    "tracePeelChainDetector": "',
                vm.toString(address(tracePeelChainDetector)),
                '",\n',
                '    "vedyxExploitDetectorRSC": "',
                vm.toString(address(vedyxRSC)),
                '"\n',
                "  },\n",
                '  "timestamp": ',
                vm.toString(block.timestamp),
                "\n",
                "}"
            )
        );

        vm.writeFile(
            "./deployments/lasna-testnet/deployment.json",
            deploymentInfo
        );
        console2.log("Saved to: ./deployments/lasna-testnet/deployment.json");
        console2.log("");
    }

    function printDeploymentSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("\nReactive Contracts:");
        console2.log("  TokenRegistry:", address(tokenRegistry));
        console2.log(
            "  LargeTransferDetector:",
            address(largeTransferDetector)
        );
        console2.log(
            "  MixerInteractionDetector:",
            address(mixerInteractionDetector)
        );
        console2.log(
            "  TracePeelChainDetector:",
            address(tracePeelChainDetector)
        );
        console2.log("  VedyxExploitDetectorRSC:", address(vedyxRSC));
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log(
            "1. Configure TokenRegistry with token addresses from Sepolia"
        );
        console2.log("2. Configure detector thresholds");
        console2.log("3. Register mixer addresses from Sepolia");
        console2.log(
            "4. Use UpdateVedyxRSC script to subscribe to Sepolia events"
        );
        console2.log("========================================");
    }
}
