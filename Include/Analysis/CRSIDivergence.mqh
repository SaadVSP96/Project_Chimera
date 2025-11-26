//+------------------------------------------------------------------+
//|                                               CRSIDivergence.mqh |
//|                    RSI Divergence Detection using Pivot Analysis |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property strict

#include "../Config/SignalConfig.mqh"
#include "../Core/MarketData/CMarketDataManager.mqh"
#include "../Core/Signal/SignalStructs.mqh"
#include "../Core/VisualizationLibrary/ChartObjectsVisualization.mqh"

//+------------------------------------------------------------------+
//| RSI Divergence Detector Class                                    |
//+------------------------------------------------------------------+
class CRSIDivergence {
  private:
   //--- Dependencies (injected references)
   CMarketDataManager* m_data;

   //--- Configuration (copied from CSignalConfig at init)
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_rsi_period;
   int m_pivot_left;
   int m_pivot_right;
   int m_max_divergence_bars;
   double m_rsi_oversold;
   double m_rsi_overbought;

   //--- RSI Indicator Handle
   int m_rsi_handle;

   //--- Pivot Storage (RSI pivots only - price pivots removed)
   SPivotPoint m_rsi_pivots[];
   int m_max_pivots;

   //--- State tracking
   datetime m_last_pivot_check_time;
   bool m_initialized;
   bool m_is_new_bar;

   // Visulaization instances
   double m_rsi_buffer[];
   int m_rsi_buffer_size;
   CLabel* m_rsi_pivot_high_labels;
   CLabel* m_rsi_pivot_low_labels;
   CIndicatorLine* m_rsi_indicator_plot;

  public:
   //--- Constructor / Destructor
   CRSIDivergence(void);
   ~CRSIDivergence(void);

   //--- Initialization (call after CMarketDataManager is ready)
   bool Initialize(CMarketDataManager* data_manager, const SRSIConfig& config);

   //--- Main Analysis Method
   void Analyze(SRSIDivergenceResult& result, bool is_new_bar);

   //--- Accessors
   double GetCurrentRSI(void);
   int GetRSIPivotCount(void) const { return ArraySize(m_rsi_pivots); }
   bool IsInitialized(void) const { return m_initialized; }

  private:
   //--- RSI Calculation
   bool CopyRSIBuffer(double& buffer[], int count);

   //--- Pivot Detection
   void DetectPivots(int candidate_bar);
   bool IsPivotHigh(int bar, const double& data[], int count);
   bool IsPivotLow(int bar, const double& data[], int count);

   //--- Divergence Detection
   bool DetectBullishDivergence(SRSIDivergenceResult& result);
   bool DetectBearishDivergence(SRSIDivergenceResult& result);

