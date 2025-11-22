# Project Chimera v9.0 - Complete Development Specification

**Target Platform:** MetaTrader 5  
**Broker:** IC Markets (Raw Spread Account)  
**Minimum Starting Capital:** $300  
**Strategy:** Multi-asset correlation analysis with phased compounding

## Table of Contents

1. System Overview
2. Multi-Asset Analysis System
3. Trading Strategy Framework
4. Pattern Detection Engine
5. Risk Management & Compounding
6. Technical Implementation
7. Prerequisites and Requirements
8. Testing & Validation
9. Deployment Procedures
10. Operational Guidelines
11. Troubleshooting Guide

## System Overview

### Purpose and Scope

Project Chimera v9.0 is an advanced algorithmic trading system designed for capital growth through intelligent multi-asset analysis and phased compounding. The system implements a sophisticated correlation-based strategy by analyzing three instruments simultaneously (XAUUSD, US30, DXY) while executing trades only on XAUUSD (Gold).

### Key Features

-   **Multi-Asset Correlation Analysis**: Uses DXY (US Dollar Index) as a primary signal filter with -0.6 correlation threshold
-   **Phased Compounding System**: Progressive risk scaling (10% → 15% → 20%) based on account growth milestones
    -   Phase 1 (Foundation): $300 → $1,000 | 10% risk | 2 pyramid entries
    -   Phase 2 (Acceleration): $1,000 → $5,000 | 15% risk | 3 pyramid entries
    -   Phase 3 (Hyper-Growth): $5,000+ | 20% risk | 4 pyramid entries
-   **Advanced Pattern Detection**: RSI Divergence + Harmonic Patterns (Gartley, Bat, ABCD, Cypher)
-   **Multi-Timeframe Intelligence**: H4/H1/M15/M5 hierarchical analysis
-   **Dynamic Risk Scaling**: Position size amplification based on signal quality and confluence
-   **Pyramiding Logic**: Add to winning positions at strategic levels
-   **Zero User Input**: Fully autonomous operation after deployment

### System Architecture

```
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Market Data │────▶│ Data Processor │────▶│ Correlation │
│ (3 Symbols x │ │ (Multi-Symbol) │ │ Analysis Engine │
│ 4 Timeframes) │ └─────────────────┘ └─────────────────┘
└─────────────────┘ │ │
▼ ▼
┌─────────────────────┐ ┌──────────────────┐
│ Pattern Detection │ │ Signal Generator │
│ - RSI Divergence │──▶│ (Multi-Layer │
│ - Harmonic Patterns│ │ Confirmation) │
└─────────────────────┘ └──────────────────┘
│
▼
┌─────────────────────┐ ┌──────────────────┐
│ Position Sizing │◀──│ Risk Management │
│ - Phased Risk │ │ - Correlation │
│ - Dynamic Scaling │ │ - Market Regime │
└─────────────────────┘ └──────────────────┘
│
▼
┌─────────────────────┐
│ Trade Execution │
│ - Entry/Exit │
│ - Pyramiding │
└─────────────────────┘
```

## Multi-Asset Analysis System

### Overview

The Chimera v9.0 Multi-Asset Analysis System represents a significant advancement in retail algorithmic trading technology. This system analyzes three instruments simultaneously while executing trades on only one, providing enhanced market intelligence and superior signal quality through sophisticated cross-asset correlation analysis.

This is the core differentiator that provides superior signal quality compared to single-asset systems.

### System Configuration

-   **Analyzed Symbols**: Gold (XAUUSD), US30 (Dow Jones), US Dollar Index (DXY)
-   **Tradeable Symbol**: Gold (XAUUSD) only
-   **Analysis Purpose**: DXY serves as the primary correlation indicator and signal filter; US30 provides secondary confirmation

### Operational Benefits

1. Enhanced Signal Quality

    - Cross-asset confirmation: All trading signals are validated against DXY correlation
    - Correlation boost: Strong correlations between Gold and DXY amplify signal strength
    - False signal filtering: Multi-asset analysis eliminates low-quality signals
    - Market regime detection: Uses all three symbols for comprehensive market analysis

2. Superior Performance Metrics
    - Signal quality: Enhanced through multi-dimensional market analysis
    - Risk management: Improved through correlation-based position sizing
    - Signal accuracy: Enhanced through multi-dimensional market analysis
    - Drawdown reduction: Better risk distribution across correlated assets

### Data Requirements

1. Synchronized Data Feeds
   All three symbols must have synchronized data with matching timestamps. The EA will handle minor timestamp discrepancies (up to 1 minute), but data must be from the same broker and timeframe.

    Required data structure for each symbol:

    ```
    struct MarketData {
        datetime time; // Timestamp
        double open; // Open price
        double high; // High price
        double low; // Low price
        double close; // Close price
        long volume; // Tick volume
    };
    ```

2. Data Quality Standards
    - Completeness: No missing data points during trading hours (London/NY sessions)
    - Accuracy: Clean data without anomalies or spikes
    - Timeliness: Real-time or near real-time data feeds
    - Consistency: Uniform data format across all symbols

### Implementation Architecture

1. Multi-Symbol Data Processing
   The EA must use iClose(), iHigh(), iLow(), iOpen() functions with symbol parameters to fetch data from multiple instruments:

    ```
    // Example: Fetch XAUUSD and DXY close prices on M5
    double gold_close = iClose("XAUUSD", PERIOD_M5, 0);
    double dxy_close = iClose("DXY", PERIOD_M5, 0);
    // Calculate correlation
    double correlation = CalculateCorrelation("XAUUSD", "DXY", PERIOD_M5, 50);
    ```

