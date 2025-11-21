//+------------------------------------------------------------------+
//| TestAllSymbolsTimeframes.mq5                                      |
//| Test Script: Display All Symbol/Timeframe Data                   |
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
   Print("║  TEST: All Symbols & Timeframes Data                  ║");
   Print("╚════════════════════════════════════════════════════════╝\n");

   CMarketDataManager* data = CMarketDataManager::GetInstance();

   if (data == NULL) {
      Print("FAILED: Could not get CMarketDataManager instance");
      return;
   }

   CMarketDataConfig* config = data.GetConfig();

   // Display data for each symbol
   for (int i = 0; i < config.GetSymbolCount(); i++) {
      SSymbolTimeframeConfig sym_config;
      if (!config.GetSymbolConfig(i, sym_config))
         continue;

      Print("╔════════════════════════════════════════════════════════╗");
      Print(StringFormat("║  Symbol: %-45s ║", sym_config.symbol));
      Print("╚════════════════════════════════════════════════════════╝");

      // Display header
      Print("┌──────────┬────────────┬────────────┬────────────┬────────────┬─────────────────────┐");
      Print("│ TF       │ Open       │ High       │ Low        │ Close      │ Time                │");
      Print("├──────────┼────────────┼────────────┼────────────┼────────────┼─────────────────────┤");

      // Display data for each timeframe
      for (int j = 0; j < ArraySize(sym_config.timeframes); j++) {
         ENUM_TIMEFRAMES tf = sym_config.timeframes[j];

         double open = data.Open(sym_config.symbol, tf, 0);
         double high = data.High(sym_config.symbol, tf, 0);
         double low = data.Low(sym_config.symbol, tf, 0);
         double close = data.Close(sym_config.symbol, tf, 0);
         datetime time = data.Time(sym_config.symbol, tf, 0);

         string tf_str = EnumToString(tf);
         StringReplace(tf_str, "PERIOD_", "");  // Remove "PERIOD_" prefix

         Print(StringFormat("│ %-8s │ %10.2f │ %10.2f │ %10.2f │ %10.2f │ %s │",
                            tf_str,
                            open,
                            high,
                            low,
                            close,
                            TimeToString(time, TIME_DATE | TIME_MINUTES)));
      }

      Print("└──────────┴────────────┴────────────┴────────────┴────────────┴─────────────────────┘\n");

      // Display last 5 bars for first timeframe (detailed history)
      if (ArraySize(sym_config.timeframes) > 0) {
         ENUM_TIMEFRAMES tf = sym_config.timeframes[0];
         string tf_str = EnumToString(tf);
         StringReplace(tf_str, "PERIOD_", "");

         Print(StringFormat("Last 5 Bars on %s:", tf_str));
         Print("┌─────┬────────────┬─────────────────────┐");
         Print("│ Bar │ Close      │ Time                │");
         Print("├─────┼────────────┼─────────────────────┤");

         for (int k = 0; k < 5; k++) {
            double close = data.Close(sym_config.symbol, tf, k);
            datetime time = data.Time(sym_config.symbol, tf, k);

            Print(StringFormat("│ [%d] │ %10.2f │ %s │",
                               k,
                               close,
                               TimeToString(time, TIME_DATE | TIME_MINUTES)));
         }

         Print("└─────┴────────────┴─────────────────────┘\n");
      }
   }

   // Cleanup
   Print("════════════════════════════════════════════════════════\n");
   CMarketDataManager::Destroy();
}