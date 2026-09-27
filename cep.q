\l sym.q

.cep.tp: @[hopen;5012;{[e] -1"Error in connecting tick",e;0}];

.cep.tp (`.u.sub;`trades);
.cep.tp (`.u.sub;`quotes);

.cep.tradeStats:([sym: `symbol$()] maxPrice: `float$(); minPrice: `float$(); totalTrades: `long$(); totalSize:`long$(); totalSizepx: `float$())
.cep.quoteStats: ([sym:`symbol$()] maxBid:`float$(); minAsk:`float$(); totalQuotes:`long$(); spread: `float$())

upd:{[table;data]
   $[table = `trades;
    (b: select maxPrice: max price, minPrice: min price, totalTrades: count i, totalSize: sum size, totalSizepx: sum(size*price) by sym from data;
    .cep.tradeStats : select maxPrice: max maxPrice, minPrice: min minPrice, totalTrades: sum totalTrades, totalSize: sum totalSize, totalSizepx: sum totalSizepx by sym from .cep.tradeStats, b );
    (b: select maxBid: max bid, minAsk: min ask, totalQuotes: count i by sym from data;
    .cep.quoteStats: select maxBid: max maxBid, minAsk: min minAsk, totalQuotes: sum totalQuotes by sym from .cep.quoteStats, b;)
    ];
    `stats set (update VWAP: (totalSizepx % totalSize) from .cep.tradeStats) lj .cep.quoteStats;
 }


.u.end:{[d] }


