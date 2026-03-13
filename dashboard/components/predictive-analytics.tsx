'use client';

import { useState, useEffect } from 'react';
import {
  TrendingUp,
  TrendingDown,
  Calendar,
  Brain,
  ArrowRight,
  Activity,
  BarChart3,
  Zap,
  Clock,
  AlertTriangle,
  CheckCircle,
} from 'lucide-react';

interface Prediction {
  id: string;
  metric: string;
  current: number;
  predicted: number;
  change: number;
  confidence: number;
  timeframe: string;
  trend: 'up' | 'down' | 'stable';
  recommendation?: string;
}

interface ForecastData {
  date: string;
  requests: number;
  predicted: number;
  upper: number;
  lower: number;
}

const mockPredictions: Prediction[] = [
  {
    id: '1',
    metric: 'Daily Requests',
    current: 45230,
    predicted: 52300,
    change: 15.6,
    confidence: 87,
    timeframe: '7 days',
    trend: 'up',
    recommendation: 'Scale up resources for expected traffic increase',
  },
  {
    id: '2',
    metric: 'Avg Response Time',
    current: 285,
    predicted: 245,
    change: -14.0,
    confidence: 82,
    timeframe: '7 days',
    trend: 'down',
    recommendation: 'Performance improvements expected from cache optimizations',
  },
  {
    id: '3',
    metric: 'Error Rate',
    current: 2.3,
    predicted: 1.8,
    change: -21.7,
    confidence: 78,
    timeframe: '7 days',
    trend: 'down',
    recommendation: 'Error handling improvements showing positive results',
  },
  {
    id: '4',
    metric: 'Active Peers',
    current: 23,
    predicted: 28,
    change: 21.7,
    confidence: 71,
    timeframe: '7 days',
    trend: 'up',
    recommendation: 'New peer connections expected from network growth',
  },
];

const mockForecast: ForecastData[] = [
  { date: 'Mon', requests: 42000, predicted: 42000, upper: 42000, lower: 42000 },
  { date: 'Tue', requests: 44500, predicted: 44500, upper: 44500, lower: 44500 },
  { date: 'Wed', requests: 45230, predicted: 45230, upper: 45230, lower: 45230 },
  { date: 'Thu', requests: 0, predicted: 46800, upper: 48500, lower: 45100 },
  { date: 'Fri', requests: 0, predicted: 48100, upper: 50800, lower: 45400 },
  { date: 'Sat', requests: 0, predicted: 50200, upper: 54200, lower: 46200 },
  { date: 'Sun', requests: 0, predicted: 52300, upper: 57800, lower: 46800 },
];

const capacityMetrics = [
  { label: 'CPU Usage', current: 45, predicted: 62, limit: 80 },
  { label: 'Memory', current: 62, predicted: 71, limit: 85 },
  { label: 'Disk I/O', current: 38, predicted: 55, limit: 75 },
  { label: 'Network', current: 52, predicted: 68, limit: 80 },
];

function getConfidenceColor(confidence: number): string {
  if (confidence >= 80) return 'var(--success)';
  if (confidence >= 60) return 'var(--warning)';
  return 'var(--critical)';
}

function PredictionCard({ prediction }: { prediction: Prediction }) {
  const isPositive = prediction.change > 0 && prediction.metric !== 'Avg Response Time' && prediction.metric !== 'Error Rate';
  const isNegative = prediction.change < 0 && (prediction.metric === 'Avg Response Time' || prediction.metric === 'Error Rate');
  const trendColor = isPositive || isNegative ? 'var(--success)' : 'var(--warning)';

  return (
    <div className="p-4 rounded-xl bg-[var(--bg-body)] border border-[var(--border-subtle)] hover:border-[var(--border-blue-glow)] transition-colors">
      <div className="flex items-start justify-between mb-3">
        <div>
          <p className="text-xs text-[var(--text-muted)] mb-1">{prediction.metric}</p>
          <p className="text-lg font-semibold text-[var(--text-primary)]">
            {prediction.metric === 'Avg Response Time' ? `${prediction.predicted}ms` :
             prediction.metric === 'Error Rate' ? `${prediction.predicted}%` :
             prediction.predicted.toLocaleString()}
          </p>
        </div>
        <div
          className="flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-medium"
          style={{
            backgroundColor: `${trendColor}15`,
            color: trendColor,
          }}
        >
          {prediction.trend === 'up' ? <TrendingUp className="w-3 h-3" /> :
           prediction.trend === 'down' ? <TrendingDown className="w-3 h-3" /> :
           <Activity className="w-3 h-3" />}
          {Math.abs(prediction.change).toFixed(1)}%
        </div>
      </div>

      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-[var(--text-muted)]">Current:</span>
          <span className="text-xs text-[var(--text-secondary)]">
            {prediction.metric === 'Avg Response Time' ? `${prediction.current}ms` :
             prediction.metric === 'Error Rate' ? `${prediction.current}%` :
             prediction.current.toLocaleString()}
          </span>
        </div>
        <div className="flex items-center gap-1.5">
          <Brain className="w-3 h-3" style={{ color: getConfidenceColor(prediction.confidence) }} />
          <span className="text-[10px]" style={{ color: getConfidenceColor(prediction.confidence) }}>
            {prediction.confidence}% confidence
          </span>
        </div>
      </div>

      {prediction.recommendation && (
        <div className="flex items-start gap-2 p-2 rounded-lg bg-[var(--bg-card)]">
          <Zap className="w-3.5 h-3.5 text-[var(--accent-blue)] flex-shrink-0 mt-0.5" />
          <p className="text-[11px] text-[var(--text-secondary)] leading-relaxed">{prediction.recommendation}</p>
        </div>
      )}
    </div>
  );
}

