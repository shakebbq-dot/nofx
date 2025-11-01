import { useEffect, useState, useRef } from 'react';
import useSWR from 'swr';

interface Futures24hTicker {
  symbol: string;
  priceChange: string;
  priceChangePercent: string;
  weightedAvgPrice: string;
  lastPrice: string;
  lastQty: string;
  openPrice: string;
  highPrice: string;
  lowPrice: string;
  volume: string;
  quoteVolume: string;
  openTime: number;
  closeTime: number;
  firstId: number;
  lastId: number;
  count: number;
}

interface FuturesPrice {
  symbol: string;
  price: string;
  time: number;
}

// 币安期货API基础URL
const BINANCE_FUTURES_API = 'https://fapi.binance.com/fapi/v1';

// 获取24小时行情数据
const fetcher24hTicker = async (symbol: string): Promise<Futures24hTicker> => {
  const response = await fetch(`${BINANCE_FUTURES_API}/ticker/24hr?symbol=${symbol}`);
  if (!response.ok) {
    throw new Error('获取24小时行情数据失败');
  }
  return response.json();
};

// 获取当前价格
const fetcherPrice = async (symbol: string): Promise<FuturesPrice> => {
  const response = await fetch(`${BINANCE_FUTURES_API}/ticker/price?symbol=${symbol}`);
  if (!response.ok) {
    throw new Error('获取当前价格失败');
  }
  return response.json();
};

