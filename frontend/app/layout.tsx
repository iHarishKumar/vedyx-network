import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Vedyx Network - Smart Contract Security Monitoring",
  description: "Real-time security monitoring for smart contracts powered by reactive architecture. Detect threats, prevent exploits, and secure your DeFi protocols.",
  icons: {
    icon: "/logo.svg",
    apple: "/logo.svg",
  },
  openGraph: {
    title: "Vedyx Network - Smart Contract Security Monitoring",
    description: "Real-time security monitoring for smart contracts powered by reactive architecture",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
