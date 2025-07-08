//+------------------------------------------------------------------+
//|                       BridgeEA.mq5                               |
//|     MT5 EA connects TCP socket to receive trade commands live    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <SocketLib.mqh>

CTrade trade;

input string ServerIP = "127.0.0.1";
input int    ServerPort = 9000;

int sock = INVALID_SOCKET64;
string recvBuffer = "";

string lastSignalKey = "";
bool connected = false;

enum LogLevel { INFO, ERROR, DEBUG };

void LogPlus(string message, LogLevel level = INFO)
{
   string levelStr = "";
   switch(level)
   {
      case INFO:  levelStr = "[INFO] ";  break;
      case ERROR: levelStr = "[ERROR] "; break;
      case DEBUG: levelStr = "[DEBUG] "; break;
   }
   Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " " + levelStr + message);
}

void UpdateDashboard(string status, color clr)
{
   string lbl = "BridgeStatus";
   if (ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);

   ObjectSetString(0, lbl, OBJPROP_TEXT, "Bridge TCP Status: " + status);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, lbl, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 60);
}

// Add a new label for trade status
void UpdateTradeStatus(string status, color clr)
{
   string lbl = "TradeStatus";
   if (ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);

   ObjectSetString(0, lbl, OBJPROP_TEXT, status);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, lbl, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 90);
}

bool ParseAndTrade(string json)
{
   // Find "cmd":"..."
   int cmdPos = StringFind(json, "\"cmd\":\"");
   int symPos = StringFind(json, "\"symbol\":\"");
   int lotPos = StringFind(json, "\"lot\":");
   int slPos  = StringFind(json, "\"sl\":");
   int tpPos  = StringFind(json, "\"tp\":");

   if (cmdPos == -1 || symPos == -1 || lotPos == -1)
   {
      LogPlus("Invalid JSON format received: " + json, ERROR);
      return false;
   }

   // Extract cmd
   int cmdStart = cmdPos + 7;
   int cmdEnd = StringFind(json, "\"", cmdStart);
   string cmd = StringSubstr(json, cmdStart, cmdEnd - cmdStart);
   StringTrimLeft(cmd); StringTrimRight(cmd);

   // Extract symbol (robust)
   int symKeyPos = StringFind(json, "\"symbol\":\"");
   string symbol = "";
   int valueStart = -1, valueEnd = -1;
   if (symKeyPos != -1) {
       valueStart = symKeyPos + StringLen("\"symbol\":\"");
       valueEnd = StringFind(json, "\"", valueStart);
       if (valueEnd > valueStart)
           symbol = StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   StringTrimLeft(symbol); StringTrimRight(symbol);
   LogPlus("symbol extraction: valueStart=" + IntegerToString(valueStart) + ", valueEnd=" + IntegerToString(valueEnd) + ", substr=[" + symbol + "]", DEBUG);

   // Extract lot
   int lotStart = lotPos + 6;
   int lotEnd = StringFind(json, ",", lotStart);
   if (lotEnd == -1) lotEnd = StringFind(json, "}", lotStart);
   string lotStr = StringSubstr(json, lotStart, lotEnd - lotStart);
   double lot = StringToDouble(lotStr);

   // Extract sl
   double sl = 0;
   if (slPos != -1)
   {
      int slStart = slPos + 5;
      int slEnd = StringFind(json, ",", slStart);
      if (slEnd == -1) slEnd = StringFind(json, "}", slStart);
      string slStr = StringSubstr(json, slStart, slEnd - slStart);
      sl = StringToDouble(slStr);
   }

   // Extract tp
   double tp = 0;
   if (tpPos != -1)
   {
      int tpStart = tpPos + 5;
      int tpEnd = StringFind(json, ",", tpStart);
      if (tpEnd == -1) tpEnd = StringFind(json, "}", tpStart);
      string tpStr = StringSubstr(json, tpStart, tpEnd - tpStart);
      tp = StringToDouble(tpStr);
   }

   LogPlus("Extracted cmd: [" + cmd + "], symbol: [" + symbol + "], lot: [" + DoubleToString(lot, 2) + "]", DEBUG);
   if (cmd == "" || symbol == "" || lot <= 0)
   {
      LogPlus("Invalid trade data received", ERROR);
      return false;
   }

   string signalKey = cmd + "|" + symbol + "|" + DoubleToString(lot, 2);
   if (signalKey == lastSignalKey)
   {
      LogPlus("Duplicate signal ignored: " + signalKey, INFO);
      return true;
   }

   if (!SymbolSelect(symbol, true))
   {
      LogPlus("Symbol not found: " + symbol, ERROR);
      return false;
   }

   // Check if already have position on symbol
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetSymbol(i) == symbol)
      {
         LogPlus("Position already open on " + symbol + ", skipping trade", INFO);
         LogPlus("Trade skipped because a position is already open for this symbol.", INFO);
         lastSignalKey = signalKey;
         return true;
      }
   }

   ENUM_ORDER_TYPE order_type = (cmd == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

   double sl_price = 0;
   double tp_price = 0;

   if (sl > 0)
      sl_price = (order_type == ORDER_TYPE_BUY) ? price - sl * _Point : price + sl * _Point;
   if (tp > 0)
      tp_price = (order_type == ORDER_TYPE_BUY) ? price + tp * _Point : price - tp * _Point;

   bool orderSent = trade.PositionOpen(symbol, order_type, lot, price, sl_price, tp_price);

   if (orderSent)
   {
      LogPlus("Trade executed: " + cmd + " " + symbol + " " + DoubleToString(lot, 2), INFO);
      lastSignalKey = signalKey;
      return true;
   }
   else
   {
      LogPlus("Trade failed: " + IntegerToString(trade.ResultRetcode()) + " | " + trade.ResultRetcodeDescription(), ERROR);
      return false;
   }
}

