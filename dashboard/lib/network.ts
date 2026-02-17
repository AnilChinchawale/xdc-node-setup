// Network configuration for XDC
export const XDC_NETWORKS = {
  mainnet: {
    chainId: 50,
    name: "XDC Mainnet",
    rpcPort: 8545,
    wsPort: 8546,
    p2pPort: 30303,
    dashboardPort: 7070,
  },
  apothem: {
    chainId: 51,
    name: "XDC Apothem Testnet",
    rpcPort: 8545,
    wsPort: 8546,
    p2pPort: 30303,
    dashboardPort: 7070,
  },
  testnet: {
    chainId: 51,
    name: "XDC Apothem Testnet",
    rpcPort: 8545,
    wsPort: 8546,
    p2pPort: 30303,
    dashboardPort: 7070,
  },
  devnet: {
    chainId: 551,
    name: "XDC Devnet",
    rpcPort: 8545,
    wsPort: 8546,
    p2pPort: 30303,
    dashboardPort: 7070,
  },
} as const;

export type NetworkType = keyof typeof XDC_NETWORKS;

export function getNetworkByChainId(chainId: number): NetworkType {
  switch (chainId) {
    case 50:
      return "mainnet";
    case 51:
      return "apothem";
    case 551:
      return "devnet";
    default:
      return "mainnet";
  }
}

export function getNetworkInfo(chainId: number) {
  const network = getNetworkByChainId(chainId);
  return {
    network,
    ...XDC_NETWORKS[network],
  };
}

export function getNetworkName(chainId: number | string): string {
  const id = typeof chainId === "string" ? parseInt(chainId) : chainId;
  const network = getNetworkByChainId(id);
  return XDC_NETWORKS[network].name;
}
