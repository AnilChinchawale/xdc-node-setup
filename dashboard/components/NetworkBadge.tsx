import { getNetworkInfo } from "@/lib/network";

interface NetworkBadgeProps {
  chainId: string | number;
  className?: string;
}

export function NetworkBadge({ chainId, className = "" }: NetworkBadgeProps) {
  const id = typeof chainId === "string" ? parseInt(chainId) : chainId;
  const info = getNetworkInfo(id);
  
  const colors = {
    mainnet: "bg-emerald-500/10 text-emerald-500 border-emerald-500/20",
    apothem: "bg-blue-500/10 text-blue-500 border-blue-500/20",
    testnet: "bg-blue-500/10 text-blue-500 border-blue-500/20",
    devnet: "bg-purple-500/10 text-purple-500 border-purple-500/20",
  };

  const color = colors[info.network] || colors.mainnet;

  return (
    <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium border ${color} ${className}`}>
      <span className="relative flex h-2 w-2">
        <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75" style={{backgroundColor: "currentColor"}}></span>
        <span className="relative inline-flex rounded-full h-2 w-2" style={{backgroundColor: "currentColor"}}></span>
      </span>
      {info.name}
      <span className="opacity-60">#{info.chainId}</span>
    </span>
  );
}
