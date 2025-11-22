//+------------------------------------------------------------------+
//|                                              TradingConfig.mqh   |
//|                                 Chimera Algorithmic Architecture |
//|                                                                  |
//| PURPOSE: Centralized trading configuration for Project CHIMERA   |
//|          Contains all structs, enums, and default values for     |
//|          trade execution, risk management, and position sizing.  |
//|                                                                  |
//| USAGE:   Include this file in any module that needs trading      |
//|          configuration. Use CTradingConfig::InitializeDefaults() |
//|          to populate a ChimeraConfig struct with default values. |
//+------------------------------------------------------------------+
#property copyright "Chimera Arch"
#property strict

//+------------------------------------------------------------------+
//| ENUM: Account Growth Phases                                      |
//|                                                                  |
//| The phased compounding system scales risk and pyramiding limits  |
//| based on account balance milestones. This enum identifies which  |
//| phase the account is currently in.                               |
//+------------------------------------------------------------------+
enum EnumChimeraPhase {
   PHASE_FOUNDATION,      // Phase 1: $300 → $1,000 (Conservative)
   PHASE_ACCELERATION,    // Phase 2: $1,000 → $5,000 (Moderate)
   PHASE_HYPER_GROWTH     // Phase 3: $5,000+ (Aggressive)
};

//+------------------------------------------------------------------+
//| STRUCT: Trade Journal Entry                                      |
//|                                                                  |
//| Records metadata about each trade for analysis and debugging.    |
//| Can be extended to write to file or database for post-trade      |
//| analysis and strategy optimization.                              |
//+------------------------------------------------------------------+
struct CTradeJournal {
   ulong             ticket;            // Position ticket number
   datetime          entry_time;        // Time of trade entry
   double            entry_correlation; // DXY correlation at entry
   int               confluence_score;  // Signal strength (0-5)
   EnumChimeraPhase  phase_at_entry;    // Account phase when entered
   double            atr_at_entry;      // ATR value at entry time
};

//+------------------------------------------------------------------+
//| STRUCT: Main Trading Configuration                               |
//|                                                                  |
//| DESIGN PHILOSOPHY: Single Source of Truth                        |
//| All trading parameters are centralized here. No magic numbers    |
//| scattered throughout the codebase. Modify defaults in one place. |
//|                                                                  |
//| SECTIONS:                                                        |
//|   1.  Identity & Symbols                                         |
//|   2.  Phase Boundaries (Account Growth Milestones)               |
//|   3.  Risk Per Phase (Phased Compounding)                        |
//|   4.  Pyramiding Limits                                          |
//|   5.  Trade Management (ATR-Based)                               |
//|   6.  Correlation Engine                                         |
//|   7.  Signal Filters & Indicators                                |
//|   8.  Timeframes (Multi-Timeframe Analysis)                      |
//|   9.  Trading Sessions                                           |
//|   10. Safety Constants                                           |
//|   11. Execution Settings                                         |
//|   12. Advanced Pyramiding                                        |
//|   13. Advanced Risk Management                                   |
//|   14. Take Profit Scaling                                        |
//+------------------------------------------------------------------+
struct ChimeraConfig {

   //=================================================================
   // SECTION 1: Identity & Symbols
   //=================================================================
   // These define which instruments the EA trades and monitors.
   // The magic number ensures we only manage our own positions.
   //=================================================================
   ulong    magic_number;           // Unique EA identifier (filters positions)
   string   symbol_trade;           // Primary trading symbol (XAUUSD)
   string   symbol_corr_primary;    // Primary correlation filter (DXY)
   string   symbol_corr_secondary;  // Secondary confirmation (US30)

   //=================================================================
   // SECTION 2: Phase Boundaries (Account Growth Milestones)
   //=================================================================
   // Defines the balance thresholds that trigger phase transitions.
   // Phase 1: balance < phase_1_limit
   // Phase 2: phase_1_limit <= balance < phase_2_limit  
   // Phase 3: balance >= phase_2_limit
   //=================================================================
   double   balance_phase_1_limit;  // Upper limit for Phase 1 ($1,000)
   double   balance_phase_2_limit;  // Upper limit for Phase 2 ($5,000)

   //=================================================================
   // SECTION 3: Risk Per Phase (Phased Compounding)
   //=================================================================
   // Risk percentage of account balance per trade.
   // Higher phases = higher risk tolerance as account grows.
   // Values are decimals: 0.10 = 10% of balance at risk.
   //=================================================================
   double   risk_percent_p1;        // Phase 1 risk (0.10 = 10%)
   double   risk_percent_p2;        // Phase 2 risk (0.15 = 15%)
   double   risk_percent_p3;        // Phase 3 risk (0.20 = 20%)
   double   risk_bonus_confluence;  // Extra risk for 5/5 confluence (0.10 = +10%)

