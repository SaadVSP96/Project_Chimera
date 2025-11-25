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

//+------------------------------------------------------------------+
//| RSI Divergence Detector Class                                    |
//+------------------------------------------------------------------+
class CRSIDivergenceWPricePivots {
  private:
   //--- Dependencies (injected references)
   CMarketDataManager* m_data;

   //--- Configuration (copied from CSignalConfig at init)
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_rsi_period;
   int m_pivot_left;
   int m_pivot_right;
   int m_pivot_tolerance;
   int m_max_divergence_bars;
   double m_rsi_oversold;
   double m_rsi_overbought;

   //--- RSI Indicator Handle
   int m_rsi_handle;

   //--- Pivot Storage (rolling history)
   SPivotPoint m_price_pivots[];
   SPivotPoint m_rsi_pivots[];
   int m_max_pivots;

   //--- State tracking
   datetime m_last_pivot_check_time;
   bool m_initialized;

  public:
   //--- Constructor / Destructor
   CRSIDivergenceWPricePivots(void);
   ~CRSIDivergenceWPricePivots(void);

   //--- Initialization (call after CMarketDataManager is ready)
   bool Initialize(CMarketDataManager* data_manager, const SRSIConfig& config);

   //--- Main Analysis Method
   void Analyze(SRSIDivergenceResult& result);

   //--- Accessors
   double GetCurrentRSI(void);
   int GetPricePivotCount(void) const { return ArraySize(m_price_pivots); }
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
   bool FindMatchingPricePivot(const SPivotPoint& rsi_pivot, SPivotPoint& price_pivot);

   //--- Pivot Management
   void AddPivot(SPivotPoint& arr[], const SPivotPoint& pivot);
   void PrunePivots(SPivotPoint& arr[], int max_age_bars);
   int GetBarShift(datetime time);
   void ResetPivotArrays(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRSIDivergenceWPricePivots::CRSIDivergenceWPricePivots(void) {
   m_data = NULL;
   m_rsi_handle = INVALID_HANDLE;
   m_max_pivots = 50;
   m_last_pivot_check_time = 0;
   m_initialized = false;

   ArrayResize(m_price_pivots, 0);
   ArrayResize(m_rsi_pivots, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRSIDivergenceWPricePivots::~CRSIDivergenceWPricePivots(void) {
   if (m_rsi_handle != INVALID_HANDLE)
      IndicatorRelease(m_rsi_handle);
}

//+------------------------------------------------------------------+
//| Initialize with data manager and config                           |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::Initialize(CMarketDataManager* data_manager, const SRSIConfig& config) {
   // Validate data manager
   if (data_manager == NULL) {
      Print("CRSIDivergenceWPricePivots: ERROR - Data manager is NULL");
      return false;
   }

   m_data = data_manager;

   // Copy configuration
   m_symbol = config.symbol;
   m_timeframe = config.timeframe;
   m_rsi_period = config.rsi_period;
   m_pivot_left = config.pivot_left;
   m_pivot_right = config.pivot_right;
   m_pivot_tolerance = config.pivot_tolerance;
   m_max_divergence_bars = config.max_divergence_bars;
   m_rsi_oversold = config.oversold;
   m_rsi_overbought = config.overbought;

   // Verify symbol exists in data manager
   if (m_data.GetSymbol(m_symbol) == NULL) {
      Print("CRSIDivergenceWPricePivots: ERROR - Symbol ", m_symbol, " not found in data manager");
      return false;
   }

   // Create RSI indicator handle
   m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);

   if (m_rsi_handle == INVALID_HANDLE) {
      Print("CRSIDivergenceWPricePivots: ERROR - Failed to create RSI indicator handle");
      return false;
   }

   ResetPivotArrays();
   m_initialized = true;

   Print("CRSIDivergenceWPricePivots: Initialized for ", m_symbol, " ", EnumToString(m_timeframe),
         " RSI(", m_rsi_period, ") Pivots(L:", m_pivot_left, " R:", m_pivot_right, ")");

   return true;
}

//+------------------------------------------------------------------+
//| Main Analysis - Call each tick                                    |
//+------------------------------------------------------------------+
void CRSIDivergenceWPricePivots::Analyze(SRSIDivergenceResult& result) {
   // Reset result
   result.Reset();

   if (!m_initialized || m_data == NULL)
      return;

   // Candidate bar for pivot detection
   // Bar at index (1 + pivot_right) because:
   // - Bar 0 is still forming
   // - We need pivot_right bars AFTER the candidate to confirm
   int candidate_bar = 1 + m_pivot_right;

   // Detect new pivots
   DetectPivots(candidate_bar);

   // Prune old pivots
   PrunePivots(m_price_pivots, m_max_divergence_bars + 20);
   PrunePivots(m_rsi_pivots, m_max_divergence_bars + 20);

   // Need at least 2 pivots to detect divergence
   if (ArraySize(m_rsi_pivots) < 2 || ArraySize(m_price_pivots) < 2)
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
}

//+------------------------------------------------------------------+
//| Detect pivots at the candidate bar                                |
//+------------------------------------------------------------------+
void CRSIDivergenceWPricePivots::DetectPivots(int candidate_bar) {
   int lookback = candidate_bar + m_pivot_left + 10;

   // Get price data from CMarketDataManager
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

   //--- Detect Price Pivot High ---
   if (IsPivotHigh(candidate_bar, high, lookback)) {
      SPivotPoint p;
      p.type = "H";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = high[candidate_bar];
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_price_pivots, p);
   }

   //--- Detect Price Pivot Low ---
   if (IsPivotLow(candidate_bar, low, lookback)) {
      SPivotPoint p;
      p.type = "L";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = low[candidate_bar];
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_price_pivots, p);
   }

