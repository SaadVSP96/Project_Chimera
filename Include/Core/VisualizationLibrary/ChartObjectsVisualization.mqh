//+------------------------------------------------------------------+
//| Chart Objects Visualization Library                              |
//| Purpose: Lightweight, composable chart object management          |
//| Architecture: Independent classes with counter-based naming       |
//|               and internal state management                       |
//+------------------------------------------------------------------+

#ifndef _CHART_OBJECTS_VIZ_
#define _CHART_OBJECTS_VIZ_

//+------------------------------------------------------------------+
//| CLine - Two-point trend lines, trend channels, support/resistance|
//+------------------------------------------------------------------+
class CLine {
  private:
   string m_prefix;              // Unique prefix for object naming
   int m_counter;                // Incremental counter for unique IDs
   int m_maxObjects;             // Maximum objects to keep (cleanup threshold)
   int m_chartID;                // 0=main chart, 1+=subwindows
   color m_lastColor;            // Last color used (for Hide/Show)
   ENUM_LINE_STYLE m_lastStyle;  // Last style used
   int m_lastWidth;              // Last width used

  public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //| Parameters:                                                       |
   //|   prefix      - Unique identifier for this line family           |
   //|                 Examples: "RSITrend", "HarmonicXAB", "Support"  |
   //|   maxObjects  - Max lines to keep before cleanup removes oldest  |
   //|   chartID     - 0 for main chart, 1+ for subwindows             |
   //+------------------------------------------------------------------+
   CLine(string prefix, int maxObjects, int chartID) {
      m_prefix = prefix;
      m_maxObjects = maxObjects;
      m_chartID = chartID;
      m_counter = 0;
      m_lastColor = clrWhite;
      m_lastStyle = STYLE_SOLID;
      m_lastWidth = 1;
   }

   //+------------------------------------------------------------------+
   //| Draw - Create a single line between two points                  |
   //| Parameters:                                                       |
   //|   time1, price1  - Start point (older bar)                      |
   //|   time2, price2  - End point (newer bar)                        |
   //|   lineColor      - Line color (clrRed, clrBlue, etc.)           |
   //|   style          - Line style (STYLE_SOLID, STYLE_DASH, etc.)   |
   //|   width          - Line width (1-5 recommended)                 |
   //| Returns: true if object created successfully                     |
   //+------------------------------------------------------------------+
   bool Draw(datetime time1, double price1, datetime time2, double price2,
             color lineColor, ENUM_LINE_STYLE style = STYLE_SOLID, int width = 1) {
      string name = m_prefix + "_" + IntegerToString(m_counter++);
      m_lastColor = lineColor;
      m_lastStyle = style;
      m_lastWidth = width;

      if (!ObjectCreate(0, name, OBJ_TREND, m_chartID, time1, price1, time2, price2)) {
         PrintFormat("CLine::Draw failed - Unable to create object %s", name);
         return false;
      }

      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Hide - Hide all objects in this family by setting color to none |
   //| Strategy: Better than delete because counter stays consistent   |
   //+------------------------------------------------------------------+
   void Hide() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrNONE);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Show - Restore color for all objects (uses last color)          |
   //+------------------------------------------------------------------+
   void Show() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, m_lastColor);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Cleanup - Delete oldest objects when counter exceeds max        |
   //| Important: Call manually in OnTick on new bar                   |
   //| Strategy: Removes oldest (lowest index) objects first            |
   //+------------------------------------------------------------------+
   void Cleanup() {
      if (m_counter <= m_maxObjects)
         return;

      int toDelete = m_counter - m_maxObjects;
      for (int i = 0; i < toDelete; i++) {
         string name = m_prefix + "_" + IntegerToString(i);
         ObjectDelete(0, name);
      }
   }

   //+------------------------------------------------------------------+
   //| GetCounter - Return current number of objects created           |
   //| Useful for debugging or understanding state                     |
   //+------------------------------------------------------------------+
   int GetCounter() {
      return m_counter;
   }
};

//+------------------------------------------------------------------+
//| CLabel - Text labels for pivots, pattern names, price levels     |
//+------------------------------------------------------------------+
class CLabel {
  private:
   string m_prefix;
   int m_counter;
   int m_maxObjects;
   int m_chartID;
   color m_lastColor;
   int m_lastFontSize;

