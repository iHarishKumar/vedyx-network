"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Shield, Activity, Bell, Lock, Zap, Globe, Search, Filter, TrendingUp, AlertTriangle, Eye, Code, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { VotingDetailsDialog } from "@/components/voting-details-dialog";
import { fetchDetectorStats, getUniqueChains, getTotalTriggers, getDetectorIdHash, type DetectorWithVotings } from "@/lib/graphql";

interface DetectorDisplay {
  id: string;
  name: string;
  originalName: string;
  category: string;
  description: string;
  chains: string[];
  alerts: number;
  status: string;
  severity: string;
}

const DETECTOR_METADATA: Record<string, { category: string; description: string; severity: string }> = {
  "MIXER_INTERACTION_DETECTOR_V1": {
    category: "Privacy & AML",
    description: "Detect interactions with known cryptocurrency mixers and privacy protocols. Helps identify potential money laundering activities.",
    severity: "Critical",
  },
  "LARGE_TRANSFER_DETECTOR_V1": {
    category: "DeFi Security",
    description: "Monitor and alert on unusually large token transfers that could indicate exploits or rug pulls. Detects transfers exceeding configurable thresholds.",
    severity: "High",
  },
  "TRACE_PEEL_CHAIN_DETECTOR_V1": {
    category: "DeFi Security",
    description: "Identify peel chain patterns in token transfers - a common technique used in money laundering where funds are split into smaller amounts.",
    severity: "High",
  },
};

function getDetectorMetadata(detectorName: string) {
  return DETECTOR_METADATA[detectorName] || {
    category: "DeFi Security",
    description: "Security detector monitoring blockchain activities for suspicious patterns.",
    severity: "Medium",
  };
}

export default function Detectors() {
  const [detectors, setDetectors] = useState<DetectorDisplay[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDetector, setSelectedDetector] = useState<{ id: string; name: string; originalName: string } | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    async function loadDetectorData() {
      try {
        const stats = await fetchDetectorStats();
        
        const detectorDisplays: DetectorDisplay[] = stats.map((detector) => {
          const metadata = getDetectorMetadata(detector.detectorName);
          const chains = getUniqueChains(detector.votings);
          const totalTriggers = getTotalTriggers(detector);
          
          return {
            id: detector.id,
            name: detector.detectorName.replace(/_/g, " ").replace(/V\d+$/, "").trim(),
            originalName: detector.detectorName,
            category: metadata.category,
            description: metadata.description,
            chains: chains.length > 0 ? chains : ["Multi-chain"],
            alerts: totalTriggers,
            status: "Active",
            severity: metadata.severity,
          };
        });

        setDetectors(detectorDisplays);
      } catch (error) {
        console.error("Failed to load detector data:", error);
      } finally {
        setLoading(false);
      }
    }

    loadDetectorData();
  }, []);

  const categories = [
    { name: "All Detectors", count: detectors.length, active: true },
    { name: "DeFi Security", count: detectors.filter(d => d.category === "DeFi Security").length },
    { name: "Privacy & AML", count: detectors.filter(d => d.category === "Privacy & AML").length },
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
                    {loading ? "Loading detectors..." : `Showing ${detectors.length} active detectors`}
                  </p>
                  <Button variant="outline" size="sm" className="lg:hidden">
                    <Filter className="h-4 w-4 mr-2" />
                    Filters
                  </Button>
                </div>
                
                {loading ? (
                  <div className="flex items-center justify-center py-12">
                    <Loader2 className="h-8 w-8 animate-spin text-primary" />
                  </div>
                ) : detectors.length === 0 ? (
                  <div className="text-center py-12">
                    <Shield className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                    <h3 className="text-lg font-semibold mb-2">No Detectors Found</h3>
                    <p className="text-muted-foreground">
                      No detector statistics are available at the moment.
                    </p>
                  </div>
                ) : (
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
                            <Button 
                              className="flex-1" 
                              size="sm"
                              onClick={() => {
                                setSelectedDetector({
                                  id: getDetectorIdHash(detector.originalName),
                                  name: detector.name,
                                  originalName: detector.originalName
                                });
                                setDialogOpen(true);
                              }}
                            >
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
                )}

                {/* Coming Soon Section */}
                <div className="mt-12">
                  <div className="mb-6 flex items-center gap-3">
                    <h2 className="text-2xl font-bold">Coming Soon</h2>
                    <Badge variant="secondary" className="text-xs">
                      In Development
                    </Badge>
                  </div>
                  <p className="text-muted-foreground mb-6">
                    We&apos;re actively developing more detectors to enhance your smart contract security. Stay tuned for these upcoming features!
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

      {selectedDetector && (
        <VotingDetailsDialog
          open={dialogOpen}
          onOpenChange={setDialogOpen}
          detectorId={selectedDetector.id}
          detectorName={selectedDetector.name}
        />
      )}
    </div>
  );
}