2. Correlation Analysis Engine
   The system continuously monitors correlations between symbols using a 50-period rolling window:

    Gold-DXY Inverse Correlation:

    - Expected range: -0.6 to -0.8
    - Threshold for trading: < -0.6 (must be inverse correlated)
    - Signal boost multiplier: 1.0× to 1.3× based on correlation strength

    Correlation Calculation (Pearson):

    ```
    double CalculateCorrelation(string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe, int period) {
        double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;

        for(int i = 0; i < period; i++) {
            double x = iClose(symbol1, timeframe, i);
            double y = iClose(symbol2, timeframe, i);

            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
            sum_y2 += y * y;
        }

        double n = (double)period;
        double numerator = (n * sum_xy) - (sum_x * sum_y);
        double denominator = MathSqrt(((n * sum_x2) - (sum_x * sum_x)) * ((n * sum_y2) - (sum_y * sum_y)));

        if(denominator == 0) return 0;
        return numerator / denominator;
    }
    ```

3. Signal Enhancement Process
   Every trading signal goes through a 5-step enhancement process:

    1. Base signal generation from XAUUSD technical analysis (RSI Divergence or Harmonic Pattern)
    2. Correlation analysis using DXY data
    3. Cross-asset confirmation from US30 (optional, adds confidence)
    4. Signal strength amplification based on correlation strength
    5. Position sizing optimization using multi-asset intelligence

    Signal Boost Calculation:

    ```
    double CalculateSignalBoost(double correlation) {
        // Correlation must be inverse (negative) for Gold-DXY
        if(correlation >= -0.6) return 0.0; // No trade if correlation is weak

        // Map correlation strength to boost multiplier
        // -0.6 = 1.0× (no boost)
        // -0.7 = 1.15×
        // -0.8 = 1.3× (maximum boost)

        double boost = 1.0 + (MathAbs(correlation) - 0.6) * 1.5;
        return MathMin(boost, 1.3); // Cap at 1.3×
    }
    ```

### Configuration Parameters

1. Symbol-Specific Settings

    ```
    // Hardcoded configuration (NO user inputs)
    struct SymbolConfig {
        string symbol;
        bool tradeable;
        double correlation_weight;
        double volatility_factor;
    };
    SymbolConfig symbols[3] = {
        {"XAUUSD", true, 0.4, 1.2}, // Gold - tradeable
        {"US30", false, 0.4, 1.0}, // US30 - analysis only
        {"DXY", false, 0.2, 0.8} // DXY - correlation filter
    };
    ```

2. Correlation Strategy Settings
    ```
    struct CorrelationStrategy {
        double correlation_threshold; // Minimum correlation to trade
        double signal_boost_max; // Maximum signal amplification
        int correlation_period; // Rolling window for correlation
    };
    CorrelationStrategy gold_dxy_strategy = {
        -0.6, // Must be at least -0.6 inverse correlation
        1.3, // Maximum 1.3× position size boost
        50 // 50-period correlation calculation
    };
    ```

### Deployment Considerations

1. Data Feed Requirements

    - Primary feeds: XAUUSD and DXY for trading execution
    - Secondary feed: US30 for additional confirmation
    - Backup feeds: Not required (system will halt if DXY data is unavailable)
    - Latency requirements: Sub-second data delivery for M5 timeframe

2. System Resources

    - CPU usage: Increased by ~30% due to multi-symbol processing
    - Memory usage: Additional ~50MB for correlation calculations and multi-symbol buffers
    - Network bandwidth: Triple data feed requirements

3. Monitoring Requirements
    - Correlation tracking: Real-time correlation monitoring displayed on UI panel
    - Data synchronization: Ensure all symbols remain synchronized (timestamp matching)
    - Signal quality metrics: Track multi-asset signal enhancement effectiveness
    - Performance comparison: Monitor signal quality and trade execution effectiveness

## Trading Strategy Framework

### Core Philosophy: Institutional-Grade Confluence Trading

Project Chimera v9.0 does not trade on a single indicator or pattern. It trades on confluence - the alignment of multiple, independent signals that together create a high-probability setup. This is how institutional traders and hedge funds operate.

A trade is only executed when ALL of the following conditions are met:

1. ✅ H4/H1 Trend Alignment - The macro trend is in our favor
2. ✅ DXY Correlation Confirmation - The dollar is moving in the opposite direction (< -0.6 correlation)
3. ✅ M15 Harmonic Pattern OR M5 RSI Divergence - A high-probability reversal signal has formed
4. ✅ Session Filter - We are trading during London or NY session (high liquidity)
5. ✅ Spread Filter - Spread is below 25 pips (cost control)

When all five align, we have an A++ setup worthy of aggressive position sizing.

### Multi-Timeframe Hierarchy

#### H4 (4-Hour): The Godfather Trend

Purpose: Determines the ONLY direction we are allowed to trade.

Logic:

-   If price > 200 EMA on H4 → ONLY look for LONG trades
-   If price < 200 EMA on H4 → ONLY look for SHORT trades
-   If price is within ±50 pips of 200 EMA → NO TRADES (ranging market)

Why this matters: Trading against the H4 trend is how retail traders get destroyed. We never fight the macro trend.

Implementation:

```
enum TrendDirection {
    TREND_UP,
    TREND_DOWN,
    TREND_NONE
};
TrendDirection GetH4Trend() {
    double ema200_h4 = iMA("XAUUSD", PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
    double current_price = iClose("XAUUSD", PERIOD_H4, 0);
    double buffer = 50 * _Point; // 50 pips buffer

    if(current_price > ema200_h4 + buffer) return TREND_UP;
    if(current_price < ema200_h4 - buffer) return TREND_DOWN;
    return TREND_NONE; // Ranging - no trades
}
```

#### H1 (1-Hour): Intermediate Trend Confirmation

