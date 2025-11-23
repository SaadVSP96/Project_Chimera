//+------------------------------------------------------------------+
//|                                                      CHIMERA.mq5 |
//|                        Chimera EA v1.2 - Pattern Detection       |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property version "1.30"

//--- Include Configuration
#include "Include/Config/MarketDataConfig.mqh"
#include "Include/Config/SignalConfig.mqh"

//--- Include Core Components
#include "Include/Core/MarketData/CMarketDataManager.mqh"
#include "Include/Core/Signal/CSignalState.mqh"

//--- Include Analyzers
#include "Include/Analysis/CCorrelationAnalyzer.mqh"
#include "Include/Analysis/CHarmonicPatterns.mqh"
#include "Include/Analysis/CRSIDivergence.mqh"

//--- Include Trade Manager
#include "Include/Config/TradingConfig.mqh"
#include "Include/Trading/ChimeraTradeManager.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Singletons
CMarketDataManager* g_data_manager = NULL;
CSignalState* g_signal_state = NULL;

// Configuration
CSignalConfig* g_signal_config = NULL;
CTradingConfig* g_trading_config = NULL;

// Analyzers
CRSIDivergence* g_rsi_divergence = NULL;
CCorrelationAnalyzer* g_correlation = NULL;
CHarmonicPatterns* g_harmonic = NULL;
// Trade Manager
CChimeraTradeManager* g_trade_manager = NULL;

