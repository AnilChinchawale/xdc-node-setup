'use client';

import { useMemo } from 'react';
import { Reward } from '@/lib/types';

interface RewardChartProps {
  rewards: Reward[];
}

export default function RewardChart({ rewards }: RewardChartProps) {
  // Group rewards by date for the chart
  const dailyData = useMemo(() => {
    const grouped = new Map<string, number>();
    
    rewards.forEach((reward) => {
      const date = new Date(reward.timestamp).toLocaleDateString();
      const current = grouped.get(date) || 0;
      grouped.set(date, current + reward.amount);
    });
    
    return Array.from(grouped.entries())
      .map(([date, amount]) => ({ date, amount }))
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
      .slice(-30); // Last 30 days
  }, [rewards]);

  if (dailyData.length === 0) {
    return (
      <div className="h-64 flex items-center justify-center text-gray-500">
        No reward data available
      </div>
    );
  }

  const maxAmount = Math.max(...dailyData.map(d => d.amount));
  const avgAmount = dailyData.reduce((sum, d) => sum + d.amount, 0) / dailyData.length;

  return (
    <div className="h-64">
      <div className="flex justify-between text-xs text-gray-400 mb-2">
        <span>Daily Rewards (XDC)</span>
        <span>Avg: {avgAmount.toFixed(2)} XDC/day</span>
      </div>
      
      <div className="h-48 flex items-end gap-1">
        {dailyData.map((day, index) => {
          const height = maxAmount > 0 ? (day.amount / maxAmount) * 100 : 0;
          return (
            <div
              key={index}
              className="flex-1 bg-xdc-primary/60 hover:bg-xdc-primary rounded-t transition-all"
              style={{ height: `${Math.max(height, 5)}%` }}
              title={`${day.date}: ${day.amount.toFixed(4)} XDC`}
            />
          );
        })}
      </div>
      
      <div className="flex justify-between text-xs text-gray-500 mt-2">
        <span>{dailyData[0]?.date}</span>
        <span>{dailyData[dailyData.length - 1]?.date}</span>
      </div>
    </div>
  );
}
