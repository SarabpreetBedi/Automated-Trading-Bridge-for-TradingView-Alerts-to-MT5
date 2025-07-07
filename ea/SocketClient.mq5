
#include  <ExchangeData.mqh>


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   int socket=SocketCreate();
   if(socket!=INVALID_HANDLE)
   {
      bool sockcon = SocketConnect(socket,"127.0.0.1",3000,1000);
      if(sockcon == true)
      {
         Print("Connected to "," 127.0.0.1",":",3000);
         double oppr[];
         int copyedo = CopyOpen(_Symbol,_Period,0,lrlenght,oppr);
         double hipr[];
         int copyedh = CopyHigh(_Symbol,_Period,0,lrlenght,hipr);
         double lopr[];
         int copyedl = CopyLow(_Symbol,_Period,0,lrlenght,lopr);
         double clpr[];
         int copyedc = CopyClose(_Symbol,_Period,0,lrlenght,clpr);
         
         string tosend;
         for(int i=0;i<ArraySize(clpr);i++)
         {
            tosend+=(string)oppr[i]+",";
            tosend+=(string)hipr[i]+",";
            tosend+=(string)lopr[i]+",";
            tosend+=(string)clpr[i]+" "; 
         }
         
         bool senddata = socksend(socket, tosend);
         string recieveddata = socketreceive(socket, 1000);
         Print(recieveddata);
         SocketClose(socket);
       
      }
      else
      {
          Print("Connection ","127.0.0.1",":",3000," error ",GetLastError());
          SocketClose(socket);
      }
  
   }
   else
   {
      Print("Socket creation error ",GetLastError());
   }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int socket=SocketCreate();
   if(socket!=INVALID_HANDLE)
   {
      bool sockcon = SocketConnect(socket,"127.0.0.1",3000,1000);
      if(sockcon == true)
      {
         Print("Connected to ","127.0.0.1",":",3000);
         double oppr[];
         int copyedo = CopyOpen(_Symbol,_Period,0,lrlenght,oppr);
         double hipr[];
         int copyedh = CopyHigh(_Symbol,_Period,0,lrlenght,hipr);
         double lopr[];
         int copyedl = CopyLow(_Symbol,_Period,0,lrlenght,lopr);
         double clpr[];
         int copyedc = CopyClose(_Symbol,_Period,0,lrlenght,clpr);
         
         string tosend;
         for(int i=0;i<ArraySize(clpr);i++)
         {
            tosend+=(string)oppr[i]+",";
            tosend+=(string)hipr[i]+",";
            tosend+=(string)lopr[i]+",";
            tosend+=(string)clpr[i]+" "; 
         }
         
         bool senddata = socksend(socket, tosend);
         string recieveddata = socketreceive(socket, 1000);
         Print(recieveddata);
         SocketClose(socket);
       
      }
      else
      {
          Print("Connection ","127.0.0.1",":",3000," error ",GetLastError());
          SocketClose(socket);
      }
  
   }
   else
   {
      Print("Socket creation error ",GetLastError());
   }
  
   
  }