Purpose: Confirms the H4 direction and provides additional filtering.

Logic:

-   Must agree with H4 trend
-   Uses ADX to measure trend strength
-   ADX > 25 = trending (good for trading)
-   ADX < 25 = ranging (avoid trading)

Implementation:

```
bool IsH1TrendValid(TrendDirection h4_trend) {
    double ema200_h1 = iMA("XAUUSD", PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
    double current_price = iClose("XAUUSD", PERIOD_H1, 0);
    double adx = iADX("XAUUSD", PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 0);

    // ADX must show trending market
    if(adx < 25) return false;

    // H1 must agree with H4
    if(h4_trend == TREND_UP && current_price < ema200_h1) return false;
    if(h4_trend == TREND_DOWN && current_price > ema200_h1) return false;

    return true;
}
```

#### M15 (15-Minute): Setup Timeframe

Purpose: Identifies harmonic patterns and measures volatility (ATR).

Logic:

-   Detects harmonic patterns (Gartley, Bat, ABCD, Cypher)
-   Calculates ATR for stop loss and take profit placement
-   Determines market regime (volatile vs calm)

Harmonic patterns on M15 provide the "zone" where we expect a reversal.

#### M5 (5-Minute): Execution Timeframe

Purpose: Pinpoints the exact entry using RSI Divergence.

Logic:

-   Detects RSI(9) divergence as the final confirmation signal
-   Bullish divergence = BUY signal
-   Bearish divergence = SELL signal

RSI divergence on M5 provides the "trigger" to enter the trade.

### Entry Conditions

#### LONG Entry (Buy Gold)

ALL of the following must be true:

1. H4 Trend: Price > 200 EMA on H4
2. H1 Confirmation: Price > 200 EMA on H1 AND ADX > 25
3. DXY Correlation: Gold-DXY correlation < -0.6 (inverse)
4. DXY Direction: DXY is falling (confirming Gold strength)
5. M15 Harmonic Pattern: Bullish Gartley, Bat, or ABCD detected at PRZ
6. M5 RSI Divergence: Bullish divergence (price lower low, RSI higher low)
7. Session: London (08:00-17:00 GMT) or NY (13:00-22:00 GMT)
8. Spread: < 25 pips

Entry Execution:

-   Enter at market when M5 RSI divergence is confirmed
-   Place stop loss at 2.0 × ATR(14) below entry
-   Set initial take profit at 1.5 × risk (1:1.5 R:R)
-   Activate trailing stop after 1.0 × ATR profit

#### SHORT Entry (Sell Gold)

ALL of the following must be true:

1. H4 Trend: Price < 200 EMA on H4
2. H1 Confirmation: Price < 200 EMA on H1 AND ADX > 25
3. DXY Correlation: Gold-DXY correlation < -0.6 (inverse)+
4. DXY Direction: DXY is rising (confirming Gold weakness)
5. M15 Harmonic Pattern: Bearish Gartley, Bat, or ABCD detected at PRZ
6. M5 RSI Divergence: Bearish divergence (price higher high, RSI lower high)
7. Session: London (08:00-17:00 GMT) or NY (13:00-22:00 GMT)
8. Spread: < 25 pips

Entry Execution:

-   Enter at market when M5 RSI divergence is confirmed
-   Place stop loss at 2.0 × ATR(14) above entry
-   Set initial take profit at 1.5 × risk (1:1.5 R:R)
-   Activate trailing stop after 1.0 × ATR profit

### Exit Conditions

1. Stop Loss Hit

    - Fixed stop loss at 2.0 × ATR from entry
    - Never moved closer to entry
    - Can be moved to breakeven after 1.0 × ATR profit

2. Take Profit Hit

    - Initial TP at 1.5 × risk
    - Can be extended via pyramiding

3. Trailing Stop Hit

    - Activated after 1.0 × ATR profit
    - Trails at 1.0 × ATR distance

4. Trend Reversal

    - If H1 price crosses 200 EMA in opposite direction
    - If M15 shows counter-trend harmonic pattern

5. Correlation Breakdown
    - If Gold-DXY correlation rises above -0.4 (relationship weakening)

## Pattern Detection Engine

### Overview

The Pattern Detection Engine is responsible for identifying two types of high-probability reversal patterns:

1. RSI Divergence (Primary signal on M5)
2. Harmonic Patterns (Setup signal on M15)

Both pattern types work together to identify high-probability trading opportunities.

### RSI Divergence Detection

#### What is RSI Divergence?

RSI Divergence occurs when price action and the RSI indicator move in opposite directions, signaling momentum exhaustion and an impending reversal.

Bullish Divergence:

-   Price makes a lower low
-   RSI makes a higher low
-   Signal: Momentum is weakening to the downside, expect reversal up

Bearish Divergence:

-   Price makes a higher high
-   RSI makes a lower high
-   Signal: Momentum is weakening to the upside, expect reversal down

#### Implementation

RSI Parameters:

-   Period: 9
-   Applied to: Close price
-   Timeframe: M5 (execution timeframe)

Detection Algorithm:

