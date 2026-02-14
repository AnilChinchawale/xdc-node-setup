'use client';

import { useState, useMemo } from 'react';
import { 
  AlertTriangle, 
  AlertCircle,
  CheckCircle2,
  Terminal,
  Clock,
  Wrench,
  Activity,
  HardDrive,
  Cpu,
  Network,
  Copy,
  Check,
  ChevronDown,
  ChevronUp,
  Play,
} from 'lucide-react';

interface DiagnosticCommand {
  id: string;
  name: string;
  description: string;
  command: string;
  category: 'sync' | 'peers' | 'resources' | 'database';
}

const mockDiagnosticCommands: DiagnosticCommand[] = [
  {
    id: 'diag-001',
    name: 'Check Sync Status',
    description: 'Display current block height and sync progress',
    command: 'docker exec xdc-node XDC sync status',
    category: 'sync'
  },
  {
    id: 'diag-002',
    name: 'List Peers',
    description: 'Show all connected peers with details',
    command: 'docker exec xdc-node XDC attach --exec "admin.peers"',
    category: 'peers'
  },
  {
    id: 'diag-003',
    name: 'Check Disk Usage',
    description: 'Display disk usage for data directory',
    command: 'docker exec xdc-node du -sh /work/xdcchain',
    category: 'resources'
  },
  {
    id: 'diag-004',
    name: 'View Recent Logs',
    description: 'Show last 50 log entries',
    command: 'docker logs --tail 50 xdc-node',
    category: 'sync'
  },
  {
    id: 'diag-005',
    name: 'Test RPC Connection',
    description: 'Verify RPC endpoint is responding',
    command: 'curl -X POST http://localhost:8545 -H "Content-Type: application/json" -d \'{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}\'',
    category: 'sync'
  },
  {
    id: 'diag-006',
    name: 'Database Stats',
    description: 'Show database size and status',
    command: 'docker exec xdc-node XDC attach --exec "admin.datadir"',
    category: 'database'
  },
];

export default function TroubleshootPanel() {
  const [copiedCommand, setCopiedCommand] = useState<string | null>(null);
  const [expandedCategory, setExpandedCategory] = useState<string>('sync');

  const handleCopyCommand = async (command: string, id: string) => {
    await navigator.clipboard.writeText(command);
    setCopiedCommand(id);
    setTimeout(() => setCopiedCommand(null), 2000);
  };

  const categories = Array.from(new Set(mockDiagnosticCommands.map(c => c.category)));

  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'sync': return Activity;
      case 'peers': return Network;
      case 'resources': return Cpu;
      case 'database': return HardDrive;
      default: return Terminal;
    }
  };

  return (
    <div className="card-xdc">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--warning)]/20 to-[var(--critical)]/10 flex items-center justify-center">
          <Wrench className="w-5 h-5 text-[var(--warning)]" />
        </div>
        <div>
          <h2 className="text-lg font-semibold text-[var(--text-primary)]">Quick Diagnostics</h2>
          <p className="text-sm text-[var(--text-tertiary)]">Troubleshoot your node</p>
        </div>
      </div>

      {/* Commands by Category */}
      {categories.map((category) => {
        const commands = mockDiagnosticCommands.filter(c => c.category === category);
        if (commands.length === 0) return null;
        
        const CategoryIcon = getCategoryIcon(category);
        const isExpanded = expandedCategory === category;
        
        return (
          <div key={category} className="mb-4">
            <button
              onClick={() => setExpandedCategory(isExpanded ? '' : category)}
              className="flex items-center justify-between w-full p-3 rounded-lg bg-[var(--bg-hover)] hover:bg-[var(--bg-card-hover)] transition-colors"
            >
              <div className="flex items-center gap-2">
                <CategoryIcon className="w-4 h-4 text-[var(--accent-blue)]" />
                <h3 className="text-sm font-medium text-[var(--text-primary)] capitalize">{category}</h3>
                <span className="text-xs text-[var(--text-tertiary)]">({commands.length})</span>
              </div>
              {isExpanded ? (
                <ChevronUp className="w-4 h-4 text-[var(--text-tertiary)]" />
              ) : (
                <ChevronDown className="w-4 h-4 text-[var(--text-tertiary)]" />
              )}
            </button>
            
            {isExpanded && (
              <div className="mt-2 space-y-2">
                {commands.map((cmd) => (
                  <div 
                    key={cmd.id} 
                    className="p-3 rounded-lg bg-[var(--bg-body)] border border-[var(--border-subtle)]"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <h4 className="text-sm font-medium text-[var(--text-primary)]">{cmd.name}</h4>
                        <p className="text-xs text-[var(--text-tertiary)] mt-0.5">{cmd.description}</p>
                      </div>
                    </div>
                    <code className="block p-2 rounded bg-[var(--bg-card)] text-xs text-[var(--accent-blue)] font-mono mb-2 overflow-x-auto">
                      {cmd.command}
                    </code>
                    <div className="flex items-center gap-2">
                      <button 
                        onClick={() => handleCopyCommand(cmd.command, cmd.id)}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[var(--bg-hover)] text-[var(--text-primary)] text-xs hover:bg-[var(--bg-card-hover)] transition-colors"
                      >
                        {copiedCommand === cmd.id ? <Check className="w-3.5 h-3.5 text-[var(--success)]" /> : <Copy className="w-3.5 h-3.5" />}
                        {copiedCommand === cmd.id ? 'Copied!' : 'Copy'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
