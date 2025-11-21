//+------------------------------------------------------------------+
//| CHIMERA.mq5                                                       |
//| Main Expert Advisor - Phase 1: Data Management Only              |
//+------------------------------------------------------------------+
#property copyright "Quantech Innovation"
#property link "https://quantechinnovation.com"
#property version "1.00"

// Include the market data system
#include "Include/Config/MarketDataConfig.mqh"
#include "Include/Core/MarketData/CMarketDataManager.mqh"

// Single master include - gets everything

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CMarketDataManager* g_data_manager = NULL;  // Singleton reference

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA v1.0 - Market Data Management System");
   Print("═══════════════════════════════════════════════════════");

   // Get singleton instance (creates and initializes on first call)
   g_data_manager = CMarketDataManager::GetInstance();

   if (g_data_manager == NULL) {
      Print("ERROR: Failed to initialize Market Data Manager");
      return INIT_FAILED;
   }

   // Display configuration summary
   PrintConfigurationSummary();

   Print("CHIMERA initialized successfully");
   Print("Data updates will occur on every tick");
   Print("═══════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("═══════════════════════════════════════════════════════");
   Print("  CHIMERA Shutdown");
   Print("  Reason: ", GetDeinitReasonText(reason));
   Print("═══════════════════════════════════════════════════════");

   // Cleanup singleton
   CMarketDataManager::Destroy();
   g_data_manager = NULL;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Update all market data (called every tick)
   if (!g_data_manager.UpdateAll()) {
      Print("WARNING: Failed to update market data");
      return;
   }

   // Display sample data every 10 seconds (to avoid spam)
   static datetime last_display_time = 0;
   datetime current_time = TimeCurrent();

   if (current_time - last_display_time >= 10) {
      DisplaySampleData();
      last_display_time = current_time;
   }
}

//+------------------------------------------------------------------+
//| Display configuration summary                                     |
//+------------------------------------------------------------------+
void PrintConfigurationSummary() {
   Print("─────────────────────────────────────────────────────");
   Print("Configuration Summary:");
   Print("─────────────────────────────────────────────────────");

   // Get config
   CMarketDataConfig* config = g_data_manager.GetConfig();

   for (int i = 0; i < config.GetSymbolCount(); i++) {
      SSymbolTimeframeConfig sym_config;
      if (config.GetSymbolConfig(i, sym_config)) {
         Print(StringFormat("Symbol %d: %s", i + 1, sym_config.symbol));
         Print(StringFormat("  Buffer Size: %d bars", sym_config.buffer_size));
         Print(StringFormat("  Timeframes: %d", ArraySize(sym_config.timeframes)));

         string tf_list = "  TFs: ";
         for (int j = 0; j < ArraySize(sym_config.timeframes); j++) {
            tf_list += EnumToString(sym_config.timeframes[j]);
            if (j < ArraySize(sym_config.timeframes) - 1)
               tf_list += ", ";
         }
         Print(tf_list);
         Print("─────────────────────────────────────────────────────");
      }
   }
}

//+------------------------------------------------------------------+
//| Display sample data from all symbols                             |
//+------------------------------------------------------------------+
void DisplaySampleData() {
   Print("\n╔═══════════════════════════════════════════════════════╗");
   Print("║  Current Market Data (Sample)                        ║");
   Print("╚═══════════════════════════════════════════════════════╝");

   // Get symbol configs
   CMarketDataConfig* config = g_data_manager.GetConfig();
   SSymbolTimeframeConfig XAUUSD_config;
   if (!config.GetSymbolConfig(0, XAUUSD_config)) {
      Print("ERROR: Failed to get Config For XAUUSDm");
      return;
   }
   SSymbolTimeframeConfig EURUSD_config;
   if (!config.GetSymbolConfig(1, EURUSD_config)) {
      Print("ERROR: Failed to get Config For XAUUSDm");
      return;
   }
   SSymbolTimeframeConfig DXY_config;
   if (!config.GetSymbolConfig(2, DXY_config)) {
      Print("ERROR: Failed to get Config For DXYm");
      return;
   }

   //  Now Printing results:
   // XAUUSD on M5
   double xau_m5_close = g_data_manager.Close(XAUUSD_config.symbol, XAUUSD_config.timeframes[0], 0);
   datetime xau_m5_time = g_data_manager.Time(XAUUSD_config.symbol, XAUUSD_config.timeframes[0], 0);

   Print(StringFormat("XAUUSD M5  [0]: %.2f @ %s",
                      xau_m5_close,
                      TimeToString(xau_m5_time, TIME_DATE | TIME_MINUTES)));

   // XAUUSD on H4
   double xau_h4_close = g_data_manager.Close(XAUUSD_config.symbol, XAUUSD_config.timeframes[3], 0);
   datetime xau_h4_time = g_data_manager.Time(XAUUSD_config.symbol, XAUUSD_config.timeframes[3], 0);

   Print(StringFormat("XAUUSD H4  [0]: %.2f @ %s",
                      xau_h4_close,
                      TimeToString(xau_h4_time, TIME_DATE | TIME_MINUTES)));

   // EURUSD on M5
   double eur_m5_close = g_data_manager.Close(EURUSD_config.symbol, EURUSD_config.timeframes[0], 0);
   datetime eur_m5_time = g_data_manager.Time(EURUSD_config.symbol, EURUSD_config.timeframes[0], 0);

   Print(StringFormat("EURUSD M5    [0]: %.2f @ %s",
                      eur_m5_close,
                      TimeToString(eur_m5_time, TIME_DATE | TIME_MINUTES)));

   // DXY on M5
   double dxy_m5_close = g_data_manager.Close(DXY_config.symbol, DXY_config.timeframes[0], 0);
   datetime dxy_m5_time = g_data_manager.Time(DXY_config.symbol, DXY_config.timeframes[0], 0);

   Print(StringFormat("DXY M5     [0]: %.2f @ %s",
                      dxy_m5_close,
                      TimeToString(dxy_m5_time, TIME_DATE | TIME_MINUTES)));

   Print("═══════════════════════════════════════════════════════\n");
}

//+------------------------------------------------------------------+
//| Get deinit reason as text                                         |
//+------------------------------------------------------------------+
string GetDeinitReasonText(const int reason) {
   switch (reason) {
      case REASON_PROGRAM:
         return "EA stopped by user";
      case REASON_REMOVE:
         return "EA removed from chart";
      case REASON_RECOMPILE:
         return "EA recompiled";
      case REASON_CHARTCHANGE:
         return "Chart symbol/period changed";
      case REASON_CHARTCLOSE:
         return "Chart closed";
      case REASON_PARAMETERS:
         return "Input parameters changed";
      case REASON_ACCOUNT:
         return "Account changed";
      case REASON_TEMPLATE:
         return "Template changed";
      case REASON_INITFAILED:
         return "OnInit() failed";
      case REASON_CLOSE:
         return "Terminal closed";
      default:
         return "Unknown reason";
   }
}