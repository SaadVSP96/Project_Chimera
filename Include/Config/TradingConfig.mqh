//+------------------------------------------------------------------+
//|                                              TradingConfig.mqh   |
//|                         Chimera EA - Trading Configuration       |
//|                                                                  |
//| PURPOSE: Centralized trading configuration for Project CHIMERA   |
//|          Contains all structs and default values for trade       |
//|          execution, risk management, pyramiding, and safety.     |
//|                                                                  |
//| PATTERN: Follows same design as SignalConfig.mqh                 |
//|          - Structs defined at top                                |
//|          - Private member instances                              |
//|          - Constructor auto-initializes                          |
//|          - Getters return copies                                 |
//+------------------------------------------------------------------+
#property copyright "Chimera Arch"
#property strict

//+------------------------------------------------------------------+
//| ENUM: Account Growth Phases                                      |
//|                                                                  |
//| The phased compounding system scales risk and pyramiding limits  |
//| based on account balance milestones.                             |
//+------------------------------------------------------------------+
enum EnumChimeraPhase {
   PHASE_FOUNDATION,    // Phase 1: $300 → $1,000 (Conservative)
   PHASE_ACCELERATION,  // Phase 2: $1,000 → $5,000 (Moderate)
   PHASE_HYPER_GROWTH   // Phase 3: $5,000+ (Aggressive)
};

//+------------------------------------------------------------------+
//| STRUCT: Trade Journal Entry                                      |
//|                                                                  |
//| Records metadata about each trade for analysis and debugging.    |
//+------------------------------------------------------------------+
struct STradeJournal {
   ulong ticket;                     // Position ticket number
   datetime entry_time;              // Time of trade entry
   double entry_correlation;         // DXY correlation at entry
   int confluence_score;             // Signal strength (0-5)
   EnumChimeraPhase phase_at_entry;  // Account phase when entered
   double atr_at_entry;              // ATR value at entry time
};

//+------------------------------------------------------------------+
//| STRUCT: Identity & Symbol Configuration                          |
//|                                                                  |
//| Defines which instruments the EA trades and monitors.            |
//| Magic number ensures we only manage our own positions.           |
//+------------------------------------------------------------------+
struct SIdentityConfig {
   ulong magic_number;            // Unique EA identifier (filters positions)
   string symbol_trade;           // Primary trading symbol (XAUUSD)
   string symbol_corr_primary;    // Primary correlation filter (DXY)
   string symbol_corr_secondary;  // Secondary confirmation (US30)
};

//+------------------------------------------------------------------+
//| STRUCT: Phase Boundaries Configuration                           |
//|                                                                  |
//| Defines the balance thresholds that trigger phase transitions.   |
//| Phase 1: balance < phase_1_limit                                 |
//| Phase 2: phase_1_limit <= balance < phase_2_limit                |
//| Phase 3: balance >= phase_2_limit                                |
//+------------------------------------------------------------------+
struct SPhaseConfig {
   double balance_phase_1_limit;  // Upper limit for Phase 1 ($1,000)
   double balance_phase_2_limit;  // Upper limit for Phase 2 ($5,000)
};

//+------------------------------------------------------------------+
//| STRUCT: Risk Per Phase Configuration                             |
//|                                                                  |
//| Risk percentage of account balance per trade.                    |
//| Values are decimals: 0.10 = 10% of balance at risk.              |
//+------------------------------------------------------------------+
struct SRiskConfig {
   double risk_percent_p1;        // Phase 1 risk (0.10 = 10%)
   double risk_percent_p2;        // Phase 2 risk (0.15 = 15%)
   double risk_percent_p3;        // Phase 3 risk (0.20 = 20%)
   double risk_bonus_confluence;  // Extra risk for 5/5 confluence (0.10 = +10%)
};

//+------------------------------------------------------------------+
//| STRUCT: Pyramiding Limits Configuration                          |
//|                                                                  |
//| Maximum pyramid entries allowed per direction (includes initial).|
//| E.g., max_pyramids_p1 = 2 means 1 initial + 1 pyramid = 2 total. |
//+------------------------------------------------------------------+
struct SPyramidLimitsConfig {
   int max_pyramids_p1;  // Phase 1 max entries (2)
   int max_pyramids_p2;  // Phase 2 max entries (3)
   int max_pyramids_p3;  // Phase 3 max entries (4)
};

