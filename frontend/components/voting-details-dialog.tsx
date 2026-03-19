"use client";

import { useEffect, useState } from "react";
import { ThumbsUp, ThumbsDown, Loader2, ExternalLink, Clock, CheckCircle, XCircle, AlertCircle } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { fetchVotingsByDetectorId, getChainName, type VotingDetail } from "@/lib/graphql";
import { castVote } from "@/lib/contract";
import { formatDistanceToNow } from "date-fns";
import { useAccount } from "wagmi";

interface VotingDetailsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  detectorId: string;
  detectorName: string;
}

export function VotingDetailsDialog({
  open,
  onOpenChange,
  detectorId,
  detectorName,
}: VotingDetailsDialogProps) {
  const [votings, setVotings] = useState<VotingDetail[]>([]);
  const [loading, setLoading] = useState(false);
  const [votingInProgress, setVotingInProgress] = useState<string | null>(null);
  const { address, isConnected } = useAccount();

  useEffect(() => {
    if (open && detectorId) {
      loadVotings();
    }
  }, [open, detectorId]);

  async function loadVotings() {
    setLoading(true);
    try {
      const data = await fetchVotingsByDetectorId(detectorId);
      setVotings(data);
    } catch (error) {
      console.error("Failed to load votings:", error);
    } finally {
      setLoading(false);
    }
  }

  async function handleUpvote(votingId: string) {
    if (!isConnected) {
      alert("Please connect your wallet to vote");
      return;
    }

    setVotingInProgress(votingId);
    try {
      const result = await castVote(votingId, true);
      if (result.success) {
        alert(`Vote cast successfully! Transaction: ${result.txHash}`);
        await loadVotings();
      } else {
        alert(`Failed to cast vote: ${result.error}`);
      }
    } catch (error) {
      console.error("Error voting:", error);
      alert("Failed to cast vote. Please try again.");
    } finally {
      setVotingInProgress(null);
    }
  }

  async function handleDownvote(votingId: string) {
    if (!isConnected) {
      alert("Please connect your wallet to vote");
      return;
    }

    setVotingInProgress(votingId);
    try {
      const result = await castVote(votingId, false);
      if (result.success) {
        alert(`Vote cast successfully! Transaction: ${result.txHash}`);
        await loadVotings();
      } else {
        alert(`Failed to cast vote: ${result.error}`);
      }
    } catch (error) {
      console.error("Error voting:", error);
      alert("Failed to cast vote. Please try again.");
    } finally {
      setVotingInProgress(null);
    }
  }

  function formatAddress(address: string): string {
    if (!address) return "";
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  }

  function formatTimestamp(timestamp: string): string {
    const date = new Date(parseInt(timestamp) * 1000);
    return formatDistanceToNow(date, { addSuffix: true });
  }

  function calculateVoterCount(votingPower: string): number {
    const MINIMUM_STAKE = BigInt("100000000000000000000"); // 100e18
    const power = BigInt(votingPower);
    return Number(power / MINIMUM_STAKE);
  }

  function getStatusBadge(voting: VotingDetail) {
    if (!voting.finalized) {
      return (
        <Badge variant="outline" className="bg-blue-500/10 text-blue-600 border-blue-500/20">
          <Clock className="h-3 w-3 mr-1" />
          Active
        </Badge>
      );
    }
    if (voting.isInconclusive) {
      return (
        <Badge variant="outline" className="bg-gray-500/10 text-gray-600 border-gray-500/20">
          <AlertCircle className="h-3 w-3 mr-1" />
          Inconclusive
        </Badge>
      );
    }
    if (voting.isSuspicious) {
      return (
        <Badge variant="outline" className="bg-red-500/10 text-red-600 border-red-500/20">
          <XCircle className="h-3 w-3 mr-1" />
          Suspicious
        </Badge>
      );
    }
    return (
      <Badge variant="outline" className="bg-green-500/10 text-green-600 border-green-500/20">
        <CheckCircle className="h-3 w-3 mr-1" />
        Clean
      </Badge>
    );
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-6xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="text-2xl">Voting Details - {detectorName}</DialogTitle>
          <DialogDescription>
            View all votings for this detector and cast your vote
          </DialogDescription>
        </DialogHeader>

        {loading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </div>
        ) : votings.length === 0 ? (
          <div className="text-center py-12">
            <AlertCircle className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
            <h3 className="text-lg font-semibold mb-2">No Votings Found</h3>
            <p className="text-muted-foreground">
              No voting records are available for this detector.
            </p>
          </div>
        ) : (
          <div className="border rounded-lg">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Voting ID</TableHead>
                  <TableHead>Address</TableHead>
                  <TableHead>Chain</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Votes For</TableHead>
                  <TableHead>Votes Against</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {votings.map((voting) => (
                  <TableRow key={voting.id}>
                    <TableCell className="font-mono text-sm">
                      #{voting.votingId}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-sm">
                          {formatAddress(voting.suspiciousAddress)}
                        </span>
                        <a
                          href={`https://etherscan.io/address/${voting.suspiciousAddress}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-muted-foreground hover:text-primary"
                        >
                          <ExternalLink className="h-3 w-3" />
                        </a>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">
                        {getChainName(voting.originChainId)}
                      </Badge>
                    </TableCell>
                    <TableCell>{getStatusBadge(voting)}</TableCell>
                    <TableCell className="text-green-600 font-semibold">
                      {calculateVoterCount(voting.votesFor)}
                    </TableCell>
                    <TableCell className="text-red-600 font-semibold">
                      {calculateVoterCount(voting.votesAgainst)}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {formatTimestamp(voting.createdAt)}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-green-600 hover:text-green-700 hover:bg-green-50"
                          onClick={() => handleUpvote(voting.votingId)}
                          disabled={voting.finalized || votingInProgress === voting.votingId || !isConnected}
                        >
                          {votingInProgress === voting.votingId ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <ThumbsUp className="h-4 w-4" />
                          )}
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-red-600 hover:text-red-700 hover:bg-red-50"
                          onClick={() => handleDownvote(voting.votingId)}
                          disabled={voting.finalized || votingInProgress === voting.votingId || !isConnected}
                        >
                          {votingInProgress === voting.votingId ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <ThumbsDown className="h-4 w-4" />
                          )}
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
