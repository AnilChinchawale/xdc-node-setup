'use client';

interface ApyGaugeProps {
  currentApy: number;
  expectedApy: number;
}

export default function ApyGauge({ currentApy, expectedApy }: ApyGaugeProps) {
  // Calculate percentage for the gauge (0-10% range)
  const minApy = 0;
  const maxApy = 10;
  const percentage = Math.min(Math.max(((currentApy - minApy) / (maxApy - minApy)) * 100, 0), 100);
  const expectedPercentage = Math.min(Math.max(((expectedApy - minApy) / (maxApy - minApy)) * 100, 0), 100);
  
  const difference = currentApy - expectedApy;
  const isPositive = difference >= 0;

  return (
    <div className="flex flex-col items-center">
      {/* Gauge Container */}
      <div className="relative w-48 h-24 overflow-hidden mb-4">
        {/* Background arc */}
        <div 
          className="absolute w-48 h-48 rounded-full border-8 border-xdc-border"
          style={{ clipPath: 'polygon(0 0, 100% 0, 100% 50%, 0 50%)' }}
        />
        
        {/* Expected APY marker */}
        <div
          className="absolute w-48 h-48 rounded-full border-8 border-dashed border-gray-600"
          style={{ 
            clipPath: `polygon(0 0, ${expectedPercentage}% 0, ${expectedPercentage}% 50%, 0 50%)`,
            transform: 'rotate(-180deg)',
            transformOrigin: 'center'
          }}
        />
        
        {/* Current APY fill */}
        <div
          className={`absolute w-48 h-48 rounded-full border-8 ${
            isPositive ? 'border-green-500' : 'border-yellow-500'
          }`}
          style={{ 
            clipPath: `polygon(0 0, ${percentage}% 0, ${percentage}% 50%, 0 50%)`,
            transform: 'rotate(-180deg)',
            transformOrigin: 'center'
          }}
        />
        
        {/* Center value */}
        <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 text-center">
          <span className="text-3xl font-bold text-white">{currentApy.toFixed(2)}%</span>
        </div>
      </div>

      {/* Legend */}
      <div className="flex gap-6 text-sm">
        <div className="flex items-center gap-2">
          <div className={`w-3 h-3 rounded-full ${isPositive ? 'bg-green-500' : 'bg-yellow-500'}`} />
          <span className="text-gray-300">Actual: {currentApy.toFixed(2)}%</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full border border-dashed border-gray-500" />
          <span className="text-gray-300">Expected: {expectedApy.toFixed(1)}%</span>
        </div>
      </div>

      {/* Difference indicator */}
      <div className={`mt-4 text-sm ${isPositive ? 'text-green-400' : 'text-yellow-400'}`}>
        {isPositive ? '↑' : '↓'} {Math.abs(difference).toFixed(2)}% vs expected
      </div>

      {/* Scale */}
      <div className="w-full flex justify-between text-xs text-gray-500 mt-4">
        <span>0%</span>
        <span>5%</span>
        <span>10%</span>
      </div>
    </div>
  );
}
