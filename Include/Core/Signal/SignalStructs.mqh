//+------------------------------------------------------------------+
//|                                               SignalStructs.mqh  |
//|                         Chimera EA - Signal State Structures     |
//+------------------------------------------------------------------+
#property copyright "Chimera Project"
#property strict

//+------------------------------------------------------------------+
//| Pivot Point - A confirmed swing high or low                      |
//+------------------------------------------------------------------+
struct SPivotPoint {
   string type;    // "H" = High, "L" = Low
   int bar_index;  // Bar shift when detected
   datetime time;  // Timestamp of the pivot bar
   double price;   // High or Low price at pivot
   double rsi;     // RSI value at pivot bar
   bool is_valid;  // Validation flag

   // Constructor - initialize to invalid
   void Reset() {
      type = "";
      bar_index = -1;
      time = 0;
      price = 0.0;
      rsi = 0.0;
      is_valid = false;
   }
};

//+------------------------------------------------------------------+
//| RSI Divergence Result                                            |
//+------------------------------------------------------------------+
struct SRSIDivergenceResult {
   bool detected;    // Was divergence found?
   bool is_bullish;  // true = bullish, false = bearish

   double rsi_current;
   double rsi_previous;

   SPivotPoint pivot_current;   // Most recent pivot in divergence
   SPivotPoint pivot_previous;  // Earlier pivot in divergence

   double price_diff;  // Price difference between pivots
   double rsi_diff;    // RSI difference between pivots
   int bars_between;   // Bar distance between pivots

   datetime detection_time;  // When divergence was detected

   void Reset() {
      detected = false;
      is_bullish = false;
      pivot_current.Reset();
      pivot_previous.Reset();
      price_diff = 0.0;
      rsi_diff = 0.0;
      bars_between = 0;
      detection_time = 0;
   }
};

// Correlation result
struct SCorrelationResult {
   double value;          // -1.0 to +1.0
   bool meets_threshold;  // < -0.6
   bool is_strong;        // < -0.7
   double signal_boost;   // 1.0 to 1.3
};

// Trend alignment result
struct STrendResult {
   int h4_direction;  // +1 UP, -1 DOWN, 0 NONE
   int h1_direction;
   bool h4_h1_aligned;
   double adx_value;
   bool is_trending;  // ADX > 25
};

// Session/Spread filter result
struct SFilterResult {
   bool session_valid;  // London or NY
   bool spread_valid;   // < 25 pips
   double current_spread;
};

// (Future: Harmonic patterns, etc.)