   //=================================================================
   // SECTION 4: Pyramiding Limits
   //=================================================================
   // Maximum number of pyramid entries allowed per direction.
   // Includes the initial entry. E.g., max_pyramids_p1 = 2 means
   // 1 initial entry + 1 pyramid add = 2 total positions.
   //=================================================================
   int      max_pyramids_p1;        // Phase 1 max entries (2)
   int      max_pyramids_p2;        // Phase 2 max entries (3)
   int      max_pyramids_p3;        // Phase 3 max entries (4)

   //=================================================================
   // SECTION 5: Trade Management (ATR-Based Distances)
   //=================================================================
   // All distances are expressed as ATR multipliers.
   // This makes the system adaptive to market volatility.
   // Example: sl_atr_mult = 2.0 means SL is 2x ATR from entry.
   //=================================================================
   int      atr_period;             // ATR calculation period (14)
   double   sl_atr_mult;            // Stop Loss distance (2.0 * ATR)
   double   tp_risk_mult;           // Take Profit as multiple of risk (1.5 R:R)
   double   trail_start_atr;        // Profit to activate trailing (1.0 * ATR)
   double   trail_dist_atr;         // Trailing stop distance (1.0 * ATR)
   double   pyramid_step_atr;       // Distance between pyramid adds (1.0 * ATR)

   //=================================================================
   // SECTION 6: Correlation Engine Settings
   //=================================================================
   // XAUUSD-DXY inverse correlation is the primary trade filter.
   // Strong inverse correlation (< -0.6) confirms gold direction.
   // 
   // Entry threshold: Must be below this to open new positions
   // Exit threshold:  Positions closed if correlation weakens above this
   // Perfect level:   Triggers maximum signal boost
   //=================================================================
   int      correlation_period;     // Pearson correlation lookback (50 bars)
   double   corr_threshold_entry;   // Minimum correlation to trade (-0.6)
   double   corr_threshold_exit;    // Weak correlation forces exit (-0.4)
   double   corr_perfect_level;     // Perfect correlation for bonus (-0.8)

   //=================================================================
   // SECTION 7: Signal Filters & Indicators
   //=================================================================
   // RSI: Used for divergence detection on M5 timeframe
   // ADX: Confirms trend strength on H1 timeframe
   // MA:  200 EMA for macro trend direction on H4
   // Spread: Maximum allowed spread to prevent slippage
   //=================================================================
   int      rsi_period;             // RSI period for divergence (9)
   double   rsi_overbought;         // RSI overbought level (60)
   double   rsi_oversold;           // RSI oversold level (40)
   int      adx_period;             // ADX period for trend (14)
   double   adx_min_level;          // Minimum ADX for trend confirmation (25.0)
   int      ma_fast_period;         // Fast MA period (50) - optional use
   int      ma_slow_period;         // Slow MA period (200 EMA)
   int      max_spread_pips;        // Maximum spread allowed (25 pips)

   //=================================================================
   // SECTION 8: Timeframes (Multi-Timeframe Analysis)
   //=================================================================
   // CHIMERA uses 4 timeframes for confluence scoring:
   //   - Macro (H4):  Overall trend direction (200 EMA)
   //   - Inter (H1):  Trend strength confirmation (ADX)
   //   - Setup (M15): Pattern detection (Harmonics)
   //   - Exec (M5):   Entry trigger (RSI Divergence)
   //=================================================================
   ENUM_TIMEFRAMES tf_macro;        // Macro trend timeframe (H4)
   ENUM_TIMEFRAMES tf_inter;        // Intermediate timeframe (H1)
   ENUM_TIMEFRAMES tf_setup;        // Pattern setup timeframe (M15)
   ENUM_TIMEFRAMES tf_exec;         // Execution timeframe (M5)

   //=================================================================
   // SECTION 9: Trading Sessions (GMT Hours)
   //=================================================================
   // CHIMERA only trades during high-liquidity sessions.
   // London and New York sessions have the best gold volatility.
   // Hours are in GMT (24-hour format).
   //=================================================================
   int      session_london_start;   // London session start (8 GMT)
   int      session_london_end;     // London session end (17 GMT)
   int      session_ny_start;       // New York session start (13 GMT)
   int      session_ny_end;         // New York session end (22 GMT)
   