//+------------------------------------------------------------------+
//| STRUCT: Trade Management Configuration (ATR-Based)               |
//|                                                                  |
//| All distances expressed as ATR multipliers for volatility        |
//| adaptation. Example: sl_atr_mult = 2.0 means SL is 2x ATR.       |
//+------------------------------------------------------------------+
struct STradeManagementConfig {
   int atr_period;           // ATR calculation period (14)
   double sl_atr_mult;       // Stop Loss distance (2.0 * ATR)
   double tp_risk_mult;      // Take Profit as multiple of risk (1.5 R:R)
   double trail_start_atr;   // Profit to activate trailing (1.0 * ATR)
   double trail_dist_atr;    // Trailing stop distance (1.0 * ATR)
   double pyramid_step_atr;  // Distance between pyramid adds (1.0 * ATR)
};

//+------------------------------------------------------------------+
//| STRUCT: Correlation Engine Configuration                         |
//|                                                                  |
//| XAUUSD-DXY inverse correlation is the primary trade filter.      |
//| Entry threshold: Must be below this to open new positions        |
//| Exit threshold:  Positions closed if correlation weakens         |
//+------------------------------------------------------------------+
struct SCorrelationTradeConfig {
   int correlation_period;       // Pearson correlation lookback (50 bars)
   double corr_threshold_entry;  // Minimum correlation to trade (-0.6)
   double corr_threshold_exit;   // Weak correlation forces exit (-0.4)
   double corr_perfect_level;    // Perfect correlation for bonus (-0.8)
};

//+------------------------------------------------------------------+
//| STRUCT: Indicator Settings for Trade Manager                     |
//|                                                                  |
//| Settings used by trade manager for validation and filtering.     |
//| Note: Analysis-specific settings are in SignalConfig.mqh         |
//+------------------------------------------------------------------+
struct SIndicatorTradeConfig {
   int rsi_period;         // RSI period (9)
   double rsi_overbought;  // RSI overbought level (60)
   double rsi_oversold;    // RSI oversold level (40)
   int adx_period;         // ADX period (14)
   double adx_min_level;   // Minimum ADX for trend (25.0)
   int ma_fast_period;     // Fast MA period (50)
   int ma_slow_period;     // Slow MA period (200)
   int max_spread_pips;    // Maximum spread allowed (25 pips)
};

//+------------------------------------------------------------------+
//| STRUCT: Timeframe Configuration                                  |
//|                                                                  |
//| CHIMERA uses 4 timeframes for confluence scoring.                |
//+------------------------------------------------------------------+
struct STimeframeConfig {
   ENUM_TIMEFRAMES tf_macro;  // Macro trend timeframe (H4)
   ENUM_TIMEFRAMES tf_inter;  // Intermediate timeframe (H1)
   ENUM_TIMEFRAMES tf_setup;  // Pattern setup timeframe (M15)
   ENUM_TIMEFRAMES tf_exec;   // Execution timeframe (M5)
};

//+------------------------------------------------------------------+
//| STRUCT: Trading Session Configuration (GMT Hours)                |
//|                                                                  |
//| CHIMERA only trades during high-liquidity sessions.              |
//+------------------------------------------------------------------+
struct SSessionConfig {
   int session_london_start;  // London session start (8 GMT)
   int session_london_end;    // London session end (17 GMT)
   int session_ny_start;      // New York session start (13 GMT)
   int session_ny_end;        // New York session end (22 GMT)
};

//+------------------------------------------------------------------+
//| STRUCT: Safety Circuit Breakers Configuration                    |
//|                                                                  |
//| Hard limits to protect the account from catastrophic losses.     |
//| These override all other logic and force position closure.       |
//+------------------------------------------------------------------+
struct SSafetyConfig {
   double safety_equity_dd_limit;     // Max equity drawdown (0.20 = 20%)
   double safety_margin_level_limit;  // Min margin level (300.0 = 300%)
   double safety_basket_dd_limit;     // Max basket drawdown (0.10 = 10%)
};

