\l sym.q

.cep.tp: @[hopen;5012;{[e] -1"Error in connecting tick",e;0}];

.cep.tp (`.u.sub;`trades);
.cep.tp (`.u.sub;`quotes);

.cep.tradeStats:([sym: `symbol$()] maxPrice: `float$(); minPrice: `float$(); totalTrades: `long$(); totalSize:`long$(); vwap: `float$())
.cep.quoteStats: ([sym:`symbol$()] maxBid:`float$(); minAsk:`float$(); totalQuotes:`long$(); spread: `float$())

upd:{[table;data]
   $[table = `trades;
    .cep.tradeStats +: select maxPrice: max price, minPrice: min price,totalTrades: count i, totalSize: sum size, vwap: size wavg price by sym from data;
    .cep.quoteStats +: select maxBid: max bid, minAsk: min ask, totalQuotes : count i,spread: last (bid-ask) by sym from data
    ];
    `stats set .cep.tradeStats lj .cep.quoteStats;
 }


.u.end:{[d] }



