\l log.q
\l functions.q
n_trades: 50000;
n_orders: 25000;
n_quotes: 100000;

syms: `AAPL`MSFT`GOOGL`AMZN`TSLA`META`NVDA`JPM`BAC`WFC`GS`MS`V`MA`NFLX`DIS`PYPL`INTC`AMD`CRM`ORCL`CSCO`ADBE`QCOM`TXN`AVGO`IBM`NOW`UBER`LYFT`SQ`SNAP`TWTR`ZM`DOCU`ROKU`PINS`SHOP`SPOT`PLTR`COIN`HOOD`RBLX`ABNB`DASH`DDOG`SNOW`NET`CRWD`ZS;

sectors: `Tech`Tech`Tech`Tech`Tech`Tech`Tech`Finance`Finance`Finance`Finance`Finance`Finance`Finance`Tech`Media`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Crypto`Finance`Gaming`Travel`Tech`Tech`Tech`Tech`Tech`Tech;

basePrices: 185 420 175 185 250 500 880 195 35 58 450 95 280 470 700 110 75 45 160 300 125 52 580 175 190 1300 185 880 75 18 80 12 55 75 60 70 35 85 230 25 220 18 45 165 140 130 175 95 350 210f;

lotSizes: 50#100 200 500 1000;
t_syms: n_trades?syms;
t_base: basePrices[syms?t_syms];
t_mid: t_base * 1 + (n_trades?1.0) * 0.06 - 0.03;
t_dates: n_trades#(.z.D);
t_times: 09:30:00.000 + n_trades?23400000;
condList: `N`N`N`N`N,(`$"@"),`F`O`T;  

trades: ([]date: t_dates; 
           time: t_times; 
           sym: t_syms; 
           price: t_mid + (n_trades?1.0) * 0.04 - 0.02; 
           size: n_trades?(100 200 300 500 1000 2000 5000); 
           side: n_trades?`B`S;
           exchange: n_trades?`NYSE`NASDAQ`BATS`ARCA; 
           tradeId: `$"TRD-",/:string til n_trades;
           orderId: `$"ORD-",/:string n_trades?n_orders; 
           condition: n_trades?condList; 
           broker: n_trades?`GSCO`MSCO`JPMC`BOFA`CITI`BARC`UBS`CS);


q_syms: n_quotes?syms;
q_base: basePrices[syms?q_syms];
q_mid: q_base * 1 + (n_quotes?1.0) * 0.06 - 0.03;
q_spread: 0.01 + n_quotes ? 0.15;
q_dates: n_quotes#(.z.D);
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

.log.info "Data set created"

minDate: exec min date from trades;
maxDate: exec max date from trades;
.log.info "Trade date range: ", string[minDate], " to ", string[maxDate];


minDateq: exec min date from quotes;
maxDateq: exec max date from quotes;
.log.info "Quote date range: ", string[minDateq], " to ", string[maxDateq];

.log.info "Number of rows in Trades: ",string[count trades];
.log.info "Number of rows in Quotes: ", string[count quotes];

.rdb.getTradesBySym:{[s]
    select from trades where sym = s}

.rdb.getQuotesBySym:{[s]
    select from quotes where sym = s}

.rdb.getVWAP:{[s]
    select size wavg price, totalVolume: sum size, numoftrades: count i by date, sym from trades where sym=s }

.rdb.getDate:{[]
    exec distinct date from trades }

.rdb.getSyms:{[]
    exec distinct sym from trades }

.rdb.getRowCounts:{[]
    (`trades`quotes!(count trades;count quotes))
     }

.rdb.insertTrade:{[tradeData]
    `trades insert tradeData }

.rdb.eod:{[] 
    // Trades: cleaning before saving
    cleanTrades: dedup[trades];
    cleanTrades: fillNulls[cleanTrades;`price];
    cleanTrades: removeZeroSize[cleanTrades];
    cleanTrades: filterTradingHours[cleanTrades];

     d: .z.D;
     dayTrades: `sym`time xasc select tradeId, time, sym, price, size, exchange, orderId, condition, broker,side from cleanTrades;
     dayTrades: .Q.en[`:hdb] dayTrades;
     partPath: ` sv `:hdb,(`$string d),`trades,`;
     partPath set dayTrades;
     -1 "Saved ", string[d];
    


     trades:: 0#trades;

    // quotes

    cleanQuotes: fixNegatives[quotes; `bsize];
    cleanQuotes: fixNegatives[cleanQuotes; `asize];
    cleanQuotes: fillNulls[cleanQuotes; `bid];
    cleanQuotes: filterTradingHours[cleanQuotes];


    d: .z.D;
    dayQuotes: `sym`time xasc select time, sym, bid, ask, bsize, asize, exchange, condition from cleanQuotes;
    dayQuotes: .Q.en[`:hdb] dayQuotes;
    partPath: ` sv `:hdb,(`$string d),`quotes,`;
    partPath set dayQuotes;
     -1 "Saved ", string[d];


    quotes:: 0#quotes;
    .log.info "EOD complete for ", string .z.D;
 }