   //--- Detect RSI Pivot High ---
   if (IsPivotHigh(candidate_bar, rsi, lookback)) {
      SPivotPoint p;
      p.type = "H";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = high[candidate_bar];
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_rsi_pivots, p);
   }

   //--- Detect RSI Pivot Low ---
   if (IsPivotLow(candidate_bar, rsi, lookback)) {
      SPivotPoint p;
      p.type = "L";
      p.bar_index = candidate_bar;
      p.time = time[candidate_bar];
      p.price = low[candidate_bar];
      p.rsi = rsi[candidate_bar];
      p.is_valid = true;
      AddPivot(m_rsi_pivots, p);
   }
}

//+------------------------------------------------------------------+
//| Check if bar is a pivot high                                      |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::IsPivotHigh(int bar, const double& data[], int count) {
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
bool CRSIDivergenceWPricePivots::IsPivotLow(int bar, const double& data[], int count) {
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
//| Price: Lower Low, RSI: Higher Low                                 |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::DetectBullishDivergence(SRSIDivergenceResult& result) {
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

   // Find matching Price pivots
   SPivotPoint curr_price, prev_price;

   if (!FindMatchingPricePivot(curr_rsi, curr_price))
      return false;
   if (!FindMatchingPricePivot(prev_rsi, prev_price))
      return false;

   if (curr_price.type != "L" || prev_price.type != "L")
      return false;

   //--- Bullish Divergence ---
   // Price: Lower Low, RSI: Higher Low
   bool price_lower_low = (curr_price.price < prev_price.price);
   bool rsi_higher_low = (curr_rsi.rsi > prev_rsi.rsi);

   if (price_lower_low && rsi_higher_low) {
      // RSI should be in oversold territory
      if (curr_rsi.rsi < m_rsi_oversold) {
         result.pivot_current = curr_price;
         result.pivot_current.rsi = curr_rsi.rsi;
         result.pivot_previous = prev_price;
         result.pivot_previous.rsi = prev_rsi.rsi;
         result.rsi_current = curr_rsi.rsi;
         result.rsi_previous = prev_rsi.rsi;
         result.price_diff = curr_price.price - prev_price.price;
         result.rsi_diff = curr_rsi.rsi - prev_rsi.rsi;
         result.bars_between = bars_between;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Divergence                                         |
//| Price: Higher High, RSI: Lower High                               |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::DetectBearishDivergence(SRSIDivergenceResult& result) {
   int rsi_count = ArraySize(m_rsi_pivots);
   if (rsi_count < 2)
      return false;

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

   int bars_between = GetBarShift(prev_rsi.time) - GetBarShift(curr_rsi.time);
   if (bars_between > m_max_divergence_bars || bars_between < 3)
      return false;

   SPivotPoint curr_price, prev_price;

   if (!FindMatchingPricePivot(curr_rsi, curr_price))
      return false;
   if (!FindMatchingPricePivot(prev_rsi, prev_price))
      return false;

   if (curr_price.type != "H" || prev_price.type != "H")
      return false;

   //--- Bearish Divergence ---
   // Price: Higher High, RSI: Lower High
   bool price_higher_high = (curr_price.price > prev_price.price);
   bool rsi_lower_high = (curr_rsi.rsi < prev_rsi.rsi);

   if (price_higher_high && rsi_lower_high) {
      if (curr_rsi.rsi > m_rsi_overbought) {
         result.pivot_current = curr_price;
         result.pivot_current.rsi = curr_rsi.rsi;
         result.pivot_previous = prev_price;
         result.pivot_previous.rsi = prev_rsi.rsi;
         result.rsi_current = curr_rsi.rsi;
         result.rsi_previous = prev_rsi.rsi;
         result.price_diff = curr_price.price - prev_price.price;
         result.rsi_diff = curr_rsi.rsi - prev_rsi.rsi;
         result.bars_between = bars_between;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Find price pivot that matches RSI pivot within tolerance          |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::FindMatchingPricePivot(const SPivotPoint& rsi_pivot,
                                                        SPivotPoint& price_pivot) {
   int price_count = ArraySize(m_price_pivots);
   int rsi_bar = GetBarShift(rsi_pivot.time);

   for (int i = price_count - 1; i >= 0; i--) {
      if (m_price_pivots[i].type != rsi_pivot.type)
         continue;

      int price_bar = GetBarShift(m_price_pivots[i].time);
      int bar_diff = MathAbs(price_bar - rsi_bar);

      if (bar_diff <= m_pivot_tolerance) {
         price_pivot = m_price_pivots[i];
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Add pivot to array                                                |
//+------------------------------------------------------------------+
void CRSIDivergenceWPricePivots::AddPivot(SPivotPoint& arr[], const SPivotPoint& pivot) {
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = pivot;

   if (size + 1 > m_max_pivots)
      ArrayRemove(arr, 0, 1);
}

//+------------------------------------------------------------------+
//| Remove old pivots                                                 |
//+------------------------------------------------------------------+
void CRSIDivergenceWPricePivots::PrunePivots(SPivotPoint& arr[], int max_age_bars) {
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
int CRSIDivergenceWPricePivots::GetBarShift(datetime time) {
   return iBarShift(m_symbol, m_timeframe, time);
}

//+------------------------------------------------------------------+
//| Copy RSI indicator buffer                                         |
//+------------------------------------------------------------------+
bool CRSIDivergenceWPricePivots::CopyRSIBuffer(double& buffer[], int count) {
   ArraySetAsSeries(buffer, true);
   ArrayResize(buffer, count);

   int copied = CopyBuffer(m_rsi_handle, 0, 0, count, buffer);
   return (copied == count);
}

//+------------------------------------------------------------------+
//| Get current RSI value                                             |
//+------------------------------------------------------------------+
double CRSIDivergenceWPricePivots::GetCurrentRSI(void) {
   double rsi[1];
   if (CopyBuffer(m_rsi_handle, 0, 0, 1, rsi) == 1)
      return rsi[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Reset pivot arrays                                                |
//+------------------------------------------------------------------+
void CRSIDivergenceWPricePivots::ResetPivotArrays(void) {
   ArrayFree(m_price_pivots);
   ArrayFree(m_rsi_pivots);
   ArrayResize(m_price_pivots, 0);
   ArrayResize(m_rsi_pivots, 0);
   m_last_pivot_check_time = 0;
}