//+------------------------------------------------------------------+
//|                                        ChimeraTradeManager.mqh   |
//|                                 Chimera Algorithmic Architecture |
//|                                       MQL5 Standard Library Use  |
//|                                                                  |
//| DESIGN NOTE: This class implements a "Unified Basket Stop Loss". |
//| When a pyramid level triggers a Stop Loss move (e.g., Breakeven),|
//| the ENTIRE basket is moved to that level to protect net equity.  |
//+------------------------------------------------------------------+
#property copyright "Chimera Arch"
#property strict

//--- Standard Library Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Project Config Include (contains ChimeraConfig, EnumChimeraPhase, CTradeJournal)
#include "../Config/TradingConfig.mqh"

//+------------------------------------------------------------------+
//| Class: CChimeraTradeManager                                      |
//| Logic: Handles Execution, Risk, Pyramiding, and Exits            |
//+------------------------------------------------------------------+
class CChimeraTradeManager {
private:
   //--- Standard Library Objects
   CTrade         m_trade;
   CPositionInfo  m_position;
   CSymbolInfo    m_symbol;
   ChimeraConfig  m_cfg; 
   
   //--- State Variables
   datetime m_last_correlation_breach_time;

   //--- Helpers
   EnumChimeraPhase GetCurrentPhase();
   int              CountActiveTrades(ENUM_POSITION_TYPE type);
   double           CalculateLotSize(double entry_price, double sl_price, double risk_money);
   bool             GetAnchorTicket(ENUM_POSITION_TYPE type, ulong &ticket, double &open_price, double &volume);
   double           CalcBasketTPPrice(ENUM_POSITION_TYPE type, datetime atr_time, double pending_lots=0, double pending_open=0, double pending_sl_dist=0);
   void             UpdateBasketTP(ENUM_POSITION_TYPE type, double new_tp_price);
   void             ModifyBasketSL(ENUM_POSITION_TYPE type, double new_sl_price);
   bool             CheckBasketMargin(ENUM_ORDER_TYPE type, double lots, double price);
   bool             CheckBasketDrawdown(ENUM_POSITION_TYPE type);
   void             CloseBasket(ENUM_POSITION_TYPE type);
   bool             IsSessionOpen();
   void             LogTrade(ulong ticket, int score, double corr, double atr);

public:
   CChimeraTradeManager(ChimeraConfig &config);
   
   //--- Core Methods with datetime atr_time included
   void ExecuteEntry(ENUM_ORDER_TYPE type, double sl_price, int confluence_score, double current_correlation, datetime correlation_time);
   void ManagePositions(double current_atr, double current_correlation, datetime correlation_time, datetime atr_time);
   void ManageTrailingStop(double current_atr, datetime atr_time);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChimeraTradeManager::CChimeraTradeManager(ChimeraConfig &config) {
   m_cfg = config;
   m_last_correlation_breach_time = 0;
   
   if(!m_symbol.Name(m_cfg.symbol_trade)) Print("Chimera Error: Symbol Init Failed");
   m_symbol.Refresh();
   
   m_trade.SetExpertMagicNumber(m_cfg.magic_number);
   m_trade.SetMarginMode(); 
   m_trade.SetTypeFilling(ORDER_FILLING_FOK); 
   m_trade.SetDeviationInPoints(m_cfg.max_deviation_points);
}

//+------------------------------------------------------------------+
//| Helper: Get Phase                                                |
//+------------------------------------------------------------------+
EnumChimeraPhase CChimeraTradeManager::GetCurrentPhase() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance < m_cfg.balance_phase_1_limit) return PHASE_FOUNDATION;
   if(balance < m_cfg.balance_phase_2_limit) return PHASE_ACCELERATION;
   return PHASE_HYPER_GROWTH;
}

//+------------------------------------------------------------------+
//| Helper: Count Trades (Directional Basket)                        |
//+------------------------------------------------------------------+
int CChimeraTradeManager::CountActiveTrades(ENUM_POSITION_TYPE type) {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number &&
            m_position.PositionType() == type) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Helper: Get Anchor Trade                                         |
