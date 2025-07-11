//+------------------------------------------------------------------+
//|               WebRequestContinuousEA.mq5                        |
//|     JSON fetcher with daily log, upload, tag filter             |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <SocketLib.mqh> // if you use socket functionality (optional)

CTrade trade;

// === CONFIG ===
enum LogLevel { INFO, ERROR, DEBUG };

input int    TimerInterval     = 10;
input bool   EnableDebugLog    = true;
input bool   EnableLogUpload   = false;
input string LogUploadURL      = "http://localhost:5000/upload";

// === State ===
string lastSignalKey = "";
int sock = INVALID_SOCKET64;  // ← Socket global handle
bool lastFetchSuccessful = false;


//+------------------------------------------------------------------+
//| UI Dashboard Label Update                                        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    string lbl = "BridgeStatus2";

    // Change from socket-based status to fetch-based status
    bool connected = lastFetchSuccessful;  // true if last fetch was good
    string status = connected ? "ON" : "OFF";
    color statusColor = connected ? clrLime : clrRed;

    string txt = StringFormat("WebRequest: %s  Time: %s",
                              status,
                              TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));

    if (ObjectFind(0, lbl) < 0)
        ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);

    ObjectSetString(0, lbl, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 16);
    ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, lbl, OBJPROP_COLOR, statusColor);
    ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 80);
}


//+------------------------------------------------------------------+
//| Log function with daily file                                     |
//+------------------------------------------------------------------+
void LogPlus(string message, LogLevel level = INFO, string symbol = "", string reason = "")
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    string dateStr   = TimeToString(TimeCurrent(), TIME_DATE);
    string levelStr  = "";

    switch(level)
    {
        case INFO:  levelStr = "[INFO] ";  break;
        case ERROR: levelStr = "[ERROR] "; break;
        case DEBUG: levelStr = "[DEBUG] "; break;
    }

    if (level == DEBUG && !EnableDebugLog)
        return;

    string tags = "";
    if (symbol != "") tags += "[SYM:" + symbol + "] ";
    if (reason != "") tags += "[REASON:" + reason + "] ";

    string finalMsg = timestamp + " " + levelStr + tags + message;

    string filename = "WebRequestLogs\\log_" + dateStr + ".txt";
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ);
    if (fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END);
        FileWrite(fileHandle, finalMsg);
        FileClose(fileHandle);
    }
    else
    {
        Print("[ERROR] Failed to open log file: ", GetLastError());
    }

    if (EnableLogUpload)
    {
        uchar body[];
        StringToCharArray(finalMsg, body);
        uchar result[];
        string headers;
        int timeout = 5000;
        int res = WebRequest("POST", LogUploadURL, "", timeout, body, result, headers);
        if (res == -1)
            Print("[ERROR] Log upload failed. Err: ", GetLastError());
    }

    Print(finalMsg);
}

//+------------------------------------------------------------------+
//| JSON class                                                       |
//+------------------------------------------------------------------+
class CJAVal
{
private:
    string _raw;
public:
    bool Parse(const string &text)
    {
        _raw = text;
        return (StringFind(text, "{") == 0);
    }

    string GetString(const string &key)
    {
        string search = "\"" + key + "\":";
        int pos = StringFind(_raw, search);
        if (pos == -1) return "";
        int start = StringFind(_raw, "\"", pos + StringLen(search));
        int end = StringFind(_raw, "\"", start + 1);
        if (start == -1 || end == -1) return "";
        return StringSubstr(_raw, start + 1, end - start - 1);
    }

    double GetNumber(const string &key)
    {
        string search = "\"" + key + "\":";
        int pos = StringFind(_raw, search);
        if (pos == -1) return 0.0;
        int start = pos + StringLen(search);
        int end = StringFind(_raw, ",", start);
        if (end == -1) end = StringFind(_raw, "}", start);
        string numStr = StringSubstr(_raw, start, end - start);
        StringTrimLeft(numStr);
        StringTrimRight(numStr);
        return StringToDouble(numStr);
    }
};

