// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TokenRegistry} from "../src/reactive-contracts/detectors/TokenRegistry.sol";
import {LargeTransferDetector} from "../src/reactive-contracts/detectors/LargeTransferDetector.sol";
import {MixerInteractionDetector} from "../src/reactive-contracts/detectors/MixerInteractionDetector.sol";
import {TracePeelChainDetector} from "../src/reactive-contracts/detectors/TracePeelChainDetector.sol";

/**
 * @title DeployDetectors
 * @notice Comprehensive deployment script for all Vedyx attack vector detectors
 *
 * This script deploys and configures:
 * 1. TokenRegistry (if not already deployed)
 * 2. LargeTransferDetector with token subscriptions
 * 3. MixerInteractionDetector with mixer registrations
 * 4. TracePeelChainDetector with token subscriptions
 *
 * Constructor Arguments (NEW):
 * - _registry: TokenRegistry address
 * - _callbackContract_: VedyxVotingContract address on destination chain
 * - _destinationChainId_: Destination chain ID (e.g., 1301 for Unichain Sepolia)
 *
 * Post-Deployment Configuration:
 * - LargeTransferDetector: Subscribe to token Transfer events, configure thresholds
 * - MixerInteractionDetector: Register known mixer addresses, subscribe to token Transfer events
 * - TracePeelChainDetector: Subscribe to token Transfer events, configure detection parameters
 *
 * Usage:
 *   forge script script/DeployDetectors.s.sol:DeployDetectors \
 *     --rpc-url <REACTIVE_NETWORK_RPC> \
 *     --account <account-name> \
 *     --broadcast
 *
 * Environment Variables (Optional):
 *   VOTING_CONTRACT_ADDRESS - Address of VedyxVotingContract on destination chain
 *   DESTINATION_CHAIN_ID - Destination chain ID (default: 1301)
 *   ORIGIN_CHAIN_ID - Origin chain ID to monitor (default: 1301)
 *   TOKEN_REGISTRY_ADDRESS - Existing TokenRegistry (if already deployed)
 */
