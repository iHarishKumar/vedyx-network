// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

error InvalidTokenAddress();
error InvalidDecimals();
error InvalidConfiguration();

/**
 * @title TokenRegistry
 * @notice Singleton registry for ERC20 token configurations
 * @dev Provides shared storage for all detectors monitoring Transfer events
 * 
 * Architecture:
 * - Single deployed instance on Reactive Network
 * - All detectors reference this registry for token metadata
 * - Configure once, use everywhere
 * - True shared storage across all detectors
 */
contract TokenRegistry is Ownable {
    // ─── Constants ────────────────────────────────────────────────────────
    /// @notice Default decimals for unconfigured tokens
    uint8 public constant DEFAULT_DECIMALS = 18;
    
    // ─── Token Configuration Storage ──────────────────────────────────────
    /**
     * @notice Token configuration metadata
     * @dev Shared across all detectors
     */
    struct TokenConfig {
        uint8 decimals;          // Token decimal places (e.g., 6 for USDC, 18 for WETH)
        bool isConfigured;       // Whether token has been explicitly configured
        string symbol;           // Token symbol (e.g., "USDC", "WETH")
        uint256 configuredAt;    // Timestamp when configured
    }
    
    /// @notice Mapping of token address to configuration
    mapping(address => TokenConfig) private tokenConfigs;
    
    /// @notice List of all configured token addresses
    address[] private configuredTokens;
    
    // ─── Events ───────────────────────────────────────────────────────────
    event TokenConfigured(address indexed tokenAddress, uint8 decimals, string symbol);
    event TokensConfiguredBatch(uint256 count);
    event TokenRemoved(address indexed tokenAddress);
    
    // ─── Configuration Functions ──────────────────────────────────────────
    /**
     * @notice Configures a single token with metadata
     * @param tokenAddress The token contract address on the origin chain
     * @param decimals The token's decimal places
     * @param symbol The token symbol (optional, can be empty string)
     */
    function configureToken(
        address tokenAddress,
        uint8 decimals,
        string calldata symbol
    ) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        if (decimals > 77) revert InvalidDecimals();
        
        // Track if this is a new token
        bool isNew = !tokenConfigs[tokenAddress].isConfigured;
        
        tokenConfigs[tokenAddress] = TokenConfig({
            decimals: decimals,
            isConfigured: true,
            symbol: symbol,
            configuredAt: block.timestamp
        });
        
        // Add to list if new
        if (isNew) {
            configuredTokens.push(tokenAddress);
        }
        
        emit TokenConfigured(tokenAddress, decimals, symbol);
    }
    
    /**
     * @notice Configures multiple tokens at once (gas efficient)
     * @param tokenAddresses Array of token contract addresses
     * @param decimalsArray Array of corresponding decimal values
     * @param symbols Array of token symbols (can be empty strings)
     */
    function configureTokens(
        address[] calldata tokenAddresses,
        uint8[] calldata decimalsArray,
        string[] calldata symbols
    ) external onlyOwner {
        uint256 length = tokenAddresses.length;
        if (length != decimalsArray.length || length != symbols.length) {
            revert InvalidConfiguration();
        }
        
        for (uint256 i = 0; i < length; i++) {
            if (tokenAddresses[i] == address(0)) revert InvalidTokenAddress();
            if (decimalsArray[i] > 77) revert InvalidDecimals();
            
            bool isNew = !tokenConfigs[tokenAddresses[i]].isConfigured;
            
            tokenConfigs[tokenAddresses[i]] = TokenConfig({
                decimals: decimalsArray[i],
                isConfigured: true,
                symbol: symbols[i],
                configuredAt: block.timestamp
            });
            
            if (isNew) {
                configuredTokens.push(tokenAddresses[i]);
            }
            
            emit TokenConfigured(tokenAddresses[i], decimalsArray[i], symbols[i]);
        }
        
        emit TokensConfiguredBatch(length);
    }
    
    /**
     * @notice Simplified batch configuration without symbols
     * @param tokenAddresses Array of token contract addresses
     * @param decimalsArray Array of corresponding decimal values
     */
    function configureTokensSimple(
        address[] calldata tokenAddresses,
        uint8[] calldata decimalsArray
    ) external onlyOwner {
        uint256 length = tokenAddresses.length;
        if (length != decimalsArray.length) revert InvalidConfiguration();
        
        for (uint256 i = 0; i < length; i++) {
            if (tokenAddresses[i] == address(0)) revert InvalidTokenAddress();
            if (decimalsArray[i] > 77) revert InvalidDecimals();
            
            bool isNew = !tokenConfigs[tokenAddresses[i]].isConfigured;
            
            tokenConfigs[tokenAddresses[i]] = TokenConfig({
                decimals: decimalsArray[i],
                isConfigured: true,
                symbol: "",
                configuredAt: block.timestamp
            });
            
            if (isNew) {
                configuredTokens.push(tokenAddresses[i]);
            }
            
            emit TokenConfigured(tokenAddresses[i], decimalsArray[i], "");
        }
        
        emit TokensConfiguredBatch(length);
    }
    
    /**
     * @notice Removes a token configuration
     * @dev Does not remove from configuredTokens array to save gas
     * @param tokenAddress The token address to remove
     */
    function removeToken(address tokenAddress) external onlyOwner {
        if (!tokenConfigs[tokenAddress].isConfigured) revert InvalidTokenAddress();
        
        delete tokenConfigs[tokenAddress];
        emit TokenRemoved(tokenAddress);
    }
    
    // ─── View Functions ───────────────────────────────────────────────────
    /**
     * @notice Gets token decimals (configured or default)
     * @param tokenAddress The token address to query
     * @return decimals Token decimals (configured value or DEFAULT_DECIMALS)
     */
    function getDecimals(address tokenAddress) external view returns (uint8) {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        return config.isConfigured ? config.decimals : DEFAULT_DECIMALS;
    }
    
    /**
     * @notice Returns full token configuration
     * @param tokenAddress The token address to query
     * @return tokenDecimals Token decimals
     * @return configured Whether token is configured
     * @return tokenSymbol Token symbol
     * @return timestamp Timestamp when configured
     */
    function getTokenConfig(address tokenAddress) 
        external 
        view 
        returns (
            uint8 tokenDecimals,
            bool configured,
            string memory tokenSymbol,
            uint256 timestamp
        ) 
    {
        TokenConfig memory config = tokenConfigs[tokenAddress];
        return (config.decimals, config.isConfigured, config.symbol, config.configuredAt);
    }
    
    /**
     * @notice Checks if a token is configured
     * @param tokenAddress The token address to check
     * @return True if token has been configured
     */
    function isConfigured(address tokenAddress) external view returns (bool) {
        return tokenConfigs[tokenAddress].isConfigured;
    }
    
    /**
     * @notice Returns all configured token addresses
     * @return Array of configured token addresses
     */
    function getConfiguredTokens() external view returns (address[] memory) {
        return configuredTokens;
    }
    
    /**
     * @notice Returns the number of configured tokens
     * @return Count of configured tokens
     */
    function getConfiguredTokenCount() external view returns (uint256) {
        return configuredTokens.length;
    }
    
    /**
     * @notice Returns token symbol
     * @param tokenAddress The token address to query
     * @return Token symbol or empty string if not configured
     */
    function getSymbol(address tokenAddress) external view returns (string memory) {
        return tokenConfigs[tokenAddress].symbol;
    }
    
    /**
     * @notice Batch query for multiple token decimals
     * @param tokenAddresses Array of token addresses to query
     * @return result Array of corresponding decimals
     */
    function getDecimalsBatch(address[] calldata tokenAddresses) 
        external 
        view 
        returns (uint8[] memory result) 
    {
        result = new uint8[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            TokenConfig memory config = tokenConfigs[tokenAddresses[i]];
            result[i] = config.isConfigured ? config.decimals : DEFAULT_DECIMALS;
        }
    }
}