function ForecastChart() {
  const maxValue = Math.max(...mockForecast.map(d => d.upper || d.requests || d.predicted));
  
  return (
    <div className="mt-4">
      <div className="flex items-end justify-between h-32 gap-2">
        {mockForecast.map((data, i) => {
          const isActual = data.requests > 0;
          const value = isActual ? data.requests : data.predicted;
          const height = (value / maxValue) * 100;
          
          return (
            <div key={i} className="flex-1 flex flex-col items-center gap-1">
              <div className="relative w-full flex items-end justify-center">
                {/* Confidence interval */}
                {!isActual && (
                  <div
                    className="absolute w-full rounded-t bg-[var(--accent-blue)]/10"
                    style={{
                      height: `${((data.upper - data.lower) / maxValue) * 100}%`,
                      bottom: `${(data.lower / maxValue) * 100}%`,
                    }}
                  />
                )}
                {/* Bar */}
                <div
                  className={`w-full max-w-[24px] rounded-t transition-all ${
                    isActual
                      ? 'bg-[var(--accent-blue)]'
                      : 'bg-[var(--accent-blue)]/50 border border-[var(--accent-blue)]/30 border-b-0'
                  }`}
                  style={{ height: `${height}%` }}
                />
              </div>
              <span className="text-[10px] text-[var(--text-muted)]">{data.date}</span>
            </div>
          );
        })}
      </div>
      <div className="flex items-center justify-center gap-4 mt-3">
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm bg-[var(--accent-blue)]" />
          <span className="text-[10px] text-[var(--text-muted)]">Actual</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm bg-[var(--accent-blue)]/50 border border-[var(--accent-blue)]/30" />
          <span className="text-[10px] text-[var(--text-muted)]">Predicted</span>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-3 h-3 rounded-sm bg-[var(--accent-blue)]/10" />
          <span className="text-[10px] text-[var(--text-muted)]">Confidence</span>
        </div>
      </div>
    </div>
  );
}

export default function PredictiveAnalytics() {
  const [timeframe, setTimeframe] = useState<'7d' | '30d' | '90d'>('7d');

  return (
    <div className="card-xdc">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[var(--purple)]/10 flex items-center justify-center">
            <TrendingUp className="w-5 h-5 text-[var(--purple)]" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">Predictive Analytics</h3>
            <p className="text-xs text-[var(--text-tertiary)]">AI-powered forecasts and capacity planning</p>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          {(['7d', '30d', '90d'] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTimeframe(t)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                timeframe === t
                  ? 'bg-[var(--accent-blue)]/10 text-[var(--accent-blue)]'
                  : 'text-[var(--text-secondary)] hover:bg-[var(--bg-hover)]'
              }`}
            >
              {t === '7d' ? '7 Days' : t === '30d' ? '30 Days' : '90 Days'}
            </button>
          ))}
        </div>
      </div>

      {/* Predictions Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        {mockPredictions.map((prediction) => (
          <PredictionCard key={prediction.id} prediction={prediction} />
        ))}
      </div>

      {/* Forecast Chart */}
      <div className="p-4 rounded-xl bg-[var(--bg-body)] border border-[var(--border-subtle)] mb-6">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <BarChart3 className="w-4 h-4 text-[var(--text-muted)]" />
            <span className="text-xs font-medium text-[var(--text-primary)]">Request Volume Forecast</span>
          </div>
          <div className="flex items-center gap-1.5 text-[10px] text-[var(--text-muted)]">
            <Brain className="w-3 h-3" />
            ML Model v2.4
          </div>
        </div>
        <ForecastChart />
      </div>

      {/* Capacity Planning */}
      <div className="space-y-4">
        <div className="flex items-center gap-2">
          <Clock className="w-4 h-4 text-[var(--text-muted)]" />
          <span className="text-xs font-medium text-[var(--text-primary)]">Capacity Planning</span>
        </div>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {capacityMetrics.map((metric) => {
            const willExceed = metric.predicted > metric.limit;
            return (
              <div key={metric.label} className="p-3 rounded-lg bg-[var(--bg-body)] border border-[var(--border-subtle)]">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs text-[var(--text-secondary)]">{metric.label}</span>
                  {willExceed ? (
                    <AlertTriangle className="w-3.5 h-3.5 text-[var(--critical)]" />
                  ) : (
                    <CheckCircle className="w-3.5 h-3.5 text-[var(--success)]" />
                  )}
                </div>
                
                <div className="flex items-end gap-2 mb-2">
                  <span className="text-lg font-semibold text-[var(--text-primary)]">{metric.predicted}%</span>
                  <span className="text-[10px] text-[var(--text-muted)] mb-1">/ {metric.limit}%</span>
                </div>
                
                <div className="h-1.5 rounded-full bg-[var(--bg-card)] overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all"
                    style={{
                      width: `${Math.min((metric.predicted / metric.limit) * 100, 100)}%`,
                      backgroundColor: willExceed ? 'var(--critical)' : 'var(--success)',
                    }}
                  />
                </div>
                
                <div className="flex items-center justify-between mt-1.5">
                  <span className="text-[10px] text-[var(--text-muted)]">Current: {metric.current}%</span>
                  {willExceed && (
                    <span className="text-[10px] text-[var(--critical)]">Limit exceeded</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between mt-6 pt-4 border-t border-[var(--border-subtle)]">
        <p className="text-[10px] text-[var(--text-muted)]">
          Predictions updated 2 hours ago • Based on 30 days of historical data
        </p>
        <button className="flex items-center gap-1.5 text-xs text-[var(--accent-blue)] hover:underline">
          View detailed forecast
          <ArrowRight className="w-3 h-3" />
        </button>
      </div>
    </div>
  );
}
