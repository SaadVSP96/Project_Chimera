//+------------------------------------------------------------------+
//|                                          CCorrelationAnalyzer.mqh |
//|                    Gold-DXY Correlation Analysis (Pearson)        |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property strict

#include "../Config/SignalConfig.mqh"
#include "../Core/MarketData/CMarketDataManager.mqh"
#include "../Core/Signal/SignalStructs.mqh"

//+------------------------------------------------------------------+
//| Correlation Analyzer Class                                        |
//+------------------------------------------------------------------+
class CCorrelationAnalyzer {
  private:
   //--- Dependencies
   CMarketDataManager* m_data;

   //--- Resolved symbol names (from indices)
   string m_symbol1;
   string m_symbol2;

   //--- Configuration
   ENUM_TIMEFRAMES m_timeframe;
   int m_period;
   double m_threshold;
   double m_strong_threshold;

   //--- State
   bool m_initialized;
   double m_last_correlation;
   datetime m_last_update;

  public:
   //--- Constructor / Destructor
   CCorrelationAnalyzer(void);
   ~CCorrelationAnalyzer(void);

   //--- Initialization
   bool Initialize(CMarketDataManager* data_manager, const SCorrelationConfig& config);

   //--- Main Analysis
   void Analyze(SCorrelationResult& result);

   //--- Accessors
   double GetCurrentCorrelation(void) const { return m_last_correlation; }
   bool IsInitialized(void) const { return m_initialized; }
   string GetSymbol1(void) const { return m_symbol1; }
   string GetSymbol2(void) const { return m_symbol2; }

