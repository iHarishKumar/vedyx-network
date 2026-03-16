import { BigInt, Bytes, store } from "@graphprotocol/graph-ts";
import {
  Staked,
  Unstaked,
  VotingStarted,
  VoteCast,
  VotingFinalized,
  VotingInconclusive,
  AddressAutoMarkedSuspicious,
  VerdictRecorded,
  VerdictCleared,
  FeeCollected,
  FinalizationRewardPaid,
  MinimumStakeUpdated,
  VotingDurationUpdated,
  PenaltyPercentageUpdated,
  MinimumKarmaToVoteUpdated,
  FinalizationRewardPercentageUpdated,
  MinimumVotersUpdated,
  MinimumTotalVotingPowerUpdated,
  TreasuryUpdated,
  FinalizationFeeUpdated,
  CallbackAuthorizerUpdated,
  VedyxVotingContract,
} from "../generated/VedyxVotingContract/VedyxVotingContract";
import {
  Staker,
  Voting,
  Vote,
  AddressVerdict,
  StakeEvent,
  UnstakeEvent,
  AutoMarkEvent,
  VerdictClearedEvent,
  FeeCollectedEvent,
  FinalizationReward,
  GlobalStats,
  ParameterUpdate,
  DetectorStats,
} from "../generated/schema";
import {
  getOrCreateStaker,
  getOrCreateGlobalStats,
  getOrCreateAddressVerdict,
  updateStakerFromContract,
  getOrCreateDetectorStats,
} from "./helpers";

export function handleStaked(event: Staked): void {
  let staker = getOrCreateStaker(event.params.staker);
  
  staker.stakedAmount = staker.stakedAmount.plus(event.params.amount);
  staker.updatedAt = event.block.timestamp;
  staker.save();

  let stakeEvent = new StakeEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  stakeEvent.staker = staker.id;
  stakeEvent.amount = event.params.amount;
  stakeEvent.timestamp = event.block.timestamp;
  stakeEvent.blockNumber = event.block.number;
  stakeEvent.transactionHash = event.transaction.hash;
  stakeEvent.save();

  let stats = getOrCreateGlobalStats();
  stats.totalStaked = stats.totalStaked.plus(event.params.amount);
  stats.updatedAt = event.block.timestamp;
  stats.save();

  updateStakerFromContract(event.address, event.params.staker);
}

export function handleUnstaked(event: Unstaked): void {
  let staker = getOrCreateStaker(event.params.staker);
  
  staker.stakedAmount = staker.stakedAmount.minus(event.params.amount);
  staker.updatedAt = event.block.timestamp;
  staker.save();

  let unstakeEvent = new UnstakeEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  unstakeEvent.staker = staker.id;
  unstakeEvent.amount = event.params.amount;
  unstakeEvent.timestamp = event.block.timestamp;
  unstakeEvent.blockNumber = event.block.number;
  unstakeEvent.transactionHash = event.transaction.hash;
  unstakeEvent.save();

  let stats = getOrCreateGlobalStats();
  stats.totalStaked = stats.totalStaked.minus(event.params.amount);
  stats.updatedAt = event.block.timestamp;
  stats.save();

  updateStakerFromContract(event.address, event.params.staker);
}

