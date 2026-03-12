\l functions.q
\l load.q

/Creating the pipeline
/rawTrades → dedup → fillNulls → removeZeroSize → filterTradingHours → cleanTrades
/rawQuotes → fixNegatives(bsize) → fixNegatives(asize) → fillNulls(bid) → filterTradingHours → cleanQuotes

/Trade table pipeline
show auditTable[trades]

cleanTrades: dedup[trades]
cleanTrades: fillNulls[cleanTrades;`price]
cleanTrades: removeZeroSize[cleanTrades]
cleanTrades: filterTradingHours[cleanTrades]

show auditTable[cleanTrades]

/Quote Table pipeline
show auditTable[quotes]

cleanQuotes: fixNegatives[quotes; `bsize]
cleanQuotes: fixNegatives[cleanQuotes; `asize]
cleanQuotes: fillNulls[cleanQuotes; `bid]
cleanQuotes: filterTradingHours[cleanQuotes]

show auditTable[cleanQuotes]


/Enrich the Data
/Create an enriched trades table by joining refdata onto your clean trades.

enrichedCleanTrades: cleanTrades lj `sym xkey select sym, sector, lot_size, base_price from refdata