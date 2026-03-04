import Link from "next/link";
import { Github, Twitter } from "lucide-react";
import { VedyxLogo } from "@/components/logo";

export function Footer() {
  return (
    <footer className="border-t bg-background">
      <div className="container py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <VedyxLogo size={24} className="text-primary" />
              <span className="text-xl font-bold">Vedyx</span>
            </div>
            <p className="text-sm text-muted-foreground">
              Real-time blockchain security monitoring powered by AI
            </p>
            <div className="flex gap-4">
              <Link href="https://github.com" className="text-muted-foreground hover:text-primary">
                <Github className="h-5 w-5" />
              </Link>
              <Link href="https://twitter.com" className="text-muted-foreground hover:text-primary">
                <Twitter className="h-5 w-5" />
              </Link>
            </div>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">Product</h3>
            <ul className="space-y-2 text-sm">
              <li><Link href="/dashboard" className="text-muted-foreground hover:text-primary">Dashboard</Link></li>
              <li><Link href="/monitors" className="text-muted-foreground hover:text-primary">Monitors</Link></li>
              <li><Link href="/alerts" className="text-muted-foreground hover:text-primary">Alerts</Link></li>
              <li><Link href="/pricing" className="text-muted-foreground hover:text-primary">Pricing</Link></li>
            </ul>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">Resources</h3>
            <ul className="space-y-2 text-sm">
              <li><Link href="/docs" className="text-muted-foreground hover:text-primary">Documentation</Link></li>
              <li><Link href="/docs/api" className="text-muted-foreground hover:text-primary">API Reference</Link></li>
              <li><Link href="/guides" className="text-muted-foreground hover:text-primary">Guides</Link></li>
              <li><Link href="/support" className="text-muted-foreground hover:text-primary">Support</Link></li>
            </ul>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">Company</h3>
            <ul className="space-y-2 text-sm">
              <li><Link href="/about" className="text-muted-foreground hover:text-primary">About</Link></li>
              <li><Link href="/blog" className="text-muted-foreground hover:text-primary">Blog</Link></li>
              <li><Link href="/privacy" className="text-muted-foreground hover:text-primary">Privacy</Link></li>
              <li><Link href="/terms" className="text-muted-foreground hover:text-primary">Terms</Link></li>
            </ul>
          </div>
        </div>
        
        <div className="mt-8 pt-8 border-t text-center text-sm text-muted-foreground">
          <p>&copy; {new Date().getFullYear()} Vedyx Network. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
