//+------------------------------------------------------------------+
//|                                                 CTrendFilter.mqh |
//|                        Project Chimera v9.0 Trend Alignment Core |
//|                                  Copyright 2024, Project Chimera |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property strict

// Include the config from the Config directory (relative path from Analysis/)
#include "../Config/SignalConfig.mqh"

//+------------------------------------------------------------------+
//| ENUMERATION: Trend States                                        |
//+------------------------------------------------------------------+
enum ENUM_TREND_STATE {
   TREND_UP,    // H4 Bullish, H1 Bullish, ADX > 25, Outside Buffer
   TREND_DOWN,  // H4 Bearish, H1 Bearish, ADX > 25, Outside Buffer
   TREND_NONE   // Inside Buffer, Conflicting Timeframes, Weak Momentum, or Error
};

//+------------------------------------------------------------------+
//| CLASS: CTrendFilter                                              |
//+------------------------------------------------------------------+
class CTrendFilter {
  private:
   // --- Configuration (User-Supplied) ---
   TrendFilterConfig m_config;

   // --- Indicator Handles ---
   int m_handle_h4_ma;
   int m_handle_h1_ma;
   int m_handle_h1_adx;

   // --- State & Diagnostics ---
   ENUM_TREND_STATE m_prev_trend;
   double m_last_h4_dist_pips;
   double m_last_adx_value;
   string m_status_reason;

   // --- Caching ---
   datetime m_last_calc_time;
   ENUM_TREND_STATE m_cached_result;

   // --- Internal Helpers ---
   double GetMAValue(int handle, int shift);
   double GetADXValueInternal(int handle, int shift);
   double GetPipSize();
   bool IsDataSynchronized();
   bool IsSymbolValid();
   void UpdateCache(ENUM_TREND_STATE result, int shift);

  public:
   // Constructor now accepts configuration
   CTrendFilter(const TrendFilterConfig& config);
   ~CTrendFilter();

   // --- Initialization ---
   bool Init();

   // --- Core Logic ---
   ENUM_TREND_STATE GetTrendDirection(int shift);

   // --- State Change Detection ---
   bool IsTrendChange(ENUM_TREND_STATE& new_trend);

   // --- Confluence Scoring ---
   int GetTrendStrengthScore();