//+------------------------------------------------------------------+
//| STRUCT: Execution Settings Configuration                         |
//|                                                                  |
//| Controls order execution parameters like slippage tolerance.     |
//+------------------------------------------------------------------+
struct SExecutionConfig {
   int max_deviation_points;  // Max slippage (10 points)
};

//+------------------------------------------------------------------+
//| STRUCT: Advanced Pyramiding Configuration                        |
//|                                                                  |
//| Volume Multipliers: Each pyramid uses smaller size than anchor.  |
//| Profit Thresholds: Min profit (ATR) before adding pyramid.       |
//| SL Levels: Where to move unified basket SL on pyramid trigger.   |
//+------------------------------------------------------------------+
struct SPyramidExecutionConfig {
   // Volume multipliers (relative to anchor trade)
   double pyramid_vol_mult_p2;  // Pyramid 2 volume (50% of anchor)
   double pyramid_vol_mult_p3;  // Pyramid 3 volume (33% of anchor)
   double pyramid_vol_mult_p4;  // Pyramid 4 volume (25% of anchor)

   // Profit thresholds in ATR multiples
   double pyramid_profit_threshold_p1;  // ATR profit for pyramid 1 (1.0)
   double pyramid_profit_threshold_p2;  // ATR profit for pyramid 2 (2.0)
   double pyramid_profit_threshold_p3;  // ATR profit for pyramid 3 (3.0)

   // SL levels in ATR from anchor entry
   double pyramid_sl_level_p1;  // SL level pyramid 1 (0.0 = breakeven)
   double pyramid_sl_level_p2;  // SL level pyramid 2 (1.0 ATR profit)
   double pyramid_sl_level_p3;  // SL level pyramid 3 (2.0 ATR profit)
};

//+------------------------------------------------------------------+
//| STRUCT: Margin Safety Configuration                              |
//+------------------------------------------------------------------+
struct SMarginConfig {
   double margin_requirement_multiplier;  // Margin safety buffer (1.5x)
};

//+------------------------------------------------------------------+
//| STRUCT: Take Profit Scaling Configuration                        |
//|                                                                  |
//| Unified basket TP scales with position count.                    |
//| Formula: TP = (Base + Additional * (count - 1)) * Total Risk     |
//+------------------------------------------------------------------+
struct STPScalingConfig {
   double tp_base_risk_mult;        // Base TP multiple (1.5x risk)
   double tp_additional_risk_mult;  // Additional per pyramid (0.5x)
};

//+------------------------------------------------------------------+
//| STRUCT: Complete Trading Configuration (Flat)                    |
//|                                                                  |
//| This flat struct maintains compatibility with CChimeraTradeManager|
//| which expects all fields in a single struct. The class provides  |
//| both granular getters AND this complete config getter.           |
//+------------------------------------------------------------------+
struct ChimeraConfig {
   //--- Section 1: Identity & Symbols
   ulong magic_number;
   string symbol_trade;
   string symbol_corr_primary;
   string symbol_corr_secondary;

   //--- Section 2: Phase Boundaries
   double balance_phase_1_limit;
   double balance_phase_2_limit;

   //--- Section 3: Risk Per Phase
   double risk_percent_p1;
   double risk_percent_p2;
   double risk_percent_p3;
   double risk_bonus_confluence;

   //--- Section 4: Pyramiding Limits
   int max_pyramids_p1;
   int max_pyramids_p2;
   int max_pyramids_p3;

   //--- Section 5: Trade Management (ATR-Based)
   int atr_period;
   double sl_atr_mult;
   double tp_risk_mult;
   double trail_start_atr;
   double trail_dist_atr;
   double pyramid_step_atr;

   //--- Section 6: Correlation Engine
   int correlation_period;
   double corr_threshold_entry;
   double corr_threshold_exit;
   double corr_perfect_level;

