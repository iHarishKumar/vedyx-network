import { BrowserProvider, Contract, parseUnits } from "ethers";

const VOTING_CONTRACT_ADDRESS = "0x4958A6535f634f4109e6ca4D27A2E7E55c6A6fA6";
const UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

const VOTING_CONTRACT_ABI = [
  "function castVote(uint256 votingId, bool voteSuspicious) external",
  "function stake(uint256 amount) external",
  "function unstake(uint256 amount) external",
  "function stakers(address) external view returns (uint256 stakedAmount, int256 karmaPoints, uint256 totalVotes, uint256 correctVotes, uint256 lockedAmount)",
  "function votings(uint256) external view returns (uint256 votingId, uint256 startTime, uint256 endTime, uint256 votesFor, uint256 votesAgainst, uint256 totalVotingPower, bool finalized, bool isSuspicious, bool isInconclusive)",
];

async function ensureCorrectNetwork() {
  if (typeof window === "undefined" || !window.ethereum) {
    throw new Error("No Ethereum provider found");
  }

  const provider = new BrowserProvider(window.ethereum);
  const network = await provider.getNetwork();
  
  if (Number(network.chainId) !== UNICHAIN_SEPOLIA_CHAIN_ID) {
    try {
      // Try to switch to Unichain Sepolia
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: `0x${UNICHAIN_SEPOLIA_CHAIN_ID.toString(16)}` }],
      });
    } catch (switchError: any) {
      // If the chain hasn't been added to the wallet, add it
      if (switchError.code === 4902) {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: `0x${UNICHAIN_SEPOLIA_CHAIN_ID.toString(16)}`,
              chainName: "Unichain Sepolia",
              nativeCurrency: {
                name: "Ether",
                symbol: "ETH",
                decimals: 18,
              },
              rpcUrls: ["https://sepolia.unichain.org"],
              blockExplorerUrls: ["https://sepolia.uniscan.xyz"],
            },
          ],
        });
      } else {
        throw switchError;
      }
    }
  }
}

export async function getVotingContract() {
  await ensureCorrectNetwork();
  
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return new Contract(VOTING_CONTRACT_ADDRESS, VOTING_CONTRACT_ABI, signer);
}

export async function getStakingTokenContract() {
  await ensureCorrectNetwork();
  
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return new Contract(STAKING_TOKEN_ADDRESS, ERC20_ABI, signer);
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

export async function getTokenBalance(address: string) {
  try {
    const tokenContract = await getStakingTokenContract();
    const balance = await tokenContract.balanceOf(address);
    const decimals = await tokenContract.decimals();
    return formatUnits(balance, decimals);
  } catch (error) {
    console.error("Error fetching token balance:", error);
    return "0";
  }
}

export async function getTokenAllowance(ownerAddress: string) {
  try {
    const tokenContract = await getStakingTokenContract();
    const allowance = await tokenContract.allowance(ownerAddress, VOTING_CONTRACT_ADDRESS);
    const decimals = await tokenContract.decimals();
    return formatUnits(allowance, decimals);
  } catch (error) {
    console.error("Error fetching token allowance:", error);
    return "0";
  }
}

export async function approveToken(amount: string) {
  try {
    const tokenContract = await getStakingTokenContract();
    const decimals = await tokenContract.decimals();
    const amountInWei = parseUnits(amount, decimals);
    const tx = await tokenContract.approve(VOTING_CONTRACT_ADDRESS, amountInWei);
    await tx.wait();
    return { success: true, txHash: tx.hash };
  } catch (error: any) {
    console.error("Error approving token:", error);
    return { 
      success: false, 
      error: error.message || "Failed to approve token" 
    };
  }
}

export async function stakeTokens(amount: string) {
  try {
    const contract = await getVotingContract();
    const tokenContract = await getStakingTokenContract();
    const decimals = await tokenContract.decimals();
    const amountInWei = parseUnits(amount, decimals);
    const tx = await contract.stake(amountInWei);
    await tx.wait();
    return { success: true, txHash: tx.hash };
  } catch (error: any) {
    console.error("Error staking tokens:", error);
    return { 
      success: false, 
      error: error.message || "Failed to stake tokens" 
    };
  }
}

export async function unstakeTokens(amount: string) {
  try {
    const contract = await getVotingContract();
    const tokenContract = await getStakingTokenContract();
    const decimals = await tokenContract.decimals();
    const amountInWei = parseUnits(amount, decimals);
    const tx = await contract.unstake(amountInWei);
    await tx.wait();
    return { success: true, txHash: tx.hash };
  } catch (error: any) {
    console.error("Error unstaking tokens:", error);
    return { 
      success: false, 
      error: error.message || "Failed to unstake tokens" 
    };
  }
}
