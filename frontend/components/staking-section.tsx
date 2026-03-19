"use client";

import { useEffect, useState } from "react";
import { Loader2, TrendingUp, TrendingDown, Wallet, Lock, Award } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useAccount } from "wagmi";
import { 
  getStakerInfo, 
  getTokenBalance, 
  getTokenAllowance,
  approveToken,
  stakeTokens,
  unstakeTokens 
} from "@/lib/contract";
import { formatUnits } from "ethers";

export function StakingSection() {
  const { address, isConnected } = useAccount();
  
  const [stakeAmount, setStakeAmount] = useState("");
  const [unstakeAmount, setUnstakeAmount] = useState("");
  const [tokenBalance, setTokenBalance] = useState("0");
  const [allowance, setAllowance] = useState("0");
  const [stakerInfo, setStakerInfo] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [approving, setApproving] = useState(false);
  const [staking, setStaking] = useState(false);
  const [unstaking, setUnstaking] = useState(false);

  useEffect(() => {
    if (isConnected && address) {
      loadData();
    }
  }, [isConnected, address]);

  async function loadData() {
    if (!address) return;
    
    setLoading(true);
    try {
      const [balance, allow, info] = await Promise.all([
        getTokenBalance(address),
        getTokenAllowance(address),
        getStakerInfo(address)
      ]);
      
      setTokenBalance(balance);
      setAllowance(allow);
      setStakerInfo(info);
    } catch (error) {
      console.error("Error loading staking data:", error);
    } finally {
      setLoading(false);
    }
  }

  async function refreshDataAfterTx() {
    await new Promise(resolve => setTimeout(resolve, 2000));
    await loadData();
  }

  async function handleApprove() {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      alert("Please enter a valid amount");
      return;
    }

    setApproving(true);
    try {
      const result = await approveToken(stakeAmount);
      if (result.success) {
        alert(`Approval successful! Transaction: ${result.txHash}`);
        await refreshDataAfterTx();
      } else {
        alert(`Approval failed: ${result.error}`);
      }
    } catch (error: any) {
      alert(`Approval failed: ${error.message || "Please try again"}`);
    } finally {
      setApproving(false);
    }
  }

  async function handleStake() {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      alert("Please enter a valid amount");
      return;
    }

    if (parseFloat(allowance) < parseFloat(stakeAmount)) {
      alert("Please approve tokens first");
      return;
    }

    setStaking(true);
    try {
      const result = await stakeTokens(stakeAmount);
      if (result.success) {
        alert(`Staking successful! Transaction: ${result.txHash}\n\nView on explorer: https://sepolia.uniscan.xyz/tx/${result.txHash}`);
        setStakeAmount("");
        await refreshDataAfterTx();
      } else {
        alert(`Staking failed: ${result.error}`);
      }
    } catch (error: any) {
      alert(`Staking failed: ${error.message || "Please try again"}`);
    } finally {
      setStaking(false);
    }
  }

  async function handleUnstake() {
    if (!unstakeAmount || parseFloat(unstakeAmount) <= 0) {
      alert("Please enter a valid amount");
      return;
    }

    setUnstaking(true);
    try {
      const result = await unstakeTokens(unstakeAmount);
      if (result.success) {
        alert(`Unstaking successful! Transaction: ${result.txHash}\n\nView on explorer: https://sepolia.uniscan.xyz/tx/${result.txHash}`);
        setUnstakeAmount("");
        await refreshDataAfterTx();
      } else {
        alert(`Unstaking failed: ${result.error}`);
      }
    } catch (error: any) {
      alert(`Unstaking failed: ${error.message || "Please try again"}`);
    } finally {
      setUnstaking(false);
    }
  }

  const availableToStake = stakerInfo 
    ? (parseFloat(formatUnits(stakerInfo.stakedAmount, 18)) - parseFloat(formatUnits(stakerInfo.lockedAmount, 18))).toFixed(2)
    : "0";

  if (!isConnected) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Staking</CardTitle>
          <CardDescription>Connect your wallet to stake tokens and participate in voting</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <Wallet className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
            <p className="text-muted-foreground">Please connect your wallet to view staking options</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Staked Balance</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <Lock className="h-5 w-5 text-primary" />
              <span className="text-2xl font-bold">
                {loading ? "..." : stakerInfo ? parseFloat(formatUnits(stakerInfo.stakedAmount, 18)).toFixed(2) : "0"}
              </span>
              <span className="text-sm text-muted-foreground">tokens</span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Wallet Balance</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <Wallet className="h-5 w-5 text-primary" />
              <span className="text-2xl font-bold">
                {loading ? "..." : parseFloat(tokenBalance).toFixed(2)}
              </span>
              <span className="text-sm text-muted-foreground">tokens</span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Karma Points</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <Award className="h-5 w-5 text-primary" />
              <span className="text-2xl font-bold">
                {loading ? "..." : stakerInfo ? stakerInfo.karmaPoints : "0"}
              </span>
              <Badge variant={stakerInfo && parseInt(stakerInfo.karmaPoints) >= 0 ? "default" : "destructive"}>
                {stakerInfo && parseInt(stakerInfo.karmaPoints) >= 0 ? "Positive" : "Negative"}
              </Badge>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Staking Actions */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Stake Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="h-5 w-5" />
              Stake Tokens
            </CardTitle>
            <CardDescription>
              Stake tokens to participate in voting and earn rewards
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="stake-amount">Amount to Stake</Label>
              <Input
                id="stake-amount"
                type="number"
                placeholder="0.0"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                disabled={loading || approving || staking}
              />
              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <span>Available: {parseFloat(tokenBalance).toFixed(2)} tokens</span>
                <Button
                  variant="link"
                  size="sm"
                  className="h-auto p-0"
                  onClick={() => setStakeAmount(tokenBalance)}
                >
                  Max
                </Button>
              </div>
            </div>

            {parseFloat(allowance) < parseFloat(stakeAmount || "0") && (
              <Button
                className="w-full"
                onClick={handleApprove}
                disabled={approving || !stakeAmount}
              >
                {approving ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Approving...
                  </>
                ) : (
                  "Approve Tokens"
                )}
              </Button>
            )}

            <Button
              className="w-full"
              onClick={handleStake}
              disabled={staking || !stakeAmount || parseFloat(allowance) < parseFloat(stakeAmount || "0")}
            >
              {staking ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Staking...
                </>
              ) : (
                "Stake Tokens"
              )}
            </Button>
          </CardContent>
        </Card>

        {/* Unstake Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingDown className="h-5 w-5" />
              Unstake Tokens
            </CardTitle>
            <CardDescription>
              Withdraw your staked tokens (only unlocked amount)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="unstake-amount">Amount to Unstake</Label>
              <Input
                id="unstake-amount"
                type="number"
                placeholder="0.0"
                value={unstakeAmount}
                onChange={(e) => setUnstakeAmount(e.target.value)}
                disabled={loading || unstaking}
              />
              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <span>Available: {availableToStake} tokens</span>
                <Button
                  variant="link"
                  size="sm"
                  className="h-auto p-0"
                  onClick={() => setUnstakeAmount(availableToStake)}
                >
                  Max
                </Button>
              </div>
              {stakerInfo && parseFloat(formatUnits(stakerInfo.lockedAmount, 18)) > 0 && (
                <p className="text-xs text-yellow-600">
                  ⚠️ {formatUnits(stakerInfo.lockedAmount, 18)} tokens are locked in active votes
                </p>
              )}
            </div>

            <Button
              className="w-full"
              variant="outline"
              onClick={handleUnstake}
              disabled={unstaking || !unstakeAmount}
            >
              {unstaking ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Unstaking...
                </>
              ) : (
                "Unstake Tokens"
              )}
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Voting Stats */}
      {stakerInfo && (
        <Card>
          <CardHeader>
            <CardTitle>Voting Statistics</CardTitle>
            <CardDescription>Your voting performance and history</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-4">
              <div>
                <p className="text-sm text-muted-foreground">Total Votes</p>
                <p className="text-2xl font-bold">{stakerInfo.totalVotes}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Correct Votes</p>
                <p className="text-2xl font-bold text-green-600">{stakerInfo.correctVotes}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Accuracy</p>
                <p className="text-2xl font-bold">
                  {parseInt(stakerInfo.totalVotes) > 0
                    ? ((parseInt(stakerInfo.correctVotes) / parseInt(stakerInfo.totalVotes)) * 100).toFixed(1)
                    : "0"}%
                </p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Locked Amount</p>
                <p className="text-2xl font-bold">{formatUnits(stakerInfo.lockedAmount, 18)}</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