```
bool DetectBullishRSIDivergence() {
    double rsi_current = iRSI("XAUUSD", PERIOD_M5, 9, PRICE_CLOSE, 0);
    double rsi_prev = iRSI("XAUUSD", PERIOD_M5, 9, PRICE_CLOSE, 5);

    double price_current = iLow("XAUUSD", PERIOD_M5, 0);
    double price_prev = iLow("XAUUSD", PERIOD_M5, 5);

    // Price makes lower low, RSI makes higher low
    if(price_current < price_prev && rsi_current > rsi_prev) {
        // Additional filter: RSI must be oversold (< 40)
        if(rsi_current < 40) {
            return true;
        }
    }

    return false;
}

bool DetectBearishRSIDivergence() {
    double rsi_current = iRSI("XAUUSD", PERIOD_M5, 9, PRICE_CLOSE, 0);
    double rsi_prev = iRSI("XAUUSD", PERIOD_M5, 9, PRICE_CLOSE, 5);

    double price_current = iHigh("XAUUSD", PERIOD_M5, 0);
    double price_prev = iHigh("XAUUSD", PERIOD_M5, 5);

    // Price makes higher high, RSI makes lower high
    if(price_current > price_prev && rsi_current < rsi_prev) {
        // Additional filter: RSI must be overbought (> 60)
        if(rsi_current > 60) {
            return true;
        }
    }

    return false;
}
```

Frequency: ~25-35 divergences per day on M5 (high opportunity count)

### Harmonic Pattern Detection

#### What are Harmonic Patterns?

Harmonic patterns are geometric price formations based on Fibonacci ratios that predict high-probability reversal zones (PRZ - Potential Reversal Zone). They are predictive, not reactive, meaning they tell you WHERE a reversal will happen BEFORE it occurs.

#### The Four Core Patterns

1. ABCD Pattern (Most Common)
   Structure:

    - Point A: Initial swing high/low
    - Point B: Retracement (0.382-0.886 of AB)
    - Point C: Extension (1.13-2.618 of AB)
    - Point D: PRZ (1.27-1.618 of BC)

    Fibonacci Ratios:

    - BC = 0.382-0.886 of AB
    - CD = 1.27-1.618 of BC

    Entry: At point D (PRZ)  
    Stop Loss: Beyond point D (typically 10-20 pips)  
    Target: Point C (initial target), Point A (extended target)

    Frequency: ~60-70 per day on M15

2. Gartley Pattern (Most Reliable)
   Structure:

    - Point X: Initial extreme
    - Point A: Swing opposite to X
    - Point B: 0.618 retracement of XA
    - Point C: 0.382-0.886 retracement of AB
    - Point D: 0.786 retracement of XA (PRZ)

    Fibonacci Ratios:

    - AB = 0.618 of XA
    - BC = 0.382-0.886 of AB
    - CD = 1.27-1.618 of BC
    - AD = 0.786 of XA (critical)

    Entry: At point D (0.786 of XA)  
    Stop Loss: Beyond point X  
    Target: Point C, then Point A

    Frequency: ~2-4 per day on M15

3. Bat Pattern (High R:R)
   Structure:

    - Similar to Gartley but with tighter retracements
    - Point D at 0.886 of XA (deeper than Gartley)

    Fibonacci Ratios:

    - AB = 0.382-0.50 of XA
    - BC = 0.382-0.886 of AB
    - CD = 1.618-2.618 of BC
    - AD = 0.886 of XA (critical)

    Entry: At point D (0.886 of XA)  
    Stop Loss: Beyond point X (tight stop)  
    Target: Point C, then Point A

    Frequency: ~3-5 per day on M15

4. Cypher Pattern (Aggressive)
   Structure:

    - Point X: Initial extreme
    - Point A: Swing opposite to X
    - Point B: 0.382-0.618 retracement of XA
    - Point C: 1.27-1.414 extension of XA
    - Point D: 0.786 retracement of XC (PRZ)

    Fibonacci Ratios:

    - AB = 0.382-0.618 of XA
    - BC = 1.13-1.414 extension of XA
    - CD = 0.786 of XC (critical)

    Entry: At point D (0.786 of XC)  
    Stop Loss: Beyond point C  
    Target: Point C, then Point A

    Frequency: ~1-3 per day on M15

#### Implementation

Harmonic Pattern Detection Algorithm (Simplified):

```
struct HarmonicPattern {
    string type; // "Gartley", "Bat", "ABCD", "Cypher"
    bool is_bullish; // true = bullish, false = bearish
    double point_d_price; // Entry price (PRZ)
    double stop_loss; // SL price
    double take_profit; // TP price
    datetime detected_time;
};

HarmonicPattern DetectGartleyPattern() {
    HarmonicPattern pattern;
    pattern.type = "Gartley";

    // Find swing points X, A, B, C
    double point_x = FindSwingHigh(10); // Look back 10 bars
    double point_a = FindSwingLow(10);
    double point_b = FindSwingHigh(5);
    double point_c = FindSwingLow(5);

    // Calculate Fibonacci levels
    double xa_range = point_x - point_a;
    double ab_range = point_b - point_a;
    double bc_range = point_b - point_c;

    // Validate Gartley ratios
    double ab_ratio = ab_range / xa_range;
    if(ab_ratio < 0.58 || ab_ratio > 0.68) return pattern; // Invalid

    double bc_ratio = bc_range / ab_range;
    if(bc_ratio < 0.38 || bc_ratio > 0.88) return pattern; // Invalid

    // Calculate point D (PRZ) at 0.786 of XA
    double point_d = point_x - (xa_range * 0.786);

    // Wait for price to reach point D
    double current_price = iClose("XAUUSD", PERIOD_M15, 0);
    if(MathAbs(current_price - point_d) < 10 * _Point) { // Within 10 pips
        pattern.is_bullish = true;
        pattern.point_d_price = point_d;
        pattern.stop_loss = point_x - 20 * _Point; // 20 pips beyond X
        pattern.take_profit = point_c; // Target point C
        pattern.detected_time = TimeCurrent();
        return pattern;
    }

    return pattern; // Not at PRZ yet
}
```

Note: Full harmonic pattern detection requires more sophisticated algorithms. The above is a simplified example. The developer should implement a complete harmonic scanner that checks all four patterns on M15.

#### Pattern Validation with DXY

Once a harmonic pattern is detected on XAUUSD M15, it must be validated with DXY:

