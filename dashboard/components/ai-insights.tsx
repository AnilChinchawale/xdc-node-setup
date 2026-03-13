'use client';

import { useState, useEffect } from 'react';
import {
  Brain,
  Search,
  Sparkles,
  AlertTriangle,
  Lightbulb,
  TrendingUp,
  ChevronRight,
  Loader2,
  Clock,
  BarChart3,
  Zap,
  X
} from 'lucide-react';

interface Insight {
  id: string;
  type: 'anomaly' | 'recommendation' | 'trend' | 'optimization';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  timestamp: Date;
  metric?: string;
  value?: string;
  trend?: 'up' | 'down' | 'stable';
}

interface QueryResult {
  query: string;
  answer: string;
  data?: {
    label: string;
    value: string;
    change?: string;
  }[];
  chart?: 'bar' | 'line' | 'pie';
}

const mockInsights: Insight[] = [
  {
    id: '1',
    type: 'anomaly',
    title: 'Unusual Traffic Pattern',
    description: 'Detected 3x normal request volume from 2 IPs in the last hour. Possible bot activity.',
    impact: 'high',
    timestamp: new Date(Date.now() - 1000 * 60 * 30),
    metric: 'Requests/min',
    value: '12,450',
    trend: 'up',
  },
  {
    id: '2',
    type: 'recommendation',
    title: 'Cache Optimization',
    description: 'Increasing cache TTL from 5s to 30s could reduce CU usage by 28% and save ~$120/month.',
    impact: 'medium',
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2),
    metric: 'Cache Hit Rate',
    value: '23%',
    trend: 'up',
  },
  {
    id: '3',
    type: 'trend',
    title: 'Peak Usage Predicted',
    description: 'AI model predicts traffic will peak tomorrow at 14:00 UTC. Scale up recommended.',
    impact: 'medium',
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 4),
    metric: 'Predicted Requests',
    value: '850K',
    trend: 'up',
  },
  {
    id: '4',
    type: 'optimization',
    title: 'Batch Query Opportunity',
    description: '38% of requests are single eth_call queries that could be batched for 60% CU savings.',
    impact: 'high',
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 6),
    metric: 'Potential Savings',
    value: '$180/mo',
    trend: 'down',
  },
];

const exampleQueries = [
  'Show me failed requests from yesterday',
  'What was my highest traffic hour?',
  'Which RPC methods use the most CUs?',
  'Compare my usage to last week',
  'Show me error rate trends',
  'Which clients connect most frequently?',
];

const mockNLQueryResponse = async (query: string): Promise<QueryResult> => {
  await new Promise((resolve) => setTimeout(resolve, 1500));
  
  const lowerQuery = query.toLowerCase();
  
  if (lowerQuery.includes('fail') || lowerQuery.includes('error')) {
    return {
      query,
      answer: 'Yesterday, you had 1,247 failed requests (2.3% error rate). The majority were **429 Too Many Requests** (68%) due to rate limiting, followed by **502 Bad Gateway** (22%) from upstream timeouts. Peak failure time was 14:30-15:00 UTC.',
      data: [
        { label: '429 Rate Limit', value: '848', change: '+12%' },
        { label: '502 Gateway', value: '274', change: '-5%' },
        { label: '400 Bad Request', value: '89', change: '+2%' },
        { label: '500 Server Error', value: '36', change: '-18%' },
      ],
      chart: 'bar',
    };
  }
  
  if (lowerQuery.includes('highest') || lowerQuery.includes('peak') || lowerQuery.includes('traffic')) {
    return {
      query,
      answer: 'Your highest traffic hour was **14:00 UTC yesterday** with 45,230 requests. This is 23% above your weekly average. The spike was primarily eth_call requests from 3 API keys.',
      data: [
        { label: '14:00 UTC', value: '45,230', change: 'Peak' },
        { label: '13:00 UTC', value: '38,450', change: '+18%' },
        { label: '15:00 UTC', value: '41,200', change: '+9%' },
        { label: '12:00 UTC', value: '32,100', change: '-29%' },
      ],
      chart: 'bar',
    };
  }
  
  if (lowerQuery.includes('method') || lowerQuery.includes('cu')) {
    return {
      query,
      answer: 'Your top CU-consuming methods this week: **eth_call** (42%, 2.3M CUs), **eth_getBalance** (23%, 1.1M CUs), **eth_sendRawTransaction** (18%, 980K CUs). Consider caching eth_call responses.',
      data: [
        { label: 'eth_call', value: '2.3M CUs', change: '42%' },
        { label: 'eth_getBalance', value: '1.1M CUs', change: '23%' },
        { label: 'eth_sendRawTransaction', value: '980K CUs', change: '18%' },
        { label: 'eth_getLogs', value: '340K CUs', change: '8%' },
      ],
      chart: 'pie',
    };
  }
  
  if (lowerQuery.includes('compare') || lowerQuery.includes('last week')) {
    return {
      query,
      answer: 'Compared to last week: Total requests **+18%** (↑ 45K), Average latency **-12%** (↓ 45ms), Error rate **+2.1%** (↑ to 2.3%), CU consumption **+23%** (↑ 890K CUs).',
      data: [
        { label: 'Total Requests', value: '298K', change: '+18%' },
        { label: 'Avg Latency', value: '328ms', change: '-12%' },
        { label: 'Error Rate', value: '2.3%', change: '+2.1%' },
        { label: 'CU Usage', value: '4.7M', change: '+23%' },
      ],
      chart: 'bar',
    };
  }
  
  return {
    query,
    answer: `Based on your query "${query}", here's what I found:\n\nYour node processed 1.2M requests in the last 24 hours with a 99.7% success rate. Average response time was 285ms. The most active period was 14:00-16:00 UTC.\n\nWould you like me to drill down into any specific metric or time period?`,
    data: [
      { label: 'Total Requests', value: '1.2M', change: '+5%' },
      { label: 'Success Rate', value: '99.7%', change: '+0.2%' },
      { label: 'Avg Latency', value: '285ms', change: '-8%' },
      { label: 'Active Peers', value: '23', change: '+2' },
    ],
    chart: 'bar',
  };
};

