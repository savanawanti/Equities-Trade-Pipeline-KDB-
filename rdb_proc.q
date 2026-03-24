\l log.q
\l sym.q
\l functions.q
    
.rdb.tp: @[hopen;5012;{[e] -1"Error connecting to tickerplant",e;0}];

.rdb.tp (`.u.sub;`trades);

.rdb.tp (`.u.sub;`quotes);

upd:{[t;x]
    t insert x
 }



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

.rdb.end:{[] 
    / Trades: cleaning before saving


     d: .z.D;
     dayTrades: `sym`time xasc select time, sym, price, size, side, exchange, tradeId, orderId, condition, broker from trades;
     dayTrades: .Q.en[`:hdb] dayTrades;
     partPath: ` sv `:hdb,(`$string d),`trades,`;
     partPath set dayTrades;
     -1 "Saved ", string[d];
    


     trades:: 0#trades;



    d: .z.D;
    dayQuotes: `sym`time xasc select time, sym, bid, ask, bsize, asize, exchange, condition from quotes;
    dayQuotes: .Q.en[`:hdb] dayQuotes;
    partPath: ` sv `:hdb,(`$string d),`quotes,`;
    partPath set dayQuotes;
     -1 "Saved ", string[d];


    quotes:: 0#quotes;
    .log.info "EOD complete for ", string .z.D;

 }

.u.end:{[d] .rdb.end[] }



