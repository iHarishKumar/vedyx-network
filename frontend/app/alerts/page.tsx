"use client";

import { useState } from "react";
import { AlertTriangle, CheckCircle, Info, XCircle, Search, Filter, Download, Eye, Archive } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Alerts() {
  const [alerts] = useState([
    {
      id: 1,
      type: "Large Transfer",
      severity: "Critical",
      contract: "0x1234...5678",
      contractName: "USDC Token",
      chain: "Ethereum",
      amount: "250,000 USDC",
      from: "0xabcd...1234",
      to: "0xef01...5678",
      txHash: "0x9876...4321",
      timestamp: "2024-03-02 14:23:15",
      status: "Unresolved",
      description: "Unusually large transfer detected exceeding threshold",
    },
    {
      id: 2,
      type: "Price Manipulation",
      severity: "Critical",
      contract: "0xabcd...efgh",
      contractName: "Uniswap V3 Pool",
      chain: "Ethereum",
      amount: "N/A",
      from: "0x1111...2222",
      to: "N/A",
      txHash: "0x3333...4444",
      timestamp: "2024-03-02 12:45:30",
      status: "Investigating",
      description: "Flash loan attack detected with 15% price deviation",
    },
    {
      id: 3,
      type: "Reentrancy Attempt",
      severity: "High",
      contract: "0x9876...5432",
      contractName: "Lending Protocol",
      chain: "Polygon",
      amount: "N/A",
      from: "0x5555...6666",
      to: "N/A",
      txHash: "0x7777...8888",
      timestamp: "2024-03-02 10:15:22",
      status: "Resolved",
      description: "Potential reentrancy pattern detected and blocked",
    },
    {
      id: 4,
      type: "Access Control Violation",
      severity: "Medium",
      contract: "0xdef0...1234",
      contractName: "Governance Contract",
      chain: "Arbitrum",
      amount: "N/A",
      from: "0x9999...aaaa",
      to: "N/A",
      txHash: "0xbbbb...cccc",
      timestamp: "2024-03-01 18:30:45",
      status: "Resolved",
      description: "Unauthorized function call attempt detected",
    },
    {
      id: 5,
      type: "Large Transfer",
      severity: "High",
      contract: "0x1234...5678",
      contractName: "USDC Token",
      chain: "Ethereum",
      amount: "150,000 USDC",
      from: "0xdddd...eeee",
      to: "0xffff...0000",
      txHash: "0x1111...2222",
      timestamp: "2024-03-01 16:20:10",
      status: "Resolved",
      description: "Large transfer detected and verified as legitimate",
    },
    {
      id: 6,
      type: "NFT Suspicious Transfer",
      severity: "Medium",
      contract: "0x5555...6666",
      contractName: "Bored Ape YC",
      chain: "Ethereum",
      amount: "Token #1234",
      from: "0x3333...4444",
      to: "0x5555...6666",
      txHash: "0x7777...8888",
      timestamp: "2024-03-01 14:10:05",
      status: "Unresolved",
      description: "Rapid NFT transfer pattern detected",
    },
    {
      id: 7,
      type: "Gas Price Anomaly",
      severity: "Low",
      contract: "N/A",
      contractName: "Network Monitor",
      chain: "Ethereum",
      amount: "N/A",
      from: "N/A",
      to: "N/A",
      txHash: "N/A",
      timestamp: "2024-03-01 12:05:30",
      status: "Resolved",
      description: "Unusual gas price spike detected (500 Gwei)",
    },
    {
      id: 8,
      type: "Large Transfer",
      severity: "High",
      contract: "0x1234...5678",
      contractName: "USDC Token",
      chain: "Ethereum",
      amount: "180,000 USDC",
      from: "0x9999...aaaa",
      to: "0xbbbb...cccc",
      txHash: "0xdddd...eeee",
      timestamp: "2024-03-01 09:45:20",
      status: "Resolved",
      description: "Large transfer detected exceeding threshold",
    },
  ]);

  const stats = {
    total: alerts.length,
    critical: alerts.filter(a => a.severity === "Critical").length,
    unresolved: alerts.filter(a => a.status === "Unresolved").length,
    today: alerts.filter(a => a.timestamp.startsWith("2024-03-02")).length,
  };

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case "Critical":
        return <XCircle className="h-4 w-4 text-red-500" />;
      case "High":
        return <AlertTriangle className="h-4 w-4 text-orange-500" />;
      case "Medium":
        return <Info className="h-4 w-4 text-yellow-500" />;
      default:
        return <CheckCircle className="h-4 w-4 text-blue-500" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case "Critical":
        return "destructive";
      case "High":
        return "default";
      case "Medium":
        return "secondary";
      default:
        return "outline";
    }
  };

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1 bg-muted/30">
        <div className="container py-8">
          <div className="mb-8 flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold mb-2">Security Alerts</h1>
              <p className="text-muted-foreground">
                View and manage security alerts from your monitored contracts
              </p>
            </div>
            <Button variant="outline">
              <Download className="h-4 w-4 mr-2" />
              Export
            </Button>
          </div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Total Alerts</CardTitle>
                <div className="p-2 rounded-lg bg-primary/10">
                  <AlertTriangle className="h-4 w-4 text-primary" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.total}</div>
                <p className="text-xs text-muted-foreground mt-1">All time</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Critical</CardTitle>
                <div className="p-2 rounded-lg bg-red-500/10">
                  <XCircle className="h-4 w-4 text-red-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.critical}</div>
                <p className="text-xs text-muted-foreground mt-1">Require attention</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Unresolved</CardTitle>
                <div className="p-2 rounded-lg bg-orange-500/10">
                  <Info className="h-4 w-4 text-orange-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.unresolved}</div>
                <p className="text-xs text-muted-foreground mt-1">Pending review</p>
              </CardContent>
            </Card>

            <Card className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">Today</CardTitle>
                <div className="p-2 rounded-lg bg-green-500/10">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{stats.today}</div>
                <p className="text-xs text-muted-foreground mt-1">Last 24 hours</p>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Alert History</CardTitle>
                  <CardDescription>Recent security events and threat detections</CardDescription>
                </div>
                <div className="flex gap-2">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                    <Input placeholder="Search alerts..." className="pl-9 w-64" />
                  </div>
                  <Button variant="outline" size="icon">
                    <Filter className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {alerts.map((alert) => (
                  <div
                    key={alert.id}
                    className="flex items-start gap-4 p-4 rounded-lg border hover:bg-muted/50 transition-colors"
                  >
                    <div className="p-2 rounded-lg bg-destructive/10 shrink-0">
                      {getSeverityIcon(alert.severity)}
                    </div>
                    <div className="flex-1 space-y-2">
                      <div className="flex items-start justify-between">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <Badge variant={getSeverityColor(alert.severity) as any}>
                              {alert.severity}
                            </Badge>
                            <h3 className="font-semibold">{alert.type}</h3>
                          </div>
                          <p className="text-sm text-muted-foreground">
                            {alert.contractName} • {alert.contract} • {alert.chain}
                          </p>
                        </div>
                        <Badge variant={alert.status === "Unresolved" ? "destructive" : "outline"}>
                          {alert.status}
                        </Badge>
                      </div>
                      
                      <p className="text-sm">{alert.description}</p>

                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs">
                        {alert.amount !== "N/A" && (
                          <div>
                            <div className="text-muted-foreground">Amount</div>
                            <div className="font-medium mt-1">{alert.amount}</div>
                          </div>
                        )}
                        {alert.from !== "N/A" && (
                          <div>
                            <div className="text-muted-foreground">From</div>
                            <div className="font-mono mt-1">{alert.from}</div>
                          </div>
                        )}
                        {alert.to !== "N/A" && (
                          <div>
                            <div className="text-muted-foreground">To</div>
                            <div className="font-mono mt-1">{alert.to}</div>
                          </div>
                        )}
                        {alert.txHash !== "N/A" && (
                          <div>
                            <div className="text-muted-foreground">Tx Hash</div>
                            <div className="font-mono mt-1">{alert.txHash}</div>
                          </div>
                        )}
                      </div>

                      <div className="flex items-center justify-between pt-2 border-t">
                        <div className="text-xs text-muted-foreground">
                          {alert.timestamp}
                        </div>
                        <div className="flex gap-2">
                          <Button variant="outline" size="sm">
                            <Eye className="h-3 w-3 mr-1" />
                            Details
                          </Button>
                          {alert.status === "Unresolved" && (
                            <Button variant="outline" size="sm">
                              <CheckCircle className="h-3 w-3 mr-1" />
                              Resolve
                            </Button>
                          )}
                          <Button variant="outline" size="sm">
                            <Archive className="h-3 w-3 mr-1" />
                            Archive
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