function formatTimeAgo(date: Date): string {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

const getInsightIcon = (type: string) => {
  switch (type) {
    case 'anomaly': return <AlertTriangle className="w-4 h-4" />;
    case 'recommendation': return <Lightbulb className="w-4 h-4" />;
    case 'trend': return <TrendingUp className="w-4 h-4" />;
    case 'optimization': return <Zap className="w-4 h-4" />;
    default: return <Sparkles className="w-4 h-4" />;
  }
};

const getImpactColor = (impact: string) => {
  switch (impact) {
    case 'high': return 'text-[var(--critical)] bg-[var(--critical)]/10';
    case 'medium': return 'text-[var(--warning)] bg-[var(--warning)]/10';
    case 'low': return 'text-[var(--success)] bg-[var(--success)]/10';
    default: return 'text-[var(--text-secondary)] bg-[var(--bg-hover)]';
  }
};

const getTypeColor = (type: string) => {
  switch (type) {
    case 'anomaly': return 'var(--critical)';
    case 'recommendation': return 'var(--accent-blue)';
    case 'trend': return 'var(--purple)';
    case 'optimization': return 'var(--success)';
    default: return 'var(--text-secondary)';
  }
};

export default function AIInsights() {
  const [insights] = useState<Insight[]>(mockInsights);
  const [query, setQuery] = useState('');
  const [queryResult, setQueryResult] = useState<QueryResult | null>(null);
  const [isQuerying, setIsQuerying] = useState(false);
  const [showExamples, setShowExamples] = useState(true);

  const handleQuery = async (searchQuery: string = query) => {
    if (!searchQuery.trim()) return;
    setIsQuerying(true);
    setShowExamples(false);
    
    try {
      const result = await mockNLQueryResponse(searchQuery);
      setQueryResult(result);
    } catch (error) {
      console.error('Query failed:', error);
    } finally {
      setIsQuerying(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleQuery();
    }
  };

  const clearQuery = () => {
    setQuery('');
    setQueryResult(null);
    setShowExamples(true);
  };

  return (
    <div className="space-y-6">
      {/* Natural Language Query Interface */}
      <div className="card-xdc">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--accent-blue)] to-[var(--purple)] flex items-center justify-center">
            <Brain className="w-5 h-5 text-white" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">AI Insights</h3>
            <p className="text-xs text-[var(--text-tertiary)]">Natural language queries about your RPC usage</p>
          </div>
        </div>

        {/* Search Input */}
        <div className="relative mb-6">
          <div className="absolute left-4 top-1/2 -translate-y-1/2">
            <Search className="w-5 h-5 text-[var(--text-muted)]" />
          </div>
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask anything about your RPC usage..."
            className="w-full pl-12 pr-12 py-4 bg-[var(--bg-body)] border border-[var(--border-subtle)] rounded-xl text-sm text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:border-[var(--accent-blue)]"
          />
          {query && (
            <button
              onClick={clearQuery}
              className="absolute right-4 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-[var(--bg-hover)] text-[var(--text-muted)]"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Example Queries */}
        {showExamples && (
          <div className="mb-6">
            <p className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider mb-3">Try asking</p>
            <div className="flex flex-wrap gap-2">
              {exampleQueries.map((q, i) => (
                <button
                  key={i}
                  onClick={() => {
                    setQuery(q);
                    handleQuery(q);
                  }}
                  className="px-3 py-1.5 rounded-lg bg-[var(--bg-body)] border border-[var(--border-subtle)] hover:border-[var(--accent-blue)]/30 hover:bg-[var(--bg-hover)] transition-all text-xs text-[var(--text-secondary)]"
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Query Result */}
        {isQuerying ? (
          <div className="flex items-center justify-center py-12">
            <div className="flex items-center gap-3">
              <Loader2 className="w-5 h-5 text-[var(--accent-blue)] animate-spin" />
              <span className="text-sm text-[var(--text-secondary)]">Analyzing your data...</span>
            </div>
          </div>
        ) : queryResult ? (
          <div className="p-4 rounded-xl bg-[var(--bg-body)] border border-[var(--border-subtle)]">
            <div className="flex items-center gap-2 mb-3">
              <Sparkles className="w-4 h-4 text-[var(--accent-blue)]" />
              <span className="text-xs text-[var(--accent-blue)] font-medium">AI Response</span>
            </div>
            
            <p className="text-sm text-[var(--text-secondary)] mb-4 leading-relaxed">
              {queryResult.answer.split('**').map((part, i) =>
                i % 2 === 1 ? (
                  <span key={i} className="font-semibold text-[var(--text-primary)]">{part}</span>
                ) : (
                  part
                )
              )}
            </p>

            {queryResult.data && (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {queryResult.data.map((item, i) => (
                  <div key={i} className="p-3 rounded-lg bg-[var(--bg-card)]">
                    <p className="text-[10px] text-[var(--text-muted)] mb-1">{item.label}</p>
                    <p className="text-sm font-semibold text-[var(--text-primary)]">{item.value}</p>
                    {item.change && (
                      <span className={`text-[10px] ${
                        item.change.startsWith('+') || item.change === 'Peak'
                          ? 'text-[var(--warning)]'
                          : item.change.startsWith('-')
                          ? 'text-[var(--success)]'
                          : 'text-[var(--accent-blue)]'
                      }`}>
                        {item.change}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : null}
      </div>

      {/* AI-Generated Insights */}
      <div className="card-xdc">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[var(--warning)]/10 flex items-center justify-center">
              <Lightbulb className="w-5 h-5 text-[var(--warning)]" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-[var(--text-primary)]">AI-Generated Insights</h3>
              <p className="text-xs text-[var(--text-tertiary)]">Anomalies detected and recommendations</p>
            </div>
          </div>
          
          <span className="px-2 py-1 rounded-full bg-[var(--accent-blue)]/10 text-[var(--accent-blue)] text-[10px] font-medium">
            {insights.length} New
          </span>
        </div>

        <div className="space-y-3">
          {insights.map((insight) => (
            <div
              key={insight.id}
              className="flex items-start gap-3 p-4 rounded-xl bg-[var(--bg-body)] border border-[var(--border-subtle)] hover:border-[var(--border-blue-glow)] transition-colors group cursor-pointer"
            >
              <div
                className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                style={{ backgroundColor: `${getTypeColor(insight.type)}20`, color: getTypeColor(insight.type) }}
              >
                {getInsightIcon(insight.type)}
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h4 className="text-sm font-medium text-[var(--text-primary)] mb-1">{insight.title}</h4>
                    <p className="text-xs text-[var(--text-secondary)] mb-2">{insight.description}</p>
                  </div>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-medium uppercase flex-shrink-0 ${getImpactColor(insight.impact)}`}>
                    {insight.impact}
                  </span>
                </div>

                <div className="flex items-center gap-4">
                  {insight.metric && (
                    <div className="flex items-center gap-2">
                      <BarChart3 className="w-3 h-3 text-[var(--text-muted)]" />
                      <span className="text-[10px] text-[var(--text-muted)]">{insight.metric}:</span>
                      <span className="text-[10px] font-medium text-[var(--text-primary)]">{insight.value}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-1 text-[10px] text-[var(--text-muted)]">
                    <Clock className="w-3 h-3" />
                    {formatTimeAgo(insight.timestamp)}
                  </div>
                  
                  <button className="ml-auto flex items-center gap-1 text-[10px] text-[var(--accent-blue)] opacity-0 group-hover:opacity-100 transition-opacity">
                    View Details
                    <ChevronRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