   //--- Section 7: Signal Filters & Indicators
   int rsi_period;
   double rsi_overbought;
   double rsi_oversold;
   int adx_period;
   double adx_min_level;
   int ma_fast_period;
   int ma_slow_period;
   int max_spread_pips;

   //--- Section 8: Timeframes
   ENUM_TIMEFRAMES tf_macro;
   ENUM_TIMEFRAMES tf_inter;
   ENUM_TIMEFRAMES tf_setup;
   ENUM_TIMEFRAMES tf_exec;

   //--- Section 9: Trading Sessions (GMT)
   int session_london_start;
   int session_london_end;
   int session_ny_start;
   int session_ny_end;

   //--- Section 10: Safety Constants
   double safety_equity_dd_limit;
   double safety_margin_level_limit;
   double safety_basket_dd_limit;

   //--- Section 11: Execution Settings
   int max_deviation_points;

   //--- Section 12: Advanced Pyramiding
   double pyramid_vol_mult_p2;
   double pyramid_vol_mult_p3;
   double pyramid_vol_mult_p4;
   double pyramid_profit_threshold_p1;
   double pyramid_profit_threshold_p2;
   double pyramid_profit_threshold_p3;
   double pyramid_sl_level_p1;
   double pyramid_sl_level_p2;
   double pyramid_sl_level_p3;

   //--- Section 13: Margin Safety
   double margin_requirement_multiplier;

   //--- Section 14: Take Profit Scaling
   double tp_base_risk_mult;
   double tp_additional_risk_mult;
};

//+------------------------------------------------------------------+
//| CLASS: Trading Configuration                                     |
//|                                                                  |
//| Holds all trading configuration as private members.              |
//| Constructor auto-initializes with defaults.                      |
//| Getters return copies of config structs.                         |
//+------------------------------------------------------------------+
class CTradingConfig {
  private:
   //--- Granular config structs
   SIdentityConfig m_identity;
   SPhaseConfig m_phase;
   SRiskConfig m_risk;
   SPyramidLimitsConfig m_pyramid_limits;
   STradeManagementConfig m_trade_mgmt;
   SCorrelationTradeConfig m_correlation;
   SIndicatorTradeConfig m_indicators;
   STimeframeConfig m_timeframes;
   SSessionConfig m_session;
   SSafetyConfig m_safety;
   SExecutionConfig m_execution;
   SPyramidExecutionConfig m_pyramid_exec;
   SMarginConfig m_margin;
   STPScalingConfig m_tp_scaling;

   //--- Complete flat config (for CChimeraTradeManager compatibility)
   ChimeraConfig m_config;

  public:
   //+---------------------------------------------------------------+
   //| Constructor - Auto-initializes all configs                    |
   //+---------------------------------------------------------------+
   CTradingConfig(void) {
      InitializeChimeraConfig();
   }

   //+---------------------------------------------------------------+
   //| GETTERS: Granular Config Structs                              |
   //+---------------------------------------------------------------+
   SIdentityConfig GetIdentityConfig(void) const { return m_identity; }
   SPhaseConfig GetPhaseConfig(void) const { return m_phase; }
   SRiskConfig GetRiskConfig(void) const { return m_risk; }
   SPyramidLimitsConfig GetPyramidLimitsConfig(void) const { return m_pyramid_limits; }
   STradeManagementConfig GetTradeManagementConfig(void) const { return m_trade_mgmt; }
   SCorrelationTradeConfig GetCorrelationTradeConfig(void) const { return m_correlation; }
   SIndicatorTradeConfig GetIndicatorTradeConfig(void) const { return m_indicators; }
   STimeframeConfig GetTimeframeConfig(void) const { return m_timeframes; }
   SSessionConfig GetSessionConfig(void) const { return m_session; }
   SSafetyConfig GetSafetyConfig(void) const { return m_safety; }
   SExecutionConfig GetExecutionConfig(void) const { return m_execution; }
   SPyramidExecutionConfig GetPyramidExecutionConfig(void) const { return m_pyramid_exec; }
   SMarginConfig GetMarginConfig(void) const { return m_margin; }
   STPScalingConfig GetTPScalingConfig(void) const { return m_tp_scaling; }