```
bool ValidateHarmonicWithDXY(HarmonicPattern pattern) {
    // Check if DXY is showing opposite pattern
    // If Gold shows bullish Gartley, DXY should show bearish pattern or downtrend

    double dxy_trend = GetDXYTrend(PERIOD_M15);

    if(pattern.is_bullish && dxy_trend < 0) return true; // DXY falling, Gold rising
    if(!pattern.is_bullish && dxy_trend > 0) return true; // DXY rising, Gold falling

    return false;
}
```

## Risk Management & Compounding

### Phased Compounding System: The Money Engine

This is the core

#### The Three Phases

**Phase 1: Foundation ($300 → $1,000)**
Goal: Build a cushion and survive early volatility.

Parameters:

-   Base Risk: 10% per trade
-   Max Pyramid Entries: 2
-   Correlation Boost: Enabled (up to 1.15×)
-   Target: $1,000 (3.33× growth)

Why 10% risk?

-   With a $300 account, 10% = $30 risk per trade
-   Conservative approach ensures account survival
-   Conservative start ensures we don't blow up early

Expected Duration: 5-7 trades (2-3 days)

**Phase 2: Acceleration ($1,000 → $5,000)**
Goal: Aggressive growth with an established base.

Parameters:

-   Base Risk: 15% per trade
-   Max Pyramid Entries: 3
-   Correlation Boost: Enabled (up to 1.25×)
-   Target: $5,000 (5× growth from Phase 1)

Why 15% risk?

-   We now have a $1,000 cushion
-   Can afford to lose a trade and recover
-   Accelerates compounding significantly

Expected Duration: 8-10 trades (3-5 days)

**Phase 3: Hyper-Growth ($5,000+)**
Goal: Maximum aggression to reach target.

Parameters:

-   Base Risk: 20% per trade
-   Max Pyramid Entries: 4
-   Correlation Boost: Enabled (up to 1.3×)
-   Target: Continue aggressive growth

Why 20% risk?

-   Account is large enough to absorb losses
-   Final push to target requires maximum aggression
-   Aggressive growth with established cushion

Expected Duration: 5-8 trades (2-4 days)

#### Implementation

```
enum CompoundingPhase {
    PHASE_FOUNDATION,
    PHASE_ACCELERATION,
    PHASE_HYPER_GROWTH
};

struct PhaseConfig {
    double min_balance;
    double max_balance;
    double base_risk_percent;
    int max_pyramid_entries;
    double correlation_boost_max;
};

PhaseConfig phases[3] = {
    {300, 1000, 0.10, 2, 1.15}, // Foundation
    {1000, 5000, 0.15, 3, 1.25}, // Acceleration
    {5000, 999999, 0.20, 4, 1.3} // Hyper-Growth
};

CompoundingPhase GetCurrentPhase() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);

    if(balance < 1000) return PHASE_FOUNDATION;
    if(balance < 5000) return PHASE_ACCELERATION;
    return PHASE_HYPER_GROWTH;
}

double GetBaseRiskPercent() {
    CompoundingPhase phase = GetCurrentPhase();
    return phases[phase].base_risk_percent;
}
```

### Dynamic Risk Scaling: Bet Big on A++ Setups

Not all trades are created equal. A trade with 5 confluences is better than a trade with 3. We should risk more on the better trades.

#### Confluence Scoring System

Each confirmation layer adds to the "confluence score":

1. Base Signal (RSI Divergence or Harmonic Pattern): +1 point
2. DXY Correlation (< -0.6): +1 point
3. Harmonic Pattern (if RSI Divergence was base): +1 point
4. Perfect DXY Correlation (< -0.7): +1 point
5. All Timeframes Aligned (H4, H1, M15, M5): +1 point

Maximum Confluence Score: 5 points

#### Risk Multiplier Based on Confluence

```
double CalculateRiskMultiplier(int confluence_score) {
    // Base risk from phase (10%, 15%, or 20%)
    double base_risk = GetBaseRiskPercent();

    // Add bonus risk for each confluence point
    double bonus_risk = 0.0;

    switch(confluence_score) {
        case 3: bonus_risk = 0.0; break; // Minimum tradeable setup
        case 4: bonus_risk = 0.05; break; // +5% bonus
        case 5: bonus_risk = 0.10; break; // +10% bonus (A++ setup)
    }

    return base_risk + bonus_risk;
}
```

Example:

-   Phase 2 (Acceleration): Base risk = 15%
-   Confluence score = 5 (perfect setup)
-   Final risk = 15% + 10% = 25% of account on this trade

This is how we accelerate growth on the best setups.

### Correlation Boosting

In addition to confluence-based risk scaling, we also boost position size based on the strength of the Gold-DXY correlation.

```
double CalculateCorrelationBoost(double correlation) {
    // Correlation must be inverse (negative) for Gold-DXY
    if(correlation >= -0.6) return 0.0; // No trade

    // Map correlation strength to boost multiplier
    // -0.6 = 1.0× (no boost)
    // -0.7 = 1.15×
    // -0.8 = 1.3× (maximum boost)

    CompoundingPhase phase = GetCurrentPhase();
    double max_boost = phases[phase].correlation_boost_max;

    double boost = 1.0 + (MathAbs(correlation) - 0.6) * ((max_boost - 1.0) / 0.2);
    return MathMin(boost, max_boost);
}
```

### Final Lot Size Calculation

