// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {IAttackVectorDetector} from "../interfaces/IAttackVectorDetector.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

error InvalidMixerAddress();
error MixerAlreadyRegistered();
error MixerNotRegistered();

/**
 * @title MixerInteractionDetector
 * @notice Detects interactions with known mixer/Tornado Cash contracts
 * @dev Implements IAttackVectorDetector to plug into VedyxExploitDetectorRSC
 * @dev Monitors Transfer events to detect when addresses interact with known mixers
 */
contract MixerInteractionDetector is IAttackVectorDetector, Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    uint256 private constant TOPIC_TRANSFER =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    
    bytes32 private constant DETECTOR_ID = keccak256("MIXER_INTERACTION_DETECTOR_V1");

    // ─── State ────────────────────────────────────────────────────────
    bool public active;

    struct MixerInfo {
        bool isRegistered;
        string name;
        uint256 addedTimestamp;
    }

    mapping(address => MixerInfo) private knownMixers;
    address[] private mixerAddresses;

    // ─── Events ───────────────────────────────────────────────────────────
    event MixerRegistered(
        address indexed mixerAddress,
        string name,
        uint256 timestamp
    );

    event MixerUnregistered(
        address indexed mixerAddress,
        string name
    );

    event DetectorActivated();
    event DetectorDeactivated();

    event MixerInteractionDetected(
        address indexed suspiciousAddress,
        address indexed mixerAddress,
        uint256 chainId,
        uint256 value,
        bool isDeposit
    );

    // ─── Constructor ──────────────────────────────────────────────────
    constructor() Ownable() {
        active = true;
        _registerDefaultMixers();
    }

    // ─── IAttackVectorDetector Implementation ─────────────────────────────
    /**
     * @notice Analyzes a log record for mixer interaction patterns
     * @param log The log record to analyze
     * @return detected Whether a threat was detected
     * @return suspiciousAddress The address flagged as suspicious
     * @return payload The encoded callback payload
     */
    function detect(
        IReactive.LogRecord calldata log
    )
        external
        view
        override
        returns (
            bool detected,
            address suspiciousAddress,
            bytes memory payload
        )
    {
        if (!active) {
            return (false, address(0), "");
        }

        if (log.topic_0 != TOPIC_TRANSFER) {
            return (false, address(0), "");
        }

        if (log.data.length < 32) {
            return (false, address(0), "");
        }

        address from = address(uint160(log.topic_1));
        address to = address(uint160(log.topic_2));
        address tokenContract = log._contract;
        
        bytes memory logData = log.data;
        uint256 value;
        assembly {
            value := mload(add(logData, 0x20))
        }

        bool fromIsMixer = knownMixers[from].isRegistered;
        bool toIsMixer = knownMixers[to].isRegistered;

        if (fromIsMixer) {
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256,bytes32)",
                to,
                log.chain_id,
                tokenContract,
                value,
                0,
                log.tx_hash,
                DETECTOR_ID
            );
            
            return (true, to, payload);
        }

        if (toIsMixer) {
            payload = abi.encodeWithSignature(
                "tagSuspicious(address,uint256,address,uint256,uint256,uint256,bytes32)",
                from,
                log.chain_id,
                tokenContract,
                value,
                0,
                log.tx_hash,
                DETECTOR_ID
            );
            
            return (true, from, payload);
        }

        return (false, address(0), "");
    }

    /**
     * @notice Returns the event topic_0 that this detector monitors
     * @return The Transfer event signature hash
     */
    function getMonitoredTopic() external pure override returns (uint256) {
        return TOPIC_TRANSFER;
    }

    /**
     * @notice Returns a unique identifier for this detector
     * @return The detector's unique identifier
     */
    function getDetectorId() external pure override returns (bytes32) {
        return DETECTOR_ID;
    }

    /**
     * @notice Returns whether this detector is active
     * @return True if the detector is active
     */
    function isActive() external view override returns (bool) {
        return active;
    }

    // ─── Mixer Management ─────────────────────────────────────────────────
    /**
     * @notice Registers a new mixer address
     * @param mixerAddress The address of the mixer contract
     * @param name Human-readable name for the mixer (e.g., "Tornado Cash 0.1 ETH")
     */
    function registerMixer(
        address mixerAddress,
        string calldata name
    ) external onlyOwner {
        if (mixerAddress == address(0)) revert InvalidMixerAddress();
        if (knownMixers[mixerAddress].isRegistered) revert MixerAlreadyRegistered();

        knownMixers[mixerAddress] = MixerInfo({
            isRegistered: true,
            name: name,
            addedTimestamp: block.timestamp
        });

        mixerAddresses.push(mixerAddress);

        emit MixerRegistered(mixerAddress, name, block.timestamp);
    }

    /**
     * @notice Registers multiple mixer addresses at once
     * @param mixerAddressList Array of mixer addresses
     * @param names Array of names corresponding to each mixer
     */
    function registerMixerBatch(
        address[] calldata mixerAddressList,
        string[] calldata names
    ) external onlyOwner {
        require(mixerAddressList.length == names.length, "Array length mismatch");
        
        for (uint256 i = 0; i < mixerAddressList.length; i++) {
            address mixerAddress = mixerAddressList[i];
            
            if (mixerAddress == address(0)) revert InvalidMixerAddress();
            if (knownMixers[mixerAddress].isRegistered) continue;

            knownMixers[mixerAddress] = MixerInfo({
                isRegistered: true,
                name: names[i],
                addedTimestamp: block.timestamp
            });

            mixerAddresses.push(mixerAddress);

            emit MixerRegistered(mixerAddress, names[i], block.timestamp);
        }
    }

    /**
     * @notice Unregisters a mixer address
     * @param mixerAddress The address of the mixer to remove
     */
    function unregisterMixer(address mixerAddress) external onlyOwner {
        if (!knownMixers[mixerAddress].isRegistered) {
            revert MixerNotRegistered();
        }

        string memory name = knownMixers[mixerAddress].name;
        delete knownMixers[mixerAddress];

        for (uint256 i = 0; i < mixerAddresses.length; i++) {
            if (mixerAddresses[i] == mixerAddress) {
                mixerAddresses[i] = mixerAddresses[mixerAddresses.length - 1];
                mixerAddresses.pop();
                break;
            }
        }

        emit MixerUnregistered(mixerAddress, name);
    }

    /**
     * @notice Activates the detector
     */
    function activate() external onlyOwner {
        active = true;
        emit DetectorActivated();
    }

    /**
     * @notice Deactivates the detector
     */
    function deactivate() external onlyOwner {
        active = false;
        emit DetectorDeactivated();
    }

    // ─── Getters ──────────────────────────────────────────────────────────
    /**
     * @notice Checks if an address is a registered mixer
     * @param mixerAddress The address to check
     * @return isRegistered Whether the address is a known mixer
     * @return name The name of the mixer (empty if not registered)
     * @return addedTimestamp When the mixer was added
     */
    function getMixerInfo(
        address mixerAddress
    )
        external
        view
        returns (bool isRegistered, string memory name, uint256 addedTimestamp)
    {
        MixerInfo memory info = knownMixers[mixerAddress];
        return (info.isRegistered, info.name, info.addedTimestamp);
    }

    /**
     * @notice Returns all registered mixer addresses
     * @return Array of mixer addresses
     */
    function getAllMixers() external view returns (address[] memory) {
        return mixerAddresses;
    }

    /**
     * @notice Returns the total number of registered mixers
     * @return The count of registered mixers
     */
    function getMixerCount() external view returns (uint256) {
        return mixerAddresses.length;
    }

    /**
     * @notice Checks if an address is a registered mixer
     * @param mixerAddress The address to check
     * @return True if the address is a known mixer
     */
    function isMixer(address mixerAddress) external view returns (bool) {
        return knownMixers[mixerAddress].isRegistered;
    }

    // ─── Internal Functions ───────────────────────────────────────────────
    /**
     * @notice Registers default known mixer addresses (Tornado Cash instances)
     * @dev Called during construction to populate initial mixer list
     */
    function _registerDefaultMixers() private {
        _addMixer(0x12D66f87A04A9E220743712cE6d9bB1B5616B8Fc, "Tornado Cash 0.1 ETH");
        _addMixer(0x47CE0C6eD5B0Ce3d3A51fdb1C52DC66a7c3c2936, "Tornado Cash 1 ETH");
        _addMixer(0x910Cbd523D972eb0a6f4cAe4618aD62622b39DbF, "Tornado Cash 10 ETH");
        _addMixer(0xA160cdAB225685dA1d56aa342Ad8841c3b53f291, "Tornado Cash 100 ETH");
        _addMixer(0xD4B88Df4D29F5CedD6857912842cff3b20C8Cfa3, "Tornado Cash 100 DAI");
        _addMixer(0xFD8610d20aA15b7B2E3Be39B396a1bC3516c7144, "Tornado Cash 1000 DAI");
        _addMixer(0xF60dD140cFf0706bAE9Cd734Ac3ae76AD9eBC32A, "Tornado Cash 10000 DAI");
        _addMixer(0x22aaA7720ddd5388A3c0A3333430953C68f1849b, "Tornado Cash 100000 DAI");
        _addMixer(0xBA214C1c1928a32Bffe790263E38B4Af9bFCD659, "Tornado Cash 100 USDC");
        _addMixer(0xb1C8094B234DcE6e03f10a5b673c1d8C69739A00, "Tornado Cash 1000 USDC");
        _addMixer(0x527653eA119F3E6a1F5BD18fbF4714081D7B31ce, "Tornado Cash 100 USDT");
        _addMixer(0x0836222F2B2B24A3F36f98668Ed8F0B38D1a872f, "Tornado Cash 1000 USDT");
    }

    /**
     * @notice Internal helper to add a mixer and emit registration event
     * @param mixerAddress The address of the mixer
     * @param name The name of the mixer
     */
    function _addMixer(address mixerAddress, string memory name) private {
        knownMixers[mixerAddress] = MixerInfo({
            isRegistered: true,
            name: name,
            addedTimestamp: block.timestamp
        });
        mixerAddresses.push(mixerAddress);
        
        emit MixerRegistered(mixerAddress, name, block.timestamp);
    }
}
