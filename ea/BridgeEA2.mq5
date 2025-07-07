//+------------------------------------------------------------------+
//| BridgeEA2.mq5 – TCP Client for Node.js Server                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Base64.mqh>
#include <Json.mqh>
#include <SocketLib.mqh>

input string SocketServer = "127.0.0.1";
input ushort SocketPort   = 3000;
input string AES_PASS     = "MyAESPassphrase";
input uint RetrySec       = 10;

int sock = INVALID_SOCKET64;
bool winsock_initialized = false;
CTrade trade;
datetime lastTry = 0;

//+------------------------------------------------------------------+
//| Winsock Initialization & Cleanup                                 |
//+------------------------------------------------------------------+
bool InitWinsock() {
    char wsadata[400];
    int result = WSAStartup(0x202, wsadata);
    if(result != 0) {
        Print("BridgeEA2: WSAStartup failed with code: ", result);
        winsock_initialized = false;
        return false;
    }
    winsock_initialized = true;
    return true;
}

void CleanupWinsock() {
    if (winsock_initialized) {
        WSACleanup();
        winsock_initialized = false;
    }
}

//+------------------------------------------------------------------+
//| Decrypt AES256-CBC encoded in Base64                             |
//+------------------------------------------------------------------+
string Decrypt(const string enc) {
    string decoded = Base64Decode(enc);
    if (StringLen(decoded) < 1)
        return "";

    uchar raw[];
    StringToCharArray(decoded, raw);

    uchar key[32];
    ArrayInitialize(key, 0);
    uchar temp[];
    StringToCharArray(AES_PASS, temp);
    ArrayCopy(key, temp, 0, 0, MathMin(32, ArraySize(temp)));

    uchar ct[];
    ArrayResize(ct, ArraySize(raw));
    ArrayCopy(ct, raw);

    uchar dec[];
    int decSize = CryptDecode(CRYPT_AES256, ct, key, dec);
    if (decSize <= 0)
        return "";

    string result;
    CharArrayToString(dec, result, decSize);
    return result;
}

//+------------------------------------------------------------------+
//| Attempt to connect socket                                        |
//+------------------------------------------------------------------+
void ConnectSocket() {
    if(sock != INVALID_SOCKET64 && SocketIsConnected(sock))
        return;

    Print("BridgeEA2: Trying to connect to ", SocketServer, ":", SocketPort, " ...");
    sock = SocketCreate();
    if(sock == INVALID_SOCKET64) {
        int err = WSAGetLastError();
        Print("BridgeEA2: SocketCreate() failed: ", WSAErrorDescript(err), " (code: ", err, ")");
        return;
    }
    bool connected = SocketConnect(sock, SocketServer, SocketPort, 0);
    if (!connected) {
        int err = WSAGetLastError();
        Print("BridgeEA2: SocketConnect() failed: ", WSAErrorDescript(err), " (code: ", err, ")");
        SocketClose(sock);
        sock = INVALID_SOCKET64;
    } else {
        Print("BridgeEA2: SocketConnect() called, success=", connected);
        UpdateDashboard();
    }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
    Print("BridgeEA2: Initializing...");
    if (!InitWinsock()) {
        Print("BridgeEA2: Winsock initialization failed!");
        return INIT_FAILED;
    }
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    if (sock != INVALID_SOCKET64)
        SocketClose(sock);
    CleanupWinsock();
}

//+------------------------------------------------------------------+
//| OnTimer – connect & receive data                                 |
//+------------------------------------------------------------------+
void OnTimer() {
    if (TimeCurrent() > lastTry + RetrySec) {
        ConnectSocket();
        lastTry = TimeCurrent();
    }

    if (sock != INVALID_SOCKET64 && SocketIsConnected(sock)) {
        uchar buf[4096];
        int bytes = SocketRead(sock, buf, ArraySize(buf), 0);
        if (bytes > 0) {
            string enc = CharArrayToString(buf, bytes);
            Print("BridgeEA2: Received raw data: ", enc);

            string payload = Decrypt(enc);
            Print("BridgeEA2: Decrypted payload: ", payload);

            if (StringLen(payload) > 0) {
                JSONNode root;
                if (root.Deserialize(payload)) {
                    Print("BridgeEA2: JSON parsed successfully.");
                    Print("BridgeEA2: Full JSON: ", payload);

                    string cmd = root["cmd"].ToString();
                    string symbol = root["symbol"].ToString();
                    double lot = root["lot"].ToDouble();
                    double sl = root["sl"].ToDouble();
                    double tp = root["tp"].ToDouble();
                    ulong magic = (ulong)root["magic"].ToInteger();
                    string account = root["account"].ToString();

                    Print("BridgeEA2: Command: ", cmd, ", Symbol: ", symbol, ", Lot: ", lot, ", SL: ", sl, ", TP: ", tp, ", Magic: ", magic, ", Account: ", account);

                    // Example: Place order if cmd is BUY or SELL
                    trade.SetExpertMagicNumber(magic);
                    trade.SetDeviationInPoints(5);

                    double price = (cmd == "BUY") ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                  : SymbolInfoDouble(symbol, SYMBOL_BID);

                    bool result = false;
                    if (cmd == "BUY") {
                        Print("BridgeEA2: Executing BUY order...");
                        result = trade.Buy(lot, symbol, price, sl, tp);
                    } else if (cmd == "SELL") {
                        Print("BridgeEA2: Executing SELL order...");
                        result = trade.Sell(lot, symbol, price, sl, tp);
                    } else {
                        Print("BridgeEA2: Unknown command: ", cmd);
                    }

                    if (result)
                        Print("BridgeEA2: Order executed: ", cmd);
                    else
                        Print("BridgeEA2: Order failed: ", cmd);
                } else {
                    Print("BridgeEA2: JSON parse error. Raw payload: ", payload);
                }
            } else {
                Print("BridgeEA2: Decryption failed or payload empty.");
            }
        }
    }
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Dashboard: Visual Socket Status                                  |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    string lbl = "BridgeStatus2";
    bool connected = (sock != INVALID_SOCKET64 && SocketIsConnected(sock));
    string status = connected ? "ON" : "OFF";
    color statusColor = connected ? clrLime : clrRed;

    string txt = StringFormat("Socket: %s  Time: %s",
                              status,
                              TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));

    if (ObjectFind(0, lbl) < 0) {
        ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
    }

    ObjectSetString(0, lbl, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 16);
    ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, lbl, OBJPROP_COLOR, statusColor);
    ObjectSetInteger(0, lbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);  
    ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 80);
}
//+------------------------------------------------------------------+