   //+---------------------------------------------------------------+
   //| GETTER: Complete Flat Config (for CChimeraTradeManager)       |
   //+---------------------------------------------------------------+
   ChimeraConfig GetConfig(void) const { return m_config; }

   //+---------------------------------------------------------------+
   //| Quick Access Helpers                                          |
   //+---------------------------------------------------------------+
   ulong GetMagicNumber(void) const { return m_identity.magic_number; }
   string GetTradeSymbol(void) const { return m_identity.symbol_trade; }
   int GetATRPeriod(void) const { return m_trade_mgmt.atr_period; }
   double GetMaxSpreadPips(void) const { return m_indicators.max_spread_pips; }

   //+---------------------------------------------------------------+
   //| Validate configuration values                                 |
   //+---------------------------------------------------------------+
   bool ValidateConfig(void) const {
      bool valid = true;

      //--- Symbol validation
      if (m_identity.symbol_trade == "" || m_identity.symbol_trade == NULL) {
         Print("TradingConfig ERROR: symbol_trade is empty");
         valid = false;
      }

      //--- Phase boundary validation
      if (m_phase.balance_phase_1_limit <= 0 ||
          m_phase.balance_phase_2_limit <= m_phase.balance_phase_1_limit) {
         Print("TradingConfig ERROR: Invalid phase boundaries");
         valid = false;
      }

      //--- Risk validation (must be between 0 and 1)
      if (m_risk.risk_percent_p1 <= 0 || m_risk.risk_percent_p1 > 1.0 ||
          m_risk.risk_percent_p2 <= 0 || m_risk.risk_percent_p2 > 1.0 ||
          m_risk.risk_percent_p3 <= 0 || m_risk.risk_percent_p3 > 1.0) {
         Print("TradingConfig ERROR: Risk percentages must be between 0 and 1");
         valid = false;
      }

      //--- Pyramid limits validation
      if (m_pyramid_limits.max_pyramids_p1 < 1 ||
          m_pyramid_limits.max_pyramids_p2 < 1 ||
          m_pyramid_limits.max_pyramids_p3 < 1) {
         Print("TradingConfig ERROR: Pyramid limits must be >= 1");
         valid = false;
      }

      //--- ATR multiplier validation
      if (m_trade_mgmt.sl_atr_mult <= 0 || m_trade_mgmt.tp_risk_mult <= 0) {
         Print("TradingConfig ERROR: ATR multipliers must be positive");
         valid = false;
      }

      //--- Correlation validation (should be negative for inverse)
      if (m_correlation.corr_threshold_entry >= 0 || m_correlation.corr_threshold_exit >= 0) {
         Print("TradingConfig WARNING: Correlation thresholds should be negative");
      }

      //--- Safety limits validation
      if (m_safety.safety_equity_dd_limit <= 0 || m_safety.safety_equity_dd_limit > 1.0) {
         Print("TradingConfig ERROR: safety_equity_dd_limit must be between 0 and 1");
         valid = false;
      }

      return valid;
   }

   //+---------------------------------------------------------------+
   //| Print configuration summary to Experts log                    |
   //+---------------------------------------------------------------+
   void PrintConfigSummary(void) const {
      Print("=== CHIMERA Trading Configuration ===");
      Print("Symbol: ", m_identity.symbol_trade, " | Magic: ", m_identity.magic_number);
      Print("Correlation Pair: ", m_identity.symbol_corr_primary);
      Print("---");
      PrintFormat("Phase 1: Balance < $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  m_phase.balance_phase_1_limit,
                  m_risk.risk_percent_p1 * 100,
                  m_pyramid_limits.max_pyramids_p1);
      PrintFormat("Phase 2: Balance < $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  m_phase.balance_phase_2_limit,
                  m_risk.risk_percent_p2 * 100,
                  m_pyramid_limits.max_pyramids_p2);
      PrintFormat("Phase 3: Balance >= $%.0f | Risk: %.0f%% | Max Pyramids: %d",
                  m_phase.balance_phase_2_limit,
                  m_risk.risk_percent_p3 * 100,
                  m_pyramid_limits.max_pyramids_p3);
      Print("---");
      PrintFormat("SL: %.1fx ATR | TP: %.1fx Risk | Trail Start: %.1fx ATR",
                  m_trade_mgmt.sl_atr_mult,
                  m_trade_mgmt.tp_risk_mult,
                  m_trade_mgmt.trail_start_atr);
      PrintFormat("Correlation Entry: %.2f | Exit: %.2f",
                  m_correlation.corr_threshold_entry,
                  m_correlation.corr_threshold_exit);
      Print("---");
      PrintFormat("Safety: Max DD %.0f%% | Min Margin %.0f%% | Basket DD %.0f%%",
                  m_safety.safety_equity_dd_limit * 100,
                  m_safety.safety_margin_level_limit,
                  m_safety.safety_basket_dd_limit * 100);
      Print("=====================================");
   }

