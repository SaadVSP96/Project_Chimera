//+------------------------------------------------------------------+
//| Market Data Configuration                                         |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"

//--- Symbol-Timeframe Configuration Structure
struct SSymbolTimeframeConfig {
   string symbol;                 // Symbol name
   ENUM_TIMEFRAMES timeframes[];  // Array of timeframes to track
   int buffer_size;               // History buffer size
};

//+------------------------------------------------------------------+
//| Market Data Configuration Class                                   |
//+------------------------------------------------------------------+
class CMarketDataConfig {
  private:
   SSymbolTimeframeConfig m_symbols[];  // Array of symbol configs

  public:
   // Constructor - Define your configuration here
   CMarketDataConfig(void) {
      InitializeChimeraConfig();  // Project-specific setup
   }

   // Get total symbols configured
   int GetSymbolCount(void) const { return ArraySize(m_symbols); }

   // Get symbol config by index
   bool GetSymbolConfig(int index, SSymbolTimeframeConfig& config) const {
      if (index < 0 || index >= ArraySize(m_symbols)) return false;
      config = m_symbols[index];
      return true;
   }

  private:
   // Initialize configuration for Chimera project
   void InitializeChimeraConfig(void) {
      ArrayResize(m_symbols, 3);  // 3 symbols for Chimera

      // Symbol 1: XAUUSD
      m_symbols[0].symbol = "XAUUSD";
      m_symbols[0].buffer_size = 500;
      ArrayResize(m_symbols[0].timeframes, 4);
      m_symbols[0].timeframes[0] = PERIOD_M5;
      m_symbols[0].timeframes[1] = PERIOD_M15;
      m_symbols[0].timeframes[2] = PERIOD_H1;
      m_symbols[0].timeframes[3] = PERIOD_H4;

      // Symbol 2: US30
      m_symbols[1].symbol = "US30";
      m_symbols[1].buffer_size = 500;
      ArrayResize(m_symbols[1].timeframes, 4);
      m_symbols[1].timeframes[0] = PERIOD_M5;
      m_symbols[1].timeframes[1] = PERIOD_M15;
      m_symbols[1].timeframes[2] = PERIOD_H1;
      m_symbols[1].timeframes[3] = PERIOD_H4;

      // Symbol 3: DXY
      m_symbols[2].symbol = "DXY";
      m_symbols[2].buffer_size = 500;
      ArrayResize(m_symbols[2].timeframes, 1);
      m_symbols[2].timeframes[0] = PERIOD_M5;  // Only M5 for correlation
   }
};