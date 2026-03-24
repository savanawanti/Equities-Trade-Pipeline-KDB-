
h: @[hopen;5012;{[e] -1"Error in connecting 5012 TP",e;0}]

syms: `AAPL`MSFT`GOOGL`AMZN`TSLA`META`NVDA`JPM`BAC`WFC`GS`MS`V`MA`NFLX`DIS`PYPL`INTC`AMD`CRM`ORCL`CSCO`ADBE`QCOM`TXN`AVGO`IBM`NOW`UBER`LYFT`SQ`SNAP`TWTR`ZM`DOCU`ROKU`PINS`SHOP`SPOT`PLTR`COIN`HOOD`RBLX`ABNB`DASH`DDOG`SNOW`NET`CRWD`ZS;

basePrices: 185 420 175 185 250 500 880 195 35 58 450 95 280 470 700 110 75 45 160 300 125 52 580 175 190 1300 185 880 75 18 80 12 55 75 60 70 35 85 230 25 220 18 45 165 140 130 175 95 350 210f;

// generate trades
generateTrade: {[]

    n_trades: 50;
    n_orders: 25000;
    
    t_syms: n_trades?syms;
    t_base: basePrices[syms?t_syms];
    t_mid: t_base * 1 + (n_trades?1.0) * 0.06 - 0.03;
    t_times: n_trades#(.z.T);
    condList: `N`N`N`N`N,(`$"@"),`F`O`T;  
    
    trades: ([] 
               time: t_times; 
               sym: t_syms; 
               price: t_mid + (n_trades?1.0) * 0.04 - 0.02; 
               size: n_trades?(100 200 300 500 1000 2000 5000); 
               side: n_trades?`B`S;
               exchange: n_trades?`NYSE`NASDAQ`BATS`ARCA; 
               tradeId: `$"TRD-",/:string n_trades?10000;
               orderId: `$"ORD-",/:string n_trades?n_orders; 
               condition: n_trades?condList; 
               broker: n_trades?`GSCO`MSCO`JPMC`BOFA`CITI`BARC`UBS`CS);
    :trades
 }


generateQuote: {[]
    n_quotes: 50;
    q_syms: n_quotes?syms;
    q_base: basePrices[syms?q_syms];
    q_mid: q_base * 1 + (n_quotes?1.0) * 0.06 - 0.03;
    q_spread: 0.01 + n_quotes ? 0.15;
    q_times: n_quotes#(.z.T);
    
    quotes: ([]
        time: q_times;
        sym: q_syms;
        bid: q_mid - q_spread % 2;
        ask: q_mid + q_spread % 2;
        bsize: n_quotes?(100 200 300 500 1000);
        asize: n_quotes?(100 200 300 500 1000);
        exchange: n_quotes?`NYSE`NASDAQ`BATS`ARCA;
        condition: n_quotes?`R`R`R`R`O`C);
    :quotes
 }

.z.ts:{[]
 if[h>0;
    neg[h] (`upd;`trades;generateTrade[]);
    neg[h] (`upd;`quotes;generateQuote[]);
 ];
 }

\t 1000









