\l hdb

// Calculate VWAP for every sym on every date.

aggerateResult: { result: select VWAP: size wavg price, totalVolumne:sum size, countTrade: count tradeId, highPrice: max price, lowPrice: min price    by date, sym from trades;
 (hsym `$getenv[`HOME],"/Equities Trade Pipeline/reports/aggerateResult.csv") 0: csv 0: 0!result;
 :result }

// for every 5 minutes per da
VWAPFor5minute: { select VWAP: size wavg price by date,sym, 5 xbar time.minute from trades }


/From your quotes table, calculate per sym per date

BidAskSpread: { result: select avgSpread: avg (ask-bid), medianSpread: med (ask-bid), maxSpread: max (ask-bid), avgBsize: avg bsize, avgAsize: avg asize, totalCount: count i by date, sym  from quotes where bid <> 0, ask <> 0, not null bid, not null ask;
    (hsym `$getenv[`HOME],"/Equities Trade Pipeline/reports/BidAskSpread.csv") 0: csv 0: 0!result;
    :result }


/ Anomaly Detection

AnomalyDetection: {[d;s;zS]
    result: select price, avgPrice: avg price, stdPrice: dev price from trades where date = d, sym = s; 
    result: update zScores: abs(price - avgPrice) % stdPrice from result;
    result: select price, avgPrice, stdPrice, zScores from result where zScores > zS;
    (hsym `$getenv[`HOME],"/Equities Trade Pipeline/reports/AnomalyDetection.csv") 0: csv 0: 0!result;
    :result;
 }

/ Prec of Good Trades

ExecutionQuality: {[d]
    tradeResults: select time, sym, price, size,side from trades where date = d;
    quoteResults: select time, sym, bid, ask from quotes where date = d;
    joinResults: aj[`sym`time;tradeResults;quoteResults];
    evalResult: update goodExec: ?[side=`B; price<=ask; price>=bid] from joinResults;
    result: select total: count i, goodTrade: sum goodExec, bad: sum not goodExec, pctGood: 100 * avg goodExec by sym from evalResult;
    (hsym `$getenv[`HOME],"/Equities Trade Pipeline/reports/ExecutionQuality.csv") 0: csv 0: 0!result;
    :result;
 }

/Daily P&L report

PLReport: { 
    data: select side, price, size, date, sym from trades;
    result: update totalBuyValue: ?[side=`B; price * size; 0], totalSellValue: ?[side=`S; price * size; 0] from data;
    result: select totalBuyValue: sum totalBuyValue, totalSellValue: sum totalSellValue by date, sym from result;
    result: update grossPnL: totalSellValue- totalBuyValue from result;
    (hsym `$getenv[`HOME],"/Equities Trade Pipeline/reports/PLReport.csv") 0: csv 0: 0!result;
    :result;
 }




