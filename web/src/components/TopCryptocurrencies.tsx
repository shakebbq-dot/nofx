import useSWR from 'swr';

interface CryptoTicker {
  symbol: string;
  priceChange: string;
  priceChangePercent: string;
  weightedAvgPrice: string;
  lastPrice: string;
  openPrice: string;
  highPrice: string;
  lowPrice: string;
  volume: string;
  quoteVolume: string;
  openTime: number;
  closeTime: number;
  count: number;
  // 计算字段
  turnoverRate?: number; // 换手率
  marketWeight?: number; // 市场权重
}

// 币安期货API基础URL
const BINANCE_FUTURES_API = 'https://fapi.binance.com/fapi/v1';

// 前20主流加密货币交易对（按市值排序）
const TOP_CRYPTOS = [
  'BTCUSDT',  'ETHUSDT',  'BNBUSDT',  'SOLUSDT',  'XRPUSDT',
  'DOGEUSDT', 'ADAUSDT',  'AVAXUSDT', 'SHIBUSDT', 'DOTUSDT',
  'MATICUSDT','LINKUSDT', 'TRXUSDT',  'BCHUSDT',  'UNIUSDT',
  'ATOMUSDT', 'ETCUSDT',  'LTCUSDT',  'NEARUSDT', 'APTUSDT'
];

// 获取所有交易对的24小时数据
const fetcherAllTickers = async (): Promise<CryptoTicker[]> => {
  const response = await fetch(`${BINANCE_FUTURES_API}/ticker/24hr`);
  if (!response.ok) {
    throw new Error('获取市场数据失败');
  }
  const allTickers: CryptoTicker[] = await response.json();
  
  // 过滤出我们关注的前20个币种，并按交易量排序
  const filtered = allTickers
    .filter(ticker => TOP_CRYPTOS.includes(ticker.symbol))
    .sort((a, b) => parseFloat(b.quoteVolume) - parseFloat(a.quoteVolume))
    .slice(0, 20);
  
  // 计算总交易量（用于计算权重）
  const totalVolume = filtered.reduce((sum, ticker) => sum + parseFloat(ticker.quoteVolume), 0);
  
  // 计算每个币种的权重和换手率
  return filtered.map(ticker => {
    const quoteVol = parseFloat(ticker.quoteVolume);
    const volume = parseFloat(ticker.volume);
    const price = parseFloat(ticker.lastPrice);
    const weightedPrice = parseFloat(ticker.weightedAvgPrice);
    
    // 计算市场权重（基于交易额占比）
    const marketWeight = totalVolume > 0 ? (quoteVol / totalVolume) * 100 : 0;
    
    // 计算换手率（相对活跃度指标）
    // 使用成交额与加权平均价的比值来估算活跃度
    // 换手率 = (成交额 / 加权均价) / 成交量 * 100
    // 这是一个相对指标，用于比较不同币种的交易活跃度
    let turnoverRate = 0;
    if (weightedPrice > 0 && volume > 0) {
      // 使用加权均价和成交量的关系来计算相对换手率
      // 公式: (成交额 / (加权均价 * 成交量)) * 100
      // 这个值表示相对于平均价格的交易活跃程度
      turnoverRate = (quoteVol / (weightedPrice * volume)) * 100;
      
      // 如果计算结果不合理，使用简化版本：成交额/成交量比值
      if (!isFinite(turnoverRate) || turnoverRate < 0 || turnoverRate > 1000) {
        turnoverRate = price > 0 ? (quoteVol / (price * volume)) * 100 : 0;
      }
    }
    
    return {
      ...ticker,
      marketWeight: isFinite(marketWeight) ? marketWeight : 0,
      turnoverRate: isFinite(turnoverRate) && turnoverRate >= 0 ? turnoverRate : 0
    };
  });
};