  public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //| Parameters:                                                       |
   //|   prefix      - Examples: "RSIDivergence", "HarmonicPattern",   |
   //|                 "SwingPivot"                                     |
   //|   maxObjects  - Keep only N most recent labels                   |
   //|   chartID     - Chart window (0 for main)                        |
   //+------------------------------------------------------------------+
   CLabel(string prefix, int maxObjects, int chartID) {
      m_prefix = prefix;
      m_maxObjects = maxObjects;
      m_chartID = chartID;
      m_counter = 0;
      m_lastColor = clrWhite;
      m_lastFontSize = 8;
   }

   //+------------------------------------------------------------------+
   //| Draw - Create a text label at specific chart position            |
   //| Parameters:                                                      |
   //|   time         - X-axis position (bar time)                      |
   //|   price        - Y-axis position (price level)                   |
   //|   text         - Label text (short: "H", "L", "Div", "BB")       |
   //|   labelColor   - Text color                                      |
   //|   fontSize     - Font size (7-12 typical)                        |
   //|   anchor       - Text anchor point relative to (time, price)     |
   //|                  ANCHOR_CENTER, ANCHOR_LOWER, ANCHOR_UPPER       |
   //+------------------------------------------------------------------+
   bool Draw(datetime time, double price, string text, color labelColor,
             int fontSize = 8, int anchor = ANCHOR_CENTER) {
      string name = m_prefix + "_" + IntegerToString(m_counter++);
      m_lastColor = labelColor;
      m_lastFontSize = fontSize;

      if (!ObjectCreate(0, name, OBJ_TEXT, m_chartID, time, price)) {
         PrintFormat("CLabel::Draw failed - Unable to create label %s", name);
         return false;
      }

      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);

      return true;
   }

   void Hide() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrNONE);
         }
      }
   }

   void Show() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, m_lastColor);
         }
      }
   }

   void Cleanup() {
      if (m_counter <= m_maxObjects)
         return;

      int toDelete = m_counter - m_maxObjects;
      for (int i = 0; i < toDelete; i++) {
         ObjectDelete(0, m_prefix + "_" + IntegerToString(i));
      }
   }

   int GetCounter() {
      return m_counter;
   }
};

//+------------------------------------------------------------------+
//| CPivot - Pivot markers with arrow symbols (high/low indicators) |
//+------------------------------------------------------------------+
class CPivot {
  private:
   string m_prefix;
   int m_counter;
   int m_maxObjects;
   int m_chartID;
   color m_lastColor;

  public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //| Parameters:                                                       |
   //|   prefix      - Examples: "RSIPivot", "InternalPivot",          |
   //|                 "SwingPivot"                                     |
   //|   maxObjects  - Max pivot markers to keep                        |
   //|   chartID     - Chart window                                     |
   //+------------------------------------------------------------------+
   CPivot(string prefix, int maxObjects, int chartID) {
      m_prefix = prefix;
      m_maxObjects = maxObjects;
      m_chartID = chartID;
      m_counter = 0;
      m_lastColor = clrWhite;
   }

