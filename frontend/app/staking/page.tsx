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
            <div className="grid gap-8 lg:grid-cols-3">
              {/* Main Staking Section - Takes 2 columns */}
              <div className="lg:col-span-2">
                <StakingSection />
              </div>

              {/* How It Works Sidebar - Takes 1 column */}
              <div className="space-y-6">
                <div>
                  <h2 className="text-2xl font-bold mb-6">How Staking Works</h2>
                  
                  <div className="space-y-4">
                    <Card>
                      <CardHeader className="pb-3">
                        <CardTitle className="text-base">1. Stake Your Tokens</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm text-muted-foreground">
                          Approve and stake tokens. Your staked amount determines voting power.
                        </p>
                      </CardContent>
                    </Card>

                    <Card>
                      <CardHeader className="pb-3">
                        <CardTitle className="text-base">2. Vote on Addresses</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm text-muted-foreground">
                          Review flagged addresses and vote. Your stake locks during active votes.
                        </p>
                      </CardContent>
                    </Card>

                    <Card>
                      <CardHeader className="pb-3">
                        <CardTitle className="text-base">3. Earn Rewards</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm text-muted-foreground">
                          Correct votes earn karma and rewards. Build reputation over time.
                        </p>
                      </CardContent>
                    </Card>

                    <Card>
                      <CardHeader className="pb-3">
                        <CardTitle className="text-base">4. Unstake Anytime</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p className="text-sm text-muted-foreground">
                          Withdraw unlocked tokens. Locked tokens release when votes finalize.
                        </p>
                      </CardContent>
                    </Card>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
      
      <Footer />
    </div>
  );
}
