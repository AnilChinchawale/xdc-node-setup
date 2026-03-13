'use client';

import { useState, useRef, useEffect } from 'react';
import {
  Bot,
  Send,
  Sparkles,
  Loader2,
  Copy,
  Check,
  Terminal,
  Settings,
  Wrench,
  FileCode,
  AlertCircle,
  Server,
  Cpu,
  Database,
} from 'lucide-react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  codeBlocks?: CodeBlock[];
  suggestions?: string[];
}

interface CodeBlock {
  language: string;
  code: string;
  filename?: string;
}

const mockAIResponses: Record<string, { content: string; codeBlocks?: CodeBlock[]; suggestions?: string[] }> = {
  'sync': {
    content: 'Your node is currently syncing. Based on your logs, you\'re at block 45,230,123 of 85,430,000 (53%). The estimated time to full sync is ~4 hours at current speed.',
    suggestions: ['Check sync status', 'View sync logs', 'Optimize sync settings'],
  },
  'config': {
    content: 'Here\'s your optimized XDC node configuration for better performance:',
    codeBlocks: [{
      language: 'toml',
      filename: 'config.toml',
      code: `[Eth]
NetworkId = 50
SyncMode = "snap"

[Node]
HTTPHost = "0.0.0.0"
HTTPPort = 8545
HTTPVirtualHosts = ["*"]
HTTPCors = ["*"]
HTTPModules = ["eth", "net", "web3", "txpool", "parlia"]

[Node.P2P]
MaxPeers = 50
`,
    }],
    suggestions: ['Apply this config', 'View full config', 'Backup current config'],
  },
  'peers': {
    content: 'You currently have 23 active peers. The recommended minimum is 25 for optimal performance. Here\'s how to add more bootstrap nodes:',
    codeBlocks: [{
      language: 'bash',
      code: `# Add to your startup flags
--bootnodes "enode://<node_id>@<ip>:30303,enode://<node_id2>@<ip2>:30303"

# Or add to config.toml
[Node.P2P]
BootstrapNodes = [
  "enode://...",
  "enode://..."
]`,
    }],
    suggestions: ['Find more peers', 'Check peer quality', 'Configure firewall'],
  },
  'default': {
    content: 'I can help you with:\n\n• **Configuration** - Optimize your node settings\n• **Troubleshooting** - Diagnose sync/connection issues\n• **Performance** - Improve block processing speed\n• **Monitoring** - Set up alerts and metrics\n• **Security** - Best practices for node security\n\nWhat would you like assistance with?',
    suggestions: ['Check sync status', 'Optimize performance', 'View logs', 'Security audit'],
  },
};

const quickActions = [
  { label: 'Check sync status', icon: <Server className="w-4 h-4" />, query: 'What is my current sync status?' },
  { label: 'Optimize config', icon: <Settings className="w-4 h-4" />, query: 'How can I optimize my node configuration?' },
  { label: 'Debug peers', icon: <Database className="w-4 h-4" />, query: 'Why do I have so few peers?' },
  { label: 'Performance tips', icon: <Cpu className="w-4 h-4" />, query: 'How can I improve node performance?' },
];

const mockAIResponse = async (query: string): Promise<{ content: string; codeBlocks?: CodeBlock[]; suggestions?: string[] }> => {
  await new Promise((resolve) => setTimeout(resolve, 1200));
  
  const lowerQuery = query.toLowerCase();
  
  if (lowerQuery.includes('sync') || lowerQuery.includes('block')) {
    return mockAIResponses['sync'];
  }
  if (lowerQuery.includes('config') || lowerQuery.includes('setting')) {
    return mockAIResponses['config'];
  }
  if (lowerQuery.includes('peer') || lowerQuery.includes('connect')) {
    return mockAIResponses['peers'];
  }
  
  return mockAIResponses['default'];
};

