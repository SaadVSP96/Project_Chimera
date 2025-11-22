#include "../../Config/MarketDataConfig.mqh"
#include "CSymbolData.mqh"
#include "CTimeframeData.mqh"
//+------------------------------------------------------------------+
//| Global Market Data Manager (Singleton Pattern)                   |
//| This is your "CGlobalState" - the single source of truth         |
//+------------------------------------------------------------------+
class CMarketDataManager {
  private:
   static CMarketDataManager* s_instance;  // Singleton instance

   CMarketDataConfig* m_config;
   CSymbolData* m_symbols[];  // Array of symbol data objects
   string m_symbol_map[];     // Maps symbol name to array index

   // Private constructor (Singleton pattern)
   CMarketDataManager(void) {
      m_config = new CMarketDataConfig();
      InitializeFromConfig();
   }

  public:
   // Delete copy constructor and assignment (Singleton)
   CMarketDataManager(const CMarketDataManager&) = delete;
   void operator=(const CMarketDataManager&) = delete;

   // Destructor
   ~CMarketDataManager(void) {
      if (CheckPointer(m_config) == POINTER_DYNAMIC)
         delete m_config;

      for (int i = 0; i < ArraySize(m_symbols); i++)
         if (CheckPointer(m_symbols[i]) == POINTER_DYNAMIC)
            delete m_symbols[i];
   }

   // Get singleton instance
   static CMarketDataManager* GetInstance(void) {
      if (s_instance == NULL)
         s_instance = new CMarketDataManager();
      return s_instance;
   }

   // Get the config object
   CMarketDataConfig* GetConfig(void) {
      return m_config;  // Directly return pointer (can be NULL)
   }

   // Destroy singleton (call in OnDeinit)
   static void Destroy(void) {
      if (s_instance != NULL) {
         delete s_instance;
         s_instance = NULL;
      }
   }

   // Update all symbol data (call in OnTick)
   bool UpdateAll(void) {
      bool success = true;
      for (int i = 0; i < ArraySize(m_symbols); i++)
         if (!m_symbols[i].UpdateAll())
            success = false;
      return success;
   }

   // Get symbol data object
   CSymbolData* GetSymbol(string symbol) {
      for (int i = 0; i < ArraySize(m_symbol_map); i++)
         if (m_symbol_map[i] == symbol)
            return m_symbols[i];
      return NULL;
   }

   // Get symbol name by index (for config-driven symbol selection)
   string GetSymbolName(int index) {
      if (index >= 0 && index < ArraySize(m_symbol_map))
         return m_symbol_map[index];
      return "";
   }

   // Get total number of configured symbols
   int GetSymbolCount(void) {
      return ArraySize(m_symbol_map);
   }

   // Convenience accessors (TradingView-style access)
   // Usage: CMarketDataManager::GetInstance().Close("XAUUSD", PERIOD_H4, 0)
   double Open(string symbol, ENUM_TIMEFRAMES tf, int shift = 0) {
      CSymbolData* sym = GetSymbol(symbol);
      return sym != NULL ? sym.Open(tf, shift) : 0;
   }

   double High(string symbol, ENUM_TIMEFRAMES tf, int shift = 0) {
      CSymbolData* sym = GetSymbol(symbol);
      return sym != NULL ? sym.High(tf, shift) : 0;
   }

   double Low(string symbol, ENUM_TIMEFRAMES tf, int shift = 0) {
      CSymbolData* sym = GetSymbol(symbol);
      return sym != NULL ? sym.Low(tf, shift) : 0;
   }

   double Close(string symbol, ENUM_TIMEFRAMES tf, int shift = 0) {
      CSymbolData* sym = GetSymbol(symbol);
      return sym != NULL ? sym.Close(tf, shift) : 0;
   }

   datetime Time(string symbol, ENUM_TIMEFRAMES tf, int shift = 0) {
      CSymbolData* sym = GetSymbol(symbol);
      return sym != NULL ? sym.Time(tf, shift) : 0;
   }

  private:
   // Initialize all symbols from configuration
   bool InitializeFromConfig(void) {
      int symbol_count = m_config.GetSymbolCount();
      ArrayResize(m_symbols, symbol_count);
      ArrayResize(m_symbol_map, symbol_count);

      for (int i = 0; i < symbol_count; i++) {
         SSymbolTimeframeConfig config;
         if (!m_config.GetSymbolConfig(i, config))
            return false;

         m_symbols[i] = new CSymbolData();
         m_symbol_map[i] = config.symbol;

         if (!m_symbols[i].Initialize(config)) {
            Print("ERROR: Failed to initialize " + config.symbol);
            return false;
         }
      }

      return true;
   }
};

// Initialize static member
CMarketDataManager* CMarketDataManager::s_instance = NULL;