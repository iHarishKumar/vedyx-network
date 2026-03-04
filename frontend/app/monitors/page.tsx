"use client";

import { useState } from "react";
import { Shield, Plus, Settings, Trash2, Play, Pause, Globe, Activity, AlertTriangle, CheckCircle, Search, Filter } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Monitors() {
  const [monitors] = useState([
    {
      id: 1,
      name: "Large Transfer Monitor",
      contract: "0x1234...5678",
      contractName: "USDC Token",
      chain: "Ethereum",
      detector: "Large Transfer Detector",
      status: "Active",
      threshold: "100,000 USDC",
      alerts: 45,
      lastAlert: "2 hours ago",
      createdAt: "2024-01-15",
    },
    {
      id: 2,
      name: "Price Oracle Monitor",
      contract: "0xabcd...efgh",
      contractName: "Uniswap V3 Pool",
      chain: "Ethereum",
      detector: "Price Manipulation Detector",
      status: "Active",
      threshold: "5% deviation",
      alerts: 12,
      lastAlert: "1 day ago",
      createdAt: "2024-01-20",
    },
    {
      id: 3,
      name: "Reentrancy Guard",
      contract: "0x9876...5432",
      contractName: "Lending Protocol",
      chain: "Polygon",
      detector: "Reentrancy Detector",
      status: "Active",
      threshold: "Any occurrence",
      alerts: 3,
      lastAlert: "5 days ago",
      createdAt: "2024-02-01",
    },
    {
      id: 4,
      name: "Access Control Monitor",
      contract: "0xdef0...1234",
      contractName: "Governance Contract",
      chain: "Arbitrum",
      detector: "Access Control Monitor",
      status: "Paused",
      threshold: "Unauthorized calls",
      alerts: 8,
      lastAlert: "3 days ago",
      createdAt: "2024-01-25",
    },
    {
      id: 5,
      name: "NFT Transfer Monitor",
      contract: "0x5555...6666",
      contractName: "Bored Ape YC",
      chain: "Ethereum",
      detector: "NFT Ownership Tracker",
      status: "Active",
      threshold: "Suspicious patterns",
      alerts: 23,
      lastAlert: "6 hours ago",
      createdAt: "2024-02-10",
    },
  ]);

  const stats = {
    total: monitors.length,
    active: monitors.filter(m => m.status === "Active").length,
    paused: monitors.filter(m => m.status === "Paused").length,
    totalAlerts: monitors.reduce((sum, m) => sum + m.alerts, 0),
  };

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1 bg-muted/30">
        <div className="container py-8">
          <div className="mb-8 flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold mb-2">Contract Monitors</h1>
              <p className="text-muted-foreground">
                Manage and configure security monitors for your smart contracts
              </p>
            </div>
            <Button size="lg">
              <Plus className="h-4 w-4 mr-2" />
              Add Monitor
            </Button>
          </div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Total Monitors</CardTitle>
                <div className="p-2 rounded-lg bg-primary/10">
                  <Shield className="h-4 w-4 text-primary" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.total}</div>
                <p className="text-xs text-muted-foreground mt-1">Across all chains</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Active</CardTitle>
                <div className="p-2 rounded-lg bg-green-500/10">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.active}</div>
                <p className="text-xs text-muted-foreground mt-1">Currently running</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Paused</CardTitle>
                <div className="p-2 rounded-lg bg-orange-500/10">
                  <Pause className="h-4 w-4 text-orange-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.paused}</div>
                <p className="text-xs text-muted-foreground mt-1">Temporarily disabled</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Total Alerts</CardTitle>
                <div className="p-2 rounded-lg bg-red-500/10">
                  <AlertTriangle className="h-4 w-4 text-red-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.totalAlerts}</div>
                <p className="text-xs text-muted-foreground mt-1">All time</p>
              </CardContent>
            </Card>
          </div>

          <Card className="mb-6">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Active Monitors</CardTitle>
                  <CardDescription>Monitor and manage your contract security configurations</CardDescription>
                </div>
                <div className="flex gap-2">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                    <Input placeholder="Search monitors..." className="pl-9 w-64" />
                  </div>
                  <Button variant="outline" size="icon">
                    <Filter className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {monitors.map((monitor) => (
                  <div
                    key={monitor.id}
                    className="flex items-start gap-4 p-4 rounded-lg border hover:bg-muted/50 transition-colors"
                  >
                    <div className="p-2 rounded-lg bg-primary/10 shrink-0">
                      <Shield className="h-5 w-5 text-primary" />
                    </div>
                    <div className="flex-1 space-y-2">
                      <div className="flex items-start justify-between">
                        <div>
                          <h3 className="font-semibold">{monitor.name}</h3>
                          <p className="text-sm text-muted-foreground">
                            {monitor.contractName} • {monitor.contract}
                          </p>
                        </div>
                        <Badge variant={monitor.status === "Active" ? "default" : "secondary"}>
                          {monitor.status}
                        </Badge>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground text-xs">Chain</div>
                          <div className="flex items-center gap-1 mt-1">
                            <Globe className="h-3 w-3" />
                            <span>{monitor.chain}</span>
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground text-xs">Detector</div>
                          <div className="mt-1">{monitor.detector}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground text-xs">Threshold</div>
                          <div className="mt-1">{monitor.threshold}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground text-xs">Alerts</div>
                          <div className="flex items-center gap-1 mt-1">
                            <Activity className="h-3 w-3" />
                            <span>{monitor.alerts} total</span>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between pt-2 border-t">
                        <div className="text-xs text-muted-foreground">
                          Last alert: {monitor.lastAlert} • Created: {monitor.createdAt}
                        </div>
                        <div className="flex gap-2">
                          {monitor.status === "Active" ? (
                            <Button variant="outline" size="sm">
                              <Pause className="h-3 w-3 mr-1" />
                              Pause
                            </Button>
                          ) : (
                            <Button variant="outline" size="sm">
                              <Play className="h-3 w-3 mr-1" />
                              Resume
                            </Button>
                          )}
                          <Button variant="outline" size="sm">
                            <Settings className="h-3 w-3 mr-1" />
                            Configure
                          </Button>
                          <Button variant="outline" size="sm">
                            <Trash2 className="h-3 w-3 mr-1" />
                            Delete
                          </Button>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
      
      <Footer />
    </div>
  );
}
