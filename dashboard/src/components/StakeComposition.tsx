'use client';

import { Delegation } from '@/lib/types';

interface StakeCompositionProps {
  delegations: Delegation[];
}

export default function StakeComposition({ delegations }: StakeCompositionProps) {
  const totalStake = delegations.reduce((sum, d) => sum + d.amount, 0);
  
  // Color palette for different delegations
  const colors = [
    'bg-blue-500',
    'bg-green-500',
    'bg-purple-500',
    'bg-orange-500',
    'bg-pink-500',
    'bg-cyan-500',
    'bg-yellow-500',
    'bg-red-500'
  ];

  if (delegations.length === 0) {
    return (
      <div className="h-48 flex flex-col items-center justify-center text-gray-500">
        <div className="w-32 h-32 rounded-full border-4 border-xdc-border mb-4" />
        <p>No delegations found</p>
      </div>
    );
  }

  return (
    <div className="h-48 flex items-center gap-8">
      {/* Pie Chart */}
      <div className="relative w-32 h-32">
        <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
          {(() => {
            let currentAngle = 0;
            return delegations.map((delegation, index) => {
              const percentage = (delegation.amount / totalStake) * 100;
              const angle = (percentage / 100) * 360;
              
              // Calculate path for pie slice
              const startAngle = (currentAngle * Math.PI) / 180;
              const endAngle = ((currentAngle + angle) * Math.PI) / 180;
              
              const x1 = 50 + 40 * Math.cos(startAngle);
              const y1 = 50 + 40 * Math.sin(startAngle);
              const x2 = 50 + 40 * Math.cos(endAngle);
              const y2 = 50 + 40 * Math.sin(endAngle);
              
              const largeArc = angle > 180 ? 1 : 0;
              
              const pathData = [
                `M 50 50`,
                `L ${x1} ${y1}`,
                `A 40 40 0 ${largeArc} 1 ${x2} ${y2}`,
                'Z'
              ].join(' ');
              
              currentAngle += angle;
              
              return (
                <path
                  key={delegation.id}
                  d={pathData}
                  className={`${colors[index % colors.length]} hover:opacity-80 transition-opacity`}
                  stroke="#1e1e1e"
                  strokeWidth="2"
                >
                  <title>
                    {delegation.delegatorAddress.slice(0, 20)}...: {percentage.toFixed(2)}%
                  </title>
                </path>
              );
            });
          })()}
        </svg>
        
        {/* Center circle */}
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-center">
            <span className="text-lg font-bold text-white">{delegations.length}</span>
            <p className="text-xs text-gray-400">nodes</p>
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="flex-1 space-y-2">
        {delegations.map((delegation, index) => {
          const percentage = (delegation.amount / totalStake) * 100;
          return (
            <div key={delegation.id} className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className={`w-3 h-3 rounded ${colors[index % colors.length]}`} />
                <span className="text-sm text-gray-300 font-mono">
                  {delegation.delegatorAddress.slice(0, 12)}...
                </span>
              </div>
              <div className="text-right">
                <span className="text-sm text-white">{percentage.toFixed(1)}%</span>
                <span className="text-xs text-gray-500 ml-2">
                  {delegation.amount.toLocaleString()} XDC
                </span>
              </div>
            </div>
          );
        })}
        
        <div className="pt-2 border-t border-xdc-border mt-4">
          <div className="flex justify-between">
            <span className="text-gray-400">Total Stake</span>
            <span className="text-white font-semibold">{totalStake.toLocaleString()} XDC</span>
          </div>
        </div>
      </div>
    </div>
  );
}
