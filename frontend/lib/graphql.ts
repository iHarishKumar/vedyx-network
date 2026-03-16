import { keccak256, toUtf8Bytes } from "ethers";

const GRAPH_URL = "https://api.studio.thegraph.com/query/3616/vedyx-testnet/version/latest";

export interface DetectorStatsData {
  id: string;
  detectorId: string;
  detectorName: string;
  totalVotings: string;
  totalAutoMarks: string;
  totalSuspiciousVerdicts: string;
  totalCleanVerdicts: string;
}

export interface VotingData {
  originChainId: string;
}

export interface VotingDetail {
  id: string;
  votingId: string;
  suspiciousAddress: string;
  originChainId: string;
  originContract: string;
  value: string;
  decimals: string;
  txHash: string;
  detectorId: string;
  startTime: string;
  endTime: string;
  votesFor: string;
  votesAgainst: string;
  totalVotingPower: string;
  finalized: boolean;
  isSuspicious: boolean;
  isInconclusive: boolean;
  createdAt: string;
  finalizedAt: string | null;
}

export interface DetectorWithVotings extends DetectorStatsData {
  votings: VotingData[];
}

export function getDetectorIdHash(detectorName: string): string {
  return keccak256(toUtf8Bytes(detectorName));
}

const CHAIN_ID_MAP: Record<string, string> = {
  "1": "Ethereum",
  "137": "Polygon",
  "42161": "Arbitrum",
  "10": "Optimism",
  "56": "BSC",
  "8453": "Base",
  "1301": "Unichain Sepolia",
  "111188": "Lasna Testnet",
};

export function getChainName(chainId: string): string {
  return CHAIN_ID_MAP[chainId] || `Chain ${chainId}`;
}

export async function fetchDetectorStats(): Promise<DetectorWithVotings[]> {
  const query = `
    query GetDetectorStats {
      detectorStats(orderBy: totalVotings, orderDirection: desc) {
        id
        detectorId
        detectorName
        totalVotings
        totalAutoMarks
        totalSuspiciousVerdicts
        totalCleanVerdicts
        votings {
          originChainId
        }
      }
    }
  `;

  try {
    const response = await fetch(GRAPH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    
    if (result.errors) {
      console.error("GraphQL errors:", result.errors);
      throw new Error("GraphQL query failed");
    }

    return result.data.detectorStats || [];
  } catch (error) {
    console.error("Error fetching detector stats:", error);
    return [];
  }
}

export function getUniqueChains(votings: VotingData[]): string[] {
  const chainIds = new Set<string>();
  votings.forEach(voting => {
    chainIds.add(voting.originChainId);
  });
  
  return Array.from(chainIds).map(chainId => getChainName(chainId));
}

export function getTotalTriggers(detector: DetectorStatsData): number {
  return parseInt(detector.totalVotings) + parseInt(detector.totalAutoMarks);
}

export async function fetchVotingsByDetectorId(detectorId: string): Promise<VotingDetail[]> {
  const query = `
    query GetVotingsByDetector($detectorId: Bytes!) {
      votings(
        where: { detectorId: $detectorId }
        orderBy: createdAt
        orderDirection: desc
        first: 100
      ) {
        id
        votingId
        suspiciousAddress
        originChainId
        originContract
        value
        decimals
        txHash
        detectorId
        startTime
        endTime
        votesFor
        votesAgainst
        totalVotingPower
        finalized
        isSuspicious
        isInconclusive
        createdAt
        finalizedAt
      }
    }
  `;

  try {
    const response = await fetch(GRAPH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ 
        query,
        variables: { detectorId }
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    
    if (result.errors) {
      console.error("GraphQL errors:", result.errors);
      throw new Error("GraphQL query failed");
    }

    return result.data.votings || [];
  } catch (error) {
    console.error("Error fetching votings:", error);
    return [];
  }
}
