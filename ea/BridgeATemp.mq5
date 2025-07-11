//+------------------------------------------------------------------+
//|                    FileReceiver.mq5                              |
//| Reads plain JSON files and executes trades                       |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <stdlib.mqh>


CTrade trade;

#define FILE_APPEND 16

// --- JSON Parser ---
class CJAVal {
private:
   string _raw;
public:
   bool Parse(const string &text) {
      _raw = text;
      return (StringFind(text, "{") == 0);
   }
   string GetString(const string &key) {
      string search = "\"" + key + "\":";
      int pos = StringFind(_raw, search);
      if (pos == -1) return "";
      int start = StringFind(_raw, "\"", pos + StringLen(search));
      int end = StringFind(_raw, "\"", start + 1);
      return StringSubstr(_raw, start + 1, end - start - 1);
   }
   double GetNumber(const string &key) {
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

// --- Convert string to uppercase safely ---
string ToUpper(string text) {
   string result = text;
   for(int i = 0; i < StringLen(result); i++) {
      ushort ch = StringGetCharacter(result, i);
      if(ch >= 'a' && ch <= 'z') {
         ch = ch - 32;
         StringSetCharacter(result, i, ch);
      }
   }
   return result;
}

// --- Read entire file content ---
string FileReadAllText(const string filename) {
   int f = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
   if(f == INVALID_HANDLE) {
      Print("❌ Could not open file: ", filename, " | Error: ", GetLastError());
      return "";
   }
   string s = FileReadString(f, (int)FileSize(f));
   FileClose(f);
   return s;
}


// --- Main execution ---


int OnInit()
{
    Print("📁 File communication initialized.");
    return INIT_SUCCEEDED;
}

void OnStart() {
   ObjectDelete(0, "BridgeStatus2");
   ObjectDelete(0, "BridgeStatus");
   string folder = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
   string filename;
   ulong handle = FileFindFirst("*.txt", filename);
   if(handle == INVALID_HANDLE) {
      Print("No new files.");
      return;
   }

   do {
      string content = FileReadAllText(filename);
      Print("📄 Raw content from ", filename, ": ", content);
      if(StringLen(content) == 0) {
         Print("Empty file: ", filename);
         continue;
      }

      CJAVal json;
      if(!json.Parse(content)) {
         Print("Invalid JSON in file: ", filename);
         continue;
      }

      string cmd    = ToUpper(json.GetString("cmd"));
      string symbol = json.GetString("symbol");
      double lot    = json.GetNumber("lot");
      double sl     = json.GetNumber("sl");
      double tp     = json.GetNumber("tp");
      int magic     = (int)json.GetNumber("magic");

      if(!SymbolSelect(symbol, true)) {
         Print("Symbol not found: ", symbol);
         continue;
      }

      double price    = (cmd == "BUY") ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      double sl_price = (cmd == "BUY") ? price - sl * _Point : price + sl * _Point;
      double tp_price = (cmd == "BUY") ? price + tp * _Point : price - tp * _Point;

      bool sent = trade.PositionOpen(
         symbol,
         (cmd == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
         lot,
         price,
         sl_price,
         tp_price,
         magic
      );

      if(!sent) {
         Print("❌ Order failed: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
      } else {
         PrintFormat("✅ Order sent: %s %s %.2f lots", cmd, symbol, lot);
      }

      Sleep(500);  // Small delay to avoid overloading trade context

   } while(FileFindNext(handle, filename));

   FileFindClose(handle);
}