   //--- Pivot Management
   void AddPivot(SPivotPoint& arr[], const SPivotPoint& pivot);
   void PrunePivots(SPivotPoint& arr[], int max_age_bars);
   int GetBarShift(datetime time);
   void ResetPivotArrays(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRSIDivergence::CRSIDivergence(void) {
   m_data = NULL;
   m_rsi_handle = INVALID_HANDLE;
   m_max_pivots = 50;
   m_last_pivot_check_time = 0;
   m_initialized = false;
   m_rsi_pivot_high_labels = NULL;
   m_rsi_pivot_low_labels = NULL;
   m_rsi_indicator_plot = NULL;
   ArrayResize(m_rsi_pivots, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRSIDivergence::~CRSIDivergence(void) {
   if (m_rsi_handle != INVALID_HANDLE)
      IndicatorRelease(m_rsi_handle);

   // NEW: Cleanup visualization
   if (m_rsi_indicator_plot != NULL) {
      m_rsi_indicator_plot.Delete();
      delete m_rsi_indicator_plot;
      m_rsi_indicator_plot = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize with data manager and config                           |
//+------------------------------------------------------------------+
bool CRSIDivergence::Initialize(CMarketDataManager* data_manager, const SRSIConfig& config) {
   // Validate data manager
   if (data_manager == NULL) {
      Print("CRSIDivergence: ERROR - Data manager is NULL");
      return false;
   }

   m_data = data_manager;

   // Copy configuration
   m_symbol = config.symbol;
   m_timeframe = config.timeframe;
   m_rsi_period = config.rsi_period;
   m_pivot_left = config.pivot_left;
   m_pivot_right = config.pivot_right;
   // m_pivot_tolerance = config.pivot_tolerance;  // COMMENTED OUT - no longer needed
   m_max_divergence_bars = config.max_divergence_bars;
   m_rsi_oversold = config.oversold;
   m_rsi_overbought = config.overbought;

   // Verify symbol exists in data manager
   if (m_data.GetSymbol(m_symbol) == NULL) {
      Print("CRSIDivergence: ERROR - Symbol ", m_symbol, " not found in data manager");
      return false;
   }

   // Create RSI indicator handle
   m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);

   if (m_rsi_handle == INVALID_HANDLE) {
      Print("CRSIDivergence: ERROR - Failed to create RSI indicator handle");
      return false;
   }

   ResetPivotArrays();
   m_initialized = true;

   // call constructor and assign instance to pointer in private vars
   m_rsi_pivot_high_labels = new CLabel("RSIPivotHigh", config.max_no_rsi_pivot_highs_to_display, 0);
   m_rsi_pivot_low_labels = new CLabel("RSIPivotLow", config.max_no_rsi_pivot_lows_to_display, 0);

   // NEW: Initialize RSI buffer
   m_rsi_buffer_size = config.rsi_buffer_size;
   ArrayResize(m_rsi_buffer, m_rsi_buffer_size);
   ArraySetAsSeries(m_rsi_buffer, true);

   // NEW: Create indicator line visualization
   if (config.rsi_line_visualization_enabled) {
      m_rsi_indicator_plot = new CIndicatorLine("RSIIndicatorLine", config.rsi_line_chart_id);
      m_rsi_indicator_plot.SetDataSource(m_rsi_buffer);
   }

   Print("CRSIDivergence: Initialized for ", m_symbol, " ", EnumToString(m_timeframe),
         " RSI(", m_rsi_period, ") Pivots(L:", m_pivot_left, " R:", m_pivot_right, ")");

   return true;
}

//+------------------------------------------------------------------+
//| Main Analysis - Call each tick                                    |
//| SIMPLIFIED: Only detects RSI pivots, no price pivot matching      |
//+------------------------------------------------------------------+
void CRSIDivergence::Analyze(SRSIDivergenceResult& result, bool is_new_bar) {
   // Reset result
   result.Reset();

   if (!m_initialized || m_data == NULL)
      return;

   // NEW: Update RSI buffer every tick
   if (!CopyBuffer(m_rsi_handle, 0, 0, m_rsi_buffer_size, m_rsi_buffer)) {
      return;
   }

   // NEW: Redraw indicator visualization every tick
   if (m_rsi_indicator_plot != NULL) {
      m_rsi_indicator_plot.Redraw(m_rsi_buffer);
   }

   // Candidate bar for pivot detection
   // Bar at index (1 + pivot_right) because:
   // - Bar 0 is still forming
   // - We need pivot_right bars AFTER the candidate to confirm
   int candidate_bar = 1 + m_pivot_right;

   // Detect new pivots (RSI line only)
   DetectPivots(candidate_bar);

   // Prune old pivots
   PrunePivots(m_rsi_pivots, m_max_divergence_bars + 20);

   // Need at least 2 pivots to detect divergence
   if (ArraySize(m_rsi_pivots) < 2)
      return;

   // Check for bullish divergence first
   if (DetectBullishDivergence(result)) {
      result.detected = true;
      result.is_bullish = true;
      result.detection_time = TimeCurrent();
      return;
   }

   // Check for bearish divergence
   if (DetectBearishDivergence(result)) {
      result.detected = true;
      result.is_bullish = false;
      result.detection_time = TimeCurrent();
      return;
   }
   if (is_new_bar) {
      // Cleanup old objects
      m_rsi_pivot_high_labels.Cleanup();
      m_rsi_pivot_low_labels.Cleanup();
   }
}

//+------------------------------------------------------------------+
//| Detect pivots at the candidate bar                                |
//| RSI PIVOTS ONLY - no price pivots                                 |
//| RSI pivot acts as anchor point, price values captured directly    |
//+------------------------------------------------------------------+
void CRSIDivergence::DetectPivots(int candidate_bar) {
   int lookback = candidate_bar + m_pivot_left + 10;

   // Get data from CMarketDataManager+
   double high[], low[];
   datetime time[];
   double rsi[];

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(rsi, true);

   ArrayResize(high, lookback);
   ArrayResize(low, lookback);
   ArrayResize(time, lookback);

   // Copy from data manager
   for (int i = 0; i < lookback; i++) {
      high[i] = m_data.High(m_symbol, m_timeframe, i);
      low[i] = m_data.Low(m_symbol, m_timeframe, i);
      time[i] = m_data.Time(m_symbol, m_timeframe, i);
   }

   // Copy RSI buffer
   if (!CopyRSIBuffer(rsi, lookback))
      return;

   // Skip if already processed this bar
   if (time[candidate_bar] == m_last_pivot_check_time)
      return;

   m_last_pivot_check_time = time[candidate_bar];

   //--- Detect RSI Pivot High ---
   // When RSI forms a pivot high, capture:
   // - RSI value at that bar
   // - Price HIGH at that same bar (for divergence comparison)
   if (IsPivotHigh(candidate_bar, rsi, lookback)) {
      SPivotPoint p;
      p.type = "H";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = high[candidate_bar];  // Capture price HIGH at RSI pivot bar
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_rsi_pivots, p);
      m_rsi_pivot_high_labels.Draw(p.time, p.price, "RSI_H", clrRed, 8, ANCHOR_RIGHT_UPPER);
   }

   //--- Detect RSI Pivot Low ---
   // When RSI forms a pivot low, capture:
   // - RSI value at that bar
   // - Price LOW at that same bar (for divergence comparison)
   if (IsPivotLow(candidate_bar, rsi, lookback)) {
      SPivotPoint p;
      p.type = "L";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = low[candidate_bar];  // Capture price LOW at RSI pivot bar
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_rsi_pivots, p);
      m_rsi_pivot_low_labels.Draw(p.time, p.price, "RSI_L", clrGreen, 8, ANCHOR_RIGHT_LOWER);
   }
}

//+------------------------------------------------------------------+
//| Check if bar is a pivot high                                      |
//+------------------------------------------------------------------+
bool CRSIDivergence::IsPivotHigh(int bar, const double& data[], int count) {
   if (bar + m_pivot_left >= count || bar - m_pivot_right < 0)
      return false;

   double pivot_value = data[bar];

   // Left side (older bars): all must be strictly LOWER
   for (int i = 1; i <= m_pivot_left; i++) {
      if (data[bar + i] >= pivot_value)
         return false;
   }

   // Right side (newer bars): all must be strictly LOWER
   for (int i = 1; i <= m_pivot_right; i++) {
      if (data[bar - i] >= pivot_value)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a pivot low                                       |
//+------------------------------------------------------------------+
bool CRSIDivergence::IsPivotLow(int bar, const double& data[], int count) {
   if (bar + m_pivot_left >= count || bar - m_pivot_right < 0)
      return false;

   double pivot_value = data[bar];

   // Left side (older bars): all must be strictly HIGHER
   for (int i = 1; i <= m_pivot_left; i++) {
      if (data[bar + i] <= pivot_value)
         return false;
   }

   // Right side (newer bars): all must be strictly HIGHER
   for (int i = 1; i <= m_pivot_right; i++) {
      if (data[bar - i] <= pivot_value)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Detect Bullish Divergence                                         |
//| Pattern: Price Lower Low && RSI Higher Low                        |
//| Uses RSI pivots directly - NO price pivot matching                |
//| Process:                                                           |
//| 1. Find two most recent RSI Lows (type=="L")                      |
//| 2. Compare their RSI values: newer > older = Higher Low ✓         |
//| 3. Compare their PRICE values: newer < older = Lower Low ✓        |
//| 4. Ensure RSI is in oversold (<30)                                |
//+------------------------------------------------------------------+
bool CRSIDivergence::DetectBullishDivergence(SRSIDivergenceResult& result) {
   int rsi_count = ArraySize(m_rsi_pivots);
   if (rsi_count < 2)
      return false;

   // Find two most recent RSI Lows
   SPivotPoint curr_rsi, prev_rsi;
   bool found_curr = false, found_prev = false;

   for (int i = rsi_count - 1; i >= 0 && !found_curr; i--) {
      if (m_rsi_pivots[i].type == "L") {
         curr_rsi = m_rsi_pivots[i];
         found_curr = true;

         for (int j = i - 1; j >= 0 && !found_prev; j--) {
            if (m_rsi_pivots[j].type == "L") {
               prev_rsi = m_rsi_pivots[j];
               found_prev = true;
            }
         }
      }
   }

   if (!found_curr || !found_prev)
      return false;

   // Check divergence age
   int bars_between = GetBarShift(prev_rsi.time) - GetBarShift(curr_rsi.time);
   if (bars_between > m_max_divergence_bars || bars_between < 3)
      return false;

   //--- Bullish Divergence Conditions ---
   // Compare RSI values at the two pivot bars
   bool rsi_higher_low = (curr_rsi.rsi > prev_rsi.rsi);

   // Compare PRICE values at the two pivot bars
   // (captured when RSI pivots were detected)
   bool price_lower_low = (curr_rsi.price < prev_rsi.price);

   if (price_lower_low && rsi_higher_low) {
      // RSI must be in oversold territory for valid bullish divergence
      if (curr_rsi.rsi < m_rsi_oversold) {
         result.pivot_current = curr_rsi;
         result.pivot_previous = prev_rsi;
         result.rsi_current = curr_rsi.rsi;
         result.rsi_previous = prev_rsi.rsi;
         result.price_diff = curr_rsi.price - prev_rsi.price;
         result.rsi_diff = curr_rsi.rsi - prev_rsi.rsi;
         result.bars_between = bars_between;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Divergence                                         |
//| Pattern: Price Higher High && RSI Lower High                      |
//| Uses RSI pivots directly - NO price pivot matching                |
//| Process:                                                           |
//| 1. Find two most recent RSI Highs (type=="H")                     |
//| 2. Compare their RSI values: newer < older = Lower High ✓         |
//| 3. Compare their PRICE values: newer > older = Higher High ✓      |
//| 4. Ensure RSI is in overbought (>70)                              |
//+------------------------------------------------------------------+
bool CRSIDivergence::DetectBearishDivergence(SRSIDivergenceResult& result) {
   int rsi_count = ArraySize(m_rsi_pivots);
   if (rsi_count < 2)
      return false;

   // Find two most recent RSI Highs
   SPivotPoint curr_rsi, prev_rsi;
   bool found_curr = false, found_prev = false;

   for (int i = rsi_count - 1; i >= 0 && !found_curr; i--) {
      if (m_rsi_pivots[i].type == "H") {
         curr_rsi = m_rsi_pivots[i];
         found_curr = true;

         for (int j = i - 1; j >= 0 && !found_prev; j--) {
            if (m_rsi_pivots[j].type == "H") {
               prev_rsi = m_rsi_pivots[j];
               found_prev = true;
            }
         }
      }
   }

   if (!found_curr || !found_prev)
      return false;

   // Check divergence age
   int bars_between = GetBarShift(prev_rsi.time) - GetBarShift(curr_rsi.time);
   if (bars_between > m_max_divergence_bars || bars_between < 3)
      return false;

   //--- Bearish Divergence Conditions ---
   // Compare RSI values at the two pivot bars
   bool rsi_lower_high = (curr_rsi.rsi < prev_rsi.rsi);

   // Compare PRICE values at the two pivot bars
   // (captured when RSI pivots were detected)
   bool price_higher_high = (curr_rsi.price > prev_rsi.price);

   if (price_higher_high && rsi_lower_high) {
      // RSI must be in overbought territory for valid bearish divergence
      if (curr_rsi.rsi > m_rsi_overbought) {
         result.pivot_current = curr_rsi;
         result.pivot_previous = prev_rsi;
         result.rsi_current = curr_rsi.rsi;
         result.rsi_previous = prev_rsi.rsi;
         result.price_diff = curr_rsi.price - prev_rsi.price;
         result.rsi_diff = curr_rsi.rsi - prev_rsi.rsi;
         result.bars_between = bars_between;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Add pivot to array                                                |
//+------------------------------------------------------------------+
void CRSIDivergence::AddPivot(SPivotPoint& arr[], const SPivotPoint& pivot) {
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = pivot;

   if (size + 1 > m_max_pivots)
      ArrayRemove(arr, 0, 1);
}

//+------------------------------------------------------------------+
//| Remove old pivots                                                 |
//+------------------------------------------------------------------+
void CRSIDivergence::PrunePivots(SPivotPoint& arr[], int max_age_bars) {
   int size = ArraySize(arr);
   if (size == 0) return;

   int first_valid = 0;
   for (int i = 0; i < size; i++) {
      int bar_shift = GetBarShift(arr[i].time);
      if (bar_shift <= max_age_bars) {
         first_valid = i;
         break;
      }
      first_valid = i + 1;
   }

   if (first_valid > 0 && first_valid < size)
      ArrayRemove(arr, 0, first_valid);
}

//+------------------------------------------------------------------+
//| Get bar shift from datetime                                       |
//+------------------------------------------------------------------+
int CRSIDivergence::GetBarShift(datetime time) {
   return iBarShift(m_symbol, m_timeframe, time);
}

//+------------------------------------------------------------------+
//| Copy RSI indicator buffer                                         |
//+------------------------------------------------------------------+
bool CRSIDivergence::CopyRSIBuffer(double& buffer[], int count) {
   ArraySetAsSeries(buffer, true);
   ArrayResize(buffer, count);

   int copied = CopyBuffer(m_rsi_handle, 0, 0, count, buffer);
   return (copied == count);
}

//+------------------------------------------------------------------+
//| Get current RSI value                                             |
//+------------------------------------------------------------------+
double CRSIDivergence::GetCurrentRSI(void) {
   double rsi[1];
   if (CopyBuffer(m_rsi_handle, 0, 0, 1, rsi) == 1)
      return rsi[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Reset pivot arrays                                                |
//+------------------------------------------------------------------+
void CRSIDivergence::ResetPivotArrays(void) {
   ArrayFree(m_rsi_pivots);
   ArrayResize(m_rsi_pivots, 0);
   m_last_pivot_check_time = 0;
}
