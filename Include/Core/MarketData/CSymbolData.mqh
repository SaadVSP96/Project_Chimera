// MarketDataIncludes.mqh
#include "../../Config/MarketDataConfig.mqh"
#include "CTimeframeData.mqh"
//+------------------------------------------------------------------+
//| Multi-Timeframe Data for One Symbol                              |
//| Composite pattern: Symbol contains multiple Timeframes           |
//+------------------------------------------------------------------+
class CSymbolData {
  private:
   string m_symbol;
   CTimeframeData* m_timeframes[];  // Array of timeframe data objects
   ENUM_TIMEFRAMES m_tf_map[];      // Maps timeframe enum to array index

  public:
   CSymbolData(void) {}
   ~CSymbolData(void) {
      // Cleanup
      for (int i = 0; i < ArraySize(m_timeframes); i++)
         if (CheckPointer(m_timeframes[i]) == POINTER_DYNAMIC)
            delete m_timeframes[i];
   }

   // Initialize from configuration
   bool Initialize(const SSymbolTimeframeConfig& config) {
      m_symbol = config.symbol;
      int tf_count = ArraySize(config.timeframes);

      ArrayResize(m_timeframes, tf_count);
      ArrayResize(m_tf_map, tf_count);

      for (int i = 0; i < tf_count; i++) {
         m_timeframes[i] = new CTimeframeData();
         m_tf_map[i] = config.timeframes[i];

         if (!m_timeframes[i].Initialize(m_symbol, config.timeframes[i], config.buffer_size)) {
            // CLogger::GetInstance().Error("Failed to initialize " + m_symbol + " " +
            //                              EnumToString(config.timeframes[i]));
            return false;
         }
      }

      return true;
   }

   // Update all timeframes
   bool UpdateAll(void) {
      bool success = true;
      for (int i = 0; i < ArraySize(m_timeframes); i++)
         if (!m_timeframes[i].Update())
            success = false;
      return success;
   }

   // Get specific timeframe data
   CTimeframeData* GetTimeframeData(ENUM_TIMEFRAMES tf) {
      for (int i = 0; i < ArraySize(m_tf_map); i++)
         if (m_tf_map[i] == tf)
            return m_timeframes[i];
      return NULL;
   }

   // Convenience accessors (using dot notation: symbol.H4.Close(0))
   double Open(ENUM_TIMEFRAMES tf, int shift = 0) {
      CTimeframeData* data = GetTimeframeData(tf);
      return data != NULL ? data.Open(shift) : 0;
   }

   // Convenience accessors (using dot notation: symbol.H4.Close(0))
   double High(ENUM_TIMEFRAMES tf, int shift = 0) {
      CTimeframeData* data = GetTimeframeData(tf);
      return data != NULL ? data.High(shift) : 0;
   }

   // Convenience accessors (using dot notation: symbol.H4.Close(0))
   double Low(ENUM_TIMEFRAMES tf, int shift = 0) {
      CTimeframeData* data = GetTimeframeData(tf);
      return data != NULL ? data.Low(shift) : 0;
   }

   // Convenience accessors (using dot notation: symbol.H4.Close(0))
   double Close(ENUM_TIMEFRAMES tf, int shift = 0) {
      CTimeframeData* data = GetTimeframeData(tf);
      return data != NULL ? data.Close(shift) : 0;
   }

   // Convenience accessors (using dot notation: symbol.H4.Close(0))
   datetime Time(ENUM_TIMEFRAMES tf, int shift = 0) {
      CTimeframeData* data = GetTimeframeData(tf);
      return data != NULL ? data.Time(shift) : 0;
   }

   string GetSymbol(void) const { return m_symbol; }
};