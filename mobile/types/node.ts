/**
 * Node type definitions
 */

export type NodeStatus = 'online' | 'syncing' | 'offline';

export type NetworkType = 'mainnet' | 'testnet' | 'devnet';

export interface Node {
  id: string;
  name: string;
  host: string;
  network: NetworkType;
  status: NodeStatus;
  blockHeight: number;
  peerCount: number;
  syncProgress?: number;
  lastSeen: string;
}

export interface NodeDetail extends Node {
  version: string;
  chainId: number;
  protocol: string;
  dataDir: string;
  rpcPort: number;
  p2pPort: number;
  wsPort?: number;
  uptime: string;
  cpuUsage?: number;
  memoryUsage?: number;
  diskUsage?: number;
  currentBlock?: number;
  highestBlock?: number;
  startingBlock?: number;
  isMasternode: boolean;
  masternodeStatus?: MasternodeStatus;
  peers: Peer[];
  recentLogs?: string[];
}

export interface MasternodeStatus {
  isCandidate: boolean;
  isActive: boolean;
  totalStaked: string;
  rewards: string;
  slashCount: number;
  lastBlockSigned?: number;
}

export interface Peer {
  id: string;
  enode: string;
  name: string;
  remoteAddress: string;
  localAddress: string;
  inbound: boolean;
}

export interface NodeMetrics {
  timestamp: string;
  blockHeight: number;
  peerCount: number;
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  networkIn: number;
  networkOut: number;
}
