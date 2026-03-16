"use client";

import { useState } from "react";
import { Shield, Activity, AlertTriangle, CheckCircle, TrendingUp, Eye, LayoutDashboard, Bell, Settings, FileText, BarChart3, Plus, Search, Filter, Coins } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Navbar } from "@/components/navbar";
import { StakingSection } from "@/components/staking-section";
import Link from "next/link";

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState("overview");
  
  const sidebarItems = [
    { id: "overview", label: "Overview", icon: LayoutDashboard },
    { id: "staking", label: "Staking", icon: Coins },
    { id: "alerts", label: "Alerts", icon: Bell, badge: 3 },
    { id: "monitors", label: "Monitors", icon: Shield },
    { id: "analytics", label: "Analytics", icon: BarChart3 },
    { id: "docs", label: "Documentation", icon: FileText },
    { id: "settings", label: "Settings", icon: Settings },
  ];
  
  const [stats] = useState({
    contractsMonitored: 12,
    alertsToday: 3,
    threatsDetected: 47,
    uptime: "99.9%",
  });

  const [recentAlerts] = useState([
    {
      id: 1,
      type: "Large Transfer",
      severity: "high",
      contract: "0x1234...5678",
      chain: "Ethereum",
      timestamp: "2 minutes ago",
      amount: "1,000 ETH",
    },
    {
      id: 2,
      type: "Price Manipulation",
      severity: "critical",
      contract: "0xabcd...ef01",
      chain: "Polygon",
      timestamp: "15 minutes ago",
      amount: "N/A",
    },
    {
      id: 3,
      type: "Unusual Activity",
      severity: "medium",
      contract: "0x9876...5432",
      chain: "Arbitrum",
      timestamp: "1 hour ago",
      amount: "N/A",
    },
  ]);

  const [activeMonitors] = useState([
    {
      id: 1,
      name: "Large Transfer Detector",
      contract: "0x1234...5678",
      chain: "Ethereum",
      status: "active",
      alerts: 12,
    },
    {
      id: 2,
      name: "Price Manipulation Detector",
      contract: "0xabcd...ef01",
      chain: "Polygon",
      status: "active",
      alerts: 5,
    },
    {
      id: 3,
      name: "Reentrancy Detector",
      contract: "0x9876...5432",
      chain: "Arbitrum",
      status: "active",
      alerts: 0,
    },
  ]);

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case "critical":
        return "destructive";
      case "high":
        return "default";
      case "medium":
        return "secondary";
      default:
        return "outline";
    }
  };

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <div className="flex flex-1">
        <aside className="hidden lg:block w-64 border-r bg-card">
          <div className="sticky top-0 h-screen flex flex-col">
            <div className="p-6 border-b">
              <h2 className="font-semibold text-lg">Dashboard</h2>
            </div>
            <nav className="flex-1 p-4 space-y-1">
              {sidebarItems.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveTab(item.id)}
                    className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-sm transition-colors ${
                      activeTab === item.id
                        ? "bg-primary text-primary-foreground"
                        : "hover:bg-muted"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <Icon className="h-4 w-4" />
                      <span>{item.label}</span>
                    </div>
                    {item.badge && (
                      <Badge variant="secondary" className="ml-auto">
                        {item.badge}
                      </Badge>
                    )}
                  </button>
                );
              })}
            </nav>
            <div className="p-4 border-t">
              <Button className="w-full" size="sm">
                <Plus className="h-4 w-4 mr-2" />
                Add Contract
              </Button>
            </div>
          </div>
        </aside>
        
        <main className="flex-1 bg-muted/30">
          <div className="container py-8">
            <div className="mb-8 flex items-center justify-between">
              <div>
                <h1 className="text-3xl font-bold mb-2">
                  {activeTab === "staking" ? "Staking" : "Overview"}
                </h1>
                <p className="text-muted-foreground">
                  {activeTab === "staking" 
                    ? "Stake tokens to participate in voting and earn rewards"
                    : "Monitor your smart contracts and respond to security threats in real-time"}
                </p>
              </div>
              <div className="flex gap-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                  <Input placeholder="Search..." className="pl-9 w-64" />
                </div>
                <Button variant="outline" size="icon">
                  <Filter className="h-4 w-4" />
                </Button>
              </div>
            </div>

            {activeTab === "staking" ? (
              <StakingSection />
            ) : (
              <>

            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
              <Card className="hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium">Contracts Monitored</CardTitle>
                  <div className="p-2 rounded-lg bg-primary/10">
                    <Eye className="h-4 w-4 text-primary" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{stats.contractsMonitored}</div>
                  <p className="text-xs text-muted-foreground mt-1">Across 5 chains</p>
                </CardContent>
              </Card>

              <Card className="hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium">Alerts Today</CardTitle>
                  <div className="p-2 rounded-lg bg-orange-500/10">
                    <Activity className="h-4 w-4 text-orange-500" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{stats.alertsToday}</div>
                  <p className="text-xs text-green-600 mt-1">↓ 2 from yesterday</p>
                </CardContent>
              </Card>

              <Card className="hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium">Threats Detected</CardTitle>
                  <div className="p-2 rounded-lg bg-red-500/10">
                    <AlertTriangle className="h-4 w-4 text-red-500" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{stats.threatsDetected}</div>
                  <p className="text-xs text-muted-foreground mt-1">All time</p>
                </CardContent>
              </Card>

              <Card className="hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium">System Uptime</CardTitle>
                  <div className="p-2 rounded-lg bg-green-500/10">
                    <CheckCircle className="h-4 w-4 text-green-500" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{stats.uptime}</div>
                  <p className="text-xs text-muted-foreground mt-1">Last 30 days</p>
                </CardContent>
              </Card>
            </div>

            <div className="grid gap-6 lg:grid-cols-2">
              <Card className="hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle>Recent Alerts</CardTitle>
                      <CardDescription>Latest security events detected</CardDescription>
                    </div>
                    <Link href="/alerts">
                      <Button variant="ghost" size="sm">View All</Button>
                    </Link>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {recentAlerts.map((alert) => (
                      <div
                        key={alert.id}
                        className="flex items-start gap-4 p-4 rounded-lg border hover:bg-muted/50 transition-colors cursor-pointer"
                      >
                        <div className="p-2 rounded-lg bg-destructive/10 shrink-0">
                          <AlertTriangle className="h-4 w-4 text-destructive" />
                        </div>
                        <div className="flex-1 space-y-1">
                          <div className="flex items-center gap-2">
                            <Badge variant={getSeverityColor(alert.severity) as any} className="text-xs">
                              {alert.severity}
                            </Badge>
                            <span className="font-medium text-sm">{alert.type}</span>
                          </div>
                          <div className="text-xs text-muted-foreground">
                            {alert.contract} • {alert.chain}
                          </div>
                          {alert.amount !== "N/A" && (
                            <div className="text-xs font-medium">Amount: {alert.amount}</div>
                          )}
                          <div className="text-xs text-muted-foreground">{alert.timestamp}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>

              <Card className="hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle>Active Monitors</CardTitle>
                      <CardDescription>Currently running detectors</CardDescription>
                    </div>
                    <Link href="/monitors">
                      <Button variant="ghost" size="sm">View All</Button>
                    </Link>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {activeMonitors.map((monitor) => (
                      <div
                        key={monitor.id}
                        className="flex items-start gap-4 p-4 rounded-lg border hover:bg-muted/50 transition-colors cursor-pointer"
                      >
                        <div className="p-2 rounded-lg bg-primary/10 shrink-0">
                          <Shield className="h-4 w-4 text-primary" />
                        </div>
                        <div className="flex-1 space-y-1">
                          <div className="font-medium text-sm">{monitor.name}</div>
                          <div className="text-xs text-muted-foreground">
                            {monitor.contract} • {monitor.chain}
                          </div>
                          <div className="flex items-center gap-2 text-xs">
                            <Badge variant="outline" className="text-xs">
                              {monitor.status}
                            </Badge>
                            <span className="text-muted-foreground">
                              {monitor.alerts} alerts
                            </span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card className="mt-6 hover:shadow-md transition-shadow">
              <CardHeader>
                <CardTitle>Quick Actions</CardTitle>
                <CardDescription>Manage your security monitoring</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Button className="justify-start">
                    <Shield className="mr-2 h-4 w-4" />
                    Add Contract
                  </Button>
                  <Button variant="outline" className="justify-start">
                    <Activity className="mr-2 h-4 w-4" />
                    View All Alerts
                  </Button>
                  <Button variant="outline" className="justify-start">
                    <TrendingUp className="mr-2 h-4 w-4" />
                    Analytics
                  </Button>
                  <Button variant="outline" className="justify-start">
                    <Settings className="mr-2 h-4 w-4" />
                    Settings
                  </Button>
                </div>
              </CardContent>
            </Card>
            </>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}