function CodeBlockComponent({ block }: { block: CodeBlock }) {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = () => {
    navigator.clipboard.writeText(block.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="mt-3 rounded-lg overflow-hidden border border-[var(--border-subtle)] bg-[var(--bg-body)]">
      <div className="flex items-center justify-between px-3 py-2 bg-[var(--bg-card)] border-b border-[var(--border-subtle)]">
        <div className="flex items-center gap-2">
          <FileCode className="w-4 h-4 text-[var(--text-muted)]" />
          <span className="text-xs font-medium text-[var(--text-secondary)]">{block.filename || block.language}</span>
        </div>
        <button
          onClick={copyToClipboard}
          className="flex items-center gap-1 px-2 py-1 rounded text-[10px] text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-hover)] transition-colors"
        >
          {copied ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
          {copied ? 'Copied' : 'Copy'}
        </button>
      </div>
      <pre className="p-3 overflow-x-auto text-xs font-mono text-[var(--text-secondary)]">
        <code>{block.code}</code>
      </pre>
    </div>
  );
}

export default function AIAssistant() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      role: 'assistant',
      content: 'Hello! I\'m your XDC Node AI Assistant. I can help you with configuration, troubleshooting, and optimization of your node. What can I help you with today?',
      timestamp: new Date(),
      suggestions: ['Check sync status', 'Optimize performance', 'View logs'],
    },
  ]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async (text: string = input) => {
    if (!text.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: text,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsTyping(true);

    try {
      const response = await mockAIResponse(text);
      
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.content,
        timestamp: new Date(),
        codeBlocks: response.codeBlocks,
        suggestions: response.suggestions,
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error('AI response error:', error);
    } finally {
      setIsTyping(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="card-xdc flex flex-col h-[600px]">
      {/* Header */}
      <div className="flex items-center gap-3 p-4 border-b border-[var(--border-subtle)]">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--accent-blue)] to-[var(--purple)] flex items-center justify-center">
          <Bot className="w-5 h-5 text-white" />
        </div>
        <div className="flex-1">
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">AI Assistant</h3>
          <p className="text-xs text-[var(--text-tertiary)]">Ask about configuration, debugging, optimization</p>
        </div>
        <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-[var(--success)]/10">
          <span className="w-1.5 h-1.5 rounded-full bg-[var(--success)] animate-pulse" />
          <span className="text-[10px] text-[var(--success)] font-medium">Online</span>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex gap-3 ${message.role === 'user' ? 'flex-row-reverse' : ''}`}
          >
            <div
              className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${
                message.role === 'user'
                  ? 'bg-[var(--accent-blue)]/10'
                  : 'bg-gradient-to-br from-[var(--accent-blue)] to-[var(--purple)]'
              }`}
            >
              {message.role === 'user' ? (
                <span className="text-xs font-medium text-[var(--accent-blue)]">You</span>
              ) : (
                <Sparkles className="w-4 h-4 text-white" />
              )}
            </div>
            <div className={`flex-1 max-w-[80%] ${message.role === 'user' ? 'text-right' : ''}`}>
              <div
                className={`inline-block p-3 rounded-2xl text-sm leading-relaxed ${
                  message.role === 'user'
                    ? 'bg-[var(--accent-blue)] text-white rounded-br-md'
                    : 'bg-[var(--bg-body)] text-[var(--text-secondary)] rounded-bl-md border border-[var(--border-subtle)]'
                }`}
              >
                {message.content.split('**').map((part, i) =>
                  i % 2 === 1 ? (
                    <span key={i} className="font-semibold text-[var(--text-primary)]">{part}</span>
                  ) : (
                    part
                  )
                )}
              </div>
              
              {message.codeBlocks?.map((block, i) => (
                <CodeBlockComponent key={i} block={block} />
              ))}

              {message.suggestions && message.role === 'assistant' && (
                <div className="flex flex-wrap gap-2 mt-3">
                  {message.suggestions.map((suggestion, i) => (
                    <button
                      key={i}
                      onClick={() => handleSend(suggestion)}
                      className="px-3 py-1.5 rounded-full bg-[var(--bg-card)] border border-[var(--border-subtle)] hover:border-[var(--accent-blue)]/30 hover:bg-[var(--bg-hover)] transition-all text-xs text-[var(--text-secondary)]"
                    >
                      {suggestion}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
        
        {isTyping && (
          <div className="flex gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[var(--accent-blue)] to-[var(--purple)] flex items-center justify-center">
              <Sparkles className="w-4 h-4 text-white" />
            </div>
            <div className="flex items-center gap-2 p-3 rounded-2xl bg-[var(--bg-body)] border border-[var(--border-subtle)] rounded-bl-md">
              <Loader2 className="w-4 h-4 text-[var(--accent-blue)] animate-spin" />
              <span className="text-xs text-[var(--text-secondary)]">Thinking...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Quick Actions */}
      {messages.length < 3 && (
        <div className="px-4 py-2 border-t border-[var(--border-subtle)]">
          <p className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider mb-2">Quick Actions</p>
          <div className="flex flex-wrap gap-2">
            {quickActions.map((action, i) => (
              <button
                key={i}
                onClick={() => handleSend(action.query)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[var(--bg-body)] border border-[var(--border-subtle)] hover:border-[var(--accent-blue)]/30 hover:bg-[var(--bg-hover)] transition-all text-xs text-[var(--text-secondary)]"
              >
                {action.icon}
                {action.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Input */}
      <div className="p-4 border-t border-[var(--border-subtle)]">
        <div className="flex items-center gap-2 p-2 rounded-xl bg-[var(--bg-body)] border border-[var(--border-subtle)] focus-within:border-[var(--accent-blue)]/50 transition-colors">
          <Terminal className="w-5 h-5 text-[var(--text-muted)] ml-2" />
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask about your node..."
            className="flex-1 bg-transparent border-none outline-none text-sm text-[var(--text-primary)] placeholder:text-[var(--text-muted)]"
          />
          <button
            onClick={() => handleSend()}
            disabled={!input.trim() || isTyping}
            className="p-2 rounded-lg bg-[var(--accent-blue)] text-white hover:bg-[var(--accent-blue)]/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