export function TopCryptocurrencies() {
  const { data: cryptos, error } = useSWR<CryptoTicker[]>(
    'top-cryptocurrencies',
    fetcherAllTickers,
    {
      refreshInterval: 3000, // 每3秒刷新
      revalidateOnFocus: true,
    }
  );

  if (error) {
    return (
      <div className="binance-card p-6">
        <div className="text-center text-red-500">
          <div className="text-lg font-bold mb-2">⚠️ 数据获取失败</div>
          <div className="text-sm text-gray-400">{error.message}</div>
        </div>
      </div>
    );
  }

  if (!cryptos || cryptos.length === 0) {
    return (
      <div className="binance-card p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-800 rounded w-1/3"></div>
          <div className="space-y-2">
            {[...Array(10)].map((_, i) => (
              <div key={i} className="h-16 bg-gray-800 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // 获取币种名称（去掉USDT后缀）
  const getCoinName = (symbol: string) => {
    return symbol.replace('USDT', '');
  };

  return (
    <div className="binance-card p-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg flex items-center justify-center text-xl font-bold" 
               style={{ background: 'linear-gradient(135deg, #0ECB81 0%, #F0B90B 100%)', color: '#0B0E11' }}>
            💰
          </div>
          <div>
            <h2 className="text-xl font-bold" style={{ color: '#EAECEF' }}>Top 20 加密货币</h2>
            <p className="text-xs" style={{ color: '#848E9C' }}>实时价格、交易量与市场指标</p>
          </div>
        </div>
        <div className="text-right">
          <div className="text-xs mb-1" style={{ color: '#848E9C' }}>数据更新</div>
          <div className="text-sm font-semibold" style={{ color: '#848E9C' }}>
            {new Date().toLocaleTimeString('zh-CN', { hour12: false })}
          </div>
        </div>
      </div>

      {/* Table Header */}
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="text-xs font-semibold" style={{ color: '#848E9C', borderBottom: '1px solid #2B3139' }}>
              <th className="text-left py-3 px-2">排名</th>
              <th className="text-left py-3 px-2">币种</th>
              <th className="text-right py-3 px-2">价格 (USDT)</th>
              <th className="text-right py-3 px-2">24h 涨跌</th>
              <th className="text-right py-3 px-2">24h 最高</th>
              <th className="text-right py-3 px-2">24h 最低</th>
              <th className="text-right py-3 px-2">24h 成交量</th>
              <th className="text-right py-3 px-2">24h 成交额</th>
              <th className="text-right py-3 px-2">市场权重</th>
              <th className="text-right py-3 px-2">换手率</th>
            </tr>
          </thead>
          <tbody>
            {cryptos.map((crypto, index) => {
              const price = parseFloat(crypto.lastPrice);
              const priceChange = parseFloat(crypto.priceChange);
              const priceChangePercent = parseFloat(crypto.priceChangePercent);
              const high24h = parseFloat(crypto.highPrice);
              const low24h = parseFloat(crypto.lowPrice);
              const volume = parseFloat(crypto.volume);
              const quoteVolume = parseFloat(crypto.quoteVolume);
              const isPositive = priceChange >= 0;
              const coinName = getCoinName(crypto.symbol);

              return (
                <tr 
                  key={crypto.symbol}
                  className="transition-all duration-200 hover:bg-gray-900/30"
                  style={{ borderBottom: '1px solid rgba(43, 49, 57, 0.5)' }}
                >
                  {/* 排名 */}
                  <td className="py-3 px-2">
                    <div className="text-sm font-bold mono" style={{ color: index < 3 ? '#F0B90B' : '#848E9C' }}>
                      #{index + 1}
                    </div>
                  </td>

                  {/* 币种名称 */}
                  <td className="py-3 px-2">
                    <div className="font-bold text-sm" style={{ color: '#EAECEF' }}>
                      {coinName}
                    </div>
                  </td>

                  {/* 价格 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-bold mono" style={{ color: '#EAECEF' }}>
                      {price >= 1 
                        ? price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                        : price.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 8 })
                      }
                    </div>
                  </td>

                  {/* 24h 涨跌 */}
                  <td className="py-3 px-2 text-right">
                    <div className={`text-sm font-bold mono ${isPositive ? 'text-green-500' : 'text-red-500'}`}>
                      {isPositive ? '+' : ''}{priceChangePercent.toFixed(2)}%
                    </div>
                    <div className={`text-xs mono ${isPositive ? 'text-green-500' : 'text-red-500'}`}>
                      {isPositive ? '+' : ''}{priceChange.toFixed(4)}
                    </div>
                  </td>

                  {/* 24h 最高 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-semibold mono" style={{ color: '#0ECB81' }}>
                      {high24h >= 1
                        ? high24h.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                        : high24h.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 8 })
                      }
                    </div>
                  </td>

                  {/* 24h 最低 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-semibold mono" style={{ color: '#F6465D' }}>
                      {low24h >= 1
                        ? low24h.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                        : low24h.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 8 })
                      }
                    </div>
                  </td>

                  {/* 24h 成交量 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-semibold mono" style={{ color: '#EAECEF' }}>
                      {volume >= 1000000
                        ? `${(volume / 1000000).toFixed(2)}M`
                        : volume >= 1000
                        ? `${(volume / 1000).toFixed(2)}K`
                        : volume.toFixed(2)
                      }
                    </div>
                  </td>

                  {/* 24h 成交额 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-semibold mono" style={{ color: '#EAECEF' }}>
                      {quoteVolume >= 1000000000
                        ? `$${(quoteVolume / 1000000000).toFixed(2)}B`
                        : quoteVolume >= 1000000
                        ? `$${(quoteVolume / 1000000).toFixed(2)}M`
                        : quoteVolume >= 1000
                        ? `$${(quoteVolume / 1000).toFixed(2)}K`
                        : `$${quoteVolume.toFixed(2)}`
                      }
                    </div>
                  </td>

                  {/* 市场权重 */}
                  <td className="py-3 px-2 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <div className="text-sm font-semibold mono" style={{ color: '#EAECEF' }}>
                        {crypto.marketWeight?.toFixed(2) || '0.00'}%
                      </div>
                      <div 
                        className="h-1.5 rounded-full" 
                        style={{ 
                          width: '40px',
                          background: '#2B3139',
                          overflow: 'hidden'
                        }}
                      >
                        <div 
                          className="h-full rounded-full transition-all duration-300"
                          style={{ 
                            width: `${Math.min(100, crypto.marketWeight || 0)}%`,
                            background: 'linear-gradient(90deg, #F0B90B 0%, #0ECB81 100%)'
                          }}
                        />
                      </div>
                    </div>
                  </td>

                  {/* 换手率 */}
                  <td className="py-3 px-2 text-right">
                    <div className="text-sm font-semibold mono" style={{ color: '#848E9C' }}>
                      {crypto.turnoverRate ? crypto.turnoverRate.toFixed(2) : '0.00'}%
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Footer Info */}
      <div className="mt-4 pt-4" style={{ borderTop: '1px solid #2B3139' }}>
        <div className="flex items-center justify-between text-xs" style={{ color: '#5E6673' }}>
          <div>
            数据来源: Binance Futures API
          </div>
          <div>
            总交易额: ${cryptos.reduce((sum, c) => sum + parseFloat(c.quoteVolume), 0).toLocaleString('en-US', { maximumFractionDigits: 0 })}
          </div>
        </div>
      </div>
    </div>
  );
}