   //=================================================================
   // SECTION 10: Safety Constants (Circuit Breakers)
   //=================================================================
   // Hard limits to protect the account from catastrophic losses.
   // These override all other logic and force position closure.
   //
   // Equity DD:    Close all if equity drops X% below balance
   // Margin Level: Prevent new trades if margin level too low
   // Basket DD:    Close basket if its PnL exceeds X% loss
   //=================================================================
   double   safety_equity_dd_limit;     // Max equity drawdown (0.20 = 20%)
   double   safety_margin_level_limit;  // Min margin level (300.0 = 300%)
   double   safety_basket_dd_limit;     // Max basket drawdown (0.10 = 10%)
   
   //=================================================================
   // SECTION 11: Execution Settings
   //=================================================================
   // Controls order execution parameters.
   // Deviation: Maximum price slippage allowed in points.
   //=================================================================
   int      max_deviation_points;       // Max slippage (10 points)
   
   //=================================================================
   // SECTION 12: Advanced Pyramiding Settings
   //=================================================================
   // Volume Multipliers:
   //   Each pyramid level uses smaller position size than anchor.
   //   pyramid_vol_mult_p2 = 0.50 means 50% of anchor volume.
   //
   // Profit Thresholds:
   //   Minimum profit (in ATR) required before adding pyramid.
   //   pyramid_profit_threshold_p1 = 1.0 means 1 ATR profit needed.
   //
   // Stop Loss Levels:
   //   Where to move the unified basket SL when pyramid triggers.
   //   Values are ATR multiples from anchor entry price.
   //   pyramid_sl_level_p1 = 0.0 means breakeven (anchor entry).
   //=================================================================
   double   pyramid_vol_mult_p2;        // Pyramid 2 volume (50% of anchor)
   double   pyramid_vol_mult_p3;        // Pyramid 3 volume (33% of anchor)
   double   pyramid_vol_mult_p4;        // Pyramid 4 volume (25% of anchor)
   
   double   pyramid_profit_threshold_p1; // ATR profit for pyramid 1 (1.0)
   double   pyramid_profit_threshold_p2; // ATR profit for pyramid 2 (2.0)
   double   pyramid_profit_threshold_p3; // ATR profit for pyramid 3 (3.0)
   
   double   pyramid_sl_level_p1;        // SL level pyramid 1 (0.0 = breakeven)
   double   pyramid_sl_level_p2;        // SL level pyramid 2 (1.0 ATR profit)
   double   pyramid_sl_level_p3;        // SL level pyramid 3 (2.0 ATR profit)
   
   //=================================================================
   // SECTION 13: Advanced Risk Management
   //=================================================================
   // Additional margin safety multiplier.
   // Requires X times the calculated margin to be available.
   //=================================================================
   double   margin_requirement_multiplier; // Margin safety buffer (1.5x)
   
   //=================================================================
   // SECTION 14: Take Profit Scaling
   //=================================================================
   // Unified basket TP scales with position count.
   // Formula: TP = (Base + Additional * (count - 1)) * Total Risk
   //
   // Example with 3 positions:
   //   Scale = 1.5 + 0.5 * (3-1) = 2.5x total risk as target profit
   //=================================================================
   double   tp_base_risk_mult;          // Base TP multiple (1.5x risk)
   double   tp_additional_risk_mult;    // Additional per pyramid (0.5x)
};

