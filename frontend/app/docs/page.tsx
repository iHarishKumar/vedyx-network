"use client";

import { useState } from "react";
import { Book, Code, Zap, Shield, Globe, Terminal, FileText, ExternalLink, Copy, Check } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Documentation() {
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  const copyToClipboard = (code: string, id: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(id);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const quickStartCode = `npm install @vedyx/sdk

import { VedyxClient } from '@vedyx/sdk';

const client = new VedyxClient({
  apiKey: process.env.VEDYX_API_KEY,
  network: 'ethereum',
});

// Add a monitor
await client.monitors.create({
  contract: '0x1234...5678',
  detector: 'large-transfer',
  threshold: '100000',
});`;

  const webhookCode = `// Configure webhook endpoint
await client.webhooks.create({
  url: 'https://your-app.com/webhook',
  events: ['alert.created', 'alert.resolved'],
  secret: 'your-webhook-secret',
});

// Webhook payload example
{
  "event": "alert.created",
  "data": {
    "id": "alert_123",
    "type": "large_transfer",
    "severity": "critical",
    "contract": "0x1234...5678",
    "amount": "250000",
    "timestamp": "2024-03-02T14:23:15Z"
  }
}`;

  const apiExamples = [
    {
      id: "get-alerts",
      title: "Get Alerts",
      method: "GET",
      endpoint: "/api/v1/alerts",
      code: `curl -X GET https://api.vedyx.io/v1/alerts \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json"`,
    },
    {
      id: "create-monitor",
      title: "Create Monitor",
      method: "POST",
      endpoint: "/api/v1/monitors",
      code: `curl -X POST https://api.vedyx.io/v1/monitors \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "contract": "0x1234...5678",
    "detector": "large-transfer",
    "threshold": "100000",
    "chain": "ethereum"
  }'`,
    },
    {
      id: "update-monitor",
      title: "Update Monitor",
      method: "PATCH",
      endpoint: "/api/v1/monitors/:id",
      code: `curl -X PATCH https://api.vedyx.io/v1/monitors/mon_123 \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "threshold": "200000",
    "status": "active"
  }'`,
    },
  ];

  const guides = [
    {
      title: "Getting Started",
      description: "Learn how to set up Vedyx and create your first monitor",
      icon: Zap,
      link: "#getting-started",
    },
    {
      title: "API Reference",
      description: "Complete API documentation with examples and responses",
      icon: Code,
      link: "#api-reference",
    },
    {
      title: "Detector Types",
      description: "Understand different security detectors and their use cases",
      icon: Shield,
      link: "#detectors",
    },
    {
      title: "Webhooks",
      description: "Set up real-time notifications for security events",
      icon: Terminal,
      link: "#webhooks",
    },
    {
      title: "Multi-chain Support",
      description: "Deploy monitors across Ethereum, Polygon, Arbitrum, and more",
      icon: Globe,
      link: "#chains",
    },
    {
      title: "Best Practices",
      description: "Security recommendations and optimization tips",
      icon: Book,
      link: "#best-practices",
    },
  ];

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1 bg-muted/30">
        <div className="container py-8">
          <div className="mb-8">
            <h1 className="text-3xl font-bold mb-2">Documentation</h1>
            <p className="text-muted-foreground">
              Everything you need to integrate Vedyx into your application
            </p>
          </div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-8">
            {guides.map((guide) => {
              const Icon = guide.icon;
              return (
                <Card key={guide.title} className="hover:shadow-lg transition-shadow cursor-pointer">
                  <CardHeader>
                    <div className="p-3 rounded-lg bg-primary/10 w-fit mb-3">
                      <Icon className="h-6 w-6 text-primary" />
                    </div>
                    <CardTitle className="flex items-center justify-between">
                      {guide.title}
                      <ExternalLink className="h-4 w-4 text-muted-foreground" />
                    </CardTitle>
                    <CardDescription>{guide.description}</CardDescription>
                  </CardHeader>
                </Card>
              );
            })}
          </div>

          <Card className="mb-6 hover:shadow-md transition-shadow">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Quick Start</CardTitle>
                  <CardDescription>Get up and running with Vedyx in minutes</CardDescription>
                </div>
                <Badge>JavaScript</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="relative">
                <pre className="bg-muted p-4 rounded-lg overflow-x-auto">
                  <code className="text-sm">{quickStartCode}</code>
                </pre>
                <Button
                  variant="outline"
                  size="sm"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(quickStartCode, "quickstart")}
                >
                  {copiedCode === "quickstart" ? (
                    <Check className="h-4 w-4" />
                  ) : (
                    <Copy className="h-4 w-4" />
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card className="mb-6 hover:shadow-md transition-shadow">
            <CardHeader>
              <CardTitle>API Examples</CardTitle>
              <CardDescription>Common API requests and responses</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {apiExamples.map((example) => (
                <div key={example.id} className="space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Badge variant={example.method === "GET" ? "secondary" : "default"}>
                        {example.method}
                      </Badge>
                      <span className="font-mono text-sm">{example.endpoint}</span>
                    </div>
                    <span className="text-sm font-medium">{example.title}</span>
                  </div>
                  <div className="relative">
                    <pre className="bg-muted p-4 rounded-lg overflow-x-auto">
                      <code className="text-sm">{example.code}</code>
                    </pre>
                    <Button
                      variant="outline"
                      size="sm"
                      className="absolute top-2 right-2"
                      onClick={() => copyToClipboard(example.code, example.id)}
                    >
                      {copiedCode === example.id ? (
                        <Check className="h-4 w-4" />
                      ) : (
                        <Copy className="h-4 w-4" />
                      )}
                    </Button>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>

          <Card className="hover:shadow-md transition-shadow">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Webhook Integration</CardTitle>
                  <CardDescription>Receive real-time notifications for security events</CardDescription>
                </div>
                <Badge>Advanced</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="relative">
                <pre className="bg-muted p-4 rounded-lg overflow-x-auto">
                  <code className="text-sm">{webhookCode}</code>
                </pre>
                <Button
                  variant="outline"
                  size="sm"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(webhookCode, "webhook")}
                >
                  {copiedCode === "webhook" ? (
                    <Check className="h-4 w-4" />
                  ) : (
                    <Copy className="h-4 w-4" />
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          <div className="mt-8 p-6 border rounded-lg bg-card">
            <div className="flex items-start gap-4">
              <div className="p-3 rounded-lg bg-primary/10">
                <FileText className="h-6 w-6 text-primary" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold mb-2">Need More Help?</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Check out our comprehensive documentation, join our Discord community, or contact our support team.
                </p>
                <div className="flex gap-2">
                  <Button variant="outline" size="sm">
                    <ExternalLink className="h-4 w-4 mr-2" />
                    Full Documentation
                  </Button>
                  <Button variant="outline" size="sm">
                    Join Discord
                  </Button>
                  <Button variant="outline" size="sm">
                    Contact Support
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
      
      <Footer />
    </div>
  );
}
