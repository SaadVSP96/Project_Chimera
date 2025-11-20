//+------------------------------------------------------------------+
//| Single Timeframe Data Container                                   |
//| Manages OHLCT buffers for one symbol on one timeframe            |
//+------------------------------------------------------------------+
class CTimeframeData {
  private:
   // Identification
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_buffer_size;

   // Price buffers (set as series)
   double m_open[];
   double m_high[];
   double m_low[];
   double m_close[];
   datetime m_time[];

   // Update tracking
   datetime m_last_update;
   bool m_initialized;

  public:
   CTimeframeData(void) : m_initialized(false) {}
   ~CTimeframeData(void) {}

   // Initialize buffers
   bool Initialize(string symbol, ENUM_TIMEFRAMES tf, int buffer_size) {
      m_symbol = symbol;
      m_timeframe = tf;
      m_buffer_size = buffer_size;

      // Set arrays as series (index 0 = most recent)
      ArraySetAsSeries(m_open, true);
      ArraySetAsSeries(m_high, true);
      ArraySetAsSeries(m_low, true);
      ArraySetAsSeries(m_close, true);
      ArraySetAsSeries(m_time, true);

      // Initial data load
      return Update();
   }

   // Update all buffers
   bool Update(void) {
      if (CopyOpen(m_symbol, m_timeframe, 0, m_buffer_size, m_open) <= 0) return false;
      if (CopyHigh(m_symbol, m_timeframe, 0, m_buffer_size, m_high) <= 0) return false;
      if (CopyLow(m_symbol, m_timeframe, 0, m_buffer_size, m_low) <= 0) return false;
      if (CopyClose(m_symbol, m_timeframe, 0, m_buffer_size, m_close) <= 0) return false;
      if (CopyTime(m_symbol, m_timeframe, 0, m_buffer_size, m_time) <= 0) return false;

      m_last_update = TimeCurrent();
      m_initialized = true;
      return true;
   }

   // Data accessors (TradingView-style)
   double Open(int shift = 0) const { return m_initialized && shift < m_buffer_size ? m_open[shift] : 0; }
   double High(int shift = 0) const { return m_initialized && shift < m_buffer_size ? m_high[shift] : 0; }
   double Low(int shift = 0) const { return m_initialized && shift < m_buffer_size ? m_low[shift] : 0; }
   double Close(int shift = 0) const { return m_initialized && shift < m_buffer_size ? m_close[shift] : 0; }
   datetime Time(int shift = 0) const { return m_initialized && shift < m_buffer_size ? m_time[shift] : 0; }

   // Array accessors (for algorithms needing multiple bars)
   bool GetOpenArray(double& dest[], int start = 0, int count = WHOLE_ARRAY) const {
      return CopyBuffer(m_open, start, count, dest);
   }
   bool GetHighArray(double& dest[], int start = 0, int count = WHOLE_ARRAY) const {
      return CopyBuffer(m_high, start, count, dest);
   }
   bool GetLowArray(double& dest[], int start = 0, int count = WHOLE_ARRAY) const {
      return CopyBuffer(m_low, start, count, dest);
   }
   bool GetCloseArray(double& dest[], int start = 0, int count = WHOLE_ARRAY) const {
      return CopyBuffer(m_close, start, count, dest);
   }
   bool GetTimeArray(datetime& dest[], int start = 0, int count = WHOLE_ARRAY) const {
      return CopyBuffer(m_time, start, count, dest);
   }

   // Utility
   bool IsInitialized(void) const { return m_initialized; }
   datetime GetLastUpdate(void) const { return m_last_update; }

  private:
   // used generics here cause I learned that in GOLANG.
   template <typename T>
   bool CopyBuffer(const T& source[], int start, int count, T& dest[]) const {
      if (!m_initialized) return false;
      int copy_count = (count == WHOLE_ARRAY) ? m_buffer_size : count;
      return ArrayCopy(dest, source, 0, start, copy_count) > 0;
   }
};
