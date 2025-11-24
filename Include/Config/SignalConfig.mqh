//+------------------------------------------------------------------+
//|                                                 SignalConfig.mqh |
//|                         Chimera EA - Signal Configuration        |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"

//+------------------------------------------------------------------+
//| Global Signal Settings                                            |
//+------------------------------------------------------------------+
struct SSignalGlobalConfig {
   int min_confluence_score;            // Minimum score to take trades
   bool require_rsi_divergence_signal;  // Must have RSI or Harmonic before trading

   // Default constructor
   SSignalGlobalConfig() : min_confluence_score(3), require_rsi_divergence_signal(true) {}
};

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
   int symbol1_index;  // Index in MarketDataConfig (0 = XAUUSD)
   int symbol2_index;  // Index in MarketDataConfig (2 = DXY)
   ENUM_TIMEFRAMES timeframe;
   int period;               // Rolling window for correlation
   double threshold;         // Minimum correlation for trade (-0.6)
   double strong_threshold;  // Strong correlation for boost (-0.7)
};

//+------------------------------------------------------------------+
//| Pattern Ratio Definition (Fibonacci ratios for one pattern)      |
//+------------------------------------------------------------------+
struct SPatternRatios {
   string name;   // "Gartley", "Bat", "ABCD", "Cypher"
   bool enabled;  // User can enable/disable per pattern

   // Fibonacci ratios with ranges
   double AB_XA_min, AB_XA_max;
   double BC_AB_min, BC_AB_max;
   double CD_BC_min, CD_BC_max;
   double AD_XA;  // D projection ratio (KEY for PRZ)

   // Default constructor
   SPatternRatios() : name(""), enabled(false), AB_XA_min(0), AB_XA_max(0), BC_AB_min(0), BC_AB_max(0), CD_BC_min(0), CD_BC_max(0), AD_XA(0) {}
};

//+------------------------------------------------------------------+
//| Harmonic Patterns Configuration                                  |
//+------------------------------------------------------------------+
struct SHarmonicConfig {
   bool enabled;               // Master enable/disable
   int symbol_index;           // Index in MarketDataConfig
   ENUM_TIMEFRAMES timeframe;  // M15 per spec

   // Pivot detection
   int pivot_left;   // Bars to left for confirmation
   int pivot_right;  // Bars to right for confirmation
   int max_pivots;   // Max pivot buffer size

   // Pattern validation
   SPatternRatios patterns[4];  // [0]=Gartley, [1]=Bat, [2]=ABCD, [3]=Cypher
   double ratio_tolerance;      // ±tolerance for ratio matching (e.g., 0.02)

   // PRZ settings
   double prz_tolerance_pips;  // How close to D = "hit"

   // Invalidation rules
   bool check_X_break;        // Invalidate if price breaks X
   int max_pattern_age_bars;  // Max bars to wait for D
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
   SSignalGlobalConfig m_global;
   SRSIConfig m_rsi;
   SCorrelationConfig m_correlation;
   SHarmonicConfig m_harmonic;
   STrendConfig m_trend;
   SFilterConfig m_filters;

  public:
   CSignalConfig(void) {
      InitializeChimeraConfig();
   }

   // Getters
   int GetMinConfluenceScore(void) const { return m_global.min_confluence_score; }
   bool RequiresRSIDivergenceSignal(void) const { return m_global.require_rsi_divergence_signal; }
   SSignalGlobalConfig GetGlobalConfig(void) const { return m_global; }
   SRSIConfig GetRSIConfig(void) const { return m_rsi; }
   SCorrelationConfig GetCorrelationConfig(void) const { return m_correlation; }
   SHarmonicConfig GetHarmonicConfig(void) const { return m_harmonic; }
   STrendConfig GetTrendConfig(void) const { return m_trend; }
   SFilterConfig GetFilterConfig(void) const { return m_filters; }

   // Check if specific analyzers are enabled
   bool IsRSIEnabled(void) const { return m_rsi.enabled; }
   bool IsCorrelationEnabled(void) const { return m_correlation.enabled; }
   bool IsHarmonicEnabled(void) const { return m_harmonic.enabled; }
   bool IsTrendEnabled(void) const { return m_trend.enabled; }
   bool IsSessionFilterEnabled(void) const { return m_filters.session_filter_enabled; }
   bool IsSpreadFilterEnabled(void) const { return m_filters.spread_filter_enabled; }

