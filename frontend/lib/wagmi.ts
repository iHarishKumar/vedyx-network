import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia, mainnet, polygon, arbitrum, optimism } from "wagmi/chains";
import { defineChain } from "viem";

// Define Unichain Sepolia
export const unichainSepolia = defineChain({
  id: 1301,
  name: "Unichain Sepolia",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: ["https://sepolia.unichain.org"],
    },
    public: {
      http: ["https://sepolia.unichain.org"],
    },
  },
  blockExplorers: {
    default: {
      name: "Unichain Sepolia Explorer",
      url: "https://sepolia.uniscan.xyz",
    },
  },
  testnet: true,
});

export const config = getDefaultConfig({
  appName: "Vedyx Network",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "",
  chains: [unichainSepolia, mainnet, sepolia, polygon, arbitrum, optimism],
  ssr: true,
});
