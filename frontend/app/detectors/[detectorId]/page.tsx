"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ThumbsUp, ThumbsDown, Loader2, ExternalLink, Clock, CheckCircle, XCircle, AlertCircle, ArrowLeft } from "lucide-react";
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
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { fetchDetectorWithVotings, getChainName, type VotingDetail } from "@/lib/graphql";
import { castVote } from "@/lib/contract";
import { formatDistanceToNow } from "date-fns";
import { useAccount, useChainId } from "wagmi";

export default function DetectorVotingsPage() {
  const params = useParams();
  const router = useRouter();
  const detectorId = params.detectorId as string;
  
  const [detectorName, setDetectorName] = useState<string>("");
  const [votings, setVotings] = useState<VotingDetail[]>([]);
  const [loading, setLoading] = useState(false);
  const [votingInProgress, setVotingInProgress] = useState<string | null>(null);
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  
  const UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

  useEffect(() => {
    if (detectorId) {
      loadVotings();
    }
  }, [detectorId]);

  async function loadVotings() {
    setLoading(true);
    try {
      const data = await fetchDetectorWithVotings(detectorId);
      if (data) {
        setDetectorName(data.detectorName);
        setVotings(data.votings);
      }
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
        alert(`Vote cast successfully! Transaction: ${result.txHash}\n\nView on explorer: https://sepolia.uniscan.xyz/tx/${result.txHash}`);
        await loadVotings();
      } else {
        alert(`Failed to cast vote: ${result.error}`);
      }
    } catch (error: any) {
      console.error("Error voting:", error);
      if (error.message?.includes("user rejected")) {
        alert("Transaction was rejected");
      } else {
        alert(`Failed to cast vote: ${error.message || "Please try again"}`);
      }
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
        alert(`Vote cast successfully! Transaction: ${result.txHash}\n\nView on explorer: https://sepolia.uniscan.xyz/tx/${result.txHash}`);
        await loadVotings();
      } else {
        alert(`Failed to cast vote: ${result.error}`);
      }
    } catch (error: any) {
      console.error("Error voting:", error);
      if (error.message?.includes("user rejected")) {
        alert("Transaction was rejected");
      } else {
        alert(`Failed to cast vote: ${error.message || "Please try again"}`);
      }
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
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1 bg-muted/30">
        <div className="container py-8">
          <div className="mb-6">
            <Button
              variant="ghost"
              onClick={() => router.push("/detectors")}
              className="mb-4"
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Detectors
            </Button>
            
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-3xl font-bold">Voting Details</h1>
              {chainId === UNICHAIN_SEPOLIA_CHAIN_ID ? (
                <Badge variant="outline" className="bg-green-500/10 text-green-600 border-green-500/20">
                  <CheckCircle className="h-3 w-3 mr-1" />
                  Unichain Sepolia
                </Badge>
              ) : (
                <Badge variant="outline" className="bg-yellow-500/10 text-yellow-600 border-yellow-500/20">
                  <AlertCircle className="h-3 w-3 mr-1" />
                  Switch to Unichain Sepolia
                </Badge>
              )}
            </div>
            <p className="text-muted-foreground">
              View and participate in votings for {detectorName}
            </p>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Votings for {detectorName}</CardTitle>
              <CardDescription>
                {loading ? "Loading votings..." : `${votings.length} voting${votings.length !== 1 ? 's' : ''} found`}
              </CardDescription>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-8 w-8 animate-spin text-primary" />
                </div>
              ) : votings.length === 0 ? (
                <div className="text-center py-12">
                  <AlertCircle className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                  <h3 className="text-lg font-semibold mb-2">No Votings Found</h3>
                  <p className="text-muted-foreground">
                    There are no votings for this detector yet.
                  </p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Voting ID</TableHead>
                        <TableHead>Suspicious Address</TableHead>
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
                              <code className="text-sm bg-muted px-2 py-1 rounded">
                                {formatAddress(voting.suspiciousAddress)}
                              </code>
                              <a
                                href={`https://etherscan.io/address/${voting.suspiciousAddress}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="text-primary hover:text-primary/80"
                              >
                                <ExternalLink className="h-3 w-3" />
                              </a>
                            </div>
                          </TableCell>
                          <TableCell>
                            <Badge variant="secondary">
                              {getChainName(voting.originChainId)}
                            </Badge>
                          </TableCell>
                          <TableCell>{getStatusBadge(voting)}</TableCell>
                          <TableCell className="font-semibold text-green-600">
                            {voting.votesFor}
                          </TableCell>
                          <TableCell className="font-semibold text-red-600">
                            {voting.votesAgainst}
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
            </CardContent>
          </Card>
        </div>
      </main>
      
      <Footer />
    </div>
  );
}
