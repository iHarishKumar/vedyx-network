# Vedyx Frontend

Modern Web3 security monitoring dashboard built with Next.js 14, TypeScript, and TailwindCSS.

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: TailwindCSS + shadcn/ui
- **Web3**: wagmi + viem + RainbowKit
- **Icons**: Lucide React
- **Charts**: Recharts

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
Copy `.env.example` to `.env` and fill in your actual values:
```bash
cp .env.example .env
```

At minimum, update the WalletConnect Project ID in `.env`:
```
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id
```

Get your WalletConnect Project ID from: https://cloud.walletconnect.com/
See `.env.example` for all available configuration options with descriptions.

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
frontend/
├── app/                    # Next.js app directory
│   ├── dashboard/         # Dashboard page
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Landing page
│   ├── providers.tsx      # Web3 providers
│   └── globals.css        # Global styles
├── components/            # React components
│   ├── ui/               # shadcn/ui components
│   ├── navbar.tsx        # Navigation bar
│   └── footer.tsx        # Footer
└── lib/                  # Utilities
    ├── utils.ts          # Helper functions
    └── wagmi.ts          # Web3 configuration
```

## Features

- 🔐 Web3 wallet connection (MetaMask, WalletConnect, etc.)
- 📊 Real-time security monitoring dashboard
- 🚨 Alert management and notifications
- 🎨 Modern, responsive UI with dark mode support
- ⚡ Fast page loads with Next.js App Router
- 🔗 Multi-chain support (Ethereum, Polygon, Arbitrum, Optimism)

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

## License

MIT