   //+------------------------------------------------------------------+
   //| Draw - Create a pivot marker (arrow symbol)                     |
   //| Parameters:                                                       |
   //|   time       - Bar time where pivot is                          |
   //|   price      - Price level of pivot                             |
   //|   pivotType  - Type of pivot: "H", "L", "HH", "HL", "LH", "LL"|
   //|               (H=high, L=low, HH=higher high, LL=lower low, etc)|
   //|   pivotColor - Arrow color (typically bullish/bearish signal)  |
   //| Returns: true if marker created                                 |
   //+------------------------------------------------------------------+
   bool Draw(datetime time, double price, string pivotType, color pivotColor) {
      // Choose arrow symbol based on pivot type
      // Pivot highs use down-pointing symbol, lows use up-pointing
      bool isHigh = (pivotType == "H" || pivotType == "HH" || pivotType == "LH");
      int arrowCode = isHigh ? 234 : 233;  // 234=down triangle, 233=up triangle
      int anchor = isHigh ? ANCHOR_LOWER : ANCHOR_UPPER;

      string name = m_prefix + "_" + pivotType + "_" + IntegerToString(m_counter++);
      m_lastColor = pivotColor;

      if (!ObjectCreate(0, name, OBJ_ARROW, m_chartID, time, price)) {
         PrintFormat("CPivot::Draw failed - Unable to create pivot %s", name);
         return false;
      }

      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, name, OBJPROP_COLOR, pivotColor);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      return true;
   }

   void Hide() {
      for (int i = 0; i < m_counter; i++) {
         for (int j = 0; j < 6; j++) {
            string types[] = {"H", "L", "HH", "HL", "LH", "LL"};
            string name = m_prefix + "_" + types[j] + "_" + IntegerToString(i);
            if (ObjectFind(0, name) >= 0) {
               ObjectSetInteger(0, name, OBJPROP_COLOR, clrNONE);
            }
         }
      }
   }

   void Show() {
      for (int i = 0; i < m_counter; i++) {
         for (int j = 0; j < 6; j++) {
            string types[] = {"H", "L", "HH", "HL", "LH", "LL"};
            string name = m_prefix + "_" + types[j] + "_" + IntegerToString(i);
            if (ObjectFind(0, name) >= 0) {
               ObjectSetInteger(0, name, OBJPROP_COLOR, m_lastColor);
            }
         }
      }
   }

   void Cleanup() {
      if (m_counter <= m_maxObjects)
         return;

      int toDelete = m_counter - m_maxObjects;
      for (int i = 0; i < toDelete; i++) {
         for (int j = 0; j < 6; j++) {
            string types[] = {"H", "L", "HH", "HL", "LH", "LL"};
            ObjectDelete(0, m_prefix + "_" + types[j] + "_" + IntegerToString(i));
         }
      }
   }

   int GetCounter() {
      return m_counter;
   }
};

//+------------------------------------------------------------------+
//| CLevel - Horizontal reference levels (RSI 70/30, support, etc)  |
//+------------------------------------------------------------------+
class CLevel {
  private:
   string m_prefix;
   int m_counter;
   int m_maxObjects;
   int m_chartID;
   color m_lastColor;
   ENUM_LINE_STYLE m_lastStyle;

  public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //| Parameters:                                                       |
   //|   prefix      - Examples: "RSILevel", "Support", "Resistance"  |
   //|   maxObjects  - Max levels to keep                              |
   //|   chartID     - Chart window                                     |
   //+------------------------------------------------------------------+
   CLevel(string prefix, int maxObjects, int chartID) {
      m_prefix = prefix;
      m_maxObjects = maxObjects;
      m_chartID = chartID;
      m_counter = 0;
      m_lastColor = clrWhite;
      m_lastStyle = STYLE_DASH;
   }

   //+------------------------------------------------------------------+
   //| DrawHorizontal - Create a horizontal level line                 |
   //| Parameters:                                                       |
   //|   price      - Y-axis value (what level to draw)                |
   //|   label      - Label identifier (used in naming, keep short)    |
   //|   levelColor - Line color                                        |
   //|   style      - Line style (STYLE_SOLID, STYLE_DASH, etc.)       |
   //| Note: Line extends across entire visible chart with ray_right  |
   //+------------------------------------------------------------------+
   bool DrawHorizontal(double price, string label, color levelColor,
                       ENUM_LINE_STYLE style = STYLE_DASH) {
      string name = m_prefix + "_" + label + "_" + IntegerToString(m_counter++);
      m_lastColor = levelColor;
      m_lastStyle = style;

      // Get time bounds (500 bars back to far future)
      datetime leftTime = iTime(_Symbol, PERIOD_CURRENT, 500);
      datetime rightTime = TimeCurrent() + 100 * PeriodSeconds(PERIOD_CURRENT);

      if (leftTime == 0) {
         PrintFormat("CLevel::DrawHorizontal - Failed to get historical time");
         return false;
      }

      if (!ObjectCreate(0, name, OBJ_TREND, m_chartID, leftTime, price, rightTime, price)) {
         PrintFormat("CLevel::DrawHorizontal failed - Unable to create level %s", name);
         return false;
      }

      ObjectSetInteger(0, name, OBJPROP_COLOR, levelColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);  // Extend right infinitely

      return true;
   }

