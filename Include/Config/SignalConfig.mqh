//+------------------------------------------------------------------+
//|                                                 SignalConfig.mqh |
//|                         Chimera EA - Signal Configuration        |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"

//+------------------------------------------------------------------+
//| RSI Divergence Configuration Structure                           |
//+------------------------------------------------------------------+
struct SRSIConfig {
   bool enabled;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   int rsi_period;
   int pivot_left;           // Bars to left for pivot confirmation
   int pivot_right;          // Bars to right for pivot confirmation
   int pivot_tolerance;      // Bar tolerance for matching price/RSI pivots
   int max_divergence_bars;  // Max bars between divergence pivots
   double oversold;          // RSI threshold for bullish div
   double overbought;        // RSI threshold for bearish div
};

//+------------------------------------------------------------------+
//| Correlation Configuration Structure                              |
//+------------------------------------------------------------------+
struct SCorrelationConfig {
   bool enabled;
   string symbol1;  // Primary symbol (XAUUSD)
   string symbol2;  // Correlation symbol (DXY)
   ENUM_TIMEFRAMES timeframe;
   int period;               // Rolling window
   double threshold;         // Minimum for trade (-0.6)
   double strong_threshold;  // Strong correlation (-0.7)
};

//+------------------------------------------------------------------+
//| Trend Filter Configuration Structure                             |
//+------------------------------------------------------------------+
struct STrendConfig {
   bool enabled;
   string symbol;
   int ema_period;
   int ema_buffer_pips;
   int adx_period;
   int adx_threshold;
};

//+------------------------------------------------------------------+
//| Session/Spread Filter Configuration Structure                    |
//+------------------------------------------------------------------+
struct SFilterConfig {
   bool session_filter_enabled;
   bool spread_filter_enabled;
   int london_start_hour;
   int london_end_hour;
   int ny_start_hour;
   int ny_end_hour;
   double max_spread_pips;
};

//+------------------------------------------------------------------+
//| Signal Configuration Class                                       |
//+------------------------------------------------------------------+
class CSignalConfig {
  private:
   SRSIConfig m_rsi;
   SCorrelationConfig m_correlation;
   STrendConfig m_trend;
   SFilterConfig m_filters;

  public:
   CSignalConfig(void) {
      InitializeChimeraConfig();
   }

   // Getters
   SRSIConfig GetRSIConfig(void) const { return m_rsi; }
   SCorrelationConfig GetCorrelationConfig(void) const { return m_correlation; }
   STrendConfig GetTrendConfig(void) const { return m_trend; }
   SFilterConfig GetFilterConfig(void) const { return m_filters; }

   // Check if specific analyzers are enabled
   bool IsRSIEnabled(void) const { return m_rsi.enabled; }
   bool IsCorrelationEnabled(void) const { return m_correlation.enabled; }
   bool IsTrendEnabled(void) const { return m_trend.enabled; }
   bool IsSessionFilterEnabled(void) const { return m_filters.session_filter_enabled; }
   bool IsSpreadFilterEnabled(void) const { return m_filters.spread_filter_enabled; }

  private:
   void InitializeChimeraConfig(void) {
      //--- RSI Divergence Settings ---
      m_rsi.enabled = true;
      m_rsi.symbol = "XAUUSDm";
      m_rsi.timeframe = PERIOD_M5;
      m_rsi.rsi_period = 9;
      m_rsi.pivot_left = 3;
      m_rsi.pivot_right = 2;
      m_rsi.pivot_tolerance = 2;
      m_rsi.max_divergence_bars = 60;
      m_rsi.oversold = 40.0;
      m_rsi.overbought = 60.0;

      //--- Correlation Settings ---
      m_correlation.enabled = true;
      m_correlation.symbol1 = "XAUUSDm";
      m_correlation.symbol2 = "DXYm";
      m_correlation.timeframe = PERIOD_M5;
      m_correlation.period = 50;
      m_correlation.threshold = -0.6;
      m_correlation.strong_threshold = -0.7;

      //--- Trend Filter Settings ---
      m_trend.enabled = true;
      m_trend.symbol = "XAUUSDm";
      m_trend.ema_period = 200;
      m_trend.ema_buffer_pips = 50;
      m_trend.adx_period = 14;
      m_trend.adx_threshold = 25;

      //--- Session/Spread Filter Settings ---
      m_filters.session_filter_enabled = true;
      m_filters.spread_filter_enabled = true;
      m_filters.london_start_hour = 8;
      m_filters.london_end_hour = 17;
      m_filters.ny_start_hour = 13;
      m_filters.ny_end_hour = 22;
      m_filters.max_spread_pips = 25.0;
   }
};