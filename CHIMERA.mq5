//+------------------------------------------------------------------+
//|                                                      CHIMERA.mq5 |
//|                        Chimera EA v1.2 - Pattern Detection       |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property version "1.20"

//--- Include Configuration
#include "Include/Config/MarketDataConfig.mqh"
#include "Include/Config/SignalConfig.mqh"

//--- Include Core Components
#include "Include/Core/MarketData/CMarketDataManager.mqh"
#include "Include/Core/Signal/CSignalState.mqh"

//--- Include Analyzers
#include "Include/Analysis/CCorrelationAnalyzer.mqh"
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

// Trade Manager
CChimeraTradeManager* g_trade_manager = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA v1.2 - Pattern Detection System");
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

   //--- Print Configuration Summary
   PrintConfigurationSummary();

   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA initialized successfully");
   Print("═══════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
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

   // Future: Add other analyzers here
   // if(g_signal_config.IsTrendEnabled()) { ... }

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

   //--- Cleanup analyzers first
   if (g_rsi_divergence != NULL) {
      delete g_rsi_divergence;
      g_rsi_divergence = NULL;
   }

   if (g_correlation != NULL) {
      delete g_correlation;
      g_correlation = NULL;
   }

   //--- Cleanup configuration
   if (g_signal_config != NULL) {
      delete g_signal_config;
      g_signal_config = NULL;
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
   //--- Step 1: Update all market data
   if (!g_data_manager.UpdateAll()) {
      Print("WARNING: Failed to update market data");
      return;
   }

   //--- Step 2: Reset signal state for this tick
   g_signal_state.ResetAll();

   //--- Step 3: Run all active analyzers
   RunAnalyzers();

   //--- Step 4: Calculate confluence score
   int score = CalculateConfluenceScore();

   //--- Step 5: Trade decision block (future implementation)
   // if(score >= 3 && g_signal_state.PassesFilters()) {
   //     ExecuteTrade();
   // }

   //--- Step 6: Display status (throttled)
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

   // Future: Add other analyzers
   // if(g_trend != NULL) { g_trend.Analyze(...); }
}

//+------------------------------------------------------------------+
//| Calculate confluence score                                        |
//+------------------------------------------------------------------+
int CalculateConfluenceScore() {
   int score = 0;

   // 1. Base signal (RSI or Harmonic)
   if (g_signal_state.HasBaseSignal())
      score++;

   // 2. DXY Correlation < -0.6
   if (g_signal_state.HasValidCorrelation())
      score++;

   // 3. Harmonic pattern when RSI is base (future)
   // if(has_harmonic && has_rsi) score++;

   // 4. Strong correlation < -0.7
   if (g_signal_state.HasStrongCorrelation())
      score++;

   // 5. All timeframes aligned
   if (g_signal_state.IsTrendAligned())
      score++;

   return score;
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

   //--- Signal State
   SRSIDivergenceResult rsi = g_signal_state.GetRSI();
   Print(StringFormat("RSI Divergence: %s | Direction: %s",
                      rsi.detected ? "DETECTED" : "None",
                      rsi.is_bullish ? "BULLISH" : (rsi.detected ? "BEARISH" : "N/A")));

   //--- Confluence Score
   int score = CalculateConfluenceScore();
   Print(StringFormat("Confluence Score: %d/5", score));

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

   STrendConfig trend = g_signal_config.GetTrendConfig();
   Print(StringFormat("Trend Filter: %s", trend.enabled ? "ENABLED" : "DISABLED"));

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