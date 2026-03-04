import Link from "next/link";
import { Shield, Activity, Bell, Lock, Zap, Globe, Search, Filter, TrendingUp, AlertTriangle, Eye, Code } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Detectors() {
  const categories = [
    { name: "All Detectors", count: 3, active: true },
    { name: "DeFi Security", count: 2 },
    { name: "Privacy & AML", count: 1 },
  ];

  const detectors = [
    {
      id: 1,
      name: "Large Transfer Detector",
      category: "DeFi Security",
      description: "Monitor and alert on unusually large token transfers that could indicate exploits or rug pulls. Detects transfers exceeding configurable thresholds.",
      chains: ["Ethereum", "Polygon", "Arbitrum"],
      alerts: 1247,
      status: "Active",
      severity: "High",
    },
    {
      id: 2,
      name: "Mixer Interaction Detector",
      category: "Privacy & AML",
      description: "Detect interactions with known cryptocurrency mixers and privacy protocols. Helps identify potential money laundering activities.",
      chains: ["Ethereum", "Polygon"],
      alerts: 892,
      status: "Active",
      severity: "Critical",
    },
    {
      id: 3,
      name: "Trace Peel Chain Detector",
      category: "DeFi Security",
      description: "Identify peel chain patterns in token transfers - a common technique used in money laundering where funds are split into smaller amounts.",
      chains: ["Ethereum", "Polygon"],
      alerts: 456,
      status: "Active",
      severity: "High",
    },
  ];

  const comingSoonDetectors = [
    {
      name: "Price Manipulation Detector",
      category: "DeFi Security",
      description: "Detect flash loan attacks and price oracle manipulation in real-time.",
    },
    {
      name: "Reentrancy Guard",
      category: "Access Control",
      description: "Identify potential reentrancy vulnerabilities in smart contract interactions.",
    },
    {
      name: "Access Control Monitor",
      category: "Access Control",
      description: "Track unauthorized access attempts and privilege escalation patterns.",
    },
    {
      name: "NFT Ownership Tracker",
      category: "NFT Protection",
      description: "Monitor NFT transfers and detect suspicious ownership changes.",
    },
    {
      name: "Gas Price Anomaly Detector",
      category: "Network Security",
      description: "Alert on unusual gas price spikes that may indicate network attacks.",
    },
    {
      name: "Front-Running Detector",
      category: "DeFi Security",
      description: "Detect and prevent front-running attacks on DEX transactions.",
    },
  ];

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1">
        <section className="border-b bg-gradient-to-b from-primary/5 to-background py-12">
          <div className="container">
            <div className="mx-auto max-w-3xl text-center mb-8">
              <h1 className="mb-4 text-4xl font-bold tracking-tight sm:text-5xl">
                Security Detectors
              </h1>
              <p className="text-lg text-muted-foreground">
                Real-time threat detection for your smart contracts across multiple chains
              </p>
            </div>
            
            <div className="mx-auto max-w-2xl">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  placeholder="Search detectors..."
                  className="pl-10 h-12 text-base"
                />
              </div>
            </div>
          </div>
        </section>

        <section className="py-8">
          <div className="container">
            <div className="flex gap-8">
              <aside className="hidden lg:block w-64 shrink-0">
                <div className="sticky top-8 space-y-6">
                  <div>
                    <h3 className="font-semibold mb-3 flex items-center gap-2">
                      <Filter className="h-4 w-4" />
                      Categories
                    </h3>
                    <div className="space-y-1">
                      {categories.map((category) => (
                        <button
                          key={category.name}
                          className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-sm transition-colors ${
                            category.active
                              ? "bg-primary text-primary-foreground"
                              : "hover:bg-muted"
                          }`}
                        >
                          <span>{category.name}</span>
                          <span className="text-xs opacity-70">{category.count}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                  
                  <div>
                    <h3 className="font-semibold mb-3">Chains</h3>
                    <div className="space-y-2">
                      {["Ethereum", "Polygon", "Arbitrum", "Optimism", "BSC"].map((chain) => (
                        <label key={chain} className="flex items-center gap-2 text-sm cursor-pointer">
                          <input type="checkbox" className="rounded" defaultChecked={chain === "Ethereum"} />
                          <span>{chain}</span>
                        </label>
                      ))}
                    </div>
                  </div>
                  
                  <div>
                    <h3 className="font-semibold mb-3">Severity</h3>
                    <div className="space-y-2">
                      {["Critical", "High", "Medium", "Low"].map((severity) => (
                        <label key={severity} className="flex items-center gap-2 text-sm cursor-pointer">
                          <input type="checkbox" className="rounded" />
                          <span>{severity}</span>
                        </label>
                      ))}
                    </div>
                  </div>
                </div>
              </aside>
              
              <div className="flex-1">
                <div className="mb-6 flex items-center justify-between">
                  <p className="text-sm text-muted-foreground">
                    Showing {detectors.length} active detectors
                  </p>
                  <Button variant="outline" size="sm" className="lg:hidden">
                    <Filter className="h-4 w-4 mr-2" />
                    Filters
                  </Button>
                </div>
                
                <div className="grid gap-6 md:grid-cols-2 mb-12">
                  {detectors.map((detector) => (
                    <Card key={detector.id} className="hover:shadow-lg transition-shadow cursor-pointer">
                      <CardHeader>
                        <div className="flex items-start justify-between mb-2">
                          <div className="flex items-center gap-2">
                            <div className="p-2 rounded-lg bg-primary/10">
                              <Shield className="h-5 w-5 text-primary" />
                            </div>
                            <Badge variant={detector.severity === "Critical" ? "destructive" : "secondary"}>
                              {detector.severity}
                            </Badge>
                          </div>
                          <Badge variant="outline" className="text-xs bg-green-500/10 text-green-600 border-green-500/20">
                            {detector.status}
                          </Badge>
                        </div>
                        <CardTitle className="text-xl">{detector.name}</CardTitle>
                        <CardDescription className="text-sm">
                          {detector.description}
                        </CardDescription>
                      </CardHeader>
                      <CardContent>
                        <div className="space-y-3">
                          <div className="flex items-center gap-2 text-sm text-muted-foreground">
                            <Globe className="h-4 w-4" />
                            <span>{detector.chains.join(", ")}</span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-muted-foreground">
                            <Activity className="h-4 w-4" />
                            <span>{detector.alerts.toLocaleString()} alerts triggered</span>
                          </div>
                          <div className="flex gap-2 pt-2">
                            <Button className="flex-1" size="sm">
                              <Eye className="h-4 w-4 mr-2" />
                              View Details
                            </Button>
                            <Button variant="outline" size="sm">
                              <Code className="h-4 w-4" />
                            </Button>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>

                {/* Coming Soon Section */}
                <div className="mt-12">
                  <div className="mb-6 flex items-center gap-3">
                    <h2 className="text-2xl font-bold">Coming Soon</h2>
                    <Badge variant="secondary" className="text-xs">
                      In Development
                    </Badge>
                  </div>
                  <p className="text-muted-foreground mb-6">
                    We're actively developing more detectors to enhance your smart contract security. Stay tuned for these upcoming features!
                  </p>
                  
                  <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                    {comingSoonDetectors.map((detector, index) => (
                      <Card key={index} className="opacity-60 hover:opacity-80 transition-opacity">
                        <CardHeader>
                          <div className="flex items-start justify-between mb-2">
                            <div className="p-2 rounded-lg bg-muted">
                              <Shield className="h-5 w-5 text-muted-foreground" />
                            </div>
                            <Badge variant="outline" className="text-xs">
                              Coming Soon
                            </Badge>
                          </div>
                          <CardTitle className="text-lg">{detector.name}</CardTitle>
                          <CardDescription className="text-sm">
                            {detector.description}
                          </CardDescription>
                        </CardHeader>
                      </Card>
                    ))}
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
