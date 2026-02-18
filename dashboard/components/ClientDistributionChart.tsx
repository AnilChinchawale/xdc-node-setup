'use client';

import { useMemo } from 'react';
import { Cpu } from 'lucide-react';

interface ClientDistribution {
  erigon: number;
  nethermind: number;
  geth: number;
  unknown: number;
}

interface ClientDistributionChartProps {
  distribution: ClientDistribution;
  total: number;
}

const CLIENT_COLORS = {
  erigon: '#1E90FF',     // Blue
  nethermind: '#10B981', // Green  
  geth: '#8B5CF6',       // Purple
  unknown: '#6B7280',    // Gray
};

const CLIENT_LABELS = {
  erigon: 'Erigon',
  nethermind: 'Nethermind',
  geth: 'Geth',
  unknown: 'Unknown',
};

export default function ClientDistributionChart({ 
  distribution, 
  total 
}: ClientDistributionChartProps) {
  const chartData = useMemo(() => {
    const entries = Object.entries(distribution) as [keyof ClientDistribution, number][];
    return entries
      .map(([key, count]) => ({
        key,
        count,
        percentage: total > 0 ? (count / total) * 100 : 0,
        color: CLIENT_COLORS[key],
        label: CLIENT_LABELS[key],
      }))
      .sort((a, b) => b.count - a.count);
  }, [distribution, total]);

  // Calculate donut segments
  const segments = useMemo(() => {
    let cumulativePercent = 0;
    const radius = 40;
    const circumference = 2 * Math.PI * radius;

    return chartData.map((item) => {
      const segmentLength = (item.percentage / 100) * circumference;
      const offset = (cumulativePercent / 100) * circumference;
      cumulativePercent += item.percentage;

      return {
        ...item,
        radius,
        circumference,
        segmentLength,
        offset: -offset,
      };
    });
  }, [chartData]);

  if (total === 0) {
    return (
      <div className="card-xdc">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-[var(--accent-blue)]/10 flex items-center justify-center">
            <Cpu className="w-5 h-5 text-[var(--accent-blue)]" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">Client Distribution</h3>
            <p className="text-xs text-[var(--text-tertiary)]">Fleet node types</p>
          </div>
        </div>
        <div className="flex items-center justify-center h-40 text-[var(--text-tertiary)] text-sm">
          No data available
        </div>
      </div>
    );
  }

  return (
    <div className="card-xdc">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-[var(--accent-blue)]/10 flex items-center justify-center">
          <Cpu className="w-5 h-5 text-[var(--accent-blue)]" />
        </div>
        <div>
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">Client Distribution</h3>
          <p className="text-xs text-[var(--text-tertiary)]">Fleet node types</p>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row items-center gap-6">
        {/* Donut Chart */}
        <div className="relative w-32 h-32 flex-shrink-0">
          <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
            {/* Background circle */}
            <circle
              cx="50"
              cy="50"
              r={segments[0]?.radius || 40}
              fill="none"
              stroke="var(--border-subtle)"
              strokeWidth="12"
            />
            
            {/* Segments */}
            {segments.map((segment) => (
              <circle
                key={segment.key}
                cx="50"
                cy="50"
                r={segment.radius}
                fill="none"
                stroke={segment.color}
                strokeWidth="12"
                strokeDasharray={`${segment.segmentLength} ${segment.circumference - segment.segmentLength}`}
                strokeDashoffset={segment.offset}
                className="transition-all duration-500"
              />
            ))}
          </svg>
          
          {/* Center text */}
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-xl font-bold text-[var(--text-primary)] font-mono-nums">
              {total}
            </span>
            <span className="text-[10px] text-[var(--text-tertiary)] uppercase">
              Nodes
            </span>
          </div>
        </div>

        {/* Legend */}
        <div className="flex-1 w-full">
          <div className="space-y-2">
            {chartData.map((item) => (
              <div
                key={item.key}
                className="flex items-center justify-between text-sm"
              >
                <div className="flex items-center gap-2">
                  <span
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: item.color }}
                  />
                  <span className="text-[var(--text-secondary)] capitalize">
                    {item.label}
                  </span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-[var(--text-primary)] font-medium font-mono-nums">
                    {item.count}
                  </span>
                  <span className="text-[var(--text-tertiary)] text-xs w-12 text-right">
                    {item.percentage.toFixed(1)}%
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
