import { BrowserProvider, Contract, parseUnits } from "ethers";

const VOTING_CONTRACT_ADDRESS = "0x4958A6535f634f4109e6ca4D27A2E7E55c6A6fA6";

const VOTING_CONTRACT_ABI = [
  "function castVote(uint256 votingId, bool voteSuspicious) external",
  "function stake(uint256 amount) external",
  "function unstake(uint256 amount) external",
  "function stakers(address) external view returns (uint256 stakedAmount, int256 karmaPoints, uint256 totalVotes, uint256 correctVotes, uint256 lockedAmount)",
  "function votings(uint256) external view returns (uint256 votingId, uint256 startTime, uint256 endTime, uint256 votesFor, uint256 votesAgainst, uint256 totalVotingPower, bool finalized, bool isSuspicious, bool isInconclusive)",
];

export async function getVotingContract() {
  if (typeof window === "undefined" || !window.ethereum) {
    throw new Error("No Ethereum provider found");
  }

  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return new Contract(VOTING_CONTRACT_ADDRESS, VOTING_CONTRACT_ABI, signer);
}

export async function castVote(votingId: string, voteSuspicious: boolean) {
  try {
    const contract = await getVotingContract();
    const tx = await contract.castVote(votingId, voteSuspicious);
    await tx.wait();
    return { success: true, txHash: tx.hash };
  } catch (error: any) {
    console.error("Error casting vote:", error);
    return { 
      success: false, 
      error: error.message || "Failed to cast vote" 
    };
  }
}

export async function getStakerInfo(address: string) {
  try {
    const contract = await getVotingContract();
    const info = await contract.stakers(address);
    return {
      stakedAmount: info.stakedAmount.toString(),
      karmaPoints: info.karmaPoints.toString(),
      totalVotes: info.totalVotes.toString(),
      correctVotes: info.correctVotes.toString(),
      lockedAmount: info.lockedAmount.toString(),
    };
  } catch (error) {
    console.error("Error fetching staker info:", error);
    return null;
  }
}
