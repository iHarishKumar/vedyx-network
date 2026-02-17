// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// ─── Custom Errors ────────────────────────────────────────────────────
error InvalidAmount();
error InsufficientStake();
error VotingNotActive();
error VotingAlreadyEnded();
error AlreadyVoted();
error VotingNotEnded();
error NoStakeToWithdraw();
error InvalidVotingId();
error UnauthorizedCallback();
error InvalidAddress();
error VotingStillActive();
error CannotUnstakeWhenVotingIsActive();
error InvalidFeePercentage();
error InvalidTreasury();
error InsufficientFeesForReward();
error InsufficientVotingPower();
error InsufficientKarma();

/**
 * @title VedyxVotingContract
 * @notice Manages decentralized voting on suspicious addresses detected by the Vedyx Exploit Detector on Reactive Network
 * @dev Implements staking-based voting with karma tracking and penalty mechanisms
 *
 * ─── Key Features ─────────────────────────────────────────────────────────────
 * • Stake-based voting power: Users stake protocol tokens to participate
 * • Callback integration: Receives suspicious address reports from Vedyx Exploit Detector
 * • Multi-voting support: Manages multiple concurrent voting processes
 * • Penalty system: Slashes stakes of voters who vote against consensus
 * • Karma tracking: Rewards good voters and penalizes bad actors
 * • Time-bound voting: Each vote has a configurable duration
 * ──────────────────────────────────────────────────────────────────────────────
 */