export function BinanceFuturesMonitor() {
  const symbol = 'BTCUSDT';
  const [priceFlash, setPriceFlash] = useState<'up' | 'down' | null>(null);
  const prevPriceRef = useRef<number | null>(null);

  // 获取24小时行情数据（每2秒刷新）
  const { data: ticker24h, error: error24h } = useSWR<Futures24hTicker>(
    `futures-24h-${symbol}`,
    () => fetcher24hTicker(symbol),
    {
      refreshInterval: 2000,
      revalidateOnFocus: true,
    }
  );

  // 获取当前价格（每1秒刷新）
  const { data: priceData, error: priceError } = useSWR<FuturesPrice>(
    `futures-price-${symbol}`,
    () => fetcherPrice(symbol),
    {
      refreshInterval: 1000,
      revalidateOnFocus: true,
    }
  );

  // 价格变化动画效果
  useEffect(() => {
    if (!priceData) return;
    
    const currentPrice = parseFloat(priceData.price);
    
    // 只有在有上一次价格时才进行比较
    if (prevPriceRef.current !== null && prevPriceRef.current !== currentPrice) {
      if (currentPrice > prevPriceRef.current) {
        setPriceFlash('up');
        setTimeout(() => setPriceFlash(null), 500);
      } else if (currentPrice < prevPriceRef.current) {
        setPriceFlash('down');
        setTimeout(() => setPriceFlash(null), 500);
      }
    }
    
    // 更新上一次的价格
    prevPriceRef.current = currentPrice;
  }, [priceData]);

  if (error24h || priceError) {
    return (
      <div className="binance-card p-6">
        <div className="text-center text-red-500">
          <div className="text-lg font-bold mb-2">⚠️ 数据获取失败</div>
          <div className="text-sm text-gray-400">
            {error24h?.message || priceError?.message || '未知错误'}
          </div>
        </div>
      </div>
    );
  }

  if (!ticker24h || !priceData) {
    return (
      <div className="binance-card p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-800 rounded w-1/3"></div>
          <div className="h-6 bg-gray-800 rounded w-1/4"></div>
          <div className="grid grid-cols-2 gap-4 mt-4">
            <div className="h-16 bg-gray-800 rounded"></div>
            <div className="h-16 bg-gray-800 rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  const currentPrice = parseFloat(priceData.price);
  const priceChange = parseFloat(ticker24h.priceChange);
  const priceChangePercent = parseFloat(ticker24h.priceChangePercent);
  const volume = parseFloat(ticker24h.volume);
  const quoteVolume = parseFloat(ticker24h.quoteVolume);
  const high24h = parseFloat(ticker24h.highPrice);
  const low24h = parseFloat(ticker24h.lowPrice);
  const open24h = parseFloat(ticker24h.openPrice);

  const isPositive = priceChange >= 0;

  return (
    <div className="binance-card p-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg flex items-center justify-center text-xl font-bold" 
               style={{ background: 'linear-gradient(135deg, #F0B90B 0%, #FCD535 100%)', color: '#0B0E11' }}>
            ₿
          </div>
          <div>
            <h2 className="text-xl font-bold" style={{ color: '#EAECEF' }}>BTC/USDT 永续合约</h2>
            <p className="text-xs" style={{ color: '#848E9C' }}>Binance Futures</p>
          </div>
        </div>
        <div className="text-right">
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>实时价格</div>
          <div className="text-sm font-semibold" style={{ color: '#848E9C' }}>
            {new Date().toLocaleTimeString('zh-CN', { hour12: false })}
          </div>
        </div>
      </div>

      {/* Current Price */}
      <div className="mb-6">
        <div className={`text-4xl font-bold mono transition-all duration-300 ${
          priceFlash === 'up' ? 'animate-pulse' : priceFlash === 'down' ? 'animate-pulse' : ''
        }`}
        style={{ 
          color: isPositive ? '#0ECB81' : '#F6465D',
          textShadow: priceFlash ? `0 0 10px ${isPositive ? 'rgba(14, 203, 129, 0.5)' : 'rgba(246, 70, 93, 0.5)'}` : 'none'
        }}>
          ${currentPrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
        <div className="flex items-center gap-3 mt-2">
          <span className={`text-lg font-semibold mono ${
            isPositive ? 'text-green-500' : 'text-red-500'
          }`}>
            {isPositive ? '+' : ''}{priceChange.toFixed(2)} ({isPositive ? '+' : ''}{priceChangePercent.toFixed(2)}%)
          </span>
          <span className="text-xs px-2 py-1 rounded" style={{ 
            background: isPositive ? 'rgba(14, 203, 129, 0.1)' : 'rgba(246, 70, 93, 0.1)',
            color: isPositive ? '#0ECB81' : '#F6465D',
            border: `1px solid ${isPositive ? 'rgba(14, 203, 129, 0.2)' : 'rgba(246, 70, 93, 0.2)'}`
          }}>
            24h
          </span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-4">
        {/* 24h High */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 最高</div>
          <div className="text-lg font-bold mono" style={{ color: '#0ECB81' }}>
            ${high24h.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
        </div>

        {/* 24h Low */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 最低</div>
          <div className="text-lg font-bold mono" style={{ color: '#F6465D' }}>
            ${low24h.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
        </div>

        {/* 24h Volume */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 成交量 (BTC)</div>
          <div className="text-lg font-bold mono" style={{ color: '#EAECEF' }}>
            {volume.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
        </div>

        {/* 24h Quote Volume */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 成交额 (USDT)</div>
          <div className="text-lg font-bold mono" style={{ color: '#EAECEF' }}>
            ${quoteVolume.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </div>
        </div>

        {/* Open Price */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 开盘价</div>
          <div className="text-lg font-bold mono" style={{ color: '#EAECEF' }}>
            ${open24h.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
        </div>

        {/* Weighted Avg Price */}
        <div className="p-4 rounded" style={{ background: '#0B0E11', border: '1px solid #2B3139' }}>
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>24h 加权均价</div>
          <div className="text-lg font-bold mono" style={{ color: '#EAECEF' }}>
            ${parseFloat(ticker24h.weightedAvgPrice).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
        </div>
      </div>

      {/* Price Change Indicator */}
      <div className="mt-4 pt-4" style={{ borderTop: '1px solid #2B3139' }}>
        <div className="flex items-center justify-between">
          <div className="text-xs" style={{ color: '#848E9C' }}>
            当前价格相对24h开盘价
          </div>
          <div className={`text-sm font-bold mono ${
            currentPrice >= open24h ? 'text-green-500' : 'text-red-500'
          }`}>
            {currentPrice >= open24h ? '↑' : '↓'} {Math.abs(((currentPrice - open24h) / open24h) * 100).toFixed(2)}%
          </div>
        </div>
        {/* Progress Bar */}
        <div className="mt-2 h-1 rounded-full overflow-hidden" style={{ background: '#2B3139' }}>
          <div 
            className="h-full transition-all duration-300"
            style={{ 
              width: `${Math.min(100, Math.max(0, ((currentPrice - low24h) / (high24h - low24h)) * 100))}%`,
              background: isPositive ? 'linear-gradient(90deg, #0ECB81 0%, #0ECB81 100%)' : 'linear-gradient(90deg, #F6465D 0%, #F6465D 100%)'
            }}
          />
        </div>
        <div className="flex justify-between text-xs mt-1" style={{ color: '#5E6673' }}>
          <span>{low24h.toFixed(2)}</span>
          <span>{high24h.toFixed(2)}</span>
        </div>
      </div>
    </div>
  );
}

