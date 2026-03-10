// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockMixer
 * @notice Mock mixer contract for testing on Lasna testnet
 * @dev Simulates Tornado Cash-like mixer behavior for testing detection
 */
contract MockMixer {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable denomination;
    
    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifiers;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address indexed to, bytes32 nullifierHash, uint256 fee);

    constructor(address _token, uint256 _denomination) {
        token = IERC20(_token);
        denomination = _denomination;
    }

    /**
     * @notice Deposit tokens into the mixer
     * @param commitment The commitment hash
     */
    function deposit(bytes32 commitment) external {
        require(!commitments[commitment], "Commitment already exists");
        
        token.safeTransferFrom(msg.sender, address(this), denomination);
        commitments[commitment] = true;
        
        emit Deposit(commitment, 0, block.timestamp);
    }

    /**
     * @notice Withdraw tokens from the mixer
     * @param recipient The recipient address
     * @param nullifierHash The nullifier hash
     */
    function withdraw(
        address recipient,
        bytes32 nullifierHash,
        bytes32 /* proof - not validated in mock */
    ) external {
        require(!nullifiers[nullifierHash], "Nullifier already used");
        
        nullifiers[nullifierHash] = true;
        token.safeTransfer(recipient, denomination);
        
        emit Withdrawal(recipient, nullifierHash, 0);
    }

    /**
     * @notice Check if a commitment exists
     */
    function isKnownCommitment(bytes32 commitment) external view returns (bool) {
        return commitments[commitment];
    }

    /**
     * @notice Check if a nullifier has been used
     */
    function isSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifiers[nullifierHash];
    }
}
