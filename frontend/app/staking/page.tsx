"use client";

import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { StakingSection } from "@/components/staking-section";
import { Coins, TrendingUp, Award, Shield } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export default function StakingPage() {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1">
        <section className="border-b bg-gradient-to-b from-primary/5 to-background py-12">
          <div className="container">
            <div className="mx-auto max-w-3xl text-center mb-8">
              <div className="mb-4 inline-flex items-center gap-2 rounded-full border bg-background px-4 py-2 text-sm">
                <Coins className="h-4 w-4 text-primary" />
                <span>Participate in Governance</span>
              </div>
              <h1 className="mb-4 text-4xl font-bold tracking-tight sm:text-5xl">
                Stake & Vote
              </h1>
              <p className="text-lg text-muted-foreground">
                Stake tokens to participate in voting on suspicious addresses and earn rewards based on your accuracy
              </p>
            </div>

            <div className="grid gap-6 md:grid-cols-3 max-w-4xl mx-auto">
              <Card>
                <CardHeader className="text-center">
                  <div className="mx-auto p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <TrendingUp className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle className="text-lg">Earn Rewards</CardTitle>
                  <CardDescription>
                    Stake tokens and earn rewards for accurate voting on suspicious addresses
                  </CardDescription>
                </CardHeader>
              </Card>

              <Card>
                <CardHeader className="text-center">
                  <div className="mx-auto p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Award className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle className="text-lg">Build Karma</CardTitle>
                  <CardDescription>
                    Increase your karma points with correct votes and unlock higher voting power
                  </CardDescription>
                </CardHeader>
              </Card>

              <Card>
                <CardHeader className="text-center">
                  <div className="mx-auto p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Shield className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle className="text-lg">Secure Network</CardTitle>
                  <CardDescription>
                    Help protect the network by identifying malicious addresses and activities
                  </CardDescription>
                </CardHeader>
              </Card>
            </div>
          </div>
        </section>

        <section className="py-12 bg-muted/30">
          <div className="container">
            <StakingSection />
          </div>
        </section>

        <section className="py-12 border-t">
          <div className="container">
            <div className="mx-auto max-w-3xl">
              <h2 className="text-2xl font-bold mb-6 text-center">How Staking Works</h2>
              
              <div className="space-y-6">
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">1. Stake Your Tokens</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">
                      Approve and stake your tokens to the voting contract. Your staked amount determines your voting power and eligibility to participate in governance.
                    </p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">2. Vote on Suspicious Addresses</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">
                      Review flagged addresses and cast your vote on whether they are suspicious or clean. Your stake is locked while you have active votes.
                    </p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">3. Earn Rewards & Build Karma</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">
                      Correct votes earn you karma points and rewards. Incorrect votes may result in karma penalties. High karma increases your voting power and influence.
                    </p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">4. Unstake When Ready</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">
                      Withdraw your unlocked tokens at any time. Tokens locked in active votes will be available once those votes are finalized.
                    </p>
                  </CardContent>
                </Card>
              </div>
            </div>
          </div>
        </section>
      </main>
      
      <Footer />
    </div>
  );
}