```
double CalculateLotSize(double stop_loss_pips, int confluence_score, double correlation) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_percent = CalculateRiskMultiplier(confluence_score);
    double correlation_boost = CalculateCorrelationBoost(correlation);

    // Calculate risk amount in dollars
    double risk_amount = balance * risk_percent * correlation_boost;

    // Calculate lot size based on stop loss
    double pip_value = 10.0; // $10 per pip for 0.01 lot on XAUUSD (IC Markets)
    double lot_size = risk_amount / (stop_loss_pips * pip_value);

    // Ensure lot size is within broker limits
    double min_lot = SymbolInfoDouble("XAUUSD", SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble("XAUUSD", SYMBOL_VOLUME_MAX);

    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);

    return NormalizeDouble(lot_size, 2);
}
```

### Pyramiding Logic

Pyramiding allows us to add to winning positions, turning a 1:1.5 R:R trade into a 1:5 or 1:10 R:R trade.

#### Rules

1. First Entry: Full position size based on phased risk
2. Second Entry: 50% of first entry, added at +1.0 × ATR profit
3. Third Entry: 33% of first entry, added at +2.0 × ATR profit
4. Fourth Entry: 25% of first entry, added at +3.0 × ATR profit (Phase 3 only)

Stop Loss Management:

-   After first pyramid entry, move initial SL to breakeven
-   After second pyramid entry, move SL to +1.0 × ATR
-   After third pyramid entry, move SL to +2.0 × ATR

```
void ManagePyramiding(int ticket) {
    double entry_price = OrderOpenPrice();
    double current_price = SymbolInfoDouble("XAUUSD", SYMBOL_BID);
    double atr = iATR("XAUUSD", PERIOD_M15, 14, 0);

    double profit_pips = MathAbs(current_price - entry_price) / _Point;
    double atr_pips = atr / _Point;

    int pyramid_count = GetPyramidCount(ticket);
    int max_pyramids = phases[GetCurrentPhase()].max_pyramid_entries;

    // Check if we should add a pyramid entry
    if(pyramid_count == 1 && profit_pips >= atr_pips) {
        AddPyramidEntry(ticket, 0.5); // 50% of original
        MoveStopLossToBreakeven(ticket);
    }
    else if(pyramid_count == 2 && profit_pips >= 2 * atr_pips) {
        AddPyramidEntry(ticket, 0.33); // 33% of original
        MoveStopLoss(ticket, entry_price + atr);
    }
    else if(pyramid_count == 3 && profit_pips >= 3 * atr_pips && max_pyramids >= 4) {
        AddPyramidEntry(ticket, 0.25); // 25% of original
        MoveStopLoss(ticket, entry_price + 2 * atr);
    }
}
```

## Technical Implementation

### Prerequisites

-   Platform: MetaTrader 5 (Build 3802 or higher)
-   Broker: IC Markets (Raw Spread Account)
-   Language: MQL5
-   Architecture: Object-Oriented Programming (OOP)

### Core Classes

1. CChimeraEA (Main EA Class)

    ```
    class CChimeraEA {
    private:
        CMarketData* m_market_data;
        CCorrelationEngine* m_correlation;
        CPatternDetector* m_pattern_detector;
        CRiskManager* m_risk_manager;
        CTradeExecutor* m_trade_executor;
        CUIPanel* m_ui_panel;

        CompoundingPhase m_current_phase;

    public:
        CChimeraEA();
        ~CChimeraEA();

        int OnInit();
        void OnTick();
        void OnDeinit(const int reason);
    };
    ```

2. CMarketData (Multi-Symbol Data Handler)

    ```
    class CMarketData {
    private:
        string m_symbols[3]; // XAUUSD, US30, DXY
        ENUM_TIMEFRAMES m_timeframes[4]; // H4, H1, M15, M5

    public:
        double GetClose(string symbol, ENUM_TIMEFRAMES tf, int shift);
        double GetHigh(string symbol, ENUM_TIMEFRAMES tf, int shift);
        double GetLow(string symbol, ENUM_TIMEFRAMES tf, int shift);
        bool IsDataSynchronized();
    };
    ```

3. CCorrelationEngine

    ```
    class CCorrelationEngine {
    private:
        int m_correlation_period;

    public:
        double CalculateCorrelation(string symbol1, string symbol2, ENUM_TIMEFRAMES tf);
        double GetSignalBoost(double correlation);
        bool IsCorrelationValid(double correlation);
    };
    ```

4. CPatternDetector

    ```
    class CPatternDetector {
    public:
        bool DetectBullishRSIDivergence();
        bool DetectBearishRSIDivergence();
        HarmonicPattern DetectGartley();
        HarmonicPattern DetectBat();
        HarmonicPattern DetectABCD();
        HarmonicPattern DetectCypher();
    };
    ```

5. CRiskManager

    ```
    class CRiskManager {
    private:
        PhaseConfig m_phases[3];

    public:
        CompoundingPhase GetCurrentPhase();
        double GetBaseRiskPercent();
        double CalculateLotSize(double sl_pips, int confluence, double correlation);
        bool ValidateRisk(double lot_size);
    };
    ```

6. CTradeExecutor

    ```
    class CTradeExecutor {
    public:
        int OpenTrade(string symbol, ENUM_ORDER_TYPE type, double lot, double sl, double tp);
        void ManagePyramiding(int ticket);
        void UpdateStopLoss(int ticket, double new_sl);
        void CloseAllTrades();
    };
    ```

7. CUIPanel (On-Chart Display)
    ```
    class CUIPanel {
    public:
        void CreatePanel();
        void UpdatePhaseDisplay(CompoundingPhase phase);
        void UpdateBalance(double balance);
        void UpdateCorrelation(double correlation);
        void UpdateNextTradeInfo(double lot_size, double risk_percent);
    };
    ```

### File Structure

```
ChimeraEA/
├── ChimeraEA.mq5 // Main EA file
├── Include/
│ ├── MarketData.mqh
│ ├── CorrelationEngine.mqh
│ ├── PatternDetector.mqh
│ ├── RiskManager.mqh
│ ├── TradeExecutor.mqh
│ └── UIPanel.mqh
└── Config/
└── Settings.mqh // Hardcoded parameters
```

