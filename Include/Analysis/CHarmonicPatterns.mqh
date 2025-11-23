//+------------------------------------------------------------------+
//|                                           CHarmonicPatterns.mqh  |
//|                    Harmonic Pattern Detection (XABCD Patterns)   |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property strict

#include "../Config/SignalConfig.mqh"
#include "../Core/MarketData/CMarketDataManager.mqh"
#include "../Core/Signal/SignalStructs.mqh"

//+------------------------------------------------------------------+
//| Harmonic Patterns Analyzer Class                                 |
//+------------------------------------------------------------------+
class CHarmonicPatterns {
  private:
   //--- Dependencies
   CMarketDataManager* m_data;
   CTimeframeData* m_tf_data;  // Direct access to timeframe buffers

   //--- Resolved from config
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   //--- Configuration
   int m_pivot_left;
   int m_pivot_right;
   int m_max_pivots;
   SPatternRatios m_patterns[4];
   double m_ratio_tolerance;
   double m_prz_tolerance_pips;
   bool m_check_X_break;
   int m_max_pattern_age_bars;
   double m_point;  // Point size for pip calculation

   //--- State
   bool m_initialized;
   SHarmonicPivot m_pivots[];  // Series array (0 = most recent)
   datetime m_last_pivot_check;

   //--- Current pattern tracking
   SHarmonicPatternResult m_current_result;
   bool m_monitoring_patterns;  // Are we waiting for any D?

  public:
   //--- Constructor / Destructor
   CHarmonicPatterns(void);
   ~CHarmonicPatterns(void);

   //--- Initialization
   bool Initialize(CMarketDataManager* data_manager, const SHarmonicConfig& config);

   //--- Main Methods
   void Update(bool is_new_bar);
   void Analyze(SHarmonicPatternResult& result);

   //--- Accessors
   bool IsInitialized(void) const { return m_initialized; }
   int GetPivotCount(void) const { return ArraySize(m_pivots); }
   string GetSymbol(void) const { return m_symbol; }

  private:
   //--- Pivot Detection (runs on new bar only)
   void DetectNewPivot(void);
   bool IsPivotHigh(int bar);
   bool IsPivotLow(int bar);
   void AddPivot(const SHarmonicPivot& pivot);
   void PrunePivots(void);

   //--- Pattern Validation
   void CheckForPatterns(void);
   bool ValidateBullishXABC(void);
   bool ValidateBearishXABC(void);
   void CheckAllPatternRatios(bool is_bullish);
   bool CheckPatternRatios(int pattern_idx, SSinglePatternState& state,
                           double XA, double AB, double BC, bool is_bullish);

   //--- PRZ Monitoring (runs every tick)
   void MonitorPRZ(void);
   bool IsPriceInPRZ(double current_price, double D_price);

   //--- Invalidation
   bool IsPatternInvalidated(void);
   void ResetPattern(void);