//+------------------------------------------------------------------+
bool CChimeraTradeManager::GetAnchorTicket(ENUM_POSITION_TYPE type, ulong &ticket, double &open_price, double &volume) {
   ticket = 0;
   datetime oldest_time = TimeCurrent() + 100000; 
   bool found = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number &&
            m_position.PositionType() == type) {
            
            if(m_position.Time() < oldest_time) {
               oldest_time = m_position.Time();
               ticket = m_position.Ticket();
               open_price = m_position.PriceOpen();
               volume = m_position.Volume();
               found = true;
            }
         }
      }
   }
   return found;
}

//+------------------------------------------------------------------+
//| Helper: Calculate Unified Basket TP (Linear Scale)               |
//| Supports Pre-Calculation for Pending Trades (Anti-Race)          |
//+------------------------------------------------------------------+
double CChimeraTradeManager::CalcBasketTPPrice(ENUM_POSITION_TYPE type, datetime atr_time, double pending_lots=0, double pending_open=0, double pending_sl_dist=0) {
   if(TimeCurrent() - atr_time > 60) {
      Print("Chimera: Stale ATR in TP calc. Aborting.");
      return 0;
   }

   double total_risk_money = 0;
   double total_lots = 0;
   double avg_open_price = 0;
   
   if(!m_symbol.RefreshRates()) return 0;
   double point = m_symbol.Point();
   double tick_value = m_symbol.TickValue();
   if(point == 0 || tick_value == 0) return 0;
   
   // 1. Sum Existing Trades
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number && 
            m_position.PositionType() == type) {
            
            double sl = m_position.StopLoss();
            // If existing trade has no SL, we skip risk calc but count lots (safer than aborting)
            double sl_dist = 0;
            if(sl > 0) sl_dist = MathAbs(m_position.PriceOpen() - sl);
            
            total_risk_money += (sl_dist / point) * m_position.Volume() * tick_value;
            total_lots += m_position.Volume();
            avg_open_price += m_position.PriceOpen() * m_position.Volume(); 
         }
      }
   }
   
   // 2. Add Pending Trade (Simulate Basket State)
   if(pending_lots > 0) {
      total_risk_money += (pending_sl_dist / point) * pending_lots * tick_value;
      total_lots += pending_lots;
      avg_open_price += pending_open * pending_lots;
   }
   
   if(total_lots == 0) return 0;
   avg_open_price /= total_lots; 
   
   // 3. Calculate Target
   // Scale: 1.5 Base + 0.5 per additional trade
   int count = CountActiveTrades(type) + (pending_lots > 0 ? 1 : 0);
   double scale_factor = m_cfg.tp_base_risk_mult + ((double)(count - 1) * m_cfg.tp_additional_risk_mult); 
   double target_profit = total_risk_money * scale_factor;
   
   double points_needed = target_profit / (total_lots * tick_value);
   double final_tp = avg_open_price + (type == POSITION_TYPE_BUY ? points_needed * point : -points_needed * point);
   
   return final_tp;
}