//+------------------------------------------------------------------+
//| CLASS: Trading Configuration Initializer                         |
//|                                                                  |
//| Provides static method to populate ChimeraConfig with defaults.  |
//| This ensures consistent initialization across all components.    |
//|                                                                  |
//| USAGE:                                                           |
//|   ChimeraConfig cfg;                                             |
//|   CTradingConfig::InitializeDefaults(cfg);                       |
//+------------------------------------------------------------------+
class CTradingConfig {
public:
   //+---------------------------------------------------------------+
   //| Initialize all config fields with default values              |
   //+---------------------------------------------------------------+
   static void InitializeDefaults(ChimeraConfig &cfg) {
      
      //--- Section 1: Identity & Symbols
      cfg.magic_number           = 202411;      // Unique EA identifier
      cfg.symbol_trade           = "XAUUSD";    // Gold
      cfg.symbol_corr_primary    = "DXY";       // Dollar Index
      cfg.symbol_corr_secondary  = "US30";      // Dow Jones
      
      //--- Section 2: Phase Boundaries
      cfg.balance_phase_1_limit  = 1000.0;      // Phase 1 → 2 at $1,000
      cfg.balance_phase_2_limit  = 5000.0;      // Phase 2 → 3 at $5,000
      
      //--- Section 3: Risk Per Phase
      cfg.risk_percent_p1        = 0.10;        // 10% risk in Phase 1
      cfg.risk_percent_p2        = 0.15;        // 15% risk in Phase 2
      cfg.risk_percent_p3        = 0.20;        // 20% risk in Phase 3
      cfg.risk_bonus_confluence  = 0.10;        // +10% for 5/5 confluence
      
      //--- Section 4: Pyramiding Limits
      cfg.max_pyramids_p1        = 2;           // Max 2 positions Phase 1
      cfg.max_pyramids_p2        = 3;           // Max 3 positions Phase 2
      cfg.max_pyramids_p3        = 4;           // Max 4 positions Phase 3
      
      //--- Section 5: Trade Management (ATR-Based)
      cfg.atr_period             = 14;          // Standard ATR period
      cfg.sl_atr_mult            = 2.0;         // SL = 2x ATR
      cfg.tp_risk_mult           = 1.5;         // Initial TP = 1.5x risk
      cfg.trail_start_atr        = 1.0;         // Trail after 1 ATR profit
      cfg.trail_dist_atr         = 1.0;         // Trail distance = 1 ATR
      cfg.pyramid_step_atr       = 1.0;         // Pyramid every 1 ATR
      
      //--- Section 6: Correlation Engine
      cfg.correlation_period     = 50;          // 50-bar Pearson correlation
      cfg.corr_threshold_entry   = -0.6;        // Need < -0.6 to enter
      cfg.corr_threshold_exit    = -0.4;        // Exit if > -0.4
      cfg.corr_perfect_level     = -0.8;        // Perfect correlation
      
      //--- Section 7: Signal Filters & Indicators
      cfg.rsi_period             = 9;           // Fast RSI for divergence
      cfg.rsi_overbought         = 60.0;        // Conservative OB level
      cfg.rsi_oversold           = 40.0;        // Conservative OS level
      cfg.adx_period             = 14;          // Standard ADX
      cfg.adx_min_level          = 25.0;        // Trend threshold
      cfg.ma_fast_period         = 50;          // 50 EMA (optional)
      cfg.ma_slow_period         = 200;         // 200 EMA for trend
      cfg.max_spread_pips        = 25;          // Max 25 pip spread
      
      //--- Section 8: Timeframes
      cfg.tf_macro               = PERIOD_H4;   // Macro trend
      cfg.tf_inter               = PERIOD_H1;   // Intermediate
      cfg.tf_setup               = PERIOD_M15;  // Pattern setup
      cfg.tf_exec                = PERIOD_M5;   // Execution
      
      //--- Section 9: Trading Sessions (GMT)
      cfg.session_london_start   = 8;           // London 08:00 GMT
      cfg.session_london_end     = 17;          // London 17:00 GMT
      cfg.session_ny_start       = 13;          // New York 13:00 GMT
      cfg.session_ny_end         = 22;          // New York 22:00 GMT
      
      //--- Section 10: Safety Constants
      cfg.safety_equity_dd_limit     = 0.20;    // 20% max equity drawdown
      cfg.safety_margin_level_limit  = 300.0;   // 300% min margin level
      cfg.safety_basket_dd_limit     = 0.10;    // 10% max basket loss
      
      //--- Section 11: Execution Settings
      cfg.max_deviation_points       = 10;      // 10 points max slippage
      
      //--- Section 12: Advanced Pyramiding
      cfg.pyramid_vol_mult_p2        = 0.50;    // Pyramid 2 = 50% volume
      cfg.pyramid_vol_mult_p3        = 0.33;    // Pyramid 3 = 33% volume
      cfg.pyramid_vol_mult_p4        = 0.25;    // Pyramid 4 = 25% volume
      
      cfg.pyramid_profit_threshold_p1 = 1.0;    // 1 ATR for pyramid 1
      cfg.pyramid_profit_threshold_p2 = 2.0;    // 2 ATR for pyramid 2
      cfg.pyramid_profit_threshold_p3 = 3.0;    // 3 ATR for pyramid 3
      
      cfg.pyramid_sl_level_p1        = 0.0;     // Breakeven at pyramid 1
      cfg.pyramid_sl_level_p2        = 1.0;     // +1 ATR at pyramid 2
      cfg.pyramid_sl_level_p3        = 2.0;     // +2 ATR at pyramid 3
      
      //--- Section 13: Advanced Risk Management
      cfg.margin_requirement_multiplier = 1.5;  // 1.5x margin buffer
      
      //--- Section 14: Take Profit Scaling
      cfg.tp_base_risk_mult          = 1.5;     // Base 1.5x risk
      cfg.tp_additional_risk_mult    = 0.5;     // +0.5x per pyramid
   }
   
