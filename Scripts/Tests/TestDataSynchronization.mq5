//+------------------------------------------------------------------+
//|                                           MarketWatchSymbols.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   int total = SymbolsTotal(false);     // false = only visible in Market Watch

   Print("=== SYMBOLS IN MARKET WATCH ===");

   for (int i = 0; i < total; i++)
   {
      string sym = SymbolName(i, false);
      Print(i, ": ", sym);
   }
}
