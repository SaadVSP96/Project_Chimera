# Project Chimera

A modular Expert Advisor for MetaTrader 5 that automates XAUUSD (Gold) trading through multi-analyzer confluence and advanced technical pattern recognition.

## Overview
Project Chimera combines multiple analytical frameworks into a single cohesive trading system. Rather than relying on a single indicator, the EA synthesizes signals from RSI divergence detection, harmonic pattern analysis, multi-timeframe correlation filtering, and trend confirmation to execute high-confidence trades.

## Architecture

The system is built on a **modular, object-oriented foundation** with strict separation of concerns:

### Core Components

- **Market Data Manager** - Universal market data system managing OHLC buffers across multiple symbols and timeframes with TradingView-style access patterns
- **RSI Divergence Analyzer** - Detects bullish and bearish divergences using pivot-based analysis with configurable oversold/overbought thresholds
- **Harmonic Pattern Analyzer** - Identifies Gartley, Bat, ABCD, and Cypher patterns using Fibonacci ratio validation and Potential Reversal Zone (PRZ) monitoring
- **Correlation Filter** - Multi-asset correlation analysis using DXY/US30 to filter XAUUSD entries
- **Trend Filter** - Multi-timeframe trend confirmation using MA and ADX on H4/H1 timeframes
- **Confluence Scoring System** - Aggregates signals from multiple analyzers into a composite confidence score
- **Trade Management** - ATR-based dynamic stop losses, take profits, and sophisticated pyramiding across three account growth phases

### Visualization Library

Custom lightweight chart object visualization system supporting:
- Trend lines and divergence markers
- Pivot point labeling
- Horizontal reference levels
- Indicator line plotting (RSI, EMAs, etc.)
- Multi-timeframe alignment for cross-timeframe visualization

## Key Features

**Multi-Pattern Detection** - Simultaneous detection of RSI divergences and harmonic patterns  
**Confluence-Based Entries** - Multiple signal alignment required before trade execution  
**Phased Risk Management** - Three-tier account growth with position sizing adaptation  
**Multi-Timeframe Analysis** - Integration of M5, M15, H1, H4, and D1 data  
**Dynamic Visualization** - Real-time chart overlay of detected patterns and indicators  
**Production-Ready** - Proper error handling, state management, and resource cleanup  

## Technical Stack

- **Language:** MQL5
- **Platform:** MetaTrader 5
- **Architecture Pattern:** Dependency Injection, Singleton, Strategy, Observer, Facade
- **Configuration:** Struct-based with getter methods for immutable config access

