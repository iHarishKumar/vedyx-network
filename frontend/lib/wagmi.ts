import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia, mainnet, polygon, arbitrum, optimism } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Vedyx Network",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "",
  chains: [mainnet, sepolia, polygon, arbitrum, optimism],
  ssr: true,
});