   //+---------------------------------------------------------------+
   //| Validate configuration values                                 |
   //| Returns true if all values are within acceptable ranges       |
   //+---------------------------------------------------------------+
   static bool ValidateConfig(const ChimeraConfig &cfg) {
      bool valid = true;
      
      //--- Symbol validation
      if(cfg.symbol_trade == "" || cfg.symbol_trade == NULL) {
         Print("TradingConfig ERROR: symbol_trade is empty");
         valid = false;
      }
      
      //--- Phase boundary validation
      if(cfg.balance_phase_1_limit <= 0 || cfg.balance_phase_2_limit <= cfg.balance_phase_1_limit) {
         Print("TradingConfig ERROR: Invalid phase boundaries");
         valid = false;
      }
      
      //--- Risk validation (must be between 0 and 1)
      if(cfg.risk_percent_p1 <= 0 || cfg.risk_percent_p1 > 1.0 ||
         cfg.risk_percent_p2 <= 0 || cfg.risk_percent_p2 > 1.0 ||
         cfg.risk_percent_p3 <= 0 || cfg.risk_percent_p3 > 1.0) {
         Print("TradingConfig ERROR: Risk percentages must be between 0 and 1");
         valid = false;
      }
      
      //--- Pyramid limits validation
      if(cfg.max_pyramids_p1 < 1 || cfg.max_pyramids_p2 < 1 || cfg.max_pyramids_p3 < 1) {
         Print("TradingConfig ERROR: Pyramid limits must be >= 1");
         valid = false;
      }
      
      //--- ATR multiplier validation
      if(cfg.sl_atr_mult <= 0 || cfg.tp_risk_mult <= 0) {
         Print("TradingConfig ERROR: ATR multipliers must be positive");
         valid = false;
      }
      
      //--- Correlation validation (should be negative for inverse correlation)
      if(cfg.corr_threshold_entry >= 0 || cfg.corr_threshold_exit >= 0) {
         Print("TradingConfig WARNING: Correlation thresholds should be negative for inverse correlation");
         // Not a hard error, just a warning
      }
      
      //--- Safety limits validation
      if(cfg.safety_equity_dd_limit <= 0 || cfg.safety_equity_dd_limit > 1.0) {
         Print("TradingConfig ERROR: safety_equity_dd_limit must be between 0 and 1");
         valid = false;
      }
      
      return valid;
   }
   
   //+---------------------------------------------------------------+
   //| Print configuration summary to Experts log                    |
   //+---------------------------------------------------------------+
   static void PrintConfigSummary(const ChimeraConfig &cfg) {
      Print("=== CHIMERA Trading Configuration ===");
      Print("Symbol: ", cfg.symbol_trade, " | Magic: ", cfg.magic_number);
      Print("Correlation Pair: ", cfg.symbol_corr_primary);
      Print("---");
      PrintFormat("Phase 1: Balance < $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  cfg.balance_phase_1_limit, cfg.risk_percent_p1 * 100, cfg.max_pyramids_p1);
      PrintFormat("Phase 2: Balance < $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  cfg.balance_phase_2_limit, cfg.risk_percent_p2 * 100, cfg.max_pyramids_p2);
      PrintFormat("Phase 3: Balance >= $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  cfg.balance_phase_2_limit, cfg.risk_percent_p3 * 100, cfg.max_pyramids_p3);
      Print("---");
      PrintFormat("SL: %.1fx ATR | TP: %.1fx Risk | Trail Start: %.1fx ATR",
                  cfg.sl_atr_mult, cfg.tp_risk_mult, cfg.trail_start_atr);
      PrintFormat("Correlation Entry: %.2f | Exit: %.2f",
                  cfg.corr_threshold_entry, cfg.corr_threshold_exit);
      Print("---");
      PrintFormat("Safety: Max DD %.0f%% | Min Margin %.0f%% | Basket DD %.0f%%",
                  cfg.safety_equity_dd_limit * 100,
                  cfg.safety_margin_level_limit,
                  cfg.safety_basket_dd_limit * 100);
      Print("=====================================");
   }
};
//+------------------------------------------------------------------+
