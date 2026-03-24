\l log.q
\l hdb

.log.info "The Hdb Port is Open at 5010";

.log.info "The tables present in HDB", " " sv string tables[];

t: select distinct date from trades;

minDate: exec min date from t;
maxDate: exec max date from t;
.log.info "Trade date range: ", string[minDate], " to ", string[maxDate];

q: select distinct date from quotes;
minDateq: exec min date from q;
maxDateq: exec max date from q;
.log.info "Quote date range: ", string[minDateq], " to ", string[maxDateq];

.log.info "Number of rows in Trades: ",string[count trades];
.log.info "Number of rows in Quotes: ", string[count quotes];


.hdb.getTradesBySymDate:{[s;d]
  select from trades where date = d, sym=s
 }


.hdb.getQuotesBySymDate:{[s;d]
   select from quotes where date = d, sym=s
 }

.hdb.getVWAP:{[s;d]
 select size wavg price, totalVolume: sum size, numoftrades: count i by date, sym from trades where date = d, sym=s
 }

.hdb.getDates:{[]
 date
 }

.hdb.getSyms:{[]
    exec distinct sym from select sym from trades}


