'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { Filter, Check } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';

type NetworkOption = 'all' | 'mainnet' | 'apothem' | 'devnet';

const networkOptions: { value: NetworkOption; label: string }[] = [
  { value: 'all', label: 'All Networks' },
  { value: 'mainnet', label: 'Mainnet' },
  { value: 'apothem', label: 'Apothem' },
  { value: 'devnet', label: 'Devnet' },
];

interface NetworkFilterProps {
  className?: string;
}

export default function NetworkFilter({ className = '' }: NetworkFilterProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const currentNetwork = (searchParams.get('network') as NetworkOption) || 'all';

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSelect = (network: NetworkOption) => {
    const params = new URLSearchParams(searchParams.toString());
    if (network === 'all') {
      params.delete('network');
    } else {
      params.set('network', network);
    }
    router.push(`?${params.toString()}`, { scroll: false });
    setIsOpen(false);
  };

  const currentLabel = networkOptions.find(o => o.value === currentNetwork)?.label || 'All Networks';

  return (
    <div ref={dropdownRef} className={`relative ${className}`}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 px-3 py-2 rounded-lg bg-[var(--bg-card)] border border-[var(--border-subtle)] text-sm text-[var(--text-primary)] hover:border-[var(--border-blue-glow)] transition-colors"
      >
        <Filter className="w-4 h-4 text-[var(--accent-blue)]" />
        <span className="hidden sm:inline">{currentLabel}</span>
        <span className="sm:hidden">Filter</span>
        <svg
          className={`w-4 h-4 text-[var(--text-tertiary)] transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute right-0 top-full mt-2 w-48 bg-[var(--bg-card)] border border-[var(--border-subtle)] rounded-xl shadow-lg z-50 overflow-hidden">
          {networkOptions.map((option) => (
            <button
              key={option.value}
              onClick={() => handleSelect(option.value)}
              className={`w-full flex items-center justify-between px-4 py-2.5 text-sm transition-colors ${
                currentNetwork === option.value
                  ? 'bg-[var(--bg-active)] text-[var(--accent-blue)]'
                  : 'text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]'
              }`}
            >
              <span>{option.label}</span>
              {currentNetwork === option.value && (
                <Check className="w-4 h-4" />
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