  private:
   void InitializeChimeraConfig(void) {
      //--- Global Signal Settings ---
      m_global.min_confluence_score = 3;              // Minimum score to trade (out of 9)
      m_global.require_rsi_divergence_signal = true;  // Must have RSI or Harmonic

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
      m_correlation.symbol1_index = 0;  // Index 0 = XAUUSDm (primary)
      m_correlation.symbol2_index = 2;  // Index 2 = DXYm (correlation filter)
      m_correlation.timeframe = PERIOD_M5;
      m_correlation.period = 14;  // 50;
      m_correlation.threshold = -0.6;
      m_correlation.strong_threshold = -0.7;

      //--- Harmonic Pattern Settings ---
      m_harmonic.enabled = true;
      m_harmonic.symbol_index = 0;  // XAUUSDm
      m_harmonic.timeframe = PERIOD_M15;

      m_harmonic.pivot_left = 5;
      m_harmonic.pivot_right = 3;
      m_harmonic.max_pivots = 50;

      m_harmonic.ratio_tolerance = 0.02;  // ±2%
      m_harmonic.prz_tolerance_pips = 10.0;

      m_harmonic.check_X_break = true;
      m_harmonic.max_pattern_age_bars = 100;

      //--- Gartley Pattern ---
      m_harmonic.patterns[0].name = "Gartley";
      m_harmonic.patterns[0].enabled = true;
      m_harmonic.patterns[0].AB_XA_min = 0.618 - m_harmonic.ratio_tolerance;
      m_harmonic.patterns[0].AB_XA_max = 0.618 + m_harmonic.ratio_tolerance;
      m_harmonic.patterns[0].BC_AB_min = 0.382;
      m_harmonic.patterns[0].BC_AB_max = 0.886;
      m_harmonic.patterns[0].CD_BC_min = 1.272;
      m_harmonic.patterns[0].CD_BC_max = 1.618;
      m_harmonic.patterns[0].AD_XA = 0.786;

      //--- Bat Pattern ---
      m_harmonic.patterns[1].name = "Bat";
      m_harmonic.patterns[1].enabled = true;
      m_harmonic.patterns[1].AB_XA_min = 0.382;
      m_harmonic.patterns[1].AB_XA_max = 0.50;
      m_harmonic.patterns[1].BC_AB_min = 0.382;
      m_harmonic.patterns[1].BC_AB_max = 0.886;
      m_harmonic.patterns[1].CD_BC_min = 1.618;
      m_harmonic.patterns[1].CD_BC_max = 2.618;
      m_harmonic.patterns[1].AD_XA = 0.886;

      //--- ABCD Pattern ---
      m_harmonic.patterns[2].name = "ABCD";
      m_harmonic.patterns[2].enabled = true;
      m_harmonic.patterns[2].AB_XA_min = 0.0;  // X not used in ratios
      m_harmonic.patterns[2].AB_XA_max = 999.0;
      m_harmonic.patterns[2].BC_AB_min = 0.382;
      m_harmonic.patterns[2].BC_AB_max = 0.886;
      m_harmonic.patterns[2].CD_BC_min = 1.272;
      m_harmonic.patterns[2].CD_BC_max = 1.618;
      m_harmonic.patterns[2].AD_XA = 0.0;  // Not used

      //--- Cypher Pattern ---
      m_harmonic.patterns[3].name = "Cypher";
      m_harmonic.patterns[3].enabled = true;
      m_harmonic.patterns[3].AB_XA_min = 0.382;
      m_harmonic.patterns[3].AB_XA_max = 0.618;
      m_harmonic.patterns[3].BC_AB_min = 1.13;
      m_harmonic.patterns[3].BC_AB_max = 1.414;
      m_harmonic.patterns[3].CD_BC_min = 0.0;  // Uses XC instead
      m_harmonic.patterns[3].CD_BC_max = 999.0;
      m_harmonic.patterns[3].AD_XA = 0.786;  // 0.786 of XC

      //--- Trend Filter Settings ---
      m_trend.enabled = false;
      m_trend.symbol = "XAUUSDm";
      m_trend.ema_period = 200;
      m_trend.ema_buffer_pips = 50;
      m_trend.adx_period = 14;
      m_trend.adx_threshold = 25;

      //--- Session/Spread Filter Settings ---
      m_filters.session_filter_enabled = false;
      m_filters.spread_filter_enabled = true;
      m_filters.london_start_hour = 8;
      m_filters.london_end_hour = 17;
      m_filters.ny_start_hour = 13;
      m_filters.ny_end_hour = 22;
      m_filters.max_spread_pips = 25.0;
   }
};