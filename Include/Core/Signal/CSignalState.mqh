#include "SignalStructs.mqh"

class CSignalState {
  private:
   static CSignalState* s_instance;  // Singleton instance

   SRSIDivergenceResult m_rsi;
   SCorrelationResult m_correlation;
   STrendResult m_trend;
   SFilterResult m_filters;
   datetime m_last_update;

   // Private constructor (Singleton pattern)
   CSignalState(void) {
      ResetAll();
   }

  public:
   // Delete copy constructor and assignment (Singleton)
   CSignalState(const CSignalState&) = delete;
   void operator=(const CSignalState&) = delete;

   // Destructor
   ~CSignalState(void) {}

   // Get singleton instance
   static CSignalState* GetInstance(void) {
      if (s_instance == NULL)
         s_instance = new CSignalState();
      return s_instance;
   }

   // Destroy singleton (call in OnDeinit)
   static void Destroy(void) {
      if (s_instance != NULL) {
         delete s_instance;
         s_instance = NULL;
      }
   }

   // Reset all signals
   void ResetAll(void) {
      ResetRSI();
      ResetCorrelation();
      ResetTrend();
      ResetFilters();
      m_last_update = 0;
   }

   // Reset individual signals
   void ResetRSI(void) {
      m_rsi.Reset();  // Use the struct's own Reset method
   }

   void ResetCorrelation(void) {
      m_correlation.value = 0;
      m_correlation.meets_threshold = false;
      m_correlation.is_strong = false;
      m_correlation.signal_boost = 1.0;
   }

   void ResetTrend(void) {
      m_trend.h4_direction = 0;
      m_trend.h1_direction = 0;
      m_trend.h4_h1_aligned = false;
      m_trend.adx_value = 0;
      m_trend.is_trending = false;
   }

   void ResetFilters(void) {
      m_filters.session_valid = false;
      m_filters.spread_valid = false;
      m_filters.current_spread = 0;
   }

   // Setters (called by analyzers)
   void SetRSIDivergence(const SRSIDivergenceResult& result) {
      m_rsi = result;
      m_last_update = TimeCurrent();
   }

   void SetCorrelation(const SCorrelationResult& result) {
      m_correlation = result;
      m_last_update = TimeCurrent();
   }

   void SetTrend(const STrendResult& result) {
      m_trend = result;
      m_last_update = TimeCurrent();
   }

   void SetFilters(const SFilterResult& result) {
      m_filters = result;
      m_last_update = TimeCurrent();
   }

   // Getters (called by main EA for scoring)
   SRSIDivergenceResult GetRSI(void) const {
      return m_rsi;
   }

   SCorrelationResult GetCorrelation(void) const {
      return m_correlation;
   }

   STrendResult GetTrend(void) const {
      return m_trend;
   }

   SFilterResult GetFilters(void) const {
      return m_filters;
   }

   datetime GetLastUpdate(void) const {
      return m_last_update;
   }

   // Convenience booleans for scoring
   bool HasBaseSignal(void) const {
      return m_rsi.detected;
   }

   bool HasValidCorrelation(void) const {
      return m_correlation.meets_threshold;
   }

   bool HasStrongCorrelation(void) const {
      return m_correlation.is_strong;
   }

   bool IsTrendAligned(void) const {
      return m_trend.h4_h1_aligned && m_trend.is_trending;
   }

   bool PassesFilters(void) const {
      return m_filters.session_valid && m_filters.spread_valid;
   }
};

// Initialize static member
CSignalState* CSignalState::s_instance = NULL;