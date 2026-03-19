\l clean.q

tradeDates: exec distinct date from cleanTrades
quoteDates: exec distinct date from cleanQuotes

saveTrades: {[d]
 dayTrades: select from cleanTrades where date = d;
 dayTrades: `sym`time xasc select tradeId, time, sym, price, size, exchange, orderId, condition, broker,side from dayTrades;
 dayTrades: .Q.en[`:hdb] dayTrades;
 partPath: ` sv `:hdb,(`$string d),`trades,`;
 partPath set dayTrades;
    
 -1 "Saved ", string[d];
 } 

saveTrades each tradeDates


/saving RDB database
saveQuotes:{[d]
 dayQuotes: select from cleanQuotes where date = d;
 dayQuotes: `sym`time xasc select time, sym, bid, ask, bsize, asize, exchange, condition from dayQuotes;
 dayQuotes: .Q.en[`:hdb] dayQuotes;
 partPath: ` sv `:hdb,(`$string d),`quotes,`;
 partPath set dayQuotes;
    
 -1 "Saved ", string[d];
 } 

saveQuotes each quoteDates




