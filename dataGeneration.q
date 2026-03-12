
// --- CONFIG ---
n_trades: 1000000;
n_quotes: 2000000;
n_orders: 500000;
basePath: getenv[`HOME];

// --- REFERENCE DATA (50 instruments) ---
syms: `AAPL`MSFT`GOOGL`AMZN`TSLA`META`NVDA`JPM`BAC`WFC`GS`MS`V`MA`NFLX`DIS`PYPL`INTC`AMD`CRM`ORCL`CSCO`ADBE`QCOM`TXN`AVGO`IBM`NOW`UBER`LYFT`SQ`SNAP`TWTR`ZM`DOCU`ROKU`PINS`SHOP`SPOT`PLTR`COIN`HOOD`RBLX`ABNB`DASH`DDOG`SNOW`NET`CRWD`ZS;

sectors: `Tech`Tech`Tech`Tech`Tech`Tech`Tech`Finance`Finance`Finance`Finance`Finance`Finance`Finance`Tech`Media`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Crypto`Finance`Gaming`Travel`Tech`Tech`Tech`Tech`Tech`Tech;

basePrices: 185 420 175 185 250 500 880 195 35 58 450 95 280 470 700 110 75 45 160 300 125 52 580 175 190 1300 185 880 75 18 80 12 55 75 60 70 35 85 230 25 220 18 45 165 140 130 175 95 350 210f;

lotSizes: 50#100 200 500 1000;

// --- 1. Generate refdata.csv ---
refdata: ([] 
    sym: syms;
    sector: sectors;
    base_price: basePrices;
    lot_size: (count syms)?lotSizes;
    currency: count[syms]#enlist`USD;
    exchange: (count syms)?`NYSE`NASDAQ`BATS`ARCA;
    tick_size: count[syms]#0.01;
    status: (count syms)?`Active`Active`Active`Active`Suspended
  );
(hsym `$basePath,"/Equities Trade Pipeline/data","/refdata.csv") 0: csv 0: refdata;
show "refdata.csv saved: ",string count refdata;

// --- 2. Generate quotes.csv ---
show "Generating quotes... (takes a moment)";
q_syms: n_quotes?syms;
q_base: basePrices[syms?q_syms];
q_mid: q_base * 1 + (n_quotes?1.0) * 0.06 - 0.03;
q_spread: 0.01 + n_quotes ? 0.15;
q_dates: n_quotes?(2025.01.02 + til 5);
q_times: 09:30:00.000 + n_quotes?23400000;

quotes: ([]
    date: q_dates;
    time: q_times;
    sym: q_syms;
    bid: q_mid - q_spread % 2;
    ask: q_mid + q_spread % 2;
    bsize: n_quotes?(100 200 300 500 1000);
    asize: n_quotes?(100 200 300 500 1000);
    exchange: n_quotes?`NYSE`NASDAQ`BATS`ARCA;
    condition: n_quotes?`R`R`R`R`O`C
  );

// INJECT DIRTY DATA
dirtyIdx1: neg[floor n_quotes * 0.02]?n_quotes;
dirtyIdx2: neg[floor n_quotes * 0.01]?n_quotes;
dirtyIdx3: neg[floor n_quotes * 0.005]?n_quotes;
quotes: @[quotes;`bid;{[x;i] @[x;i;:;0Nf]}[;dirtyIdx1]];
quotes: @[quotes;`bsize;{[x;i] @[x;i;:;neg x[i]]}[;dirtyIdx2]];
quotes: @[quotes;`time;{[x;i] @[x;i;:;x[i]+24:00:00.000]}[;dirtyIdx3]];

quotes: `date`time xasc quotes;
(hsym `$basePath,"/Equities Trade Pipeline/data","/quotes.csv") 0: csv 0: quotes;
show "quotes.csv saved: ",string count quotes;

// --- 3. Generate trades.csv ---
show "Generating trades...";
t_syms: n_trades?syms;
t_base: basePrices[syms?t_syms];
t_mid: t_base * 1 + (n_trades?1.0) * 0.06 - 0.03;
t_dates: n_trades?(2025.01.02 + til 5);
t_times: 09:30:00.000 + n_trades?23400000;
condList: `N`N`N`N`N,(`$"@"),`F`O`T;

trades: ([]
    date: t_dates;
    time: t_times;
    sym: t_syms;
    price: t_mid + (n_trades?1.0) * 0.04 - 0.02;
    size: n_trades?(100 200 300 500 1000 2000 5000);
    side: n_trades?`B`S;
    exchange: n_trades?`NYSE`NASDAQ`BATS`ARCA;
    tradeId: `$"TRD-",/:string til n_trades;
    orderId: `$"ORD-",/:string n_trades?n_orders;
    condition: n_trades?condList;
    broker: n_trades?`GSCO`MSCO`JPMC`BOFA`CITI`BARC`UBS`CS
  );

// INJECT DIRTY DATA
dupCnt: floor n_trades * 0.005;
dupFrom: neg[dupCnt]?n_trades;
dupTo: neg[dupCnt]?n_trades;
trades: @[trades;`tradeId;{[x;f;t] @[x;t;:;x f]}[;dupFrom;dupTo]];
nullPriceIdx: neg[floor n_trades * 0.02]?n_trades;
trades: @[trades;`price;{[x;i] @[x;i;:;0Nf]}[;nullPriceIdx]];
zeroSizeIdx: neg[floor n_trades * 0.005]?n_trades;
trades: @[trades;`size;{[x;i] @[x;i;:;0]}[;zeroSizeIdx]];

trades: `date`time xasc trades;
(hsym `$basePath,"/data","/trades.csv") 0: csv 0: trades;
show "trades.csv saved: ",string count trades;

// --- 4. Generate orders.csv ---
show "Generating orders...";
o_syms: n_orders?syms;
o_base: basePrices[syms?o_syms];

orders: ([]
    date: n_orders?(2025.01.02 + til 5);
    time: 09:30:00.000 + n_orders?23400000;
    orderId: `$"ORD-",/:string til n_orders;
    sym: o_syms;
    side: n_orders?`B`S;
    orderType: n_orders?`LMT`MKT`LMT`LMT`STP;
    limitPrice: o_base * 1 + (n_orders?1.0) * 0.04 - 0.02;
    qty: n_orders?(100 200 500 1000 2000 5000 10000);
    status: n_orders?`Filled`Filled`Filled`PartFill`Cancelled`New;
    broker: n_orders?`GSCO`MSCO`JPMC`BOFA`CITI`BARC`UBS`CS
  );

orders: `date`time xasc orders;
(hsym `$basePath,"/data","/orders.csv") 0: csv 0: orders;
show "orders.csv saved: ",string count orders;

show "";
show "=== ALL FILES GENERATED ===";
show "refdata.csv : ",string count refdata;
show "quotes.csv  : ",string count quotes;
show "trades.csv  : ",string count trades;
show "orders.csv  : ",string count orders;
show "Location    : ",basePath;