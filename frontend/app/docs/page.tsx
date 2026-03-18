"use client";

import { useEffect } from "react";
import { ExternalLink } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

export default function Documentation() {
  const githubReadmeUrl = "https://github.com/iHarishKumar/vedyx-network/blob/master/README.md";

  useEffect(() => {
    window.location.href = githubReadmeUrl;
  }, []);

  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      
      <main className="flex-1 bg-muted/30">
        <div className="container py-16">
          <Card className="max-w-2xl mx-auto">
            <CardHeader>
              <CardTitle>Redirecting to Documentation</CardTitle>
              <CardDescription>
                You are being redirected to the GitHub repository README
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground mb-4">
                If you are not redirected automatically, click the button below:
              </p>
              <Button asChild>
                <a href={githubReadmeUrl} target="_blank" rel="noopener noreferrer">
                  <ExternalLink className="h-4 w-4 mr-2" />
                  View Documentation on GitHub
                </a>
              </Button>
            </CardContent>
          </Card>
        </div>
      </main>
      
      <Footer />
    </div>
  );
}