### Hardcoded Configuration (NO User Inputs)

```
// Settings.mqh
// Account Configuration
#define STARTING_BALANCE 300.0
#define TARGET_BALANCE 30000.0

// Symbol Configuration
#define TRADE_SYMBOL "XAUUSD"
#define CORRELATION_SYMBOL "DXY"
#define CONFIRMATION_SYMBOL "US30"

// Correlation Settings
#define CORRELATION_THRESHOLD -0.6
#define CORRELATION_PERIOD 50

// Phase Settings
#define PHASE1_MIN 300
#define PHASE1_MAX 1000
#define PHASE1_RISK 0.10
#define PHASE1_PYRAMIDS 2
#define PHASE1_BOOST 1.15

#define PHASE2_MIN 1000
#define PHASE2_MAX 5000
#define PHASE2_RISK 0.15
#define PHASE2_PYRAMIDS 3
#define PHASE2_BOOST 1.25

#define PHASE3_MIN 5000
#define PHASE3_RISK 0.20
#define PHASE3_PYRAMIDS 4
#define PHASE3_BOOST 1.3

// Trading Sessions (GMT)
#define LONDON_START 8
#define LONDON_END 17
#define NY_START 13
#define NY_END 22

// Risk Filters
#define MAX_SPREAD_PIPS 25
#define MIN_ADX 25

// Pattern Settings
#define RSI_PERIOD 9
#define ATR_PERIOD 14
#define EMA_PERIOD 200
```

## Prerequisites and Requirements

### System Requirements

#### Hardware Requirements

-   CPU: Minimum 4 cores, 2.5GHz or higher
-   RAM: Minimum 4GB, recommended 8GB
-   Storage: Minimum 1GB free space for EA and logs
-   Network: Stable internet connection with low latency (<100ms to broker server)

#### Software Requirements

-   Operating System: Windows 10+ (64-bit) or Windows Server 2016+
-   MetaTrader 5: Build 3802 or higher
-   VPS: Recommended for 24/7 operation (Vultr, AWS, or broker VPS)

#### Broker Requirements

IC Markets Account:

-   Account Type: Raw Spread Account (NOT Standard Account)
-   Leverage: 1:500 (verified from official specs)
-   Minimum Deposit: $300
-   API Access: Enabled for MT5
-   Symbols Required: XAUUSD, US30, DXY (all must be available)

Spread Verification:

-   XAUUSD typical spread: 0.1-0.3 pips (raw)
-   Commission: $7 per lot round-trip
-   Execution: Market execution (no requotes)

### Development Environment Setup

#### MetaEditor Configuration

1. Open MetaEditor (F4 in MT5)
2. Create new Expert Advisor project
3. Enable strict compilation mode
4. Set optimization level: O2

#### Testing Environment

-   Strategy Tester: Visual mode for initial testing
-   Optimization: Genetic algorithm for parameter validation
-   Backtest Period: Minimum 3 months of tick data
-   Forward Test: Minimum 1 month on demo account

## Testing & Validation

### Essential Testing Requirements

The EA must be tested to ensure it works correctly with no bugs. Keep testing simple and focused on verifying functionality.

#### 1. Code Compilation & Basic Testing

Requirements:

-   ✅ Code compiles without errors in MT5
-   ✅ EA attaches to XAUUSD M5 chart without crashes
-   ✅ All 3 symbols (XAUUSD, US30, DXY) load data correctly
-   ✅ UI panel displays correctly with real-time data

How to verify:

-   Compile the code in MetaEditor
-   Attach EA to demo chart
-   Verify no errors in Expert log
-   Screenshot of UI panel working

Deliverable: Screenshot showing EA running with UI panel visible

#### 2. Strategy Tester Backtest

Purpose: Verify the EA executes trades according to the specification

Settings:

-   Period: Last 1 month (minimum)
-   Mode: Every tick based on real ticks
-   Spread: Variable spread
-   Commission: $7 per lot
-   Starting balance: $300

What to verify:

-   ✅ EA opens trades (not zero trades)
-   ✅ Correlation filtering works (only trades when Gold-DXY < -0.6)
-   ✅ Phase transitions work ($300→$1K→$5K with correct risk levels)
-   ✅ Pyramiding adds positions on winning trades
-   ✅ No critical errors in backtest log

Deliverable: MT5 Strategy Tester report (HTML export)

#### 3. Demo Account Test (1 Week)

Purpose: Verify EA works in live market conditions (forward trading test)

Settings:

-   Duration: 1 week (5 trading days minimum)
-   Broker: IC Markets demo account
-   Starting balance: $300
-   Monitoring: Check daily for errors

What to verify:

-   ✅ EA generates signals in live market
-   ✅ Trades execute without errors
-   ✅ No crashes or freezes
-   ✅ Correlation filtering working
-   ✅ UI panel updates correctly

Deliverable:

-   Screenshot at end of week showing account statement
-   MT5 account history export

### Acceptance Criteria (Essential Only)

The EA is ready for delivery when:

#### Code Quality:

1. ✅ Compiles without errors
2. ✅ Key functions have comments explaining logic
3. ✅ No crashes during testing

#### Functionality:

1. ✅ Reads data from XAUUSD, US30, DXY correctly
2. ✅ Only trades when Gold-DXY correlation < -0.6
3. ✅ Detects harmonic patterns and RSI divergence
4. ✅ Phase system transitions at $1,000 and $5,000
5. ✅ Lot sizing adjusts based on balance and phase
6. ✅ Pyramiding adds positions on winning trades
7. ✅ UI panel displays all required information

