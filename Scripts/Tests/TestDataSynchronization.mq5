//+------------------------------------------------------------------+
//| TestDataSynchronization.mq5                                       |
//| Test Script: Data Synchronization Across Symbols                 |
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
   Print("║  TEST: Data Synchronization Check                     ║");
   Print("╚════════════════════════════════════════════════════════╝");

   CMarketDataManager* data = CMarketDataManager::GetInstance();

   if (data == NULL) {
      Print("FAILED: Could not get CMarketDataManager instance");
      return;
   }

   CMarketDataConfig* config = data.GetConfig();
   int symbol_count = config.GetSymbolCount();

   if (symbol_count < 2) {
      Print("FAILED: Need at least 2 symbols for synchronization test");
      CMarketDataManager::Destroy();
      return;
   }

   // Get symbol configs dynamically
   SSymbolTimeframeConfig sym_configs[];
   ArrayResize(sym_configs, symbol_count);

   for (int i = 0; i < symbol_count; i++) {
      if (!config.GetSymbolConfig(i, sym_configs[i])) {
         Print(StringFormat("FAILED: Could not get config for symbol %d", i));
         CMarketDataManager::Destroy();
         return;
      }
   }

   // Test multiple timeframes for synchronization
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_H1};
   string tf_names[] = {"M1", "M5", "H1"};
   int tolerance = 60;  // 60 seconds tolerance

   bool all_synchronized = true;

   // Loop through each timeframe
   for (int tf_idx = 0; tf_idx < ArraySize(timeframes); tf_idx++) {
      ENUM_TIMEFRAMES current_tf = timeframes[tf_idx];
      string tf_name = tf_names[tf_idx];

      Print("\n─────────────────────────────────────────────────────");
      Print(StringFormat("Testing %s Synchronization (Unconfirmed Bar):", tf_name));
      Print("─────────────────────────────────────────────────────");

      // Get unconfirmed bar (shift=0) times for all symbols
      datetime times[];
      ArrayResize(times, symbol_count);

      for (int i = 0; i < symbol_count; i++) {
         times[i] = data.Time(sym_configs[i].symbol, current_tf, 0);
         Print(StringFormat("  %s %s[0]: %s",
                            sym_configs[i].symbol,
                            tf_name,
                            TimeToString(times[i], TIME_DATE | TIME_SECONDS)));
      }

      // Calculate time differences between all symbols
      Print(StringFormat("\nTime Differences (%s):", tf_name));
      int max_diff = 0;
      bool tf_synchronized = true;

      for (int i = 0; i < symbol_count - 1; i++) {
         for (int j = i + 1; j < symbol_count; j++) {
            int diff = (int)MathAbs(times[i] - times[j]);

            Print(StringFormat("  %s - %s: %d seconds",
                               sym_configs[i].symbol,
                               sym_configs[j].symbol,
                               diff));

            if (diff > max_diff)
               max_diff = diff;

            if (diff > tolerance) {
               Print(StringFormat("WARNING: Differs by %d seconds (tolerance: %d)",
                                  diff, tolerance));
               tf_synchronized = false;
            }
         }
      }

      if (tf_synchronized) {
         Print(StringFormat("\n✓ PASSED: All %s data is synchronized (max diff: %d sec)",
                            tf_name, max_diff));
      } else {
         Print(StringFormat("\n✗ FAILED: %s data is NOT synchronized (max diff: %d sec)",
                            tf_name, max_diff));
         Print("   Possible causes:");
         Print("   - Different broker data feeds");
         Print("   - Missing bars on some symbols");
         Print("   - Delayed data updates");
         all_synchronized = false;
      }
   }

   // Summary
   Print("\n════════════════════════════════════════════════════════");
   if (all_synchronized) {
      Print("✓ PASSED: All timeframes synchronized across all symbols");
   } else {
      Print("✗ FAILED: Synchronization issues detected");
      Print("  Review warnings above for details");
   }
   Print("════════════════════════════════════════════════════════\n");

   CMarketDataManager::Destroy();
}