   void Hide() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_Level_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrNONE);
         }
      }
   }

   void Show() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_Level_" + IntegerToString(i);
         if (ObjectFind(0, name) >= 0) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, m_lastColor);
         }
      }
   }

   void Cleanup() {
      if (m_counter <= m_maxObjects)
         return;

      int toDelete = m_counter - m_maxObjects;
      for (int i = 0; i < toDelete; i++) {
         ObjectDelete(0, m_prefix + "_Level_" + IntegerToString(i));
      }
   }

   int GetCounter() {
      return m_counter;
   }
};

//+------------------------------------------------------------------+
//| CIndicatorLine - Visualize indicator values as connected lines  |
//| Assumes buffer is already aligned to current chart timeframe    |
//+------------------------------------------------------------------+
class CIndicatorLine {
  private:
   string m_prefix;
   int m_counter;
   int m_chartID;
   int m_barsToVisualize;  // Determined from buffer size
   bool m_hasBuffer;
   color m_lastColor;
   ENUM_LINE_STYLE m_lastStyle;
   int m_lastWidth;

  public:
   // Simplified: just prefix and chartID
   CIndicatorLine(string prefix, int chartID) {
      m_prefix = prefix;
      m_chartID = chartID;
      m_barsToVisualize = 0;  // Will be set by SetDataSource
      m_counter = 0;
      m_hasBuffer = false;
      m_lastColor = clrWhite;
      m_lastStyle = STYLE_SOLID;
      m_lastWidth = 1;
   }

   // SetDataSource determines bar count from buffer size
   bool SetDataSource(double& buffer[]) {
      if (ArraySize(buffer) == 0) {
         return false;
      }
      ArraySetAsSeries(buffer, true);
      m_barsToVisualize = ArraySize(buffer) - 1;  // ← Auto-determined!
      m_hasBuffer = true;
      return true;
   }

   bool DrawLine(double& buffer[], color lineColor, ENUM_LINE_STYLE style = STYLE_SOLID, int width = 1) {
      if (!m_hasBuffer) return false;

      m_lastColor = lineColor;
      m_lastStyle = style;
      m_lastWidth = width;

      for (int i = 0; i < m_barsToVisualize - 1; i++) {
         datetime time1 = iTime(_Symbol, PERIOD_CURRENT, i);
         datetime time2 = iTime(_Symbol, PERIOD_CURRENT, i + 1);
         if (time1 == 0 || time2 == 0) continue;

         double val1 = buffer[i];
         double val2 = buffer[i + 1];
         if (val1 == 0 || val2 == 0) continue;

         string name = m_prefix + "_Seg_" + IntegerToString(m_counter++);
         ObjectCreate(m_chartID, name, OBJ_TREND, m_chartID, time1, val1, time2, val2);
         ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(m_chartID, name, OBJPROP_STYLE, style);
         ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, width);
         ObjectSetInteger(m_chartID, name, OBJPROP_BACK, true);
      }
      return true;
   }

   // Delete ALL segments and redraw from scratch
   void Redraw(double& buffer[]) {
      // Delete all segments
      for (int i = 0; i < m_counter; i++) {
         ObjectDelete(m_chartID, m_prefix + "_Seg_" + IntegerToString(i));
      }
      m_counter = 0;
      // Redraw with current buffer data
      DrawLine(buffer, m_lastColor, m_lastStyle, m_lastWidth);
   }

   // Hide all segments
   void Hide() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_Seg_" + IntegerToString(i);
         if (ObjectFind(m_chartID, name) >= 0) {
            ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clrNONE);
         }
      }
   }

   // Show all segments
   void Show() {
      for (int i = 0; i < m_counter; i++) {
         string name = m_prefix + "_Seg_" + IntegerToString(i);
         if (ObjectFind(m_chartID, name) >= 0) {
            ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, m_lastColor);
         }
      }
   }

   // NEW: Delete all segments
   void Delete() {
      for (int i = 0; i < m_counter; i++) {
         ObjectDelete(m_chartID, m_prefix + "_Seg_" + IntegerToString(i));
      }
      m_counter = 0;
   }

   int GetCounter() {
      return m_counter;
   }
};
#endif  // _CHART_OBJECTS_VIZ_

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| USAGE GUIDE & COMMON PATTERNS                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