  private:
   //+---------------------------------------------------------------+
   //| Initialize all configuration with CHIMERA defaults            |
   //+---------------------------------------------------------------+
   void InitializeChimeraConfig(void) {
      //=============================================================
      // SECTION 1: Identity & Symbols
      //=============================================================
      m_identity.magic_number = 202411;
      m_identity.symbol_trade = "XAUUSD";
      m_identity.symbol_corr_primary = "DXY";
      m_identity.symbol_corr_secondary = "US30";

      //=============================================================
      // SECTION 2: Phase Boundaries
      //=============================================================
      m_phase.balance_phase_1_limit = 1000.0;  // Phase 1 → 2 at $1,000
      m_phase.balance_phase_2_limit = 5000.0;  // Phase 2 → 3 at $5,000

      //=============================================================
      // SECTION 3: Risk Per Phase
      //=============================================================
      m_risk.risk_percent_p1 = 0.10;        // 10% risk in Phase 1
      m_risk.risk_percent_p2 = 0.15;        // 15% risk in Phase 2
      m_risk.risk_percent_p3 = 0.20;        // 20% risk in Phase 3
      m_risk.risk_bonus_confluence = 0.10;  // +10% for 5/5 confluence

      //=============================================================
      // SECTION 4: Pyramiding Limits
      //=============================================================
      m_pyramid_limits.max_pyramids_p1 = 2;  // Max 2 positions Phase 1
      m_pyramid_limits.max_pyramids_p2 = 3;  // Max 3 positions Phase 2
      m_pyramid_limits.max_pyramids_p3 = 4;  // Max 4 positions Phase 3

      //=============================================================
      // SECTION 5: Trade Management (ATR-Based)
      //=============================================================
      m_trade_mgmt.atr_period = 14;         // Standard ATR period
      m_trade_mgmt.sl_atr_mult = 2.0;       // SL = 2x ATR
      m_trade_mgmt.tp_risk_mult = 1.5;      // Initial TP = 1.5x risk
      m_trade_mgmt.trail_start_atr = 1.0;   // Trail after 1 ATR profit
      m_trade_mgmt.trail_dist_atr = 1.0;    // Trail distance = 1 ATR
      m_trade_mgmt.pyramid_step_atr = 1.0;  // Pyramid every 1 ATR

      //=============================================================
      // SECTION 6: Correlation Engine
      //=============================================================
      m_correlation.correlation_period = 50;      // 50-bar correlation
      m_correlation.corr_threshold_entry = -0.6;  // Need < -0.6 to enter
      m_correlation.corr_threshold_exit = -0.4;   // Exit if > -0.4
      m_correlation.corr_perfect_level = -0.8;    // Perfect correlation

      //=============================================================
      // SECTION 7: Indicator Settings
      //=============================================================
      m_indicators.rsi_period = 9;         // Fast RSI for divergence
      m_indicators.rsi_overbought = 60.0;  // Conservative OB level
      m_indicators.rsi_oversold = 40.0;    // Conservative OS level
      m_indicators.adx_period = 14;        // Standard ADX
      m_indicators.adx_min_level = 25.0;   // Trend threshold
      m_indicators.ma_fast_period = 50;    // 50 EMA (optional)
      m_indicators.ma_slow_period = 200;   // 200 EMA for trend
      m_indicators.max_spread_pips = 25;   // Max 25 pip spread

      //=============================================================
      // SECTION 8: Timeframes
      //=============================================================
      m_timeframes.tf_macro = PERIOD_H4;   // Macro trend
      m_timeframes.tf_inter = PERIOD_H1;   // Intermediate
      m_timeframes.tf_setup = PERIOD_M15;  // Pattern setup
      m_timeframes.tf_exec = PERIOD_M5;    // Execution

      //=============================================================
      // SECTION 9: Trading Sessions (GMT)
      //=============================================================
      m_session.session_london_start = 8;  // London 08:00 GMT
      m_session.session_london_end = 17;   // London 17:00 GMT
      m_session.session_ny_start = 13;     // New York 13:00 GMT
      m_session.session_ny_end = 22;       // New York 22:00 GMT

      //=============================================================
      // SECTION 10: Safety Constants
      //=============================================================
      m_safety.safety_equity_dd_limit = 0.20;      // 20% max equity drawdown
      m_safety.safety_margin_level_limit = 300.0;  // 300% min margin level
      m_safety.safety_basket_dd_limit = 0.10;      // 10% max basket loss

      //=============================================================
      // SECTION 11: Execution Settings
      //=============================================================
      m_execution.max_deviation_points = 10;  // 10 points max slippage

      //=============================================================
      // SECTION 12: Advanced Pyramiding
      //=============================================================
      m_pyramid_exec.pyramid_vol_mult_p2 = 0.50;  // Pyramid 2 = 50% volume
      m_pyramid_exec.pyramid_vol_mult_p3 = 0.33;  // Pyramid 3 = 33% volume
      m_pyramid_exec.pyramid_vol_mult_p4 = 0.25;  // Pyramid 4 = 25% volume

      m_pyramid_exec.pyramid_profit_threshold_p1 = 1.0;  // 1 ATR for pyramid 1
      m_pyramid_exec.pyramid_profit_threshold_p2 = 2.0;  // 2 ATR for pyramid 2
      m_pyramid_exec.pyramid_profit_threshold_p3 = 3.0;  // 3 ATR for pyramid 3

      m_pyramid_exec.pyramid_sl_level_p1 = 0.0;  // Breakeven at pyramid 1
      m_pyramid_exec.pyramid_sl_level_p2 = 1.0;  // +1 ATR at pyramid 2
      m_pyramid_exec.pyramid_sl_level_p3 = 2.0;  // +2 ATR at pyramid 3

      //=============================================================
      // SECTION 13: Margin Safety
      //=============================================================
      m_margin.margin_requirement_multiplier = 1.5;  // 1.5x margin buffer

      //=============================================================
      // SECTION 14: Take Profit Scaling
      //=============================================================
      m_tp_scaling.tp_base_risk_mult = 1.5;        // Base 1.5x risk
      m_tp_scaling.tp_additional_risk_mult = 0.5;  // +0.5x per pyramid

      //=============================================================
      // BUILD FLAT CONFIG (for CChimeraTradeManager compatibility)
      //=============================================================
      BuildFlatConfig();
   }

