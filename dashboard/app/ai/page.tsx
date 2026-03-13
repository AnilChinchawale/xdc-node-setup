'use client';

import DashboardLayout from '@/components/DashboardLayout';
import AIAssistant from '@/components/ai-assistant';
import AIInsights from '@/components/ai-insights';
import PredictiveAnalytics from '@/components/predictive-analytics';
import SmartAlerts from '@/components/smart-alerts';
import { Sparkles, Brain, TrendingUp, Bell } from 'lucide-react';

export default function AIPage() {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Page Header */}
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--accent-blue)] via-[var(--purple)] to-[var(--pink)] flex items-center justify-center shadow-lg shadow-[var(--accent-blue)]/20">
              <Brain className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-[var(--text-primary)]">AI Command Center</h1>
              <p className="text-sm text-[var(--text-secondary)]">Intelligent insights, predictions, and automation for your XDC node</p>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[var(--success)]/10 text-[var(--success)] text-xs font-medium">
              <span className="w-1.5 h-1.5 rounded-full bg-[var(--success)] animate-pulse" />
              AI Systems Online
            </span>
          </div>
        </div>

        {/* Feature Overview Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card-xdc p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[var(--accent-blue)]/10 flex items-center justify-center">
              <Sparkles className="w-5 h-5 text-[var(--accent-blue)]" />
            </div>
            <div>
              <p className="text-lg font-semibold text-[var(--text-primary)]">AI Assistant</p>
              <p className="text-xs text-[var(--text-tertiary)]">Ask about configuration & debugging</p>
            </div>
          </div>

          <div className="card-xdc p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[var(--purple)]/10 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-[var(--purple)]" />
            </div>
            <div>
              <p className="text-lg font-semibold text-[var(--text-primary)]">Predictions</p>
              <p className="text-xs text-[var(--text-tertiary)]">7-day forecasts & capacity planning</p>
            </div>
          </div>

          <div className="card-xdc p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[var(--warning)]/10 flex items-center justify-center">
              <Bell className="w-5 h-5 text-[var(--warning)]" />
            </div>
            <div>
              <p className="text-lg font-semibold text-[var(--text-primary)]">Smart Alerts</p>
              <p className="text-xs text-[var(--text-tertiary)]">AI-detected anomalies & fixes</p>
            </div>
          </div>

          <div className="card-xdc p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[var(--success)]/10 flex items-center justify-center">
              <Brain className="w-5 h-5 text-[var(--success)]" />
            </div>
            <div>
              <p className="text-lg font-semibold text-[var(--text-primary)]">Natural Language</p>
              <p className="text-xs text-[var(--text-tertiary)]">Query data with plain English</p>
            </div>
          </div>
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
          {/* Left Column - AI Assistant & Insights */}
          <div className="xl:col-span-1 space-y-6">
            <AIAssistant />
          </div>

          {/* Right Column - Predictive Analytics & Smart Alerts */}
          <div className="xl:col-span-2 space-y-6">
            <AIInsights />
            <PredictiveAnalytics />
            <SmartAlerts />
          </div>
        </div>

        {/* Footer */}
        <div className="border-t border-[var(--border-subtle)] pt-6 mt-8">
          <div className="text-center text-sm text-[var(--text-tertiary)]">
            <p>XDC SkyOne AI Command Center &#183; Powered by Advanced Machine Learning</p>
            <p className="mt-1 text-xs">
              AI predictions are estimates based on historical data and should not be used as guarantees.
            </p>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