   // --- Diagnostics ---
   double GetH4DistancePips() const { return m_last_h4_dist_pips; }
   double GetADXValue() const { return m_last_adx_value; }
   string GetStatusString() const { return m_status_reason; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendFilter::CTrendFilter(const TrendFilterConfig& config) : m_config(config),  // Store user configuration
                                                              m_handle_h4_ma(INVALID_HANDLE),
                                                              m_handle_h1_ma(INVALID_HANDLE),
                                                              m_handle_h1_adx(INVALID_HANDLE),
                                                              m_prev_trend(TREND_NONE),
                                                              m_last_h4_dist_pips(0.0),
                                                              m_last_adx_value(0.0),
                                                              m_status_reason("Initializing"),
                                                              m_last_calc_time(0),
                                                              m_cached_result(TREND_NONE) {
   // Add this line to call the Init method
   if (!Init()) {
      // Handle the error case. See discussion below.
      Print("CTrendFilter Error: Initialization failed in constructor.");
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendFilter::~CTrendFilter() {
   if (m_handle_h4_ma != INVALID_HANDLE) IndicatorRelease(m_handle_h4_ma);
   if (m_handle_h1_ma != INVALID_HANDLE) IndicatorRelease(m_handle_h1_ma);
   if (m_handle_h1_adx != INVALID_HANDLE) IndicatorRelease(m_handle_h1_adx);
}

//+------------------------------------------------------------------+
//| Init: Create handles & Validate environment                      |
//+------------------------------------------------------------------+
bool CTrendFilter::Init() {
   // 1. Validate Symbol
   if (!IsSymbolValid()) return false;

   // 2. Create Handles (Using config parameters)
   m_handle_h4_ma = iMA(m_config.symbol, m_config.h4_period, m_config.ma_period, 0, m_config.ma_method, m_config.ma_price);
   m_handle_h1_ma = iMA(m_config.symbol, m_config.h1_period, m_config.ma_period, 0, m_config.ma_method, m_config.ma_price);
   m_handle_h1_adx = iADX(m_config.symbol, m_config.h1_period, m_config.adx_period);

   // 3. Validate Handles
   if (m_handle_h4_ma == INVALID_HANDLE || m_handle_h1_ma == INVALID_HANDLE || m_handle_h1_adx == INVALID_HANDLE) {
      PrintFormat("CTrendFilter Error: Handle Creation Failed. Err: %d", GetLastError());
      return false;
   }

   // 4. Validate History
   if (Bars(m_config.symbol, m_config.h4_period) < m_config.ma_period + m_config.history_buffer_bars) {
      Print("CTrendFilter Error: Insufficient H4 history");
      return false;
   }

   m_status_reason = "Ready";
   return true;
}

//+------------------------------------------------------------------+
//| GetTrendDirection: Master Logic                                  |
//+------------------------------------------------------------------+
ENUM_TREND_STATE CTrendFilter::GetTrendDirection(int shift) {
   if (shift < 0) {
      Print("CTrendFilter Error: Invalid negative shift");
      return TREND_NONE;
   }

   // Cache check
   if (shift == 0 && TimeCurrent() == m_last_calc_time) {
      return m_cached_result;
   }

   // Data sync check
   if (!IsDataSynchronized()) {
      m_status_reason = "Error: Data Not Synchronized";
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   // Timeframe calculation
   datetime time_current = iTime(m_config.symbol, PERIOD_CURRENT, shift);
   if (time_current == 0) {
      m_status_reason = "Error: Invalid Time";
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   int h4_index = iBarShift(m_config.symbol, m_config.h4_period, time_current);
   int h1_index = iBarShift(m_config.symbol, m_config.h1_period, time_current);

   // H4 Logic
   double h4_ma = GetMAValue(m_handle_h4_ma, h4_index);
   double h4_close = iClose(m_config.symbol, m_config.h4_period, h4_index);

   if (h4_ma == 0.0 || h4_close == 0.0) {
      m_status_reason = "Error: Missing H4 Data";
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   bool h4_bullish = (h4_close > h4_ma);

   // H4 Buffer Logic
   double dist_raw = MathAbs(h4_close - h4_ma);
   double pip_size = GetPipSize();
   double dist_pips = (pip_size > 0) ? dist_raw / pip_size : 0;
   m_last_h4_dist_pips = dist_pips;

   if (dist_pips <= m_config.buffer_pips) {
      m_status_reason = StringFormat("Wait: Inside H4 Buffer (%.1f <= %.1f)", dist_pips, m_config.buffer_pips);
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   // H1 Confirmation Logic
   double h1_ma = GetMAValue(m_handle_h1_ma, h1_index);
   double h1_close = iClose(m_config.symbol, m_config.h1_period, h1_index);

   if (h1_ma == 0.0 || h1_close == 0.0) {
      m_status_reason = "Error: Missing H1 Data";
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   bool h1_bullish = (h1_close > h1_ma);

   if (h4_bullish != h1_bullish) {
      m_status_reason = "Wait: Timeframe Conflict";
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   // ADX Momentum Logic
   double adx = GetADXValueInternal(m_handle_h1_adx, h1_index);
   m_last_adx_value = adx;

   if (adx < m_config.adx_threshold) {
      m_status_reason = StringFormat("Wait: Low Momentum (ADX %.1f < %.1f)", adx, m_config.adx_threshold);
      UpdateCache(TREND_NONE, shift);
      return TREND_NONE;
   }

   // Final Result
   ENUM_TREND_STATE result = h4_bullish ? TREND_UP : TREND_DOWN;
   m_status_reason = (result == TREND_UP) ? "Trend: UP" : "Trend: DOWN";
   UpdateCache(result, shift);

   return result;
}

//+------------------------------------------------------------------+
//| GetTrendStrengthScore: Confluence scoring helper                 |
//+------------------------------------------------------------------+
int CTrendFilter::GetTrendStrengthScore() {
   ENUM_TREND_STATE current = GetTrendDirection(0);
   if (current == TREND_NONE) return 0;

   if (m_last_h4_dist_pips > m_config.strong_trend_threshold_pips) {
      return 2;
   }

   return 1;
}

//+------------------------------------------------------------------+
//| IsTrendChange: Detects State Flips                               |
//+------------------------------------------------------------------+
bool CTrendFilter::IsTrendChange(ENUM_TREND_STATE& new_trend) {
   ENUM_TREND_STATE current = GetTrendDirection(0);

   if (current != m_prev_trend) {
      new_trend = current;
      m_prev_trend = current;  // Update valid state
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| IsDataSynchronized: Robust Stale Data Check                      |
//+------------------------------------------------------------------+
bool CTrendFilter::IsDataSynchronized() {
   // Check 1: Tick Freshness using SymbolInfoTick
   MqlTick last_tick;
   if (!SymbolInfoTick(m_config.symbol, last_tick)) {
      // If we can't get tick data, consider it stale
      return false;
   }
   bool tick_stale = (TimeCurrent() - last_tick.time > m_config.sync_timeout_seconds);

   // Check 2: Bar Freshness (Ensure H4 bar isn't ancient)
   datetime h4_time = iTime(m_config.symbol, m_config.h4_period, 0);
   int h4_seconds = PeriodSeconds(m_config.h4_period);
   bool bar_stale = (h4_time == 0) ||
                    (TimeCurrent() - h4_time > m_config.sync_timeout_seconds + h4_seconds);

   // Only fail if BOTH are stale (prevents false positives during lunch breaks/quiet hours)
   if (tick_stale && bar_stale) {
      return false;
   }

   // Check 3: Cross-Timeframe Alignment (Strict Window)
   datetime h1_time = iTime(m_config.symbol, m_config.h1_period, 0);
   if (h4_time == 0 || h1_time == 0) return false;

   datetime h4_end = h4_time + h4_seconds;
   if (h1_time < h4_time || h1_time >= h4_end) {
      PrintFormat("CTrendFilter: H1/H4 misalignment. H4: %s, H1: %s",
                  TimeToString(h4_time), TimeToString(h1_time));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| GetPipSize: Safe XAUUSD Handling                                 |
//+------------------------------------------------------------------+
double CTrendFilter::GetPipSize() {
   double point = SymbolInfoDouble(m_config.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_config.symbol, SYMBOL_DIGITS);

   if (point == 0.0) return 0.01;
   return (digits == 3 || digits == 5) ? point * 10 : point;
}

//+------------------------------------------------------------------+
//| IsSymbolValid: Symbol validation                                 |
//+------------------------------------------------------------------+
bool CTrendFilter::IsSymbolValid() {
   // FIX: Use SYMBOL_SELECT to check if symbol is in Market Watch
   if (!SymbolInfoInteger(m_config.symbol, SYMBOL_SELECT)) {
      PrintFormat("CTrendFilter Error: Symbol %s not found in Market Watch", m_config.symbol);
      // Attempt to select it automatically
      if (SymbolSelect(m_config.symbol, true)) {
         PrintFormat("CTrendFilter Info: Automatically selected %s in Market Watch", m_config.symbol);
         return true;
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Internal Helper: Get MA Value                                    |
//+------------------------------------------------------------------+
double CTrendFilter::GetMAValue(int handle, int shift) {
   double buf[1];
   if (CopyBuffer(handle, 0, shift, 1, buf) != 1) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Internal Helper: Get ADX Value                                   |
//+------------------------------------------------------------------+
double CTrendFilter::GetADXValueInternal(int handle, int shift) {
   double buf[1];
   if (CopyBuffer(handle, 0, shift, 1, buf) != 1) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Internal Helper: Update Cache                                    |
//+------------------------------------------------------------------+
void CTrendFilter::UpdateCache(ENUM_TREND_STATE result, int shift) {
   if (shift == 0) {
      m_last_calc_time = TimeCurrent();
      m_cached_result = result;
   }
}