int g_atr_handle = INVALID_HANDLE;
bool g_atr_initialized = false;
bool g_is_new_bar = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA v1.3 - Pattern Detection System");
   Print("═══════════════════════════════════════════════════════");

   //--- Step 1: Initialize Configuration
   g_signal_config = new CSignalConfig();
   g_trading_config = new CTradingConfig();
   //--- Step 2: Initialize Data Manager (Singleton)
   g_data_manager = CMarketDataManager::GetInstance();
   if (g_data_manager == NULL) {
      Print("ERROR: Failed to initialize CMarketDataManager");
      return INIT_FAILED;
   }

   //--- Step 3: Initialize Signal State (Singleton)
   g_signal_state = CSignalState::GetInstance();
   if (g_signal_state == NULL) {
      Print("ERROR: Failed to initialize CSignalState");
      return INIT_FAILED;
   }

   //--- Step 4: Initialize Analyzers
   if (!InitializeAnalyzers()) {
      Print("ERROR: Failed to initialize analyzers");
      return INIT_FAILED;
   }

   // Validate
   if (!g_trading_config.ValidateConfig()) {
      return INIT_PARAMETERS_INCORRECT;
   }

   // Print summary
   g_trading_config.PrintConfigSummary();

   // Get flat config and pass to trade manager
   ChimeraConfig cfg = g_trading_config.GetConfig();
   g_trade_manager = new CChimeraTradeManager(cfg);

   //--- ATR Handle will be initialized on first tick (deferred initialization)
   //--- This avoids issues with backtesting where data isn't ready during OnInit
   string atr_sym = g_trading_config.GetTradeSymbol();
   int atr_period = g_trading_config.GetATRPeriod();

   // Ensure symbol is selected in Market Watch
   if (!SymbolSelect(atr_sym, true)) {
      Print("WARNING: Could not select ", atr_sym, " in Market Watch - will retry on tick");
   }

   Print("ATR indicator will be initialized for ", atr_sym, " M15 period ", atr_period, " on first tick");
   g_atr_initialized = false;

   //--- Print Configuration Summary
   PrintConfigurationSummary();

   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA initialized successfully");
   Print("═══════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize ATR indicator (deferred)                               |
//+------------------------------------------------------------------+
bool InitializeATR() {
   if (g_atr_initialized && g_atr_handle != INVALID_HANDLE)
      return true;

   string atr_sym = g_trading_config.GetTradeSymbol();
   int atr_period = g_trading_config.GetATRPeriod();

   // Ensure symbol is in Market Watch
   if (!SymbolSelect(atr_sym, true)) {
      Print("WARNING: Symbol ", atr_sym, " not available");
      return false;
   }

   // Check if we have enough bars
   int bars = Bars(atr_sym, PERIOD_M15);
   if (bars < atr_period + 10) {
      Print("WARNING: Not enough bars for ATR calculation. Have: ", bars, ", Need: ", atr_period + 10);
      return false;
   }

   // Create ATR handle
   g_atr_handle = iATR(atr_sym, PERIOD_M15, atr_period);
   if (g_atr_handle == INVALID_HANDLE) {
      Print("WARNING: Failed to create ATR handle for ", atr_sym, " M15 - Error: ", GetLastError());
      return false;
   }

   // Wait for indicator to calculate (important for backtesting)
   int wait_count = 0;
   while (BarsCalculated(g_atr_handle) <= 0 && wait_count < 10) {
      Sleep(10);
      wait_count++;
   }

   if (BarsCalculated(g_atr_handle) <= 0) {
      Print("WARNING: ATR indicator not yet calculated");
      IndicatorRelease(g_atr_handle);
      g_atr_handle = INVALID_HANDLE;
      return false;
   }

   g_atr_initialized = true;
   Print("ATR handle successfully created for ", atr_sym, " M15 period ", atr_period);
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR value using handle or fallback calculation                |
//+------------------------------------------------------------------+
double GetATRValue(string symbol, int period, int shift = 0) {
   // Try using the indicator handle first
   if (g_atr_handle != INVALID_HANDLE) {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);

      if (CopyBuffer(g_atr_handle, 0, shift, 1, atr_buffer) == 1) {
         return atr_buffer[0];
      } else {
         Print("WARNING: CopyBuffer failed for ATR, using manual calculation");
      }
   }

   // Fallback: Manual ATR calculation
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int bars_needed = period + shift + 1;

   if (CopyHigh(symbol, PERIOD_M15, shift, bars_needed, high) != bars_needed ||
       CopyLow(symbol, PERIOD_M15, shift, bars_needed, low) != bars_needed ||
       CopyClose(symbol, PERIOD_M15, shift, bars_needed, close) != bars_needed) {
      Print("WARNING: Failed to copy price data for manual ATR calculation");
      return 0.0;
   }

   double sum_tr = 0.0;
   for (int k = 0; k < period; k++) {
      double tr1 = high[k] - low[k];
      double tr2 = MathAbs(high[k] - close[k + 1]);
      double tr3 = MathAbs(low[k] - close[k + 1]);
      sum_tr += MathMax(tr1, MathMax(tr2, tr3));
   }

   return sum_tr / period;
}

//+------------------------------------------------------------------+
//| Initialize all analyzers                                          |
//+------------------------------------------------------------------+
bool InitializeAnalyzers() {
   //--- RSI Divergence
   if (g_signal_config.IsRSIEnabled()) {
      g_rsi_divergence = new CRSIDivergence();

      SRSIConfig rsi_config = g_signal_config.GetRSIConfig();

      if (!g_rsi_divergence.Initialize(g_data_manager, rsi_config)) {
         Print("ERROR: Failed to initialize CRSIDivergence");
         return false;
      }

      Print("RSI Divergence analyzer initialized");
   }

   //--- Correlation Analyzer
   if (g_signal_config.IsCorrelationEnabled()) {
      g_correlation = new CCorrelationAnalyzer();

      SCorrelationConfig corr_config = g_signal_config.GetCorrelationConfig();

      if (!g_correlation.Initialize(g_data_manager, corr_config)) {
         Print("ERROR: Failed to initialize CCorrelationAnalyzer");
         return false;
      }

      Print("Correlation analyzer initialized");
   }

   //--- Harmonic Patterns
   if (g_signal_config.IsHarmonicEnabled()) {
      g_harmonic = new CHarmonicPatterns();

      SHarmonicConfig harm_config = g_signal_config.GetHarmonicConfig();

      if (!g_harmonic.Initialize(g_data_manager, harm_config)) {
         Print("ERROR: Failed to initialize CHarmonicPatterns");
         return false;
      }

      Print("Harmonic patterns analyzer initialized");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA Shutdown");
   Print("  Reason: ", GetDeinitReasonText(reason));
   Print("═══════════════════════════════════════════════════════");

   //--- Release ATR handle
   if (g_atr_handle != INVALID_HANDLE) {
      IndicatorRelease(g_atr_handle);
      g_atr_handle = INVALID_HANDLE;
   }
   g_atr_initialized = false;

   //--- Cleanup analyzers first
   if (g_rsi_divergence != NULL) {
      delete g_rsi_divergence;
      g_rsi_divergence = NULL;
   }

   if (g_correlation != NULL) {
      delete g_correlation;
      g_correlation = NULL;
   }

   if (g_harmonic != NULL) {
      delete g_harmonic;
      g_harmonic = NULL;
   }
   //--- Cleanup configuration
   if (g_signal_config != NULL) {
      delete g_signal_config;
      g_signal_config = NULL;
   }

   //--- Cleanup trade manager
   if (g_trade_manager != NULL) {
      delete g_trade_manager;
      g_trade_manager = NULL;
   }

   //--- Cleanup trading config
   if (g_trading_config != NULL) {
      delete g_trading_config;
      g_trading_config = NULL;
   }

   //--- Cleanup singletons last
   CSignalState::Destroy();
   CMarketDataManager::Destroy();

   g_signal_state = NULL;
   g_data_manager = NULL;
}
//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Step 0: Detect new bar (for analyzers that need it)
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   g_is_new_bar = (current_bar_time != last_bar_time);
   if (g_is_new_bar) {
      last_bar_time = current_bar_time;
   }

   //--- Step 1: Initialize ATR if not yet done (deferred initialization)
   if (!g_atr_initialized) {
      InitializeATR();
   }

   //--- Step 2: Update all market data
   if (!g_data_manager.UpdateAll()) {
      Print("WARNING: Failed to update market data");
      return;
   }

   //--- Step 3: Reset signal state for this tick
   g_signal_state.ResetAll();

   //--- Step 4: Run all active analyzers
   RunAnalyzers();

   //--- Step 5: Calculate Confluence Score
   int confluence_score = CalculateConfluenceScore();

   //--- Step 6: Trade Entry Logic (Confluence-Based)
   SRSIDivergenceResult rsi_res = g_signal_state.GetRSI();
   SCorrelationResult corr_res = g_signal_state.GetCorrelation();
   SHarmonicPatternResult harm_res = g_signal_state.GetHarmonic();

   string sym = g_trading_config.GetTradeSymbol();
   int atr_period = g_trading_config.GetATRPeriod();
   double atr = GetATRValue(sym, atr_period);

   // Check if we meet minimum confluence requirements
   int min_score = g_signal_config.GetMinConfluenceScore();
   bool has_base = g_signal_state.HasBaseSignal();  // RSI or Harmonic
   bool require_base = g_signal_config.RequiresBaseSignal();

   if (atr > 0.0 && confluence_score >= min_score && (!require_base || has_base)) {
      // Determine trade direction from active signals
      bool trade_signal = false;
      bool is_bullish = false;

      // Priority 1: Harmonic patterns (if any triggered)
      if (harm_res.any_pattern_detected && harm_res.GetTriggeredCount() > 0) {
         trade_signal = true;
         is_bullish = harm_res.is_bullish;
         Print("═══ TRADE SIGNAL: HARMONIC PATTERN ═══");
         Print("  Direction: ", is_bullish ? "BULLISH" : "BEARISH");
         Print("  Triggered Patterns: ", harm_res.GetTriggeredCount());
         Print("  Confluence Score: ", confluence_score, "/9");
      }
      // Priority 2: RSI Divergence
      else if (rsi_res.detected) {
         trade_signal = true;
         is_bullish = rsi_res.is_bullish;
         Print("═══ TRADE SIGNAL: RSI DIVERGENCE ═══");
         Print("  Direction: ", is_bullish ? "BULLISH" : "BEARISH");
         Print("  Confluence Score: ", confluence_score, "/9");
      }

      // Execute trade if we have a signal
      if (trade_signal) {
         ENUM_ORDER_TYPE ord_type = is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double entry_price = (ord_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);

         // Calculate stop loss
         STradeManagementConfig tm_cfg = g_trading_config.GetTradeManagementConfig();
         double sl_dist = tm_cfg.sl_atr_mult * atr;
         double sl_price = (ord_type == ORDER_TYPE_BUY) ? entry_price - sl_dist : entry_price + sl_dist;

         // Execute entry with confluence score
         datetime now_time = TimeCurrent();
         g_trade_manager.ExecuteEntry(ord_type, sl_price, confluence_score,
                                      corr_res.value, now_time);

         Print("  ATR: ", DoubleToString(atr, 5));
         Print("  Entry: ", DoubleToString(entry_price, _Digits));
         Print("  Stop Loss: ", DoubleToString(sl_price, _Digits));
         Print("  Risk: ", DoubleToString(sl_dist, _Digits), " (",
               DoubleToString(tm_cfg.sl_atr_mult, 1), "× ATR)");
         Print("═══════════════════════════════════");
      }
   }

   //--- Step 7: Manage existing positions
   if (atr > 0.0) {
      datetime now_time = TimeCurrent();
      g_trade_manager.ManagePositions(atr, corr_res.value, now_time, now_time);
      g_trade_manager.ManageTrailingStop(atr, now_time);
   }

   //--- Step 8: Display status (throttled)
   static datetime last_display = 0;
   if (TimeCurrent() - last_display >= 10) {
      DisplayStatus();
      last_display = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Run all active analyzers                                          |
//+------------------------------------------------------------------+
void RunAnalyzers() {
   //--- RSI Divergence
   if (g_rsi_divergence != NULL && g_rsi_divergence.IsInitialized()) {
      SRSIDivergenceResult rsi_result;
      g_rsi_divergence.Analyze(rsi_result);
      g_signal_state.SetRSIDivergence(rsi_result);

      // Log detection
      if (rsi_result.detected) {
         string div_type = rsi_result.is_bullish ? "BULLISH" : "BEARISH";
         Print("══════ RSI DIVERGENCE DETECTED ══════");
         Print("Type: ", div_type);
         Print("RSI Current: ", DoubleToString(rsi_result.rsi_current, 2));
         Print("RSI Previous: ", DoubleToString(rsi_result.rsi_previous, 2));
         Print("Bars Between: ", rsi_result.bars_between);
         Print("═════════════════════════════════════");
      }
   }

   //--- Correlation Analysis
   if (g_correlation != NULL && g_correlation.IsInitialized()) {
      SCorrelationResult corr_result;
      g_correlation.Analyze(corr_result);
      g_signal_state.SetCorrelation(corr_result);

      // Log significant correlation changes (throttled to avoid spam)
      static double last_logged_corr = 0.0;
      if (MathAbs(corr_result.value - last_logged_corr) > 0.05) {
         string status = corr_result.meets_threshold ? "VALID" : "WEAK";
         Print(StringFormat("Correlation [%s/%s]: %.3f | Status: %s | Boost: %.2fx",
                            g_correlation.GetSymbol1(),
                            g_correlation.GetSymbol2(),
                            corr_result.value,
                            status,
                            corr_result.signal_boost));
         last_logged_corr = corr_result.value;
      }
   }
   //--- Harmonic Patterns
   if (g_harmonic != NULL && g_harmonic.IsInitialized()) {
      g_harmonic.Update(g_is_new_bar);

      SHarmonicPatternResult harm_result;
      g_harmonic.Analyze(harm_result);
      g_signal_state.SetHarmonic(harm_result);

      // Log when patterns trigger
      if (harm_result.gartley.D_triggered) {
         Print("══════ GARTLEY TRIGGERED ══════");
         Print("  Projected D Price: ", DoubleToString(harm_result.gartley.D_price, 2));
         Print("═══════════════════════════════");
      }

      if (harm_result.bat.D_triggered) {
         Print("══════ BAT TRIGGERED ══════");
         Print("  Projected D Price: ", DoubleToString(harm_result.bat.D_price, 2));
         Print("═══════════════════════════");
      }

      if (harm_result.abcd.D_triggered) {
         Print("══════ ABCD TRIGGERED ══════");
         Print("  Projected D Price: ", DoubleToString(harm_result.abcd.D_price, 2));
         Print("═══════════════════════════");
      }

      if (harm_result.cypher.D_triggered) {
         Print("══════ CYPHER TRIGGERED ══════");
         Print("  Projected D Price: ", DoubleToString(harm_result.cypher.D_price, 2));
         Print("══════════════════════════════");
      }
   }
   // Future: Add other analyzers
   // if(g_trend != NULL) { g_trend.Analyze(...); }
}

//+------------------------------------------------------------------+
//| Calculate confluence score                                        |
//+------------------------------------------------------------------+
int CalculateConfluenceScore() {
   int score = 0;

   // 1. RSI Base signal (1 point)
   if (g_signal_state.GetRSI().detected)
      score++;

   // 2-5. Harmonic patterns (1 point each, max 4 points)
   SHarmonicPatternResult harm = g_signal_state.GetHarmonic();
   score += harm.GetTriggeredCount();

   // 6. DXY Correlation Valid: < -0.6 (1 point)
   if (g_signal_state.HasValidCorrelation())
      score++;

   // 7. DXY Correlation Strong: < -0.7 (1 point)
   if (g_signal_state.HasStrongCorrelation())
      score++;

   // 8. Trend alignment (1 point) - FUTURE
   if (g_signal_state.IsTrendAligned())
      score++;

   // 9. Filters passed (1 point) - FUTURE
   if (g_signal_state.PassesFilters())
      score++;

   return score;  // Max score = 9
}

//+------------------------------------------------------------------+
//| Display current status                                            |
//+------------------------------------------------------------------+
void DisplayStatus() {
   Print("\n╔═══════════════════════════════════════════════════════╗");
   Print("║  CHIMERA Status Update                                 ║");
   Print("╚═══════════════════════════════════════════════════════╝");

   //--- Market Data Sample
   SRSIConfig rsi_cfg = g_signal_config.GetRSIConfig();
   double close = g_data_manager.Close(rsi_cfg.symbol, rsi_cfg.timeframe, 0);
   datetime time = g_data_manager.Time(rsi_cfg.symbol, rsi_cfg.timeframe, 0);

   Print(StringFormat("%s %s [0]: %.2f @ %s",
                      rsi_cfg.symbol,
                      EnumToString(rsi_cfg.timeframe),
                      close,
                      TimeToString(time, TIME_DATE | TIME_MINUTES)));

   //--- ATR Status
   string sym = g_trading_config.GetTradeSymbol();
   int atr_period = g_trading_config.GetATRPeriod();
   double current_atr = GetATRValue(sym, atr_period);
   Print(StringFormat("ATR (%s M15, %d): %.5f | Handle: %s",
                      sym, atr_period, current_atr,
                      g_atr_initialized ? "Active" : "Fallback"));

   //--- RSI Status
   if (g_rsi_divergence != NULL && g_rsi_divergence.IsInitialized()) {
      Print(StringFormat("RSI Current: %.2f | Price Pivots: %d | RSI Pivots: %d",
                         g_rsi_divergence.GetCurrentRSI(),
                         g_rsi_divergence.GetPricePivotCount(),
                         g_rsi_divergence.GetRSIPivotCount()));
   }

   //--- Correlation Status
   if (g_correlation != NULL && g_correlation.IsInitialized()) {
      SCorrelationResult corr = g_signal_state.GetCorrelation();
      Print(StringFormat("Correlation [%s/%s]: %.3f | Valid: %s | Strong: %s | Boost: %.2fx",
                         g_correlation.GetSymbol1(),
                         g_correlation.GetSymbol2(),
                         corr.value,
                         corr.meets_threshold ? "YES" : "NO",
                         corr.is_strong ? "YES" : "NO",
                         corr.signal_boost));
   }
   //--- Harmonic Pattern Status
   if (g_harmonic != NULL && g_harmonic.IsInitialized()) {
      SHarmonicPatternResult harm = g_signal_state.GetHarmonic();

      if (harm.XABCD_structure_valid) {
         Print(StringFormat("Harmonic [%s]: %s | Pivots: %d | Monitoring: %s",
                            g_harmonic.GetSymbol(),
                            harm.is_bullish ? "BULLISH" : "BEARISH",
                            g_harmonic.GetPivotCount(),
                            harm.any_pattern_detected ? "YES" : "NO"));

         if (harm.gartley.waiting_for_D || harm.gartley.D_triggered) {
            Print(StringFormat("  Gartley D: %.2f | Hit: %s",
                               harm.gartley.D_price,
                               harm.gartley.D_triggered ? "YES" : "waiting"));
         }

         if (harm.bat.waiting_for_D || harm.bat.D_triggered) {
            Print(StringFormat("  Bat D: %.2f | Hit: %s",
                               harm.bat.D_price,
                               harm.bat.D_triggered ? "YES" : "waiting"));
         }

         if (harm.abcd.waiting_for_D || harm.abcd.D_triggered) {
            Print(StringFormat("  ABCD D: %.2f | Hit: %s",
                               harm.abcd.D_price,
                               harm.abcd.D_triggered ? "YES" : "waiting"));
         }

         if (harm.cypher.waiting_for_D || harm.cypher.D_triggered) {
            Print(StringFormat("  Cypher D: %.2f | Hit: %s",
                               harm.cypher.D_price,
                               harm.cypher.D_triggered ? "YES" : "waiting"));
         }
      } else {
         Print(StringFormat("Harmonic [%s]: No active patterns | Pivots: %d",
                            g_harmonic.GetSymbol(),
                            g_harmonic.GetPivotCount()));
      }
   }
   //--- Signal State
   SRSIDivergenceResult rsi = g_signal_state.GetRSI();
   Print(StringFormat("RSI Divergence: %s | Direction: %s",
                      rsi.detected ? "DETECTED" : "None",
                      rsi.is_bullish ? "BULLISH" : (rsi.detected ? "BEARISH" : "N/A")));

   //--- Confluence Score (with threshold info)
   int score = CalculateConfluenceScore();
   int min_score = g_signal_config.GetMinConfluenceScore();
   string score_status = (score >= min_score) ? "READY" : "BELOW MIN";
   Print(StringFormat("Confluence Score: %d/9 (Min: %d) | Status: %s",
                      score, min_score, score_status));

   Print("═══════════════════════════════════════════════════════\n");
}

//+------------------------------------------------------------------+
//| Print configuration summary                                       |
//+------------------------------------------------------------------+
void PrintConfigurationSummary() {
   Print("─────────────────────────────────────────────────────");
   Print("Signal Configuration:");
   Print("─────────────────────────────────────────────────────");

   SRSIConfig rsi = g_signal_config.GetRSIConfig();
   Print(StringFormat("RSI Divergence: %s", rsi.enabled ? "ENABLED" : "DISABLED"));
   if (rsi.enabled) {
      Print(StringFormat("  Symbol: %s | TF: %s | Period: %d",
                         rsi.symbol, EnumToString(rsi.timeframe), rsi.rsi_period));
      Print(StringFormat("  Pivots: L=%d R=%d | Oversold: %.0f | Overbought: %.0f",
                         rsi.pivot_left, rsi.pivot_right, rsi.oversold, rsi.overbought));
   }

   SCorrelationConfig corr = g_signal_config.GetCorrelationConfig();
   Print(StringFormat("Correlation: %s", corr.enabled ? "ENABLED" : "DISABLED"));
   if (corr.enabled) {
      string sym1 = g_data_manager.GetSymbolName(corr.symbol1_index);
      string sym2 = g_data_manager.GetSymbolName(corr.symbol2_index);
      Print(StringFormat("  Symbols: %s (idx %d) / %s (idx %d)",
                         sym1, corr.symbol1_index, sym2, corr.symbol2_index));
      Print(StringFormat("  TF: %s | Period: %d",
                         EnumToString(corr.timeframe), corr.period));
      Print(StringFormat("  Threshold: %.2f | Strong: %.2f",
                         corr.threshold, corr.strong_threshold));
   }

   SHarmonicConfig harm = g_signal_config.GetHarmonicConfig();
   Print(StringFormat("Harmonic Patterns: %s", harm.enabled ? "ENABLED" : "DISABLED"));
   if (harm.enabled) {
      string sym = g_data_manager.GetSymbolName(harm.symbol_index);
      Print(StringFormat("  Symbol: %s (idx %d) | TF: %s",
                         sym, harm.symbol_index, EnumToString(harm.timeframe)));
      Print(StringFormat("  Pivot Strength: L=%d R=%d | Max Pivots: %d",
                         harm.pivot_left, harm.pivot_right, harm.max_pivots));
      Print(StringFormat("  PRZ Tolerance: %.1f pips | Ratio Tolerance: ±%.1f%%",
                         harm.prz_tolerance_pips, harm.ratio_tolerance * 100));
      Print(StringFormat("  Patterns: %s%s%s%s",
                         harm.patterns[0].enabled ? "Gartley " : "",
                         harm.patterns[1].enabled ? "Bat " : "",
                         harm.patterns[2].enabled ? "ABCD " : "",
                         harm.patterns[3].enabled ? "Cypher" : ""));
   }

   STrendConfig trend = g_signal_config.GetTrendConfig();
   Print(StringFormat("Trend Filter: %s", trend.enabled ? "ENABLED" : "DISABLED"));

   SSignalGlobalConfig global = g_signal_config.GetGlobalConfig();
   Print("─────────────────────────────────────────────────────");
   Print("Global Signal Settings:");
   Print(StringFormat("  Minimum Confluence Score: %d/9", global.min_confluence_score));
   Print(StringFormat("  Require Base Signal: %s", global.require_base_signal ? "YES" : "NO"));
   Print("  Max Possible Score: 9 points");
   Print("    - RSI Divergence: 1 point");
   Print("    - Harmonic Patterns: 4 points (1 per pattern)");
   Print("    - Correlation Valid: 1 point");
   Print("    - Correlation Strong: 1 point");
   Print("    - Trend Aligned: 1 point");
   Print("    - Filters Passed: 1 point");

   Print("─────────────────────────────────────────────────────");
}

//+------------------------------------------------------------------+
//| Get deinit reason as text                                         |
//+------------------------------------------------------------------+
string GetDeinitReasonText(const int reason) {
   switch (reason) {
      case REASON_PROGRAM:
         return "EA stopped by user";
      case REASON_REMOVE:
         return "EA removed from chart";
      case REASON_RECOMPILE:
         return "EA recompiled";
      case REASON_CHARTCHANGE:
         return "Chart symbol/period changed";
      case REASON_CHARTCLOSE:
         return "Chart closed";
      case REASON_PARAMETERS:
         return "Input parameters changed";
      case REASON_ACCOUNT:
         return "Account changed";
      case REASON_TEMPLATE:
         return "Template changed";
      case REASON_INITFAILED:
         return "OnInit() failed";
      case REASON_CLOSE:
         return "Terminal closed";
      default:
         return "Unknown reason";
   }
}