   //+---------------------------------------------------------------+
   //| Build flat ChimeraConfig from granular structs                |
   //+---------------------------------------------------------------+
   void BuildFlatConfig(void) {
      //--- Identity
      m_config.magic_number = m_identity.magic_number;
      m_config.symbol_trade = m_identity.symbol_trade;
      m_config.symbol_corr_primary = m_identity.symbol_corr_primary;
      m_config.symbol_corr_secondary = m_identity.symbol_corr_secondary;

      //--- Phase
      m_config.balance_phase_1_limit = m_phase.balance_phase_1_limit;
      m_config.balance_phase_2_limit = m_phase.balance_phase_2_limit;

      //--- Risk
      m_config.risk_percent_p1 = m_risk.risk_percent_p1;
      m_config.risk_percent_p2 = m_risk.risk_percent_p2;
      m_config.risk_percent_p3 = m_risk.risk_percent_p3;
      m_config.risk_bonus_confluence = m_risk.risk_bonus_confluence;

      //--- Pyramid Limits
      m_config.max_pyramids_p1 = m_pyramid_limits.max_pyramids_p1;
      m_config.max_pyramids_p2 = m_pyramid_limits.max_pyramids_p2;
      m_config.max_pyramids_p3 = m_pyramid_limits.max_pyramids_p3;

      //--- Trade Management
      m_config.atr_period = m_trade_mgmt.atr_period;
      m_config.sl_atr_mult = m_trade_mgmt.sl_atr_mult;
      m_config.tp_risk_mult = m_trade_mgmt.tp_risk_mult;
      m_config.trail_start_atr = m_trade_mgmt.trail_start_atr;
      m_config.trail_dist_atr = m_trade_mgmt.trail_dist_atr;
      m_config.pyramid_step_atr = m_trade_mgmt.pyramid_step_atr;

      //--- Correlation
      m_config.correlation_period = m_correlation.correlation_period;
      m_config.corr_threshold_entry = m_correlation.corr_threshold_entry;
      m_config.corr_threshold_exit = m_correlation.corr_threshold_exit;
      m_config.corr_perfect_level = m_correlation.corr_perfect_level;

      //--- Indicators
      m_config.rsi_period = m_indicators.rsi_period;
      m_config.rsi_overbought = m_indicators.rsi_overbought;
      m_config.rsi_oversold = m_indicators.rsi_oversold;
      m_config.adx_period = m_indicators.adx_period;
      m_config.adx_min_level = m_indicators.adx_min_level;
      m_config.ma_fast_period = m_indicators.ma_fast_period;
      m_config.ma_slow_period = m_indicators.ma_slow_period;
      m_config.max_spread_pips = m_indicators.max_spread_pips;

      //--- Timeframes
      m_config.tf_macro = m_timeframes.tf_macro;
      m_config.tf_inter = m_timeframes.tf_inter;
      m_config.tf_setup = m_timeframes.tf_setup;
      m_config.tf_exec = m_timeframes.tf_exec;

      //--- Sessions
      m_config.session_london_start = m_session.session_london_start;
      m_config.session_london_end = m_session.session_london_end;
      m_config.session_ny_start = m_session.session_ny_start;
      m_config.session_ny_end = m_session.session_ny_end;

      //--- Safety
      m_config.safety_equity_dd_limit = m_safety.safety_equity_dd_limit;
      m_config.safety_margin_level_limit = m_safety.safety_margin_level_limit;
      m_config.safety_basket_dd_limit = m_safety.safety_basket_dd_limit;

      //--- Execution
      m_config.max_deviation_points = m_execution.max_deviation_points;

      //--- Pyramid Execution
      m_config.pyramid_vol_mult_p2 = m_pyramid_exec.pyramid_vol_mult_p2;
      m_config.pyramid_vol_mult_p3 = m_pyramid_exec.pyramid_vol_mult_p3;
      m_config.pyramid_vol_mult_p4 = m_pyramid_exec.pyramid_vol_mult_p4;
      m_config.pyramid_profit_threshold_p1 = m_pyramid_exec.pyramid_profit_threshold_p1;
      m_config.pyramid_profit_threshold_p2 = m_pyramid_exec.pyramid_profit_threshold_p2;
      m_config.pyramid_profit_threshold_p3 = m_pyramid_exec.pyramid_profit_threshold_p3;
      m_config.pyramid_sl_level_p1 = m_pyramid_exec.pyramid_sl_level_p1;
      m_config.pyramid_sl_level_p2 = m_pyramid_exec.pyramid_sl_level_p2;
      m_config.pyramid_sl_level_p3 = m_pyramid_exec.pyramid_sl_level_p3;

      //--- Margin
      m_config.margin_requirement_multiplier = m_margin.margin_requirement_multiplier;

      //--- TP Scaling
      m_config.tp_base_risk_mult = m_tp_scaling.tp_base_risk_mult;
      m_config.tp_additional_risk_mult = m_tp_scaling.tp_additional_risk_mult;
   }
};
//+------------------------------------------------------------------+