contract VedyxVotingContract is Ownable, ReentrancyGuard, AccessControl {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    // ─── Constants ────────────────────────────────────────────────────────

    /// @notice Basis points for 100% (10000 = 100%)
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;

    /// @notice Divisor for karma bonus calculation (each 100 karma = 1% bonus)
    uint256 private constant KARMA_BONUS_DIVISOR = 10000;

    /// @notice Divisor for exponential karma penalty calculation
    uint256 private constant KARMA_PENALTY_DIVISOR = 100000;

    /// @notice Threshold for karma penalty overflow prevention
    uint256 private constant KARMA_OVERFLOW_THRESHOLD = 10000;

    /// @notice Maximum squared karma value to prevent overflow
    uint256 private constant MAX_SQUARED_KARMA = 100000000;

    // ─── Role Constants ───────────────────────────────────────────────────

    /// @notice Role for governance operations (critical parameters)
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice Role for parameter administration (day-to-day tuning)
    bytes32 public constant PARAMETER_ADMIN_ROLE = keccak256("PARAMETER_ADMIN_ROLE");

    /// @notice Role for treasury operations (financial management)
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // ─── State Variables ──────────────────────────────────────────────────

    /// @notice The protocol token used for staking
    IERC20 public immutable stakingToken;

    /// @notice Address authorized to trigger callbacks (Reactive Network bridge)
    address public callbackAuthorizer;

    /// @notice Minimum stake required to participate in voting
    uint256 public minimumStake;

    /// @notice Duration for each voting period (in seconds)
    uint256 public votingDuration;

    /// @notice Percentage of stake slashed for voting against consensus (basis points: 10000 = 100%)
    uint256 public penaltyPercentage;

    /// @notice Karma points awarded for correct votes
    uint256 public karmaReward;

    /// @notice Karma points deducted for incorrect votes
    uint256 public karmaPenalty;

    /// @notice Finalization fee percentage (basis points: 10000 = 100%)
    uint256 public finalizationFeePercentage;

    /// @notice Treasury address to collect fees
    address public treasury;

    /// @notice Total fees collected
    uint256 public totalFeesCollected;

    /// @notice Finalization reward percentage (basis points: 10000 = 100%)
    uint256 public finalizationRewardPercentage;

    /// @notice Minimum karma required to vote (prevents chronic bad actors from voting)
    int256 public minimumKarmaToVote;

    /// @notice Counter for voting IDs
    uint256 private votingIdCounter;

    // ─── Structs ──────────────────────────────────────────────────────────

    /// @notice Information about a suspicious address report
    struct SuspiciousReport {
        address suspiciousAddress;
        uint256 originChainId;
        address originContract;
        uint256 value;
        uint256 decimals;
        uint256 txHash;
        bytes32 detectorId;
    }

    /// @notice Voting process details
    struct Voting {
        uint256 votingId;
        SuspiciousReport report;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor; // Votes confirming suspicious
        uint256 votesAgainst; // Votes denying suspicious
        uint256 totalVotingPower;
        bool finalized;
        bool isSuspicious; // Final verdict
        mapping(address => Vote) votes;
        address[] voters;
    }

    /// @notice Individual vote details
    struct Vote {
        bool hasVoted;
        bool votedFor; // true = suspicious, false = not suspicious
        uint256 votingPower;
        uint256 stakedSnapshot; // Snapshot of stake at vote time
    }

    /// @notice Staker information
    struct Staker {
        uint256 stakedAmount;
        int256 karmaPoints;
        uint256 totalVotes;
        uint256 correctVotes;
        uint256 lockedAmount; // Amount locked in active votes
    }

    // ─── Mappings ─────────────────────────────────────────────────────────

    /// @notice Voting ID => Voting details
    mapping(uint256 => Voting) public votings;

    /// @notice Address => Staker details
    mapping(address => Staker) public stakers;

    /// @notice Track active voting IDs
    uint256[] public activeVotingIds;

    /// @notice Suspicious address => list of voting IDs
    mapping(address => uint256[]) public addressVotingHistory;

    // ─── Events ───────────────────────────────────────────────────────────

    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount, uint256 fee);
    event FeeCollected(address indexed staker, uint256 feeAmount);
    event TreasuryUpdated(address indexed newTreasury);
    event FinalizationFeeUpdated(uint256 newFeePercentage);
    event VotingStarted(
        uint256 indexed votingId,
        address indexed suspiciousAddress,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed votingId,
        address indexed voter,
        bool votedFor,
        uint256 votingPower
    );
    event VotingFinalized(
        uint256 indexed votingId,
        address indexed suspiciousAddress,
        bool isSuspicious,
        uint256 votesFor,
        uint256 votesAgainst
    );
    event PenaltyApplied(
        address indexed voter,
        uint256 indexed votingId,
        uint256 penaltyAmount
    );
    event KarmaUpdated(
        address indexed voter,
        int256 karmaChange,
        int256 newKarma
    );
    event CallbackAuthorizerUpdated(address indexed newAuthorizer);
    event MinimumStakeUpdated(uint256 newMinimum);
    event VotingDurationUpdated(uint256 newDuration);
    event PenaltyPercentageUpdated(uint256 newPercentage);
    event FinalizationRewardPaid(
        uint256 indexed votingId,
        address indexed finalizer,
        uint256 rewardAmount
    );
    event FinalizationRewardPercentageUpdated(uint256 newPercentage);
    event VoterRewarded(
        address indexed voter,
        uint256 indexed votingId,
        uint256 rewardAmount
    );
    event MinimumKarmaToVoteUpdated(int256 newMinimumKarma);

    // ─── Modifiers ────────────────────────────────────────────────────────

    modifier onlyCallbackAuthorizer() {
        if (msg.sender != callbackAuthorizer) revert UnauthorizedCallback();
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────

    /**
     * @param _stakingToken Address of the protocol token used for staking
     * @param _callbackAuthorizer Address authorized to trigger callbacks
     * @param _minimumStake Minimum stake required to vote
     * @param _votingDuration Duration of each voting period in seconds
     * @param _penaltyPercentage Penalty percentage in basis points (e.g., 1000 = 10%)
     * @param _treasury Treasury address to collect fees
     * @param _finalizationFeePercentage Finalization fee percentage in basis points (e.g., 100 = 1%)
     */
    constructor(
        address _stakingToken,
        address _callbackAuthorizer,
        uint256 _minimumStake,
        uint256 _votingDuration,
        uint256 _penaltyPercentage,
        address _treasury,
        uint256 _finalizationFeePercentage
    ) Ownable() {
        if (_stakingToken == address(0) || _callbackAuthorizer == address(0)) {
            revert InvalidAddress();
        }
        if (_treasury == address(0)) revert InvalidTreasury();
        if (_finalizationFeePercentage > 1000) revert InvalidFeePercentage(); // Max 10%

        stakingToken = IERC20(_stakingToken);
        callbackAuthorizer = _callbackAuthorizer;
        minimumStake = _minimumStake;
        votingDuration = _votingDuration;
        penaltyPercentage = _penaltyPercentage;
        treasury = _treasury;
        finalizationFeePercentage = _finalizationFeePercentage;
        finalizationRewardPercentage = 200; // 2% of collected fees as default reward
        karmaReward = 10;
        karmaPenalty = 5;
        minimumKarmaToVote = -50; // Default threshold

        // Grant all roles to deployer initially
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);
        _grantRole(PARAMETER_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
    }

    // ─── Staking Functions ────────────────────────────────────────────────

    /**
     * @notice Stake tokens to gain voting power
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        stakingToken.transferFrom(msg.sender, address(this), amount);

        stakers[msg.sender].stakedAmount =
            stakers[msg.sender].stakedAmount +
            amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens (only unlocked amount) without any fees
     * @param amount Amount of tokens to unstake
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        Staker storage staker = stakers[msg.sender];
        uint256 availableAmount = staker.stakedAmount > staker.lockedAmount
            ? staker.stakedAmount - staker.lockedAmount
            : 0;

        if (amount > availableAmount) revert InsufficientStake();
        // TODO - Revisit this revert once the finalisation is validated
        if (staker.lockedAmount > 0) revert CannotUnstakeWhenVotingIsActive();

        // Update staker state
        staker.stakedAmount = staker.stakedAmount - amount;

        // Transfer full amount to user (no fees)
        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, 0);
    }

    // ─── Callback Handler ─────────────────────────────────────────────────

    /**
     * @notice Callback function invoked by Reactive Network to start voting
     * @dev Only callable by the authorized callback address
     * @param suspiciousAddress The address flagged as suspicious
     * @param originChainId Chain ID where the suspicious activity occurred
     * @param originContract Contract address that emitted the suspicious event
     * @param value Value involved in the suspicious transaction
     * @param decimals Token decimals
     * @param txHash Transaction hash of the suspicious activity
     */
    function tagSuspicious(
        address suspiciousAddress,
        uint256 originChainId,
        address originContract,
        uint256 value,
        uint256 decimals,
        uint256 txHash
    ) external onlyCallbackAuthorizer returns (uint256 votingId) {
        if (suspiciousAddress == address(0)) revert InvalidAddress();

        votingId = ++votingIdCounter;

        Voting storage voting = votings[votingId];
        voting.votingId = votingId;
        voting.report = SuspiciousReport({
            suspiciousAddress: suspiciousAddress,
            originChainId: originChainId,
            originContract: originContract,
            value: value,
            decimals: decimals,
            txHash: txHash,
            detectorId: bytes32(0)
        });
        voting.startTime = block.timestamp;
        voting.endTime = block.timestamp + votingDuration;
        voting.finalized = false;

        activeVotingIds.push(votingId);
        addressVotingHistory[suspiciousAddress].push(votingId);

        emit VotingStarted(votingId, suspiciousAddress, voting.endTime);

        return votingId;
    }

    // ─── Voting Functions ─────────────────────────────────────────────────

    /**
     * @notice Cast a vote on whether an address is suspicious
     * @param votingId ID of the voting process
     * @param voteSuspicious true if voting suspicious, false otherwise
     */
    function castVote(
        uint256 votingId,
        bool voteSuspicious
    ) external nonReentrant {
        Voting storage voting = votings[votingId];

        if (voting.startTime == 0) revert InvalidVotingId();
        // TODO: Convert from block timestamp to block number
        if (block.timestamp >= voting.endTime) revert VotingAlreadyEnded();
        if (voting.finalized) revert VotingAlreadyEnded();
        if (voting.votes[msg.sender].hasVoted) revert AlreadyVoted();

        Staker storage staker = stakers[msg.sender];

        // Check karma threshold - prevent chronic bad actors from voting
        if (staker.karmaPoints < minimumKarmaToVote) {
            revert InsufficientKarma();
        }

        // Calculate available (unlocked) stake
        uint256 availableStake = staker.stakedAmount > staker.lockedAmount
            ? staker.stakedAmount - staker.lockedAmount
            : 0;

        // Check minimum stake requirement on available stake
        if (availableStake < minimumStake) revert InsufficientStake();

        // Calculate voting power based on minimum stake (not entire available stake)
        int256 votingPower = _calculateVotingPowerWithStake(
            staker.karmaPoints,
            availableStake
        );

        // Check if voting power is positive after karma penalties
        if (votingPower <= 0) {
            revert InsufficientVotingPower();
        }

        voting.votes[msg.sender] = Vote({
            hasVoted: true,
            votedFor: voteSuspicious,
            votingPower: uint256(votingPower), // At this point we are sure that only users with votingPower >= 0 would be here
            stakedSnapshot: availableStake
        });

        voting.voters.push(msg.sender);

        uint256 votingPowerUint = uint256(votingPower);

        if (voteSuspicious) {
            voting.votesFor = voting.votesFor + votingPowerUint;
        } else {
            voting.votesAgainst = voting.votesAgainst + votingPowerUint;
        }

        voting.totalVotingPower = voting.totalVotingPower + votingPowerUint;

        // Lock only the minimum stake for this vote
        staker.lockedAmount = staker.lockedAmount + minimumStake;
        staker.totalVotes = staker.totalVotes + 1;

        emit VoteCast(votingId, msg.sender, voteSuspicious, votingPowerUint);
    }

    /**
     * @notice Finalize a voting process after it ends
     * @dev Caller receives a reward from collected fees for finalizing the vote
     * @param votingId ID of the voting process to finalize
     */
    function finalizeVoting(uint256 votingId) external nonReentrant {
        Voting storage voting = votings[votingId];

        if (voting.startTime == 0) revert InvalidVotingId();
        // TODO: Migrate from block timestamp to block number
        if (block.timestamp < voting.endTime) revert VotingStillActive();
        if (voting.finalized) revert VotingAlreadyEnded();

        voting.finalized = true;

        // Determine consensus
        bool consensus = voting.votesFor > voting.votesAgainst;
        voting.isSuspicious = consensus;

        // Process rewards and penalties
        _processVotingResults(votingId, consensus);

        // Remove from active votings
        _removeActiveVoting(votingId);

        emit VotingFinalized(
            votingId,
            voting.report.suspiciousAddress,
            consensus,
            voting.votesFor,
            voting.votesAgainst
        );

        // Do the reward distribution in the end
        // Calculate and distribute finalization reward
        uint256 rewardAmount = 0;
        if (totalFeesCollected > 0 && finalizationRewardPercentage > 0) {
            rewardAmount = totalFeesCollected.mulDivDown(
                finalizationRewardPercentage,
                BASIS_POINTS_DIVISOR
            );

            // Ensure we have enough fees to pay the reward
            if (rewardAmount > 0 && rewardAmount <= totalFeesCollected) {
                totalFeesCollected = totalFeesCollected > rewardAmount
                    ? totalFeesCollected - rewardAmount
                    : 0;
                stakingToken.transfer(msg.sender, rewardAmount);

                emit FinalizationRewardPaid(votingId, msg.sender, rewardAmount);
            }
        }
    }

    // ─── Internal Functions ───────────────────────────────────────────────
    /**
     * @notice Calculate voting power for a voter based on their stake and karma
     * @param voter Address of the voter
     * @return Voting power as a signed integer (can be negative if karma is very negative)
     */
    function _calculateVotingPower(
        address voter
    ) internal view returns (int256) {
        Staker memory staker = stakers[voter];
        uint256 availableStake = staker.stakedAmount > staker.lockedAmount
            ? staker.stakedAmount - staker.lockedAmount
            : 0;
        return
            _calculateVotingPowerWithStake(staker.karmaPoints, availableStake);
    }

    /**
     * @notice Calculate voting power with a specific stake amount
     * @param karmaPoints Current Karma Points for the user for calculation
     * @param stakeAmount Stake amount to use for calculation
     * @return Voting power
     */
    function _calculateVotingPowerWithStake(
        int256 karmaPoints,
        uint256 stakeAmount
    ) internal pure returns (int256) {
        // Base voting power is the provided stake amount
        int256 basePower = int256(stakeAmount);

        // Karma multiplier: each 100 karma points adds 1% to voting power
        int256 karmaEffect;

        if (karmaPoints >= 0) {
            // Linear bonus for positive karma
            karmaEffect = int256(
                stakeAmount.mulDivDown(uint256(karmaPoints), KARMA_BONUS_DIVISOR)
            );
        } else {
            // EXPONENTIAL penalty for negative karma
            // Formula: penalty = stake * (karma^2) / 100000
            // This makes penalties progressively more severe
            uint256 absKarma = uint256(-karmaPoints);

            // Square the karma penalty (capped to prevent overflow)
            uint256 squaredKarma = absKarma > KARMA_OVERFLOW_THRESHOLD
                ? MAX_SQUARED_KARMA
                : (absKarma * absKarma);

            // Apply exponential penalty
            uint256 penaltyAmount = stakeAmount.mulDivDown(
                squaredKarma,
                KARMA_PENALTY_DIVISOR
            );
            karmaEffect = -int256(penaltyAmount);
        }

        return basePower + karmaEffect;
    }

    /**
     * @notice Process voting results, apply penalties and update karma
     * @param votingId ID of the voting process
     * @param consensus The final verdict (true = suspicious)
     */
    function _processVotingResults(uint256 votingId, bool consensus) internal {
        Voting storage voting = votings[votingId];

        // First pass: collect penalties and calculate total voting power of correct voters
        uint256 totalPenalties = 0;
        uint256 correctVotersTotalPower = 0;

        for (uint256 i = 0; i < voting.voters.length; i++) {
            address voter = voting.voters[i];
            Vote memory vote = voting.votes[voter];
            Staker storage staker = stakers[voter];

            // Unlock the staked amount using the snapshot
            uint256 stakedSnapshot = vote.stakedSnapshot;
            if (staker.lockedAmount >= minimumStake) {
                staker.lockedAmount = staker.lockedAmount - minimumStake;
            } else {
                staker.lockedAmount = 0;
            }

            // Check if voter voted with consensus
            bool votedCorrectly = vote.votedFor == consensus;

            if (votedCorrectly) {
                correctVotersTotalPower =
                    correctVotersTotalPower +
                    vote.votingPower;
            } else {
                // Calculate penalty for incorrect voters
                uint256 penalty = stakedSnapshot.mulDivDown(
                    penaltyPercentage,
                    BASIS_POINTS_DIVISOR
                );

                if (penalty > staker.stakedAmount) {
                    penalty = staker.stakedAmount;
                }

                totalPenalties = totalPenalties + penalty;
                staker.stakedAmount = staker.stakedAmount - penalty;

                // Deduct karma. Let it go below 0.
                staker.karmaPoints = staker.karmaPoints - int256(karmaPenalty);

                emit PenaltyApplied(voter, votingId, penalty);
                emit KarmaUpdated(
                    voter,
                    -int256(karmaPenalty),
                    staker.karmaPoints
                );
            }
        }

        // Collect finalization fee from total penalties
        uint256 finalizationFee = 0;
        uint256 penaltiesForDistribution = totalPenalties;

        if (totalPenalties > 0 && finalizationFeePercentage > 0) {
            finalizationFee = totalPenalties.mulDivDown(
                finalizationFeePercentage,
                BASIS_POINTS_DIVISOR
            );
            totalFeesCollected = totalFeesCollected + finalizationFee;
            penaltiesForDistribution = totalPenalties - finalizationFee;
            emit FeeCollected(address(this), finalizationFee);
        }

        // Second pass: distribute remaining penalties to correct voters proportionally
        for (uint256 i = 0; i < voting.voters.length; i++) {
            address voter = voting.voters[i];
            Vote memory vote = voting.votes[voter];
            Staker storage staker = stakers[voter];

            bool votedCorrectly = vote.votedFor == consensus;

            if (votedCorrectly) {
                // Update karma
                staker.karmaPoints = staker.karmaPoints + int256(karmaReward);
                staker.correctVotes = staker.correctVotes + 1;

                emit KarmaUpdated(
                    voter,
                    int256(karmaReward),
                    staker.karmaPoints
                );

                // Distribute proportional reward from penalties (after fee deduction)
                if (
                    penaltiesForDistribution > 0 && correctVotersTotalPower > 0
                ) {
                    uint256 voterReward = penaltiesForDistribution.mulDivDown(
                        vote.votingPower,
                        correctVotersTotalPower
                    );

                    if (voterReward > 0) {
                        staker.stakedAmount = staker.stakedAmount + voterReward;
                        emit VoterRewarded(voter, votingId, voterReward);
                    }
                }
            }
        }
    }

    /**
     * @notice Remove a voting ID from active votings array
     * @param votingId ID to remove
     */
    function _removeActiveVoting(uint256 votingId) internal {
        for (uint256 i = 0; i < activeVotingIds.length; i++) {
            if (activeVotingIds[i] == votingId) {
                activeVotingIds[i] = activeVotingIds[
                    activeVotingIds.length - 1
                ];
                activeVotingIds.pop();
                break;
            }
        }
    }

    // ─── Admin Functions ──────────────────────────────────────────────────

    /**
     * @notice Update the callback authorizer address
     * @param newAuthorizer New authorizer address
     */
    function setCallbackAuthorizer(address newAuthorizer) external onlyRole(GOVERNANCE_ROLE) {
        if (newAuthorizer == address(0)) revert InvalidAddress();
        callbackAuthorizer = newAuthorizer;
        emit CallbackAuthorizerUpdated(newAuthorizer);
    }

    /**
     * @notice Update minimum stake requirement
     * @param newMinimum New minimum stake amount
     */
    function setMinimumStake(uint256 newMinimum) external onlyRole(GOVERNANCE_ROLE) {
        minimumStake = newMinimum;
        emit MinimumStakeUpdated(newMinimum);
    }

    /**
     * @notice Update voting duration
     * @param newDuration New duration in seconds
     */
    function setVotingDuration(uint256 newDuration) external onlyRole(GOVERNANCE_ROLE) {
        votingDuration = newDuration;
        emit VotingDurationUpdated(newDuration);
    }

    /**
     * @notice Update penalty percentage
     * @param newPercentage New percentage in basis points
     */
    function setPenaltyPercentage(uint256 newPercentage) external onlyRole(GOVERNANCE_ROLE) {
        if (newPercentage > 5000) revert InvalidFeePercentage();
        penaltyPercentage = newPercentage;
        emit PenaltyPercentageUpdated(newPercentage);
    }

    /**
     * @notice Update karma reward amount
     * @param newReward New karma reward
     */
    function setKarmaReward(uint256 newReward) external onlyRole(PARAMETER_ADMIN_ROLE) {
        karmaReward = newReward;
    }

    /**
     * @notice Update karma penalty amount
     * @param newPenalty New karma penalty
     */
    function setKarmaPenalty(uint256 newPenalty) external onlyRole(PARAMETER_ADMIN_ROLE) {
        karmaPenalty = newPenalty;
    }

    /**
     * @notice Update minimum karma threshold required to vote
     * @param newMinimumKarma New minimum karma threshold (typically negative, e.g., -50)
     */
    function setMinimumKarmaToVote(int256 newMinimumKarma) external onlyRole(GOVERNANCE_ROLE) {
        minimumKarmaToVote = newMinimumKarma;
        emit MinimumKarmaToVoteUpdated(newMinimumKarma);
    }

    /**
     * @notice Update finalization reward percentage
     * @param newPercentage New percentage in basis points (max 10%)
     */
    function setFinalizationRewardPercentage(
        uint256 newPercentage
    ) external onlyRole(PARAMETER_ADMIN_ROLE) {
        if (newPercentage > 1000) revert InvalidFeePercentage(); // Max 10%
        // newPercentage cannot be >= finalizationFeePercentage
        if (newPercentage >= finalizationFeePercentage)
            revert InvalidFeePercentage();
        finalizationRewardPercentage = newPercentage;
        emit FinalizationRewardPercentageUpdated(newPercentage);
    }

    // ─── View Functions ───────────────────────────────────────────────────

    /**
     * @notice Get voting details
     * @param votingId ID of the voting process
     * @return report Suspicious report details
     * @return startTime Voting start time
     * @return endTime Voting end time
     * @return votesFor Votes confirming suspicious
     * @return votesAgainst Votes denying suspicious
     * @return finalized Whether voting is finalized
     * @return isSuspicious Final verdict
     */
    function getVotingDetails(
        uint256 votingId
    )
        external
        view
        returns (
            SuspiciousReport memory report,
            uint256 startTime,
            uint256 endTime,
            uint256 votesFor,
            uint256 votesAgainst,
            bool finalized,
            bool isSuspicious
        )
    {
        Voting storage voting = votings[votingId];
        return (
            voting.report,
            voting.startTime,
            voting.endTime,
            voting.votesFor,
            voting.votesAgainst,
            voting.finalized,
            voting.isSuspicious
        );
    }

    /**
     * @notice Get voter's vote for a specific voting
     * @param votingId ID of the voting process
     * @param voter Address of the voter
     * @return hasVoted Whether the voter has voted
     * @return votedFor The vote (true = suspicious)
     * @return votingPower Voting power used
     */
    function getVote(
        uint256 votingId,
        address voter
    )
        external
        view
        returns (bool hasVoted, bool votedFor, uint256 votingPower)
    {
        Vote memory vote = votings[votingId].votes[voter];
        return (vote.hasVoted, vote.votedFor, vote.votingPower);
    }

    /**
     * @notice Get staker information
     * @param staker Address of the staker
     * @return staker Staking information of the staker
     */
    function getStakerInfo(
        address stakerAddress
    ) external view returns (Staker memory staker) {
        staker = stakers[stakerAddress];
    }

    /**
     * @notice Get all active voting IDs
     * @return Array of active voting IDs
     */
    function getActiveVotings() external view returns (uint256[] memory) {
        return activeVotingIds;
    }

    /**
     * @notice Get voting history for an address
     * @param suspiciousAddress Address to query
     * @return Array of voting IDs
     */
    function getAddressVotingHistory(
        address suspiciousAddress
    ) external view returns (uint256[] memory) {
        return addressVotingHistory[suspiciousAddress];
    }

    /**
     * @notice Get voter's voting power
     * @param voter Address of the voter
     * @return Current voting power (can be negative if karma is very negative)
     */
    function getVotingPower(address voter) external view returns (int256) {
        return _calculateVotingPower(voter);
    }

    /**
     * @notice Get voter's accuracy rate
     * @param voter Address of the voter
     * @return Accuracy percentage (basis points)
     */
    function getVoterAccuracy(address voter) external view returns (uint256) {
        Staker memory staker = stakers[voter];
        if (staker.totalVotes == 0) return 0;
        return staker.correctVotes.mulDivDown(BASIS_POINTS_DIVISOR, staker.totalVotes);
    }

    /**
     * @notice Get all voters for a specific voting
     * @param votingId ID of the voting process
     * @return Array of voter addresses
     */
    function getVoters(
        uint256 votingId
    ) external view returns (address[] memory) {
        return votings[votingId].voters;
    }

    // ─── Admin Functions ──────────────────────────────────────────────────

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(TREASURY_ROLE) {
        if (newTreasury == address(0)) revert InvalidTreasury();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Update finalization fee percentage
     * @param newFeePercentage New fee percentage in basis points (max 10%)
     */
    function setFinalizationFeePercentage(
        uint256 newFeePercentage
    ) external onlyRole(TREASURY_ROLE) {
        if (newFeePercentage > 1000) revert InvalidFeePercentage(); // Max 10%
        if (newFeePercentage <= finalizationRewardPercentage)
            revert InvalidFeePercentage(); // newFeePercentage cannot be <= finalizationRewardPercentage.
        finalizationFeePercentage = newFeePercentage;
        emit FinalizationFeeUpdated(newFeePercentage);
    }

    /**
     * @notice Transfer collected fees to treasury
     * @dev Only callable by owner
     * @param amount Amount of fees to transfer
     */
    function transferFeesToTreasury(uint256 amount) external onlyRole(TREASURY_ROLE) {
        if (amount == 0) revert InvalidAmount();
        if (amount > totalFeesCollected) revert InvalidAmount();

        totalFeesCollected = totalFeesCollected > amount
            ? totalFeesCollected - amount
            : 0;
        stakingToken.transfer(treasury, amount);

        emit FeeCollected(treasury, amount);
    }
}