   //--- Utilities
   double CalculateDistance(double price1, double price2);
   double CalculateRatio(double leg1, double leg2);
   int GetBarShift(datetime time);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CHarmonicPatterns::CHarmonicPatterns(void) {
   m_data = NULL;
   m_tf_data = NULL;
   m_symbol = "";
   m_timeframe = PERIOD_M15;
   m_pivot_left = 5;
   m_pivot_right = 3;
   m_max_pivots = 50;
   m_ratio_tolerance = 0.02;
   m_prz_tolerance_pips = 10.0;
   m_check_X_break = true;
   m_max_pattern_age_bars = 100;
   m_point = _Point;
   m_initialized = false;
   m_last_pivot_check = 0;
   m_monitoring_patterns = false;

   ArrayResize(m_pivots, 0);
   ArraySetAsSeries(m_pivots, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CHarmonicPatterns::~CHarmonicPatterns(void) {
   // No dynamic allocations to clean up
}

//+------------------------------------------------------------------+
//| Initialize with data manager and config                           |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::Initialize(CMarketDataManager* data_manager,
                                   const SHarmonicConfig& config) {
   // Validate data manager
   if (data_manager == NULL) {
      Print("CHarmonicPatterns: ERROR - Data manager is NULL");
      return false;
   }

   m_data = data_manager;

   // Resolve symbol from index
   m_symbol = m_data.GetSymbolName(config.symbol_index);
   if (m_symbol == "") {
      Print("CHarmonicPatterns: ERROR - Invalid symbol_index: ", config.symbol_index);
      return false;
   }

   // Verify symbol exists
   if (m_data.GetSymbol(m_symbol) == NULL) {
      Print("CHarmonicPatterns: ERROR - Symbol ", m_symbol, " not found");
      return false;
   }

   // Get direct timeframe data access
   m_timeframe = config.timeframe;
   m_tf_data = m_data.GetSymbol(m_symbol).GetTimeframeData(m_timeframe);
   if (m_tf_data == NULL) {
      Print("CHarmonicPatterns: ERROR - Timeframe ", EnumToString(m_timeframe), " not found");
      return false;
   }

   // Copy configuration
   m_pivot_left = config.pivot_left;
   m_pivot_right = config.pivot_right;
   m_max_pivots = config.max_pivots;
   m_ratio_tolerance = config.ratio_tolerance;
   m_prz_tolerance_pips = config.prz_tolerance_pips;
   m_check_X_break = config.check_X_break;
   m_max_pattern_age_bars = config.max_pattern_age_bars;

   // Copy pattern configs
   for (int i = 0; i < 4; i++) {
      m_patterns[i] = config.patterns[i];
   }

   // Get point size
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

   // Initial pivot scan (historical)
   Print("CHarmonicPatterns: Scanning historical pivots...");
   int scanned = 0;
   int lookback = 200;  // Scan 200 bars back

   for (int bar = m_pivot_right + 1; bar < lookback; bar++) {
      if (IsPivotHigh(bar)) {
         SHarmonicPivot p;
         p.type = "H";
         p.bar_index = bar;
         p.time = m_tf_data.m_time[bar];
         p.price = m_tf_data.m_high[bar];
         p.is_valid = true;
         AddPivot(p);
         scanned++;
      }

      if (IsPivotLow(bar)) {
         SHarmonicPivot p;
         p.type = "L";
         p.bar_index = bar;
         p.time = m_tf_data.m_time[bar];
         p.price = m_tf_data.m_low[bar];
         p.is_valid = true;
         AddPivot(p);
         scanned++;
      }
   }

   m_initialized = true;

   Print("CHarmonicPatterns: Initialized");
   Print("  Symbol: ", m_symbol, " (index ", config.symbol_index, ")");
   Print("  Timeframe: ", EnumToString(m_timeframe));
   Print("  Pivot Strength: L=", m_pivot_left, " R=", m_pivot_right);
   Print("  Initial Pivots Found: ", scanned);
   Print("  Enabled Patterns: ",
         (m_patterns[0].enabled ? "Gartley " : ""),
         (m_patterns[1].enabled ? "Bat " : ""),
         (m_patterns[2].enabled ? "ABCD " : ""),
         (m_patterns[3].enabled ? "Cypher" : ""));

   return true;
}

//+------------------------------------------------------------------+
//| Update - Called every tick                                        |
//+------------------------------------------------------------------+
void CHarmonicPatterns::Update(bool is_new_bar) {
   if (!m_initialized || m_tf_data == NULL)
      return;

   //--- Only detect pivots on new bar
   if (is_new_bar) {
      DetectNewPivot();

      // Check if we have enough pivots to form pattern
      if (ArraySize(m_pivots) >= 4) {
         CheckForPatterns();
      }
   }

   //--- Monitor PRZ every tick (if patterns active)
   if (m_monitoring_patterns) {
      MonitorPRZ();

      // Check invalidation
      if (IsPatternInvalidated()) {
         ResetPattern();
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze - Return current pattern state                            |
//+------------------------------------------------------------------+
void CHarmonicPatterns::Analyze(SHarmonicPatternResult& result) {
   result = m_current_result;
}

//+------------------------------------------------------------------+
//| Detect new pivot at candidate bar                                 |
//+------------------------------------------------------------------+
void CHarmonicPatterns::DetectNewPivot(void) {
   int candidate_bar = m_pivot_right + 1;

   // Skip if not enough data
   if (candidate_bar + m_pivot_left >= m_tf_data.m_buffer_size)
      return;

   datetime candidate_time = m_tf_data.m_time[candidate_bar];

   // Skip if already checked this bar
   if (candidate_time == m_last_pivot_check)
      return;

   m_last_pivot_check = candidate_time;

   //--- Check Pivot High
   if (IsPivotHigh(candidate_bar)) {
      SHarmonicPivot p;
      p.type = "H";
      p.bar_index = candidate_bar;
      p.time = candidate_time;
      p.price = m_tf_data.m_high[candidate_bar];
      p.is_valid = true;
      AddPivot(p);

      Print("CHarmonicPatterns: New Pivot HIGH at ",
            TimeToString(p.time, TIME_DATE | TIME_MINUTES),
            " Price: ", DoubleToString(p.price, 2));
   }

   //--- Check Pivot Low
   if (IsPivotLow(candidate_bar)) {
      SHarmonicPivot p;
      p.type = "L";
      p.bar_index = candidate_bar;
      p.time = candidate_time;
      p.price = m_tf_data.m_low[candidate_bar];
      p.is_valid = true;
      AddPivot(p);

      Print("CHarmonicPatterns: New Pivot LOW at ",
            TimeToString(p.time, TIME_DATE | TIME_MINUTES),
            " Price: ", DoubleToString(p.price, 2));
   }
}

//+------------------------------------------------------------------+
//| Check if bar is a pivot high                                      |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsPivotHigh(int bar) {
   if (bar + m_pivot_left >= m_tf_data.m_buffer_size || bar - m_pivot_right < 0)
      return false;

   double pivot_value = m_tf_data.m_high[bar];

   // Left side: all must be strictly lower
   for (int i = 1; i <= m_pivot_left; i++) {
      if (m_tf_data.m_high[bar + i] >= pivot_value)
         return false;
   }

   // Right side: all must be strictly lower
   for (int i = 1; i <= m_pivot_right; i++) {
      if (m_tf_data.m_high[bar - i] >= pivot_value)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a pivot low                                       |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsPivotLow(int bar) {
   if (bar + m_pivot_left >= m_tf_data.m_buffer_size || bar - m_pivot_right < 0)
      return false;

   double pivot_value = m_tf_data.m_low[bar];

   // Left side: all must be strictly higher
   for (int i = 1; i <= m_pivot_left; i++) {
      if (m_tf_data.m_low[bar + i] <= pivot_value)
         return false;
   }

   // Right side: all must be strictly higher
   for (int i = 1; i <= m_pivot_right; i++) {
      if (m_tf_data.m_low[bar - i] <= pivot_value)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Add pivot to buffer (series array, 0 = most recent)               |
//+------------------------------------------------------------------+
void CHarmonicPatterns::AddPivot(const SHarmonicPivot& pivot) {
   int size = ArraySize(m_pivots);

   // Resize and insert at [0]
   ArrayResize(m_pivots, size + 1);

   // Shift existing pivots
   for (int i = size; i > 0; i--)
      m_pivots[i] = m_pivots[i - 1];

   m_pivots[0] = pivot;

   // Prune if exceeds max
   PrunePivots();
}

//+------------------------------------------------------------------+
//| Prune old pivots                                                  |
//+------------------------------------------------------------------+
void CHarmonicPatterns::PrunePivots(void) {
   int size = ArraySize(m_pivots);
   if (size > m_max_pivots) {
      ArrayResize(m_pivots, m_max_pivots);
   }
}

//+------------------------------------------------------------------+
//| Check for valid XABCD patterns                                    |
//+------------------------------------------------------------------+
void CHarmonicPatterns::CheckForPatterns(void) {
   // Need at least 4 pivots
   if (ArraySize(m_pivots) < 4)
      return;

   //--- Extract most recent 4 pivots
   // Remember: pivots[0] = most recent (C), pivots[3] = oldest (X)
   SHarmonicPivot C = m_pivots[0];
   SHarmonicPivot B = m_pivots[1];
   SHarmonicPivot A = m_pivots[2];
   SHarmonicPivot X = m_pivots[3];

   //--- Check if sequence is valid
   bool bullish = ValidateBullishXABC();  // H-L-H-L
   bool bearish = ValidateBearishXABC();  // L-H-L-H

   if (!bullish && !bearish) {
      // Invalid sequence (consecutive same types)
      return;
   }

   //--- Store pivots in result
   m_current_result.X = X;
   m_current_result.A = A;
   m_current_result.B = B;
   m_current_result.C = C;
   m_current_result.is_bullish = bullish;
   m_current_result.XABCD_structure_valid = true;

   Print("CHarmonicPatterns: Valid ", (bullish ? "BULLISH" : "BEARISH"), " XABCD structure detected");
   Print("  X: ", X.type, " @ ", DoubleToString(X.price, 2));
   Print("  A: ", A.type, " @ ", DoubleToString(A.price, 2));
   Print("  B: ", B.type, " @ ", DoubleToString(B.price, 2));
   Print("  C: ", C.type, " @ ", DoubleToString(C.price, 2));

   //--- Check ratios for all enabled patterns
   CheckAllPatternRatios(bullish);

   //--- Enter monitoring mode if any pattern valid
   if (m_current_result.any_pattern_detected) {
      m_monitoring_patterns = true;
      m_current_result.detection_time = TimeCurrent();

      Print("CHarmonicPatterns: Entering monitoring mode");
   }
}

//+------------------------------------------------------------------+
//| Validate bullish XABCD sequence (H-L-H-L)                         |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateBullishXABC(void) {
   if (ArraySize(m_pivots) < 4) return false;

   // X=H, A=L, B=H, C=L
   return (m_pivots[3].type == "H" &&
           m_pivots[2].type == "L" &&
           m_pivots[1].type == "H" &&
           m_pivots[0].type == "L");
}

//+------------------------------------------------------------------+
//| Validate bearish XABCD sequence (L-H-L-H)                         |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateBearishXABC(void) {
   if (ArraySize(m_pivots) < 4) return false;

   // X=L, A=H, B=L, C=H
   return (m_pivots[3].type == "L" &&
           m_pivots[2].type == "H" &&
           m_pivots[1].type == "L" &&
           m_pivots[0].type == "H");
}

//+------------------------------------------------------------------+
//| Check all enabled patterns for ratio matches                      |
//+------------------------------------------------------------------+
void CHarmonicPatterns::CheckAllPatternRatios(bool is_bullish) {
   m_current_result.any_pattern_detected = false;

   // Calculate leg distances
   double XA = CalculateDistance(m_current_result.X.price, m_current_result.A.price);
   double AB = CalculateDistance(m_current_result.A.price, m_current_result.B.price);
   double BC = CalculateDistance(m_current_result.B.price, m_current_result.C.price);

   Print("CHarmonicPatterns: Leg distances - XA:", DoubleToString(XA, 2),
         " AB:", DoubleToString(AB, 2), " BC:", DoubleToString(BC, 2));

   //--- Check each enabled pattern
   if (m_patterns[0].enabled) {  // Gartley
      if (CheckPatternRatios(0, m_current_result.gartley, XA, AB, BC, is_bullish)) {
         m_current_result.any_pattern_detected = true;
         Print("  ✓ GARTLEY pattern match");
      }
   }

   if (m_patterns[1].enabled) {  // Bat
      if (CheckPatternRatios(1, m_current_result.bat, XA, AB, BC, is_bullish)) {
         m_current_result.any_pattern_detected = true;
         Print("  ✓ BAT pattern match");
      }
   }

   if (m_patterns[2].enabled) {  // ABCD
      if (CheckPatternRatios(2, m_current_result.abcd, XA, AB, BC, is_bullish)) {
         m_current_result.any_pattern_detected = true;
         Print("  ✓ ABCD pattern match");
      }
   }

   if (m_patterns[3].enabled) {  // Cypher
      if (CheckPatternRatios(3, m_current_result.cypher, XA, AB, BC, is_bullish)) {
         m_current_result.any_pattern_detected = true;
         Print("  ✓ CYPHER pattern match");
      }
   }
}

//+------------------------------------------------------------------+
//| Check if ratios match a specific pattern                          |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::CheckPatternRatios(int pattern_idx,
                                           SSinglePatternState& state,
                                           double XA, double AB, double BC,
                                           bool is_bullish) {
   SPatternRatios p = m_patterns[pattern_idx];

   // Calculate ratios
   double AB_XA = CalculateRatio(AB, XA);
   double BC_AB = CalculateRatio(BC, AB);

   // Special handling for ABCD (doesn't use X in ratios)
   bool AB_match, BC_match;

   if (pattern_idx == 2) {  // ABCD
      AB_match = true;      // Skip AB/XA check for ABCD
      BC_match = (BC_AB >= p.BC_AB_min && BC_AB <= p.BC_AB_max);
   } else {
      AB_match = (AB_XA >= p.AB_XA_min && AB_XA <= p.AB_XA_max);
      BC_match = (BC_AB >= p.BC_AB_min && BC_AB <= p.BC_AB_max);
   }

   if (AB_match && BC_match) {
      // Calculate D projection
      double D_price;

      if (pattern_idx == 2) {            // ABCD uses BC for projection
         double CD_length = BC * 1.272;  // Default ABCD projection
         if (is_bullish) {
            D_price = m_current_result.C.price - CD_length;
         } else {
            D_price = m_current_result.C.price + CD_length;
         }
      } else {  // Standard patterns use AD/XA ratio
         if (is_bullish) {
            D_price = m_current_result.X.price - (XA * p.AD_XA);
         } else {
            D_price = m_current_result.X.price + (XA * p.AD_XA);
         }
      }

      // Populate state
      state.pattern_valid = true;
      state.waiting_for_D = true;
      state.D_price = D_price;
      state.AB_XA_ratio = AB_XA;
      state.BC_AB_ratio = BC_AB;
      state.CD_projected_ratio = p.AD_XA;

      Print("    ", p.name, " - D projected at: ", DoubleToString(D_price, 2),
            " | AB/XA:", DoubleToString(AB_XA, 3),
            " | BC/AB:", DoubleToString(BC_AB, 3));

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Monitor if price hit any PRZ                                      |
//+------------------------------------------------------------------+
void CHarmonicPatterns::MonitorPRZ(void) {
   double current_price = m_tf_data.m_close[0];

   // Check each pattern waiting for D
   if (m_current_result.gartley.waiting_for_D) {
      if (IsPriceInPRZ(current_price, m_current_result.gartley.D_price)) {
         m_current_result.gartley.D_triggered = true;
         m_current_result.gartley.waiting_for_D = false;
         Print("═══ GARTLEY PRZ HIT ═══");
         Print("  Price: ", DoubleToString(current_price, 2));
         Print("  D Target: ", DoubleToString(m_current_result.gartley.D_price, 2));
      }
   }

   if (m_current_result.bat.waiting_for_D) {
      if (IsPriceInPRZ(current_price, m_current_result.bat.D_price)) {
         m_current_result.bat.D_triggered = true;
         m_current_result.bat.waiting_for_D = false;
         Print("═══ BAT PRZ HIT ═══");
         Print("  Price: ", DoubleToString(current_price, 2));
         Print("  D Target: ", DoubleToString(m_current_result.bat.D_price, 2));
      }
   }

   if (m_current_result.abcd.waiting_for_D) {
      if (IsPriceInPRZ(current_price, m_current_result.abcd.D_price)) {
         m_current_result.abcd.D_triggered = true;
         m_current_result.abcd.waiting_for_D = false;
         Print("═══ ABCD PRZ HIT ═══");
         Print("  Price: ", DoubleToString(current_price, 2));
         Print("  D Target: ", DoubleToString(m_current_result.abcd.D_price, 2));
      }
   }

   if (m_current_result.cypher.waiting_for_D) {
      if (IsPriceInPRZ(current_price, m_current_result.cypher.D_price)) {
         m_current_result.cypher.D_triggered = true;
         m_current_result.cypher.waiting_for_D = false;
         Print("═══ CYPHER PRZ HIT ═══");
         Print("  Price: ", DoubleToString(current_price, 2));
         Print("  D Target: ", DoubleToString(m_current_result.cypher.D_price, 2));
      }
   }

   // If no patterns waiting, exit monitoring mode
   if (!m_current_result.gartley.waiting_for_D &&
       !m_current_result.bat.waiting_for_D &&
       !m_current_result.abcd.waiting_for_D &&
       !m_current_result.cypher.waiting_for_D) {
      m_monitoring_patterns = false;
   }
}

//+------------------------------------------------------------------+
//| Check if price is within PRZ tolerance                            |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsPriceInPRZ(double current_price, double D_price) {
   double distance_pips = MathAbs(current_price - D_price) / m_point;
   return (distance_pips <= m_prz_tolerance_pips);
}

//+------------------------------------------------------------------+
//| Check if pattern should be invalidated                            |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsPatternInvalidated(void) {
   if (!m_current_result.XABCD_structure_valid)
      return false;

   double current_price = m_tf_data.m_close[0];

   //--- 1. Price broke beyond X
   if (m_check_X_break) {
      if (m_current_result.is_bullish && current_price > m_current_result.X.price) {
         Print("CHarmonicPatterns: Pattern invalidated - Price broke above X");
         return true;
      }
      if (!m_current_result.is_bullish && current_price < m_current_result.X.price) {
         Print("CHarmonicPatterns: Pattern invalidated - Price broke below X");
         return true;
      }
   }

   //--- 2. Pattern age exceeded
   int bars_elapsed = GetBarShift(m_current_result.C.time);
   if (bars_elapsed > m_max_pattern_age_bars) {
      Print("CHarmonicPatterns: Pattern invalidated - Timeout (", bars_elapsed, " bars)");
      return true;
   }

   //--- 3. New pivot formed (structure changed)
   if (ArraySize(m_pivots) > 4) {
      // Check if pivot[0] is newer than C
      if (m_pivots[0].time > m_current_result.C.time) {
         Print("CHarmonicPatterns: Pattern invalidated - New pivot formed");
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Reset pattern state                                               |
//+------------------------------------------------------------------+
void CHarmonicPatterns::ResetPattern(void) {
   m_current_result.Reset();
   m_monitoring_patterns = false;
   Print("CHarmonicPatterns: Pattern reset");
}

//+------------------------------------------------------------------+
//| Calculate distance between two prices                             |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateDistance(double price1, double price2) {
   return MathAbs(price1 - price2);
}

//+------------------------------------------------------------------+
//| Calculate ratio between two legs                                  |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateRatio(double leg1, double leg2) {
   if (leg2 == 0) return 0;
   return leg1 / leg2;
}

//+------------------------------------------------------------------+
//| Get bar shift from datetime                                       |
//+------------------------------------------------------------------+
int CHarmonicPatterns::GetBarShift(datetime time) {
   return iBarShift(m_symbol, m_timeframe, time);
}