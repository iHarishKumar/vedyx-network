import Link from "next/link";
import { Shield, Activity, Bell, Lock, Zap, Globe, TrendingUp, Code, CheckCircle, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1">
        <section className="relative overflow-hidden bg-gradient-to-b from-primary/10 via-background to-background py-20 md:py-32">
          <div className="container relative z-10">
            <div className="mx-auto max-w-4xl text-center">
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border bg-background/50 px-4 py-2 text-sm backdrop-blur">
                <Zap className="h-4 w-4 text-primary" />
                <span>Reactive Smart Contract Security</span>
              </div>
              <h1 className="mb-6 text-4xl font-bold tracking-tight sm:text-6xl md:text-7xl">
                Protect Your Smart Contracts with{" "}
                <span className="bg-gradient-to-r from-primary to-purple-600 bg-clip-text text-transparent">
                  Vedyx Network
                </span>
              </h1>
              <p className="mb-8 text-lg text-muted-foreground md:text-xl">
                Real-time security monitoring powered by reactive smart contracts. Detect threats, prevent exploits, and secure your DeFi protocols across multiple blockchains.
              </p>
              <div className="flex flex-col gap-4 sm:flex-row sm:justify-center">
                <Link href="/dashboard">
                  <Button size="lg" className="w-full sm:w-auto">
                    Launch Dashboard
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </Button>
                </Link>
                <Link href="/detectors">
                  <Button size="lg" variant="outline" className="w-full sm:w-auto">
                    Explore Detectors
                  </Button>
                </Link>
              </div>
              
              <div className="mt-16 grid grid-cols-3 gap-8 border-t pt-8">
                <div>
                  <div className="text-3xl font-bold text-primary">24/7</div>
                  <div className="text-sm text-muted-foreground">Real-time Monitoring</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-primary">5+</div>
                  <div className="text-sm text-muted-foreground">Chains Supported</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-primary">12+</div>
                  <div className="text-sm text-muted-foreground">Security Detectors</div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="py-20">
          <div className="container">
            <div className="mx-auto max-w-2xl text-center mb-16">
              <h2 className="mb-4 text-3xl font-bold sm:text-4xl">
                Comprehensive Security Features
              </h2>
              <p className="text-muted-foreground">
                Advanced threat detection powered by reactive smart contracts and real-time analysis
              </p>
            </div>
            
            <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Activity className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Real-time Detection</CardTitle>
                  <CardDescription>
                    Monitor transactions as they happen with instant threat detection and alerting across all supported chains
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Bell className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Smart Alerts</CardTitle>
                  <CardDescription>
                    Get notified immediately via webhook, Discord, Telegram, or email when threats are detected
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Lock className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Multiple Detectors</CardTitle>
                  <CardDescription>
                    Large transfers, price manipulation, reentrancy, access control, and more security patterns
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Globe className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Multi-chain Support</CardTitle>
                  <CardDescription>
                    Monitor contracts across Ethereum, Polygon, Arbitrum, Optimism, BSC, and more blockchains
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Shield className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Reactive Architecture</CardTitle>
                  <CardDescription>
                    Built on reactive smart contracts for trustless, decentralized, and transparent monitoring
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                    <Code className="h-6 w-6 text-primary" />
                  </div>
                  <CardTitle>Easy Integration</CardTitle>
                  <CardDescription>
                    Simple API and SDK for seamless integration with your existing infrastructure and workflows
                  </CardDescription>
                </CardHeader>
              </Card>
            </div>
          </div>
        </section>

        <section className="border-t bg-muted/50 py-20">
          <div className="container">
            <div className="mx-auto max-w-2xl text-center mb-16">
              <h2 className="mb-4 text-3xl font-bold sm:text-4xl">
                How It Works
              </h2>
              <p className="text-muted-foreground">
                Get started with Vedyx in three simple steps
              </p>
            </div>
            
            <div className="grid gap-8 md:grid-cols-3">
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary text-primary-foreground text-xl font-bold">
                    1
                  </div>
                  <CardTitle>Connect Wallet</CardTitle>
                  <CardDescription>
                    Connect your Web3 wallet to access the dashboard and configure your security monitoring preferences
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary text-primary-foreground text-xl font-bold">
                    2
                  </div>
                  <CardTitle>Add Contracts</CardTitle>
                  <CardDescription>
                    Specify the smart contracts you want to monitor and select the detection patterns that matter to you
                  </CardDescription>
                </CardHeader>
              </Card>
              
              <Card className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary text-primary-foreground text-xl font-bold">
                    3
                  </div>
                  <CardTitle>Monitor & Respond</CardTitle>
                  <CardDescription>
                    Receive real-time alerts and take immediate action when security threats are detected
                  </CardDescription>
                </CardHeader>
              </Card>
            </div>
          </div>
        </section>

        <section className="py-20">
          <div className="container">
            <Card className="border-primary/50 bg-gradient-to-r from-primary/10 to-purple-600/10 hover:shadow-lg transition-shadow">
              <CardContent className="p-12 text-center">
                <h2 className="mb-4 text-3xl font-bold sm:text-4xl">
                  Ready to Secure Your Contracts?
                </h2>
                <p className="mb-8 text-lg text-muted-foreground">
                  Start monitoring your smart contracts today with Vedyx Network
                </p>
                <div className="flex flex-col gap-4 sm:flex-row sm:justify-center">
                  <Link href="/dashboard">
                    <Button size="lg">
                      Launch Dashboard
                      <ArrowRight className="ml-2 h-4 w-4" />
                    </Button>
                  </Link>
                  <Link href="/detectors">
                    <Button size="lg" variant="outline">
                      View All Detectors
                    </Button>
                  </Link>
                </div>
              </CardContent>
            </Card>
          </div>
        </section>
      </main>
      
      <Footer />
    </div>
  );
}
