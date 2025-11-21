//+------------------------------------------------------------------+
//| TestMarketDataBasic.mq5                                           |
//| Test Script: Basic Market Data Access                            |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property script_show_inputs

// Include the market data system
#include "../../Include/Core/MarketData/CMarketDataManager.mqh"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
   Print("\n");
   Print("╔════════════════════════════════════════════════════════╗");
   Print("║  TEST: Basic Market Data Access                       ║");
   Print("╚════════════════════════════════════════════════════════╝");

   // Get the data manager instance
   CMarketDataManager* data = CMarketDataManager::GetInstance();

   if (data == NULL) {
      Print("FAILED: Could not get CMarketDataManager instance");
      return;
   }

   Print("PASSED: CMarketDataManager singleton created\n");

   // Test each configured symbol
   CMarketDataConfig* config = data.GetConfig();
   int symbol_count = config.GetSymbolCount();

   Print(StringFormat("Testing %d symbols...\n", symbol_count));

   int passed = 0;
   int failed = 0;

   for (int i = 0; i < symbol_count; i++) {
      SSymbolTimeframeConfig sym_config;
      if (!config.GetSymbolConfig(i, sym_config)) {
         Print(StringFormat("FAILED: Could not get config for symbol %d", i));
         failed++;
         continue;
      }

      Print("─────────────────────────────────────────────────────");
      Print(StringFormat("Testing Symbol: %s", sym_config.symbol));
      Print("─────────────────────────────────────────────────────");

      // Test each timeframe for this symbol
      for (int j = 0; j < ArraySize(sym_config.timeframes); j++) {
         ENUM_TIMEFRAMES tf = sym_config.timeframes[j];

         // Try to get current close price
         double close = data.Close(sym_config.symbol, tf, 0);
         datetime time = data.Time(sym_config.symbol, tf, 0);

         if (close > 0 && time > 0) {
            Print(StringFormat(" %s: Close[0] = %.5f @ %s",
                               EnumToString(tf),
                               close,
                               TimeToString(time, TIME_DATE | TIME_MINUTES)));
            passed++;
         } else {
            Print(StringFormat(" %s: Failed to get data (Close=%.5f, Time=%s)",
                               EnumToString(tf),
                               close,
                               TimeToString(time)));
            failed++;
         }
      }
   }

   // Summary
   Print("\n╔════════════════════════════════════════════════════════╗");
   Print("║  TEST SUMMARY                                          ║");
   Print("╚════════════════════════════════════════════════════════╝");
   Print(StringFormat("PASSED: %d tests", passed));
   Print(StringFormat("FAILED: %d tests", failed));
   Print(StringFormat("Total: %d tests", passed + failed));

   if (failed == 0)
      Print("\nALL TESTS PASSED!");
   else
      Print(StringFormat("\n %d TEST(S) FAILED", failed));

   Print("════════════════════════════════════════════════════════\n");

   // Cleanup
   CMarketDataManager::Destroy();
}