//+------------------------------------------------------------------+
//| Helper: uchar to string                                          |
//+------------------------------------------------------------------+
string CharArrayToString(const uchar &arr[])
{
    string s = "";
    for (int i = 0; i < ArraySize(arr); i++)
        s += (string)arr[i];
    return s;
}

//+------------------------------------------------------------------+
//| Checks if a position exists                                      |
//+------------------------------------------------------------------+
bool HasOpenPosition(const string symbol)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetTicket(i) > 0 &&
            PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Fetch + Parse + Execute Trade                                    |
//+------------------------------------------------------------------+
void FetchAndTrade()
{
    string URL = "http://127.0.0.1:5000/data";
    uchar post[], result[];
    string headers = "";
    int timeout = 5000;
    ResetLastError();

    int res = WebRequest("GET", URL, NULL, timeout, post, result, headers);

    if (res == -1)
    {
        LogPlus("WebRequest failed. Error: " + IntegerToString(GetLastError()), ERROR);
        lastFetchSuccessful = false;
        return;
    }

    string response_str = CharArrayToString(result);
    LogPlus("Server response: " + response_str, DEBUG);

    CJAVal json;
    if (!json.Parse(response_str))
    {
        LogPlus("Failed to parse JSON", ERROR);
        lastFetchSuccessful = false;
        return;
    }

    string cmd = json.GetString("cmd");
    StringTrimLeft(cmd); StringTrimRight(cmd);
    string symbol = json.GetString("symbol");
    StringTrimLeft(symbol); StringTrimRight(symbol);
    double lot = json.GetNumber("lot");
    double sl = json.GetNumber("sl");
    double tp = json.GetNumber("tp");

    if (cmd == "" || symbol == "" || lot <= 0)
    {
        LogPlus("Invalid trade data received", ERROR);
        lastFetchSuccessful = false;
        return;
    }

    string signalKey = cmd + "|" + symbol + "|" + DoubleToString(lot, 2);
    if (signalKey == lastSignalKey)
    {
        LogPlus("Duplicate signal ignored: " + signalKey, INFO, symbol, "DuplicateFilter");
        lastFetchSuccessful = true;  // Still successful fetch even if no trade executed
        return;
    }

    if (!SymbolSelect(symbol, true))
    {
        LogPlus("Symbol not found: " + symbol, ERROR);
        lastFetchSuccessful = false;
        return;
    }

    if (HasOpenPosition(symbol))
    {
        LogPlus("Position already open on symbol " + symbol + ", skipping.", INFO, symbol, "AlreadyOpen");
        lastFetchSuccessful = true; // Still successful fetch
        return;
    }

    ENUM_ORDER_TYPE order_type = (cmd == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl_price = 0, tp_price = 0;

    if (sl > 0)
        sl_price = (order_type == ORDER_TYPE_BUY) ? price - sl * _Point : price + sl * _Point;
    if (tp > 0)
        tp_price = (order_type == ORDER_TYPE_BUY) ? price + tp * _Point : price - tp * _Point;

    bool sent = trade.PositionOpen(symbol, order_type, lot, price, sl_price, tp_price, "");

    if (sent)
    {
        LogPlus("Trade sent: " + cmd + " " + symbol + " " + DoubleToString(lot, 2) + " lots", INFO, symbol, "TradeExecuted");
        lastSignalKey = signalKey;
        lastFetchSuccessful = true;
    }
    else
    {
        LogPlus("Trade failed: " + IntegerToString(trade.ResultRetcode()) + " | " + trade.ResultRetcodeDescription(), ERROR, symbol, "TradeFailure");
        lastFetchSuccessful = false;
    }
}


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
    EventSetTimer(TimerInterval);
    LogPlus("EA started. Timer: " + IntegerToString(TimerInterval) + "s", INFO);
    UpdateDashboard();  // ← Initial dashboard update
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    ObjectDelete(0, "BridgeStatus2");  // ← Clean up UI label
    LogPlus("EA stopped. Timer cleared.", INFO);
}

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
    FetchAndTrade();
    UpdateDashboard();  // ← Keep updating status
}