//+------------------------------------------------------------------+
//| Helper: Update All TPs in Basket                                 |
//+------------------------------------------------------------------+
void CChimeraTradeManager::UpdateBasketTP(ENUM_POSITION_TYPE type, double new_tp_price) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number &&
            m_position.PositionType() == type) {
            
            double norm_tp = NormalizeDouble(new_tp_price, m_symbol.Digits());
            if(MathAbs(m_position.TakeProfit() - norm_tp) > m_symbol.Point()) {
               if(!m_trade.PositionModify(m_position.Ticket(), m_position.StopLoss(), norm_tp)) {
                  Print("Chimera Warn: Failed TP Update Tkt:", m_position.Ticket(), " Err:", m_trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Modify Basket Stop Loss (Unified)                        |
//+------------------------------------------------------------------+
void CChimeraTradeManager::ModifyBasketSL(ENUM_POSITION_TYPE type, double new_sl_price) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number &&
            m_position.PositionType() == type) {
            
            double norm_sl = NormalizeDouble(new_sl_price, m_symbol.Digits());
            bool modify = false;
            double current_sl = m_position.StopLoss();
            
            // Logic: Only tighten stops (Buy: Move Up, Sell: Move Down)
            if(type == POSITION_TYPE_BUY && (norm_sl > current_sl || current_sl == 0)) modify = true;
            if(type == POSITION_TYPE_SELL && (norm_sl < current_sl || current_sl == 0)) modify = true;
            
            if(modify) {
               if(!m_trade.PositionModify(m_position.Ticket(), norm_sl, m_position.TakeProfit())) {
                  Print("Chimera Warn: Failed SL Update Tkt:", m_position.Ticket(), " Err:", m_trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Check Basket Margin (Strict)                             |
//+------------------------------------------------------------------+
bool CChimeraTradeManager::CheckBasketMargin(ENUM_ORDER_TYPE type, double lots, double price) {
   double new_trade_margin = 0.0;
   if(!OrderCalcMargin(type, m_cfg.symbol_trade, lots, price, new_trade_margin)) {
      Print("Chimera: Margin Calc Fail. Err: ", GetLastError());
      return false;
   }
   
   // Use ACCOUNT_MARGIN_FREE instead of deprecated ACCOUNT_FREEMARGIN
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free_margin < new_trade_margin * m_cfg.margin_requirement_multiplier) {
      Print("Chimera: Insufficient Free Margin. Req:", new_trade_margin, " Free:", free_margin);
      return false;
   }
   
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(margin_level > 0 && margin_level < m_cfg.safety_margin_level_limit) { 
      Print("Chimera: Margin Level Too Low (<300%): ", margin_level);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Check Basket Drawdown (Safe Exit)                        |
//+------------------------------------------------------------------+
bool CChimeraTradeManager::CheckBasketDrawdown(ENUM_POSITION_TYPE type) {
   double basket_pnl = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number && 
            m_position.PositionType() == type) {
            basket_pnl += m_position.Profit();
         }
      }
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(basket_pnl < (balance * -m_cfg.safety_basket_dd_limit)) {
      Print("Chimera: Basket Drawdown Limit Hit (10%). Closing Basket.");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Close Basket                                             |
//+------------------------------------------------------------------+
void CChimeraTradeManager::CloseBasket(ENUM_POSITION_TYPE type) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && 
            m_position.Magic() == m_cfg.magic_number &&
            m_position.PositionType() == type) {
            m_trade.PositionClose(m_position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Session Filter                                           |
//+------------------------------------------------------------------+
bool CChimeraTradeManager::IsSessionOpen() {
   MqlDateTime gmt_time;
   TimeGMT(gmt_time);
   int hour = gmt_time.hour;
   bool london = (hour >= m_cfg.session_london_start && hour < m_cfg.session_london_end);
   bool ny = (hour >= m_cfg.session_ny_start && hour < m_cfg.session_ny_end);
   return (london || ny);
}

//+------------------------------------------------------------------+
//| Helper: Log Trade                                                |
//+------------------------------------------------------------------+
void CChimeraTradeManager::LogTrade(ulong ticket, int score, double corr, double atr) {
   PrintFormat("CHIMERA ENTRY | Tkt:%d | Ph:%d | Scr:%d | Corr:%.2f | ATR:%.5f",
               ticket, GetCurrentPhase(), score, corr, atr);
}

//+------------------------------------------------------------------+
//| Helper: Calculate Lot Size                                       |
//+------------------------------------------------------------------+
double CChimeraTradeManager::CalculateLotSize(double entry_price, double sl_price, double risk_money) {
   double risk_points = MathAbs(entry_price - sl_price);
   if(risk_points == 0) return m_symbol.LotsMin();
   
   double tick_value = m_symbol.TickValue();
   double tick_size = m_symbol.TickSize();
   if(tick_size == 0 || tick_value == 0) return m_symbol.LotsMin();
   
   double raw_lots = risk_money / ((risk_points / tick_size) * tick_value);
   
   double step = m_symbol.LotsStep();
   double normalized_lots = MathFloor(raw_lots / step) * step;
   
   if(normalized_lots < m_symbol.LotsMin()) normalized_lots = m_symbol.LotsMin();
   if(normalized_lots > m_symbol.LotsMax()) normalized_lots = m_symbol.LotsMax();
   
   return normalized_lots;
}

//+------------------------------------------------------------------+
//| Core Method: Execute New Entry                                   |
//+------------------------------------------------------------------+
void CChimeraTradeManager::ExecuteEntry(ENUM_ORDER_TYPE type, double sl_price, int confluence_score, double current_correlation, datetime correlation_time) {
   if(!m_symbol.RefreshRates()) return;
   
   //--- 1. Hard Correlation Gate
   if(current_correlation > m_cfg.corr_threshold_entry) { // e.g. > -0.6 (weak)
      Print("Chimera: Correlation too weak for entry: ", current_correlation);
      return;
   }

   //--- 2. Data Freshness & Session
   if(TimeCurrent() - correlation_time > 60) {
      Print("Chimera: Old Correlation Data. Rejecting Entry.");
      return;
   }
   if(!IsSessionOpen()) {
      Print("Chimera: Closed Session. Rejecting Entry.");
      return;
   }
   
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double point = m_symbol.Point();
   int digits = m_symbol.Digits();
   double entry_price = (type == ORDER_TYPE_BUY) ? ask : bid;

   //--- 3. Input Validation
   if(MathAbs(entry_price - sl_price) < point * 10) {
      Print("Chimera: SL too tight.");
      return;
   }
   if((ask - bid) / point / 10.0 > m_cfg.max_spread_pips) return;

   //--- 4. Check Active Basket (One per direction)
   ENUM_POSITION_TYPE pos_type = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if(CountActiveTrades(pos_type) > 0) {
      // Allow only ONE initial basket per direction. Pyramiding handles the rest.
      return; 
   }

   //--- 5. Phase & Risk Logic
   EnumChimeraPhase phase = GetCurrentPhase();
   double base_risk = 0.0;
   
   switch(phase) {
      case PHASE_FOUNDATION: base_risk = m_cfg.risk_percent_p1; break;
      case PHASE_ACCELERATION: base_risk = m_cfg.risk_percent_p2; break;
      case PHASE_HYPER_GROWTH: base_risk = m_cfg.risk_percent_p3; break;
   }

   // Confluence Bonus
   if(confluence_score == 4) base_risk += (m_cfg.risk_bonus_confluence * 0.5); // +5%
   if(confluence_score == 5) base_risk += m_cfg.risk_bonus_confluence;       // +10%
   
   // Correlation Boost
   double risk_multiplier = 1.0;
   if(current_correlation <= m_cfg.corr_threshold_entry) {
      double abs_corr = MathAbs(current_correlation);
      double abs_thresh = MathAbs(m_cfg.corr_threshold_entry);
      risk_multiplier = 1.0 + (abs_corr - abs_thresh) * 1.5;
      if(risk_multiplier > 1.3) risk_multiplier = 1.3;
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (base_risk * risk_multiplier);
   
   //--- 6. Execution Prep
   double lot_size = CalculateLotSize(entry_price, sl_price, risk_money);
   
   if(!CheckBasketMargin(type, lot_size, entry_price)) return;
   
   double dist_sl = MathAbs(entry_price - sl_price);
   double dist_tp = dist_sl * m_cfg.tp_risk_mult;
   double tp_price = (type == ORDER_TYPE_BUY) ? (entry_price + dist_tp) : (entry_price - dist_tp);
   
   double norm_sl = NormalizeDouble(sl_price, digits);
   double norm_tp = NormalizeDouble(tp_price, digits);
   double norm_entry = NormalizeDouble(entry_price, digits);
   
   bool res = false;
   if(type == ORDER_TYPE_BUY) res = m_trade.Buy(lot_size, m_cfg.symbol_trade, norm_entry, norm_sl, norm_tp, "Chimera Buy");
   else res = m_trade.Sell(lot_size, m_cfg.symbol_trade, norm_entry, norm_sl, norm_tp, "Chimera Sell");
   
   if(res) LogTrade(m_trade.ResultOrder(), confluence_score, current_correlation, 0);
}

//+------------------------------------------------------------------+
//| Core Method: Manage Positions                                    |
//+------------------------------------------------------------------+
void CChimeraTradeManager::ManagePositions(double current_atr, double current_correlation, datetime correlation_time, datetime atr_time) {
   if(PositionsTotal() == 0) return;
   
   if(TimeCurrent() - atr_time > 60) {
      Print("Chimera: Stale ATR. Skipping Management.");
      return;
   }
   if(current_atr <= 0) return;
   
   m_symbol.RefreshRates();

   //--- Phase and Limits
   EnumChimeraPhase phase = GetCurrentPhase();
   int limit_pyramids = (phase == PHASE_FOUNDATION) ? m_cfg.max_pyramids_p1 : 
                        (phase == PHASE_ACCELERATION) ? m_cfg.max_pyramids_p2 : m_cfg.max_pyramids_p3;

   //--- Tier 2: Safety Checks
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (equity < balance * (1.0 - m_cfg.safety_equity_dd_limit)) {
      Print("Chimera: CRITICAL - Hard Drawdown Stop Triggered");
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i) && m_position.Symbol() == m_cfg.symbol_trade && m_position.Magic() == m_cfg.magic_number) {
            m_trade.PositionClose(m_position.Ticket());
         }
      }
      return;
   }

   //--- Tier 1: Instant Correlation Exit
   if(TimeCurrent() - correlation_time < 60) {
      if(current_correlation > m_cfg.corr_threshold_exit) {
         Print("Chimera: Emergency Correlation Exit (Instant)");
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(m_position.SelectByIndex(i) && m_position.Symbol() == m_cfg.symbol_trade && m_position.Magic() == m_cfg.magic_number) {
               m_trade.PositionClose(m_position.Ticket());
            }
         }
         return;
      }
   }

   //--- Manage Buy Basket
   ulong anchor_buy;
   double anchor_buy_open, anchor_buy_vol;
   
   if(CheckBasketDrawdown(POSITION_TYPE_BUY)) {
      CloseBasket(POSITION_TYPE_BUY);
   } else if(GetAnchorTicket(POSITION_TYPE_BUY, anchor_buy, anchor_buy_open, anchor_buy_vol)) {
      int total_count = CountActiveTrades(POSITION_TYPE_BUY);
      int pyramid_count = (total_count > 0) ? total_count - 1 : 0;
      
      double current_price = m_symbol.Bid();
      double profit_points = current_price - anchor_buy_open;
      double profit_atr = profit_points / current_atr;
      
      double step_atr = m_cfg.pyramid_step_atr;
      
      double new_vol = 0;
      bool trigger = false;
      string comment = "";
      double ladder_sl = 0;
      
      if(pyramid_count < limit_pyramids) {
         if(profit_atr > (m_cfg.pyramid_profit_threshold_p1 * step_atr) && pyramid_count == 0) {
            new_vol = anchor_buy_vol * m_cfg.pyramid_vol_mult_p2;
            trigger = true;
            comment = "Chimera Pyr 2 Buy";
            ladder_sl = anchor_buy_open + (m_cfg.pyramid_sl_level_p1 * current_atr); // Breakeven
         }
         else if(profit_atr > (m_cfg.pyramid_profit_threshold_p2 * step_atr) && pyramid_count == 1) {
            new_vol = anchor_buy_vol * m_cfg.pyramid_vol_mult_p3;
            trigger = true;
            comment = "Chimera Pyr 3 Buy";
            ladder_sl = anchor_buy_open + (m_cfg.pyramid_sl_level_p2 * current_atr);
         }
         else if(profit_atr > (m_cfg.pyramid_profit_threshold_p3 * step_atr) && pyramid_count == 2) {
            new_vol = anchor_buy_vol * m_cfg.pyramid_vol_mult_p4;
            trigger = true;
            comment = "Chimera Pyr 4 Buy";
            ladder_sl = anchor_buy_open + (m_cfg.pyramid_sl_level_p3 * current_atr);
         }
      }
      
      if(trigger && IsSessionOpen()) {
         double point = m_symbol.Point();
         double current_spread = (m_symbol.Ask() - m_symbol.Bid()) / point / 10.0;
         if(current_spread > m_cfg.max_spread_pips) {
            Print("Chimera: Spread too high for pyramid: ", current_spread);
         } else {
            double step = m_symbol.LotsStep();
            new_vol = MathFloor(new_vol / step) * step;
            if(new_vol < m_symbol.LotsMin()) new_vol = m_symbol.LotsMin();
            
            if(CheckBasketMargin(ORDER_TYPE_BUY, new_vol, m_symbol.Ask())) {
               
               // Calculate potential new trade SL dist
               double new_trade_sl_dist = m_cfg.sl_atr_mult * current_atr;
               
               // PRE-CALCULATE UNIFIED BASKET TP (Avoid Race Condition)
               double unified_tp = CalcBasketTPPrice(POSITION_TYPE_BUY, atr_time, new_vol, m_symbol.Ask(), new_trade_sl_dist);
               
               if(unified_tp == 0) {
                  Print("Chimera ERROR: TP calc failed. Aborting Pyr.");
               } else {
                  double new_trade_sl = m_symbol.Ask() - new_trade_sl_dist;
                  int digits = m_symbol.Digits();
                  
                  // EXECUTE with Valid TP
                  if(m_trade.Buy(new_vol, m_cfg.symbol_trade, NormalizeDouble(m_symbol.Ask(), digits), 
                                 NormalizeDouble(new_trade_sl, digits), NormalizeDouble(unified_tp, digits), comment)) 
                  {
                     // Sync Rest of Basket
                     if(ladder_sl > 0) ModifyBasketSL(POSITION_TYPE_BUY, ladder_sl);
                     UpdateBasketTP(POSITION_TYPE_BUY, unified_tp);
                  }
               }
            }
         }
      }
   }

   //--- Manage Sell Basket
   ulong anchor_sell;
   double anchor_sell_open, anchor_sell_vol;
   
   if(CheckBasketDrawdown(POSITION_TYPE_SELL)) {
      CloseBasket(POSITION_TYPE_SELL);
   } else if(GetAnchorTicket(POSITION_TYPE_SELL, anchor_sell, anchor_sell_open, anchor_sell_vol)) {
      int total_count = CountActiveTrades(POSITION_TYPE_SELL);
      int pyramid_count = (total_count > 0) ? total_count - 1 : 0;
      
      double current_price = m_symbol.Ask();
      double profit_points = anchor_sell_open - current_price;
      double profit_atr = profit_points / current_atr;
      
      double step_atr = m_cfg.pyramid_step_atr;
      
      double new_vol = 0;
      bool trigger = false;
      string comment = "";
      double ladder_sl = 0;
      
      if(pyramid_count < limit_pyramids) {
         if(profit_atr > (m_cfg.pyramid_profit_threshold_p1 * step_atr) && pyramid_count == 0) {
            new_vol = anchor_sell_vol * m_cfg.pyramid_vol_mult_p2;
            trigger = true;
            comment = "Chimera Pyr 2 Sell";
            ladder_sl = anchor_sell_open + (m_cfg.pyramid_sl_level_p1 * current_atr);
         }
         else if(profit_atr > (m_cfg.pyramid_profit_threshold_p2 * step_atr) && pyramid_count == 1) {
            new_vol = anchor_sell_vol * m_cfg.pyramid_vol_mult_p3;
            trigger = true;
            comment = "Chimera Pyr 3 Sell";
            ladder_sl = anchor_sell_open - (m_cfg.pyramid_sl_level_p2 * current_atr);
         }
         else if(profit_atr > (m_cfg.pyramid_profit_threshold_p3 * step_atr) && pyramid_count == 2) {
            new_vol = anchor_sell_vol * m_cfg.pyramid_vol_mult_p4;
            trigger = true;
            comment = "Chimera Pyr 4 Sell";
            ladder_sl = anchor_sell_open - (m_cfg.pyramid_sl_level_p3 * current_atr);
         }
      }
      
      if(trigger && IsSessionOpen()) {
         double point = m_symbol.Point();
         double current_spread = (m_symbol.Ask() - m_symbol.Bid()) / point / 10.0;
         if(current_spread > m_cfg.max_spread_pips) {
            Print("Chimera: Spread too high for pyramid: ", current_spread);
         } else {
            double step = m_symbol.LotsStep();
            new_vol = MathFloor(new_vol / step) * step;
            if(new_vol < m_symbol.LotsMin()) new_vol = m_symbol.LotsMin();
            
            if(CheckBasketMargin(ORDER_TYPE_SELL, new_vol, m_symbol.Bid())) {
               
               double new_trade_sl_dist = m_cfg.sl_atr_mult * current_atr;
               double unified_tp = CalcBasketTPPrice(POSITION_TYPE_SELL, atr_time, new_vol, m_symbol.Bid(), new_trade_sl_dist);
               
               if(unified_tp == 0) {
                  Print("Chimera ERROR: TP calc failed. Aborting Pyr.");
               } else {
                  double new_trade_sl = m_symbol.Bid() + new_trade_sl_dist;
                  int digits = m_symbol.Digits();
                  
                  if(m_trade.Sell(new_vol, m_cfg.symbol_trade, NormalizeDouble(m_symbol.Bid(), digits), 
                                  NormalizeDouble(new_trade_sl, digits), NormalizeDouble(unified_tp, digits), comment)) 
                  {
                     if(ladder_sl > 0) ModifyBasketSL(POSITION_TYPE_SELL, ladder_sl);
                     UpdateBasketTP(POSITION_TYPE_SELL, unified_tp);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Core Method: Manage Trailing Stop                                |
//+------------------------------------------------------------------+
void CChimeraTradeManager::ManageTrailingStop(double current_atr, datetime atr_time) {
   if(current_atr <= 0) return;
   if(TimeCurrent() - atr_time > 60) return;
   
   m_symbol.RefreshRates();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_cfg.symbol_trade && m_position.Magic() == m_cfg.magic_number) {
            
            double open_price = m_position.PriceOpen();
            double current_sl = m_position.StopLoss();
            double new_sl = 0.0;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY) {
               double current_price = m_symbol.Bid();
               if((current_price - open_price) > (m_cfg.trail_start_atr * current_atr)) {
                  double calc_sl = current_price - (m_cfg.trail_dist_atr * current_atr);
                  if(calc_sl > current_sl && calc_sl < current_price) {
                     new_sl = NormalizeDouble(calc_sl, m_symbol.Digits());
                     if(!m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit())) {
                        Print("Chimera Warn: Trailing Fail Tkt:", m_position.Ticket());
                     }
                  }
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL) {
               double current_price = m_symbol.Ask();
               if((open_price - current_price) > (m_cfg.trail_start_atr * current_atr)) {
                  double calc_sl = current_price + (m_cfg.trail_dist_atr * current_atr);
                  if((calc_sl < current_sl || current_sl == 0) && calc_sl > current_price) {
                     new_sl = NormalizeDouble(calc_sl, m_symbol.Digits());
                     if(!m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit())) {
                        Print("Chimera Warn: Trailing Fail Tkt:", m_position.Ticket());
                     }
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
