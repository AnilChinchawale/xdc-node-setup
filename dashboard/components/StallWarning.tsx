'use client';

import { Clock, AlertTriangle } from 'lucide-react';

interface StallWarningProps {
  stallHours: number;
  stalledAtBlock: number;
}

export default function StallWarning({ stallHours, stalledAtBlock }: StallWarningProps) {
  if (!stallHours || stallHours === 0) return null;

  const severity = stallHours < 0.5 ? 'warning' : stallHours < 2 ? 'critical' : 'severe';
  
  return (
    <div className={`
      flex items-center gap-3 px-4 py-3 rounded-xl border-2
      ${severity === 'warning' ? 'bg-yellow-500/10 border-yellow-500/30' : ''}
      ${severity === 'critical' ? 'bg-orange-500/10 border-orange-500/30' : ''}
      ${severity === 'severe' ? 'bg-red-500/10 border-red-500/30' : ''}
      animate-pulse-slow
    `}>
      <div className={`
        p-2 rounded-lg
        ${severity === 'warning' ? 'bg-yellow-500/20' : ''}
        ${severity === 'critical' ? 'bg-orange-500/20' : ''}
        ${severity === 'severe' ? 'bg-red-500/20' : ''}
      `}>
        <Clock className={`
          h-5 w-5
          ${severity === 'warning' ? 'text-yellow-400' : ''}
          ${severity === 'critical' ? 'text-orange-400' : ''}
          ${severity === 'severe' ? 'text-red-400' : ''}
        `} />
      </div>
      
      <div className="flex-1">
        <div className="flex items-center gap-2">
          <span className={`
            text-sm font-semibold
            ${severity === 'warning' ? 'text-yellow-400' : ''}
            ${severity === 'critical' ? 'text-orange-400' : ''}
            ${severity === 'severe' ? 'text-red-400' : ''}
          `}>
            Sync Stalled
          </span>
          {severity === 'severe' && (
            <AlertTriangle className="h-4 w-4 text-red-400" />
          )}
        </div>
        <p className="text-xs text-[var(--text-secondary)] mt-0.5">
          Node stuck on block <span className="font-mono font-medium text-[var(--text-primary)]">#{stalledAtBlock.toLocaleString()}</span> for{' '}
          <span className="font-medium text-[var(--text-primary)]">{stallHours.toFixed(1)} hours</span>
          {stallHours < 0.5 && ' — Auto-injecting peers...'}
          {stallHours >= 0.5 && stallHours < 2 && ' — Watchdog monitoring'}
          {stallHours >= 2 && ' — Auto-restart may be needed'}
        </p>
      </div>
    </div>
  );
}
