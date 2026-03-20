import { Address, BigInt, Bytes, log } from "@graphprotocol/graph-ts";
import { Staker, GlobalStats, AddressVerdict, DetectorStats } from "../generated/schema";
import { VedyxVotingContract } from "../generated/VedyxVotingContract/VedyxVotingContract";

/**
 * Maps known detector ID hashes to human-readable names
 * Add new detector mappings here as they are deployed
 */
export function getDetectorName(detectorId: Bytes): string {
  let hash = detectorId.toHexString();
  
  // Known detector ID mappings (keccak256 hashes)
  // MIXER_INTERACTION_DETECTOR_V1 = keccak256("MIXER_INTERACTION_DETECTOR_V1")
  if (hash == "0x6b3d01054d791087086e711a499e5ef7f3b91cd1e251a821a0e50578979b6bbf") {
    return "MIXER_INTERACTION_DETECTOR_V1";
  }

  if(hash == "0x9373c3035f6afcc2f890d08622b3cf7e58aa746ca02ece5e9331eb5a347e1805") {
    return "LARGE_TRANSFER_DETECTOR_V1"
  }

  if(hash == "0x9d08ac44fe748ef45252504a7fb89f31a5c1e21d864df480cd7b0f78b816596b") {
    return "TRACE_PEEL_CHAIN_DETECTOR_V1"
  }
  
  // Add more detector mappings here as they are deployed
  // Example:
  // LARGE_TRANSFER_DETECTOR_V1 = keccak256("LARGE_TRANSFER_DETECTOR_V1")
  // if (hash == "0x...") {
  //   return "LARGE_TRANSFER_DETECTOR_V1";
  // }
  
  // Fallback: return shortened hex for unknown detectors
  return hash.slice(0, 10) + "...";
}

export function getOrCreateStaker(address: Address): Staker {
  let staker = Staker.load(address.toHexString());

  if (staker == null) {
    staker = new Staker(address.toHexString());
    staker.address = address;
    staker.stakedAmount = BigInt.fromI32(0);
    staker.lockedAmount = BigInt.fromI32(0);
    staker.karmaPoints = BigInt.fromI32(0);
    staker.totalVotes = BigInt.fromI32(0);
    staker.correctVotes = BigInt.fromI32(0);
    staker.createdAt = BigInt.fromI32(0);
    staker.updatedAt = BigInt.fromI32(0);
    staker.save();

    let stats = getOrCreateGlobalStats();
    stats.totalStakers = stats.totalStakers.plus(BigInt.fromI32(1));
    stats.save();
  }

  return staker;
}

export function getOrCreateGlobalStats(): GlobalStats {
  let stats = GlobalStats.load("global");

  if (stats == null) {
    stats = new GlobalStats("global");
    stats.totalStakers = BigInt.fromI32(0);
    stats.totalStaked = BigInt.fromI32(0);
    stats.totalVotings = BigInt.fromI32(0);
    stats.totalVotingsConcluded = BigInt.fromI32(0);
    stats.totalVotingsInconclusive = BigInt.fromI32(0);
    stats.totalSuspiciousVerdicts = BigInt.fromI32(0);
    stats.totalCleanVerdicts = BigInt.fromI32(0);
    stats.totalFeesCollected = BigInt.fromI32(0);
    stats.totalPenaltiesApplied = BigInt.fromI32(0);
    stats.totalRewardsDistributed = BigInt.fromI32(0);
    stats.updatedAt = BigInt.fromI32(0);
    stats.save();
  }

  return stats;
}

export function getOrCreateAddressVerdict(address: Address): AddressVerdict {
  let verdict = AddressVerdict.load(address.toHexString());

  if (verdict == null) {
    verdict = new AddressVerdict(address.toHexString());
    verdict.address = address;
    verdict.hasVerdict = false;
    verdict.isSuspicious = false;
    verdict.lastVotingId = BigInt.fromI32(0);
    verdict.verdictTimestamp = BigInt.fromI32(0);
    verdict.totalIncidents = BigInt.fromI32(0);
    verdict.createdAt = BigInt.fromI32(0);
    verdict.updatedAt = BigInt.fromI32(0);
    verdict.save();
  }

  return verdict;
}

export function updateStakerFromContract(contractAddress: Address, stakerAddress: Address): void {
  let contract = VedyxVotingContract.bind(contractAddress);
  let stakerData = contract.stakers(stakerAddress);

  let staker = getOrCreateStaker(stakerAddress);
  staker.stakedAmount = stakerData.getStakedAmount();
  staker.lockedAmount = stakerData.getLockedAmount();
  staker.karmaPoints = BigInt.fromI32(stakerData.getKarmaPoints().toI32());
  staker.totalVotes = stakerData.getTotalVotes();
  staker.correctVotes = stakerData.getCorrectVotes();
  staker.save();
}

export function getOrCreateDetectorStats(detectorId: Bytes): DetectorStats {
  let stats = DetectorStats.load(detectorId.toHexString());

  let readableName = getDetectorName(detectorId);
  log.info("Getting or creating detector stats for detectorId: {}, readable: {}", [detectorId.toHexString(), readableName]);

  if (stats == null) {
    stats = new DetectorStats(detectorId.toHexString());
    stats.detectorId = detectorId;
    stats.detectorName = readableName;
    stats.totalVotings = BigInt.fromI32(0);
    stats.totalAutoMarks = BigInt.fromI32(0);
    stats.totalSuspiciousVerdicts = BigInt.fromI32(0);
    stats.totalCleanVerdicts = BigInt.fromI32(0);
    stats.updatedAt = BigInt.fromI32(0);
    stats.save();
  }

  return stats;
}