  private:
   //--- Core Calculations
   double CalculatePearsonCorrelation(void);
   double CalculateSignalBoost(double correlation);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CCorrelationAnalyzer::CCorrelationAnalyzer(void) {
   m_data = NULL;
   m_symbol1 = "";
   m_symbol2 = "";
   m_timeframe = PERIOD_M5;
   m_period = 50;
   m_threshold = -0.6;
   m_strong_threshold = -0.7;
   m_initialized = false;
   m_last_correlation = 0.0;
   m_last_update = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CCorrelationAnalyzer::~CCorrelationAnalyzer(void) {
   // No dynamic allocations to clean up
}

//+------------------------------------------------------------------+
//| Initialize with data manager and config                           |
//+------------------------------------------------------------------+
bool CCorrelationAnalyzer::Initialize(CMarketDataManager* data_manager,
                                      const SCorrelationConfig& config) {
   // Validate data manager
   if (data_manager == NULL) {
      Print("CCorrelationAnalyzer: ERROR - Data manager is NULL");
      return false;
   }

   m_data = data_manager;

   // Resolve symbol names from indices
   m_symbol1 = m_data.GetSymbolName(config.symbol1_index);
   m_symbol2 = m_data.GetSymbolName(config.symbol2_index);

   if (m_symbol1 == "") {
      Print("CCorrelationAnalyzer: ERROR - Invalid symbol1_index: ", config.symbol1_index);
      return false;
   }

   if (m_symbol2 == "") {
      Print("CCorrelationAnalyzer: ERROR - Invalid symbol2_index: ", config.symbol2_index);
      return false;
   }

   // Verify symbols exist in data manager
   if (m_data.GetSymbol(m_symbol1) == NULL) {
      Print("CCorrelationAnalyzer: ERROR - Symbol ", m_symbol1, " not found in data manager");
      return false;
   }

   if (m_data.GetSymbol(m_symbol2) == NULL) {
      Print("CCorrelationAnalyzer: ERROR - Symbol ", m_symbol2, " not found in data manager");
      return false;
   }

   // Copy configuration
   m_timeframe = config.timeframe;
   m_period = config.period;
   m_threshold = config.threshold;
   m_strong_threshold = config.strong_threshold;

   // Validate period
   if (m_period < 10) {
      Print("CCorrelationAnalyzer: WARNING - Period too small, setting to 10");
      m_period = 10;
   }

   m_initialized = true;

   Print("CCorrelationAnalyzer: Initialized");
   Print("  Symbol 1: ", m_symbol1, " (index ", config.symbol1_index, ")");
   Print("  Symbol 2: ", m_symbol2, " (index ", config.symbol2_index, ")");
   Print("  Timeframe: ", EnumToString(m_timeframe));
   Print("  Period: ", m_period);
   Print("  Threshold: ", DoubleToString(m_threshold, 2));
   Print("  Strong Threshold: ", DoubleToString(m_strong_threshold, 2));

   return true;
}

//+------------------------------------------------------------------+
//| Main Analysis - Call each tick                                    |
//+------------------------------------------------------------------+
void CCorrelationAnalyzer::Analyze(SCorrelationResult& result) {
   // Reset result
   result.value = 0.0;
   result.meets_threshold = false;
   result.is_strong = false;
   result.signal_boost = 1.0;

   if (!m_initialized || m_data == NULL)
      return;

   // Calculate correlation
   double correlation = CalculatePearsonCorrelation();

   // Store for accessor
   m_last_correlation = correlation;
   m_last_update = TimeCurrent();

   // Populate result
   result.value = correlation;

   // Check thresholds (inverse correlation, so we check if LESS THAN threshold)
   // e.g., -0.65 < -0.6 means correlation is strong enough
   result.meets_threshold = (correlation < m_threshold);
   result.is_strong = (correlation < m_strong_threshold);

   // Calculate signal boost (only if meets threshold)
   if (result.meets_threshold) {
      result.signal_boost = CalculateSignalBoost(correlation);
   } else {
      result.signal_boost = 0.0;  // No trade allowed
   }
}

//+------------------------------------------------------------------+
//| Calculate Pearson Correlation Coefficient                         |
//| Formula: r = [n*Σxy - Σx*Σy] / sqrt[(n*Σx² - (Σx)²)(n*Σy² - (Σy)²)]|
//+------------------------------------------------------------------+
double CCorrelationAnalyzer::CalculatePearsonCorrelation(void) {
   // Sums for Pearson formula
   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;
   double sum_y2 = 0.0;

   int valid_bars = 0;

   // Iterate through the period
   for (int i = 0; i < m_period; i++) {
      double x = m_data.Close(m_symbol1, m_timeframe, i);
      double y = m_data.Close(m_symbol2, m_timeframe, i);

      // Skip if data is invalid
      if (x == 0.0 || y == 0.0)
         continue;

      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
      sum_y2 += y * y;

      valid_bars++;
   }

   // Need sufficient data
   if (valid_bars < 10) {
      Print("CCorrelationAnalyzer: WARNING - Insufficient data (", valid_bars, " bars)");
      return 0.0;
   }

   double n = (double)valid_bars;

   // Calculate numerator and denominator
   double numerator = (n * sum_xy) - (sum_x * sum_y);
   double denom_left = (n * sum_x2) - (sum_x * sum_x);
   double denom_right = (n * sum_y2) - (sum_y * sum_y);

   // Check for division by zero
   if (denom_left <= 0.0 || denom_right <= 0.0) {
      return 0.0;
   }

   double denominator = MathSqrt(denom_left * denom_right);

   if (denominator == 0.0) {
      return 0.0;
   }

   double correlation = numerator / denominator;

   // Clamp to valid range [-1, 1] (handles floating point errors)
   correlation = MathMax(-1.0, MathMin(1.0, correlation));

   return correlation;
}

//+------------------------------------------------------------------+
//| Calculate Signal Boost based on correlation strength              |
//| Maps: -0.6 → 1.0x, -0.7 → 1.15x, -0.8 → 1.3x                      |
//+------------------------------------------------------------------+
double CCorrelationAnalyzer::CalculateSignalBoost(double correlation) {
   // Must meet minimum threshold
   if (correlation >= m_threshold) {
      return 0.0;  // No trade allowed
   }

   // Linear interpolation from threshold to max boost
   // At -0.6: boost = 1.0
   // At -0.8: boost = 1.3
   // Formula: boost = 1.0 + (|correlation| - 0.6) * 1.5

   double abs_corr = MathAbs(correlation);
   double boost = 1.0 + (abs_corr - MathAbs(m_threshold)) * 1.5;

   // Cap at 1.3x
   return MathMin(boost, 1.3);
}