contract DeployDetectors is Script {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TRANSFER_TOPIC =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant DEFAULT_DESTINATION_CHAIN_ID = 1301; // Unichain Sepolia
    uint256 private constant DEFAULT_ORIGIN_CHAIN_ID = 1301; // Unichain Sepolia

    // ─── Deployed Contracts ───────────────────────────────────────────────
    TokenRegistry public tokenRegistry;
    LargeTransferDetector public largeTransferDetector;
    MixerInteractionDetector public mixerInteractionDetector;
    TracePeelChainDetector public tracePeelChainDetector;

    // ─── Configuration ────────────────────────────────────────────────────
    address public votingContract;
    uint256 public destinationChainId;
    uint256 public originChainId;

    function run() external {
        console2.log("========================================");
        console2.log("VEDYX DETECTORS DEPLOYMENT");
        console2.log("========================================");
        console2.log("Deployer:", msg.sender);
        console2.log("Chain ID:", block.chainid);
        console2.log("========================================\n");

        // Load configuration
        loadConfiguration();

        vm.startBroadcast();

        // Step 1: Deploy or load TokenRegistry
        deployOrLoadTokenRegistry();

        // Step 2: Deploy Detectors with new constructor args
        deployDetectors();

        // Step 3: Configure TokenRegistry with token metadata
        // configureTokenRegistry();

        // Step 4: Configure LargeTransferDetector thresholds
        configureLargeTransferDetector();

        // Step 5: Register mixer addresses in MixerInteractionDetector
        configureMixerInteractionDetector();

        // Step 6: Configure TracePeelChainDetector parameters
        configureTracePeelChainDetector();

        // // Step 7: Subscribe to Transfer events for all tokens
        // subscribeToTransferEvents();

        vm.stopBroadcast();

        // Step 8: Save deployment info
        saveDeployments();

        // Final summary
        printDeploymentSummary();
    }

    // ─── Configuration Loading ────────────────────────────────────────────
    function loadConfiguration() internal {
        console2.log("Loading Configuration...\n");

        // Load voting contract address
        votingContract = getVotingContractAddress();
        console2.log("Voting Contract:", votingContract);

        // Load destination chain ID
        destinationChainId = getDestinationChainId();
        console2.log("Destination Chain ID:", destinationChainId);

        // Load origin chain ID
        originChainId = getOriginChainId();
        console2.log("Origin Chain ID:", originChainId);
        console2.log("");
    }

    function getVotingContractAddress() internal view returns (address) {
        // Try environment variable first
        try vm.envAddress("VOTING_CONTRACT_ADDRESS") returns (address addr) {
            return addr;
        } catch {
            // Try to read from deployment file
            try
                vm.readFile("./deployments/unichain-sepolia/deployment.json")
            returns (string memory json) {
                bytes memory data = vm.parseJson(
                    json,
                    ".contracts.votingContract"
                );
                return abi.decode(data, (address));
            } catch {
                revert(
                    "VOTING_CONTRACT_ADDRESS not found in environment or deployment file"
                );
            }
        }
    }

    function getDestinationChainId() internal view returns (uint256) {
        try vm.envUint("DESTINATION_CHAIN_ID") returns (uint256 chainId) {
            return chainId;
        } catch {
            return DEFAULT_DESTINATION_CHAIN_ID;
        }
    }

    function getOriginChainId() internal view returns (uint256) {
        try vm.envUint("ORIGIN_CHAIN_ID") returns (uint256 chainId) {
            return chainId;
        } catch {
            return DEFAULT_ORIGIN_CHAIN_ID;
        }
    }

    // ─── Step 1: TokenRegistry Deployment ─────────────────────────────────
    function deployOrLoadTokenRegistry() internal {
        console2.log("STEP 1: TokenRegistry Setup...");

        // Check if TokenRegistry already exists
        try vm.envAddress("TOKEN_REGISTRY_ADDRESS") returns (
            address existingRegistry
        ) {
            tokenRegistry = TokenRegistry(existingRegistry);
            console2.log(
                "Using existing TokenRegistry:",
                address(tokenRegistry)
            );
        } catch {
            // Deploy new TokenRegistry
            tokenRegistry = new TokenRegistry();
            console2.log("Deployed new TokenRegistry:", address(tokenRegistry));
        }
        console2.log("");
    }

    // ─── Step 2: Deploy Detectors ─────────────────────────────────────────
    function deployDetectors() internal {
        console2.log("STEP 2: Deploying Attack Vector Detectors...");

        // Deploy LargeTransferDetector with new constructor args
        largeTransferDetector = new LargeTransferDetector{value: 0.1 ether}(
            address(tokenRegistry),
            votingContract,
            destinationChainId
        );
        console2.log("LargeTransferDetector:", address(largeTransferDetector));

        // Deploy MixerInteractionDetector with new constructor args
        mixerInteractionDetector = new MixerInteractionDetector{value: 0.1 ether}(
            address(tokenRegistry),
            votingContract,
            destinationChainId
        );
        console2.log(
            "MixerInteractionDetector:",
            address(mixerInteractionDetector)
        );

        // Deploy TracePeelChainDetector with new constructor args
        tracePeelChainDetector = new TracePeelChainDetector{value: 0.1 ether}(
            address(tokenRegistry),
            votingContract,
            destinationChainId
        );
        console2.log(
            "TracePeelChainDetector:",
            address(tracePeelChainDetector)
        );
        console2.log("");
    }

    // ─── Step 3: Configure TokenRegistry ──────────────────────────────────
    function configureTokenRegistry() internal {
        console2.log("STEP 3: Configuring TokenRegistry...");

        // Get tokens to monitor
        address[] memory tokens = getTokensToMonitor();

        if (tokens.length == 0) {
            console2.log(
                "WARNING: No tokens configured. Skipping TokenRegistry configuration."
            );
            console2.log(
                "Set TOKEN_1, TOKEN_2, etc. environment variables or add to deployment file."
            );
            console2.log("");
            return;
        }

        // Configure each token in the registry
        for (uint256 i = 0; i < tokens.length; i++) {
            // Default configuration - adjust decimals and symbols as needed
            uint8 decimals = 18; // Default to 18 decimals
            string memory symbol = string(
                abi.encodePacked("TOKEN", vm.toString(i + 1))
            );

            // Try to get decimals from environment
            try
                vm.envUint(
                    string(
                        abi.encodePacked(
                            "TOKEN_",
                            vm.toString(i + 1),
                            "_DECIMALS"
                        )
                    )
                )
            returns (uint256 dec) {
                decimals = uint8(dec);
            } catch {}

            // Try to get symbol from environment
            try
                vm.envString(
                    string(
                        abi.encodePacked(
                            "TOKEN_",
                            vm.toString(i + 1),
                            "_SYMBOL"
                        )
                    )
                )
            returns (string memory sym) {
                symbol = sym;
            } catch {}

            tokenRegistry.configureToken(tokens[i], decimals, symbol);
            console2.log("  Configured:", tokens[i]);
            console2.log("  - Decimals:", decimals);
            console2.log("  - Symbol:", symbol);
        }
        console2.log("");
    }

    // ─── Step 4: Configure LargeTransferDetector ──────────────────────────
    function configureLargeTransferDetector() internal {
        console2.log("STEP 4: Configuring LargeTransferDetector Thresholds...");

        address[] memory tokens = getTokensToMonitor();

        if (tokens.length == 0) {
            console2.log(
                "WARNING: No tokens to configure. Skipping threshold configuration."
            );
            console2.log("");
            return;
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            // Default threshold: 1000 tokens (in native decimals)
            uint256 threshold = 1000;

            // Try to get threshold from environment
            try
                vm.envUint(
                    string(
                        abi.encodePacked(
                            "TOKEN_",
                            vm.toString(i + 1),
                            "_THRESHOLD"
                        )
                    )
                )
            returns (uint256 t) {
                threshold = t;
            } catch {}

            largeTransferDetector.configureTokenThreshold(tokens[i], threshold);
            console2.log("  Token:", tokens[i], "- Threshold:", threshold);
        }
        console2.log("");
    }

    // ─── Step 5: Configure MixerInteractionDetector ───────────────────────
    function configureMixerInteractionDetector() internal {
        console2.log("STEP 5: Registering Mixer Addresses...");

        // Get mixer addresses from environment or use defaults
        address[] memory mixers = getMixersToMonitor();

        if (mixers.length == 0) {
            console2.log(
                "WARNING: No mixers configured. Using default Tornado Cash addresses."
            );
            console2.log(
                "Set MIXER_1, MIXER_2, etc. environment variables for custom mixers."
            );
            console2.log("");
            return;
        }

        // Prepare arrays for batch registration
        string[] memory names = new string[](mixers.length);
        for (uint256 i = 0; i < mixers.length; i++) {
            // Try to get mixer name from environment
            try
                vm.envString(
                    string(
                        abi.encodePacked("MIXER_", vm.toString(i + 1), "_NAME")
                    )
                )
            returns (string memory name) {
                names[i] = name;
            } catch {
                names[i] = string(
                    abi.encodePacked("Mixer_", vm.toString(i + 1))
                );
            }
        }

        // Batch register mixers
        mixerInteractionDetector.registerMixerBatch(mixers, names);

        for (uint256 i = 0; i < mixers.length; i++) {
            console2.log("  Registered:", mixers[i], "-", names[i]);
        }
        console2.log("");
    }

    // ─── Step 6: Configure TracePeelChainDetector ─────────────────────────
    function configureTracePeelChainDetector() internal {
        console2.log(
            "STEP 6: Configuring TracePeelChainDetector Parameters..."
        );

        // Default parameters (can be overridden via environment)
        uint64 minPeelPercentage = 500; // 5%
        uint64 maxPeelPercentage = 3000; // 30%
        uint64 minPeelCount = 3; // 3 peels minimum
        uint64 blockWindow = 100; // Within 100 blocks

        // Try to load from environment
        try vm.envUint("PEEL_MIN_PERCENTAGE") returns (uint256 val) {
            minPeelPercentage = uint64(val);
        } catch {}

        try vm.envUint("PEEL_MAX_PERCENTAGE") returns (uint256 val) {
            maxPeelPercentage = uint64(val);
        } catch {}

        try vm.envUint("PEEL_MIN_COUNT") returns (uint256 val) {
            minPeelCount = uint64(val);
        } catch {}

        try vm.envUint("PEEL_BLOCK_WINDOW") returns (uint256 val) {
            blockWindow = uint64(val);
        } catch {}

        tracePeelChainDetector.configure(
            minPeelPercentage,
            maxPeelPercentage,
            minPeelCount,
            blockWindow
        );

        console2.log(
            "  Min Peel %:",
            minPeelPercentage / 100,
            ".",
            minPeelPercentage % 100
        );
        console2.log(
            "  Max Peel %:",
            maxPeelPercentage / 100,
            ".",
            maxPeelPercentage % 100
        );
        console2.log("  Min Peel Count:", minPeelCount);
        console2.log("  Block Window:", blockWindow);
        console2.log("");
    }

    // ─── Step 7: Subscribe to Transfer Events ─────────────────────────────
    function subscribeToTransferEvents() internal {
        console2.log("STEP 7: Subscribing to Transfer Events...");

        address[] memory tokens = getTokensToMonitor();

        if (tokens.length == 0) {
            console2.log(
                "WARNING: No tokens to subscribe. Skipping subscriptions."
            );
            console2.log("");
            return;
        }

        console2.log(
            "Subscribing to",
            tokens.length,
            "tokens on chain",
            originChainId
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("  Token:", tokens[i]);

            // Subscribe LargeTransferDetector
            largeTransferDetector.subscribe(
                originChainId,
                tokens[i],
                TRANSFER_TOPIC
            );
            console2.log("    - LargeTransferDetector subscribed");

            // Subscribe MixerInteractionDetector
            mixerInteractionDetector.subscribe(
                originChainId,
                tokens[i],
                TRANSFER_TOPIC
            );
            console2.log("    - MixerInteractionDetector subscribed");

            // Subscribe TracePeelChainDetector
            tracePeelChainDetector.subscribe(
                originChainId,
                tokens[i],
                TRANSFER_TOPIC
            );
            console2.log("    - TracePeelChainDetector subscribed");
        }
        console2.log("");
    }

    // ─── Helper Functions ─────────────────────────────────────────────────
    function getTokensToMonitor() internal view returns (address[] memory) {
        // Try to load from deployment file first
        try
            vm.readFile("./deployments/unichain-sepolia/deployment.json")
        returns (string memory json) {
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

            if (count > 0) {
                address[] memory result = new address[](count);
                for (uint256 i = 0; i < count; i++) {
                    result[i] = tokens[i];
                }
                return result;
            }
        } catch {}

        // Fallback: Try environment variables
        try vm.envAddress("TOKEN_1") returns (address token1) {
            address[] memory tokens = new address[](6);
            uint256 count = 1;
            tokens[0] = token1;

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

            address[] memory result = new address[](count);
            for (uint256 i = 0; i < count; i++) {
                result[i] = tokens[i];
            }
            return result;
        } catch {
            return new address[](0);
        }
    }

    function getMixersToMonitor() internal view returns (address[] memory) {
        // Try to load from Unichain Sepolia deployment file first
        try
            vm.readFile("./deployments/unichain-sepolia/deployment.json")
        returns (string memory json) {
            console2.log(
                "  Loading mixers from Unichain Sepolia deployment file"
            );

            // Parse mixer addresses from deployment file (only try keys that exist)
            address[] memory mixers = new address[](2);
            uint256 count = 0;

            // Only parse mixer1 and mixer2 since those are the only ones in the file
            try vm.parseJson(json, ".mockMixers.mixer1") returns (
                bytes memory data
            ) {
                mixers[count++] = abi.decode(data, (address));
            } catch {}

            try vm.parseJson(json, ".mockMixers.mixer2") returns (
                bytes memory data
            ) {
                mixers[count++] = abi.decode(data, (address));
            } catch {}

            // Resize array to actual count
            if (count > 0) {
                address[] memory result = new address[](count);
                for (uint256 i = 0; i < count; i++) {
                    result[i] = mixers[i];
                }
                console2.log("  Loaded", count, "mixers from deployment file");
                return result;
            }
        } catch {}

        // Fallback: Try environment variables
        try vm.envAddress("MIXER_1") returns (address mixer1) {
            console2.log("  Loading mixers from environment variables");
            address[] memory mixers = new address[](10);
            uint256 count = 1;
            mixers[0] = mixer1;

            try vm.envAddress("MIXER_2") returns (address mixer2) {
                mixers[count++] = mixer2;
            } catch {}

            address[] memory result = new address[](count);
            for (uint256 i = 0; i < count; i++) {
                result[i] = mixers[i];
            }
            return result;
        } catch {
            return new address[](0);
        }
    }

    // ─── Step 8: Save Deployments ─────────────────────────────────────────
    function saveDeployments() internal {
        console2.log("STEP 8: Saving Deployment Addresses...");

        string memory part1 = string(
            abi.encodePacked(
                "{\n",
                '  "network": "reactive-network",\n',
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "contracts": {\n',
                '    "tokenRegistry": "',
                vm.toString(address(tokenRegistry)),
                '",\n'
            )
        );

        string memory part2 = string(
            abi.encodePacked(
                '    "largeTransferDetector": "',
                vm.toString(address(largeTransferDetector)),
                '",\n',
                '    "mixerInteractionDetector": "',
                vm.toString(address(mixerInteractionDetector)),
                '",\n',
                '    "tracePeelChainDetector": "',
                vm.toString(address(tracePeelChainDetector)),
                '"\n',
                "  },\n"
            )
        );

        string memory part3 = string(
            abi.encodePacked(
                '  "configuration": {\n',
                '    "votingContract": "',
                vm.toString(votingContract),
                '",\n',
                '    "destinationChainId": ',
                vm.toString(destinationChainId),
                ",\n",
                '    "originChainId": ',
                vm.toString(originChainId),
                "\n",
                "  },\n",
                '  "timestamp": ',
                vm.toString(block.timestamp),
                "\n",
                "}"
            )
        );

        string memory deploymentInfo = string(
            abi.encodePacked(part1, part2, part3)
        );

        vm.writeFile("./deployments/detectors-deployment.json", deploymentInfo);
        console2.log("Saved to: ./deployments/detectors-deployment.json");
        console2.log("");
    }

    // ─── Final Summary ────────────────────────────────────────────────────
    function printDeploymentSummary() internal view {
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("\nDeployed Contracts:");
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
        console2.log("\nConfiguration:");
        console2.log("  Voting Contract:", votingContract);
        console2.log("  Destination Chain ID:", destinationChainId);
        console2.log("  Origin Chain ID:", originChainId);
        console2.log("========================================");
        console2.log("\nNext Steps:");
        console2.log("1. Register detectors with VedyxExploitDetectorRSC");
        console2.log("2. Verify subscriptions are active");
        console2.log("3. Test detection with sample transactions");
        console2.log("4. Monitor ThreatDetected events");
        console2.log("========================================");
    }
}