int OnInit()
{
   LogPlus("BridgeEA starting...", INFO);
   // Create the socket using the correct function
   sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
   if (sock == INVALID_SOCKET64)
   {
      LogPlus("Failed to create socket", ERROR);
      return(INIT_FAILED);
   }

   // Prepare sockaddr_in for connect
   char ch[16]; StringToCharArray(ServerIP, ch);
   sockaddr_in addrin;
   addrin.sin_family = AF_INET;
   addrin.sin_addr.u.S_addr = inet_addr(ch);
   addrin.sin_port = (ushort)htons((ushort)ServerPort); // explicit cast to suppress warning
   char ref_addr[];
   StructToCharArray(addrin, ref_addr);
   if (connect(sock, ref_addr, ArraySize(ref_addr)) == SOCKET_ERROR)
   {
      int err = WSAGetLastError();
      LogPlus("Failed to connect to server " + ServerIP + ":" + IntegerToString(ServerPort) + " (Error: " + IntegerToString(err) + ")", ERROR);
      LogPlus(WSAErrorDescript(err), ERROR);
      return(INIT_FAILED);
   }

   // Set non-blocking mode
   int non_block = 1;
   ioctlsocket(sock, FIONBIO, non_block);
   connected = true;

   UpdateDashboard("Connected", clrLime);

   EventSetTimer(1); // 1 sec timer for socket check
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if (sock != INVALID_SOCKET64)
   {
      SocketClose(sock);
      sock = INVALID_SOCKET64;
   }
   ObjectDelete(0, "BridgeStatus");
   ObjectDelete(0, "TradeStatus");
   LogPlus("BridgeEA stopped.", INFO);
}

void OnTimer()
{
   if (!connected || sock == INVALID_SOCKET64)
   {
      UpdateDashboard("Disconnected", clrRed);
      return;
   }

   // Extra check for socket validity
   if (sock == INVALID_SOCKET64)
   {
      LogPlus("Socket is invalid before recv", ERROR);
      connected = false;
      UpdateDashboard("Disconnected", clrRed);
      return;
   }

   char buffer[1024];
   int received = recv(sock, buffer, sizeof(buffer) - 1, 0);
   if (received > 0)
   {
      buffer[received] = '\0';
      string receivedStr = CharArrayToString(buffer, 0, received);
      LogPlus("Raw TCP received: " + receivedStr, DEBUG);
      recvBuffer += receivedStr;

      // Check for newline delimiter in buffer to parse full JSON messages
      int nlPos = StringFind(recvBuffer, "\n");
      while (nlPos != -1)
      {
         string jsonMsg = StringSubstr(recvBuffer, 0, nlPos);
         LogPlus("ParseAndTrade called with: " + jsonMsg, DEBUG);
         bool tradeResult = ParseAndTrade(jsonMsg);
         if (tradeResult)
            UpdateTradeStatus("Trade executed", clrLime);
         else
            UpdateTradeStatus("No trade executed", clrYellow);
         recvBuffer = StringSubstr(recvBuffer, nlPos + 1);
         nlPos = StringFind(recvBuffer, "\n");
      }

      UpdateDashboard("Received data", clrLime);
   }
   else if (received == 0)
   {
      UpdateDashboard("Waiting for data...", clrYellow);
   }
   else
   {
      int err = WSAGetLastError();
      if (err == 10035) // WSAEWOULDBLOCK - no data available
      {
         // No data available, not an error in non-blocking mode
         UpdateDashboard("Waiting for data...", clrYellow);
         return;
      }
      LogPlus("Socket error: " + IntegerToString(err), ERROR);
      LogPlus(WSAErrorDescript(err), ERROR);
      connected = false;
      UpdateDashboard("Disconnected", clrRed);
   }
}
