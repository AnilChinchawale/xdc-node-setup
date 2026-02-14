'use client';

import { useState, useMemo } from 'react';
import { Activity, Clock, TrendingUp, TrendingDown } from 'lucide-react';
import { Sparkline } from './charts/Sparkline';

interface MetricsHistory {
  timestamps: string[];
  blockHeight: number[];
  peers: number[];
  cpu: number[];
  memory: number[];
  disk: number[];
  syncPercent: number[];
  txPoolPending: number[];
}

interface MetricsHistoryPanelProps {
  history: MetricsHistory;
  onTimeRangeChange?: (hours: number) => void;
}

function MetricsChart({ 
  data, 
  labels,
  series,
  height = 200 
}: { 
  data: MetricsHistory; 
  labels: string[];
  series: string[];
  height?: number;
}) {
  const width = 800;
  const padding = { top: 20, right: 30, bottom: 40, left: 60 };
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;

  const colors: Record<string, string> = {
    blockHeight: '#1E90FF',
    peers: '#10B981',
    cpu: '#F59E0B',
    memory: '#8B5CF6',
    disk: '#EF4444',
    syncPercent: '#EC4899',
    txPoolPending: '#F59E0B',
  };

  const getSeriesData = (key: string): number[] => {
    switch (key) {
      case 'blockHeight': return data.blockHeight;
      case 'peers': return data.peers;
      case 'cpu': return data.cpu;
      case 'memory': return data.memory;
      case 'disk': return data.disk;
      case 'syncPercent': return data.syncPercent;
      case 'txPoolPending': return data.txPoolPending;
      default: return [];
    }
  };

  const getY = (value: number, min: number, max: number) => {
    const range = max - min || 1;
    return padding.top + chartHeight - ((value - min) / range) * chartHeight;
  };

  const getX = (index: number, total: number) => {
    return padding.left + (index / (total - 1 || 1)) * chartWidth;
  };

  const generatePath = (values: number[]) => {
    if (values.length === 0) return '';
    const min = Math.min(...values);
    const max = Math.max(...values);
    
    return values.map((value, i) => 
      `${i === 0 ? 'M' : 'L'} ${getX(i, values.length)} ${getY(value, min, max)}`
    ).join(' ');
  };

  return (
    <div className="w-full overflow-x-auto">
      <svg viewBox={`0 0 ${width} ${height}`} className="w-full min-w-[600px]">
        {/* Grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map(t => (
          <line
            key={t}
            x1={padding.left}
            y1={padding.top + t * chartHeight}
            x2={width - padding.right}
            y2={padding.top + t * chartHeight}
            stroke="rgba(255,255,255,0.05)"
            strokeWidth="1"
          />
        ))}
        
        {/* Series lines */}
        {series.map(s => {
          const values = getSeriesData(s);
          if (values.length === 0) return null;
          return (
            <path 
              key={s} 
              d={generatePath(values)} 
              fill="none" 
              stroke={colors[s]} 
              strokeWidth="2" 
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          );
        })}
        
        {/* X-axis labels */}
        {labels.filter((_, i) => i % Math.max(1, Math.floor(labels.length / 6)) === 0).map((label, i, arr) => {
          const index = i * Math.max(1, Math.floor(labels.length / 6));
          return (
            <text
              key={i}
              x={getX(index, labels.length)}
              y={height - 10}
              textAnchor="middle"
              fill="#64748B"
              fontSize="10"
            >
              {new Date(label).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </text>
          );
        })}
      </svg>
      
      {/* Legend */}
      <div className="flex items-center justify-center gap-6 mt-2 flex-wrap">
        {series.map(s => (
          <div key={s} className="flex items-center gap-2">
            <div className="w-4 h-1 rounded" style={{ backgroundColor: colors[s] }} />
            <span className="text-xs text-[var(--text-tertiary)] capitalize">{s.replace(/([A-Z])/g, ' $1').trim()}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function MetricsHistoryPanel({ history, onTimeRangeChange }: MetricsHistoryPanelProps) {
  const [timeRange, setTimeRange] = useState<number>(1);
  const [selectedSeries, setSelectedSeries] = useState<string[]>(['blockHeight', 'peers']);

  const handleTimeRangeChange = (hours: number) => {
    setTimeRange(hours);
    if (onTimeRangeChange) {
      onTimeRangeChange(hours);
    }
  };

  // Calculate trends
  const trends = useMemo(() => {
    const calc = (arr: number[]) => {
      if (arr.length < 2) return { trend: 'same', change: 0 };
      const recent = arr.slice(-5);
      const older = arr.slice(-10, -5);
      const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
      const olderAvg = older.length > 0 ? older.reduce((a, b) => a + b, 0) / older.length : recentAvg;
      const change = olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg) * 100 : 0;
      return {
        trend: change > 1 ? 'up' : change < -1 ? 'down' : 'same',
        change: Math.abs(change).toFixed(1)
      };
    };
    
    return {
      blockHeight: calc(history.blockHeight),
      peers: calc(history.peers),
      cpu: calc(history.cpu),
      memory: calc(history.memory),
    };
  }, [history]);

  const availableSeries = ['blockHeight', 'peers', 'cpu', 'memory', 'disk', 'syncPercent', 'txPoolPending'];

  return (
    <div className="card-xdc">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between mb-5 gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--accent-blue)]/20 to-[var(--success)]/10 flex items-center justify-center">
            <Activity className="w-5 h-5 text-[var(--accent-blue)]" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-[var(--text-primary)]">Metrics History</h2>
            <div className="text-sm text-[var(--text-tertiary)]">Performance over time</div>
          </div>
        </div>

        <div className="flex flex-col sm:flex-row gap-3 sm:items-center">
          {/* Time Range Selector */}
          <div className="flex gap-1">
            {[1, 6, 24].map((hours) => (
              <button
                key={hours}
                onClick={() => handleTimeRangeChange(hours)}
                className={`px-3 py-1.5 rounded text-xs transition-colors min-h-[44px] sm:min-h-0 ${
                  timeRange === hours
                    ? 'bg-[var(--accent-blue-glow)] text-[var(--accent-blue)]'
                    : 'bg-[var(--bg-hover)] text-[var(--text-tertiary)] hover:text-[var(--text-primary)]'
                }`}
              >
                {hours}h
              </button>
            ))}
          </div>

          {/* Series Toggles */}
          <div className="flex gap-1 overflow-x-auto pb-1 sm:pb-0 -mx-4 px-4 sm:mx-0 sm:px-0 scrollbar-hide">
            {availableSeries.map((series) => (
              <button
                key={series}
                onClick={() => {
                  setSelectedSeries(prev =>
                    prev.includes(series)
                      ? prev.filter(s => s !== series)
                      : [...prev, series]
                  );
                }}
                className={`px-3 py-1.5 rounded text-xs transition-colors whitespace-nowrap flex-shrink-0 min-h-[44px] sm:min-h-0 ${
                  selectedSeries.includes(series)
                    ? 'bg-[var(--accent-blue-glow)] text-[var(--accent-blue)]'
                    : 'bg-[var(--bg-hover)] text-[var(--text-tertiary)]'
                }`}
              >
                {series.replace(/([A-Z])/g, ' $1').trim()}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
        <div className="p-3 rounded-xl bg-[var(--bg-hover)]">
          <div className="flex items-center justify-between mb-1">
            <span className="section-header">Block Height</span>
            {trends.blockHeight.trend !== 'same' && (
              <span className={`text-xs flex items-center gap-1 ${trends.blockHeight.trend === 'up' ? 'text-[var(--success)]' : 'text-[var(--critical)]'}`}>
                {trends.blockHeight.trend === 'up' ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                {trends.blockHeight.change}%
              </span>
            )}
          </div>
          <div className="h-[40px]">
            <Sparkline data={history.blockHeight.slice(-30)} color="#1E90FF" height={40} width={120} />
          </div>
        </div>

        <div className="p-3 rounded-xl bg-[var(--bg-hover)]">
          <div className="flex items-center justify-between mb-1">
            <span className="section-header">Peers</span>
            {trends.peers.trend !== 'same' && (
              <span className={`text-xs flex items-center gap-1 ${trends.peers.trend === 'up' ? 'text-[var(--success)]' : 'text-[var(--critical)]'}`}>
                {trends.peers.trend === 'up' ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                {trends.peers.change}%
              </span>
            )}
          </div>
          <div className="h-[40px]">
            <Sparkline data={history.peers.slice(-30)} color="#10B981" height={40} width={120} />
          </div>
        </div>

        <div className="p-3 rounded-xl bg-[var(--bg-hover)]">
          <div className="flex items-center justify-between mb-1">
            <span className="section-header">CPU</span>
            {trends.cpu.trend !== 'same' && (
              <span className={`text-xs flex items-center gap-1 ${trends.cpu.trend === 'up' ? 'text-[var(--warning)]' : 'text-[var(--success)]'}`}>
                {trends.cpu.trend === 'up' ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                {trends.cpu.change}%
              </span>
            )}
          </div>
          <div className="h-[40px]">
            <Sparkline data={history.cpu.slice(-30)} color="#F59E0B" height={40} width={120} />
          </div>
        </div>

        <div className="p-3 rounded-xl bg-[var(--bg-hover)]">
          <div className="flex items-center justify-between mb-1">
            <span className="section-header">Memory</span>
            {trends.memory.trend !== 'same' && (
              <span className={`text-xs flex items-center gap-1 ${trends.memory.trend === 'up' ? 'text-[var(--warning)]' : 'text-[var(--success)]'}`}>
                {trends.memory.trend === 'up' ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                {trends.memory.change}%
              </span>
            )}
          </div>
          <div className="h-[40px]">
            <Sparkline data={history.memory.slice(-30)} color="#8B5CF6" height={40} width={120} />
          </div>
        </div>
      </div>

      {/* Main Chart */}
      {history.timestamps.length > 0 ? (
        <MetricsChart 
          data={history} 
          labels={history.timestamps} 
          series={selectedSeries}
          height={250}
        />
      ) : (
        <div className="text-center py-12 text-[var(--text-tertiary)]">
          <Clock className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No historical data available yet</p>
          <p className="text-sm mt-1">Metrics will appear after a few minutes of data collection</p>
        </div>
      )}
    </div>
  );
}