/*
================================================================================
GENERAL PRINCIPLES
================================================================================

1. COUNTER-BASED NAMING
   - Each class maintains an internal counter
   - Objects named: "prefix_0", "prefix_1", "prefix_2", etc.
   - Counter increments with each Draw() call
   - Cleanup() deletes oldest objects when counter > maxObjects

2. CONSTRUCTOR PARAMETERS
   string prefix    → Unique identifier for this object family
                     Should reflect what's being drawn
                     Examples: "RSITrend", "HarmonicXAB", "SwingPivot"

   int maxObjects   → Threshold before cleanup() starts deleting old objects
                     Set based on chart clutter tolerance
                     50-100 for markers, 100-200 for complex analyzers

   int chartID      → 0 = main price chart
                      1+ = indicator subwindows
                      If using subwindow, MT5 creates it automatically

3. HIDE/SHOW STRATEGY
   - Hide() sets color to clrNONE (keeps object, makes invisible)
   - Show() restores original color
   - Faster than delete/recreate
   - Useful for toggle visibility based on user input

4. CLEANUP RESPONSIBILITY
   - You must call Cleanup() manually in OnTick()
   - Typically on new bar: if(isNewBar) { obj.Cleanup(); }
   - Or after pattern completion: harmonic.Cleanup();
   - Without cleanup, objects accumulate forever

================================================================================
CLASS SPECIFICS & TRICKY PARTS
================================================================================

CLine
------
TRICKY: time1/time2 ordering
   - time1 should be older bar (left side of chart)
   - time2 should be newer bar (right side of chart)
   - Reversed order still works but visually confusing

EXAMPLE PITFALL:
   // WRONG: Times are reversed
   trendLine.Draw(time2, price2, time1, price1, clrRed);

   // RIGHT: Older to newer
   trendLine.Draw(time1, price1, time2, price2, clrRed);

USAGE:
   CLine rsiTrendLines("RSITrend", 50, 0);

   // Pivot low at bar 10, high at bar 5
   datetime lowTime = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime highTime = iTime(_Symbol, PERIOD_CURRENT, 5);
   double lowPrice =  get pivot low ;
   double highPrice =  get pivot high ;

   // Draw line from low to high
   rsiTrendLines.Draw(lowTime, lowPrice, highTime, highPrice, clrGreen);

---

CLabel
-------
TRICKY: Anchor points affect text placement relative to (time, price)
   ANCHOR_CENTER   → Text centered on point (default)
   ANCHOR_UPPER    → Text above point (for labels below pivots)
   ANCHOR_LOWER    → Text below point (for labels above pivots)

EXAMPLE:
   CLabel pivotLabels("SwingPivot", 100, 0);

   // For pivot HIGH (want label ABOVE the point)
   pivotLabels.Draw(highTime, highPrice, "HH", clrRed, 8, ANCHOR_UPPER);

   // For pivot LOW (want label BELOW the point)
   pivotLabels.Draw(lowTime, lowPrice, "LL", clrGreen, 8, ANCHOR_LOWER);

PITFALL: Font size affects visibility
   - 7-8: Small, good for dense charts
   - 9-10: Medium, default readable
   - 11+: Large, can clutter fast

---

CPivot
-------
CRITICAL: pivotType parameter must match object naming
   Valid types: "H", "L", "HH", "HL", "LH", "LL"
   Class uses these in internal naming for hide/show to work correctly

PITFALL: Using invalid types breaks hide/show:
   // WRONG: pivot type "X" not recognized
   pivot.Draw(time, price, "X", clrRed);
   // Later: pivot.Hide() won't find objects with "X"

   // RIGHT: Use standard types
   pivot.Draw(time, price, "LL", clrRed);

ARROW SYMBOLS:
   234 = Down triangle (for highs: HH, LH, H)
   233 = Up triangle (for lows: LL, HL, L)
   This is automatic based on pivotType

USAGE:
   CPivot internalPivots("Internal", 100, 0);

   if(internalHighDetected) {
      internalPivots.Draw(highTime, highPrice, "H", clrRed);
   }
   if(internalLowDetected) {
      internalPivots.Draw(lowTime, lowPrice, "L", clrBlue);
   }

   // More complex:
   if(lastHighWasHigher) {
      internalPivots.Draw(highTime, highPrice, "HH", clrDarkRed);
   } else {
      internalPivots.Draw(highTime, highPrice, "LH", clrOrange);
   }

---

CLevel
-------
TRICKY: Time bounds calculation
   - DrawHorizontal() automatically spans entire chart
   - Left bound: 500 bars back from current
   - Right bound: Current time + 100 periods forward

PITFALL: iTime() can return 0 on weekends/gaps
   Class checks for this and returns false if error

CAREFUL: leftTime = iTime(..., 500) might fail if fewer than 500 bars loaded
   Strategy: The library checks, but ensure you have 500+ bars loaded in MT5

USAGE:
   CLevel rsiLevels("RSILevel", 20, 1);  // In subwindow 1

   // Draw standard RSI reference levels
   rsiLevels.DrawHorizontal(70.0, "70", clrRed, STYLE_DASHED);
   rsiLevels.DrawHorizontal(30.0, "30", clrGreen, STYLE_DASHED);

   // Support/resistance on main chart
   CLevel supportLines("Support", 50, 0);
   supportLines.DrawHorizontal(1.0850, "SR1", clrBlue, STYLE_SOLID);

---

CIndicatorLine
---------------
CRITICAL: SetDataSource() must be called BEFORE any Draw/Redraw

BUFFER ALIGNMENT RESPONSIBILITY:
   The analyzer is responsible for:
   - Calculating indicator values
   - Filling the buffer
   - For multi-timeframe: converting to current chart timeframe
   - Setting buffer to series mode (ArraySetAsSeries)

   The visualization class just:
   - Takes reference to buffer
   - Draws segments connecting buffer values

PITFALL: Using raw H4 buffer on M5 chart without alignment
   // WRONG: H4 buffer passed directly to M5 chart
   double h4RSI[];
   CopyBuffer(iRSI(_Symbol, PERIOD_H4, ...), 0, 0, 500, h4RSI);
   rsiLine.SetDataSource(h4RSI);  // h4RSI[0] ≠ most recent M5 value!

   // RIGHT: Analyzer aligns first
   // (See earlier buffer alignment example)
   rsiLine.SetDataSource(m5_alignedRSI);

BUFFER VALIDITY:
   - Buffer values of 0 are skipped (treated as no data)
   - Useful for gaps in data
   - If entire buffer is zeros, no line is drawn

REDRAW STRATEGY:
   Called every tick to update with new bar data
   Deletes all old segments and redraws
   ~2-3ms performance impact (acceptable)

   USAGE PATTERN:
   void OnTick() {
      bool isNewBar = detect ;

      // Update indicator calculation
      CalculateRSI(rsiBuffer);

      // Redraw visualization every tick
      rsiLine.Redraw();

      if(isNewBar) {
         rsiLine.Cleanup();
      }
   }


class CRSIDivergenceAnalyzer {
private:
   // Buffers maintained by analyzer
   double rsiBuffer[];

   // Visualization instances (owned by analyzer)
   CIndicatorLine rsiLine;      // RSI visualization
   CLine trendLines;            // Divergence trend lines
   CLabel divergenceLabels;     // Divergence markers
   CPivot rsiPivots;            // RSI pivot points

public:
   CRSIDivergenceAnalyzer()
      : rsiLine("RSI", 100, 1, 200),         // Subwindow 1
        trendLines("RSIDivTrend", 50, 0),   // Main chart
        divergenceLabels("RSIDiv", 30, 0),  // Main chart
        rsiPivots("RSIPivot", 100, 0) {     // Main chart

      ArrayResize(rsiBuffer, 500);
      ArraySetAsSeries(rsiBuffer, true);
      rsiLine.SetDataSource(rsiBuffer);
   }

   void OnTick(bool isNewBar) {
      // 1. Calculate RSI
      CalculateRSI(rsiBuffer);

      // 2. Visualize every tick (lightweight)
      rsiLine.Redraw();

      // 3. Detect patterns
      DetectDivergences();

      // 4. Cleanup on new bar (expensive, do once/bar)
      if(isNewBar) {
         rsiLine.Cleanup();
         trendLines.Cleanup();
         divergenceLabels.Cleanup();
         rsiPivots.Cleanup();
      }
   }

   void DrawDivergence(datetime t1, double p1, datetime t2, double p2, bool bullish) {
      color col = bullish ? clrGreen : clrRed;

      // Draw trend line
      trendLines.Draw(t1, p1, t2, p2, col);

      // Label endpoints
      divergenceLabels.Draw(t1, p1, "Div", col);
      divergenceLabels.Draw(t2, p2, "Div", col);
   }
};
*/