export function handleVotingStarted(event: VotingStarted): void {
  let voting = new Voting(event.params.votingId.toString());
  
  let contract = VedyxVotingContract.bind(event.address);
  let votingData = contract.votings(event.params.votingId);
  
  voting.votingId = event.params.votingId;
  voting.suspiciousAddress = event.params.suspiciousAddress;
  voting.originChainId = votingData.getReport().originChainId;
  voting.originContract = votingData.getReport().originContract;
  voting.value = votingData.getReport().value;
  voting.decimals = votingData.getReport().decimals;
  voting.txHash = votingData.getReport().txHash;
  voting.detectorId = event.params.detectorId;
  voting.startTime = votingData.getStartTime();
  voting.endTime = event.params.endTime;
  voting.votesFor = BigInt.fromI32(0);
  voting.votesAgainst = BigInt.fromI32(0);
  voting.totalVotingPower = BigInt.fromI32(0);
  voting.finalized = false;
  voting.isSuspicious = false;
  voting.isInconclusive = false;
  voting.createdAt = event.block.timestamp;

  let detectorStats = getOrCreateDetectorStats(event.params.detectorId);
  detectorStats.totalVotings = detectorStats.totalVotings.plus(BigInt.fromI32(1));
  detectorStats.updatedAt = event.block.timestamp;
  detectorStats.save();
  
  voting.detectorStats = detectorStats.id;
  voting.save();

  let verdict = getOrCreateAddressVerdict(event.params.suspiciousAddress);
  voting.verdict = verdict.id;
  voting.save();

  let stats = getOrCreateGlobalStats();
  stats.totalVotings = stats.totalVotings.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleVoteCast(event: VoteCast): void {
  let voting = Voting.load(event.params.votingId.toString());
  if (!voting) return;

  let staker = getOrCreateStaker(event.params.voter);
  
  let voteId = event.params.votingId.toString() + "-" + event.params.voter.toHexString();
  let vote = new Vote(voteId);
  vote.voting = voting.id;
  vote.voter = staker.id;
  vote.votedFor = event.params.votedFor;
  vote.votingPower = event.params.votingPower;
  vote.timestamp = event.block.timestamp;
  
  let contract = VedyxVotingContract.bind(event.address);
  let voteInfo = contract.voteInfo(event.params.votingId, event.params.voter);
  vote.stakedSnapshot = voteInfo.value3;
  
  vote.save();

  voting.totalVotingPower = voting.totalVotingPower.plus(event.params.votingPower);
  if (event.params.votedFor) {
    voting.votesFor = voting.votesFor.plus(event.params.votingPower);
  } else {
    voting.votesAgainst = voting.votesAgainst.plus(event.params.votingPower);
  }
  voting.save();

  updateStakerFromContract(event.address, event.params.voter);
}

export function handleVotingFinalized(event: VotingFinalized): void {
  let voting = Voting.load(event.params.votingId.toString());
  if (!voting) return;

  voting.finalized = true;
  voting.isSuspicious = event.params.isSuspicious;
  voting.votesFor = event.params.votesFor;
  voting.votesAgainst = event.params.votesAgainst;
  voting.finalizedAt = event.block.timestamp;
  voting.save();

  if (voting.detectorStats) {
    let detectorStats = DetectorStats.load(voting.detectorStats!);
    if (detectorStats) {
      if (event.params.isSuspicious) {
        detectorStats.totalSuspiciousVerdicts = detectorStats.totalSuspiciousVerdicts.plus(BigInt.fromI32(1));
      } else {
        detectorStats.totalCleanVerdicts = detectorStats.totalCleanVerdicts.plus(BigInt.fromI32(1));
      }
      detectorStats.updatedAt = event.block.timestamp;
      detectorStats.save();
    }
  }

  let stats = getOrCreateGlobalStats();
  stats.totalVotingsConcluded = stats.totalVotingsConcluded.plus(BigInt.fromI32(1));
  if (event.params.isSuspicious) {
    stats.totalSuspiciousVerdicts = stats.totalSuspiciousVerdicts.plus(BigInt.fromI32(1));
  } else {
    stats.totalCleanVerdicts = stats.totalCleanVerdicts.plus(BigInt.fromI32(1));
  }
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleVotingInconclusive(event: VotingInconclusive): void {
  let voting = Voting.load(event.params.votingId.toString());
  if (!voting) return;

  voting.finalized = true;
  voting.isInconclusive = true;
  voting.finalizedAt = event.block.timestamp;
  voting.save();

  let stats = getOrCreateGlobalStats();
  stats.totalVotingsInconclusive = stats.totalVotingsInconclusive.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleAddressAutoMarkedSuspicious(event: AddressAutoMarkedSuspicious): void {
  let verdict = getOrCreateAddressVerdict(event.params.suspiciousAddress);
  verdict.totalIncidents = event.params.incidentNumber;
  verdict.updatedAt = event.block.timestamp;
  verdict.save();

  let autoMarkEvent = new AutoMarkEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  autoMarkEvent.verdict = verdict.id;
  autoMarkEvent.suspiciousAddress = event.params.suspiciousAddress;
  autoMarkEvent.incidentNumber = event.params.incidentNumber;
  autoMarkEvent.previousVotingId = event.params.previousVotingId;
  autoMarkEvent.txHash = event.params.txHash;
  autoMarkEvent.detectorId = event.params.detectorId;
  autoMarkEvent.timestamp = event.block.timestamp;
  autoMarkEvent.blockNumber = event.block.number;
  autoMarkEvent.transactionHash = event.transaction.hash;
  autoMarkEvent.save();

  let detectorStats = getOrCreateDetectorStats(event.params.detectorId);
  detectorStats.totalAutoMarks = detectorStats.totalAutoMarks.plus(BigInt.fromI32(1));
  detectorStats.updatedAt = event.block.timestamp;
  detectorStats.save();
}

export function handleVerdictRecorded(event: VerdictRecorded): void {
  let verdict = getOrCreateAddressVerdict(event.params.suspiciousAddress);
  verdict.hasVerdict = true;
  verdict.isSuspicious = event.params.isSuspicious;
  verdict.lastVotingId = event.params.votingId;
  verdict.verdictTimestamp = event.params.timestamp;
  verdict.updatedAt = event.block.timestamp;
  verdict.save();
}

export function handleVerdictCleared(event: VerdictCleared): void {
  let verdict = getOrCreateAddressVerdict(event.params.suspiciousAddress);
  verdict.hasVerdict = false;
  verdict.isSuspicious = false;
  verdict.updatedAt = event.block.timestamp;
  verdict.save();

  let clearedEvent = new VerdictClearedEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  clearedEvent.verdict = verdict.id;
  clearedEvent.suspiciousAddress = event.params.suspiciousAddress;
  clearedEvent.clearedBy = event.params.clearedBy;
  clearedEvent.timestamp = event.block.timestamp;
  clearedEvent.blockNumber = event.block.number;
  clearedEvent.transactionHash = event.transaction.hash;
  clearedEvent.save();
}

export function handleFeeCollected(event: FeeCollected): void {
  let feeEvent = new FeeCollectedEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  feeEvent.recipient = event.params.staker;
  feeEvent.amount = event.params.feeAmount;
  feeEvent.timestamp = event.block.timestamp;
  feeEvent.blockNumber = event.block.number;
  feeEvent.transactionHash = event.transaction.hash;
  feeEvent.save();

  let stats = getOrCreateGlobalStats();
  stats.totalFeesCollected = stats.totalFeesCollected.plus(event.params.feeAmount);
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleFinalizationRewardPaid(event: FinalizationRewardPaid): void {
  let reward = new FinalizationReward(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  reward.votingId = event.params.votingId;
  reward.finalizer = event.params.finalizer;
  reward.amount = event.params.rewardAmount;
  reward.timestamp = event.block.timestamp;
  reward.blockNumber = event.block.number;
  reward.transactionHash = event.transaction.hash;
  reward.save();

  let stats = getOrCreateGlobalStats();
  stats.totalRewardsDistributed = stats.totalRewardsDistributed.plus(event.params.rewardAmount);
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleMinimumStakeUpdated(event: MinimumStakeUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "minimumStake";
  update.newValue = event.params.newMinimum;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleVotingDurationUpdated(event: VotingDurationUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "votingDuration";
  update.newValue = event.params.newDuration;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handlePenaltyPercentageUpdated(event: PenaltyPercentageUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "penaltyPercentage";
  update.newValue = event.params.newPercentage;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleMinimumKarmaToVoteUpdated(event: MinimumKarmaToVoteUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "minimumKarmaToVote";
  update.newValue = BigInt.fromI32(event.params.newMinimumKarma.toI32());
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleFinalizationRewardPercentageUpdated(event: FinalizationRewardPercentageUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "finalizationRewardPercentage";
  update.newValue = event.params.newPercentage;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleMinimumVotersUpdated(event: MinimumVotersUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "minimumVoters";
  update.newValue = event.params.newMinimumVoters;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleMinimumTotalVotingPowerUpdated(event: MinimumTotalVotingPowerUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "minimumTotalVotingPower";
  update.newValue = event.params.newMinimumPower;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleTreasuryUpdated(event: TreasuryUpdated): void {
}

export function handleFinalizationFeeUpdated(event: FinalizationFeeUpdated): void {
  let update = new ParameterUpdate(
    event.transaction.hash.concatI32(event.logIndex.toI32()).toHexString()
  );
  update.parameter = "finalizationFeePercentage";
  update.newValue = event.params.newFeePercentage;
  update.oldValue = BigInt.fromI32(0);
  update.updatedBy = event.transaction.from;
  update.timestamp = event.block.timestamp;
  update.blockNumber = event.block.number;
  update.transactionHash = event.transaction.hash;
  update.save();
}

export function handleCallbackAuthorizerUpdated(event: CallbackAuthorizerUpdated): void {
}