#### Testing Evidence:

1. ✅ Screenshot of EA running on demo chart
2. ✅ Backtest report (1 month minimum)
3. ✅ Demo account test results (1 week minimum)

#### Documentation:

1. ✅ Installation instructions (simple text file)
2. ✅ Brief explanation of how to use the EA

That's it. No excessive testing phases. Just prove it works.

## Deployment Procedures

### Step 1: Installation

1. Copy ChimeraEA.ex5 to MQL5/Experts/ folder
2. Copy all .mqh files to MQL5/Include/ChimeraEA/ folder
3. Restart MetaTrader 5

### Step 2: Chart Setup

1. Open XAUUSD M5 chart
2. Attach ChimeraEA to the chart
3. Enable AutoTrading (Ctrl+E)
4. Verify UI panel appears in top-left corner

### Step 3: Symbol Verification

1. Ensure XAUUSD, US30, and DXY are in Market Watch
2. Verify all symbols have data on M5, M15, H1, H4
3. Check spread on XAUUSD (should be < 0.5 pips on Raw Spread account)

### Step 4: Account Verification

1. Confirm account balance is $300+
2. Verify leverage is 1:500
3. Check margin requirements for 0.01 lot XAUUSD

### Step 5: Monitoring

1. Watch for first trade (may take 1-2 hours)
2. Verify correlation value on UI panel (should be < -0.6 when trading)
3. Monitor phase transitions

## Operational Guidelines

### Daily Startup Checklist

-   ☑ Verify all three data feeds are active (XAUUSD, US30, DXY)
-   ☑ Check data synchronization across symbols
-   ☑ Validate correlation calculations (should update every tick)
-   ☑ Confirm current phase is correct based on balance
-   ☑ Review overnight trades (if any)

### Real-Time Monitoring

What to watch:

-   Correlation Dashboard: Live Gold-DXY correlation (displayed on UI)
-   Signal Quality: Number of confluence points for each trade
-   Phase Progress: Current balance vs phase target
-   Pyramid Status: Number of active pyramid entries

Warning signs:

-   Correlation rising above -0.4 (relationship weakening)
-   Multiple losing trades in a row (> 2)
-   Spread widening beyond 25 pips
-   Data feed disconnection

### Performance Validation

Daily Performance Review:

-   Compare win rate to expected 95%
-   Verify correlation filtering is working (no trades when correlation > -0.6)
-   Check pyramid entries are being added correctly
-   Monitor drawdown (should stay < 20%)

## Troubleshooting Guide

### Common Issues

#### 1. No Trades Being Executed

Symptoms: EA is running but not opening any trades

Possible Causes:

-   DXY correlation not meeting threshold (< -0.6)
-   No harmonic patterns or RSI divergences detected
-   Outside trading sessions (London/NY)
-   Spread too wide (> 25 pips)

Solutions:

-   Check correlation value on UI panel
-   Verify all symbols have data
-   Wait for London/NY session
-   Check XAUUSD spread

#### 2. Correlation Calculation Errors

Symptoms: Correlation shows NaN or 0.0

Possible Causes:

-   Insufficient data history (< 50 periods)
-   Data gaps or anomalies
-   Symbol names incorrect

Solutions:

-   Ensure minimum 50 bars of data on M5
-   Verify symbol names: "XAUUSD", "DXY", "US30"
-   Restart EA to reset correlation buffers

#### 3. Incorrect Lot Sizes

Symptoms: Lot sizes too large or too small

Possible Causes:

-   Balance not updating correctly
-   Phase detection error
-   Broker lot size limits

Solutions:

-   Verify account balance matches UI display
-   Check current phase is correct
-   Review broker min/max lot sizes for XAUUSD

#### 4. Pyramiding Not Working

Symptoms: No additional entries being added to winning trades

Possible Causes:

-   Trade not in profit by 1.0 × ATR yet
-   Maximum pyramids reached for current phase
-   Insufficient margin

Solutions:

-   Wait for trade to reach +1.0 × ATR profit
-   Check current phase pyramid limit
-   Verify free margin is sufficient

## Timeframe Recommendation

Which timeframe should you attach the EA to?

Answer: M5 (5-Minute Chart)

Why M5?

1. Execution Timeframe: M5 is where RSI divergence signals are generated
2. Tick Frequency: M5 provides enough ticks for real-time monitoring without excessive CPU usage
3. Pattern Detection: M5 allows the EA to catch divergences as they form
4. Standard Practice: Most multi-timeframe EAs are attached to their execution timeframe

Important Notes:

-   The EA will automatically analyze H4, H1, and M15 internally using iClose(), iMA(), etc.
-   You do NOT need to open multiple charts
-   Attach to XAUUSD M5 only
-   The EA handles all other timeframes programmatically

## Final Notes for Developer

### Code Quality Standards

-   Clean Code: Follow MQL5 best practices
-   Comments: Document all complex logic
-   Error Handling: Use GetLastError() and handle all trade errors
-   Logging: Write detailed logs for debugging
-   Performance: Optimize for speed (avoid nested loops)

### Deliverables

1. Source Code: All .mq5 and .mqh files
2. Compiled EA: ChimeraEA.ex5
3. User Manual: PDF guide for installation and operation
4. Backtest Report: Strategy Tester HTML report
5. Demo Video: Screen recording showing EA in action

### Support & Updates

-   Bug Fixes: 30 days of free bug fixes after delivery
-   Minor Updates: Adjustments to hardcoded parameters if needed
-   Major Updates: New features (if requested) will be quoted separately

---

End of Specification

This document contains everything needed to build Project Chimera v9.0. If you have any questions during development, refer back to this specification or contact the project owner.

Good luck, and happy coding!
