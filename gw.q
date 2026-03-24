\l log.q

.gw.hdb: @[hopen;5010;{[e] .log.warn "HDB connection failed: ",e; 0}]
.gw.rdb: @[hopen;5011;{[e] .log.warn "RDB connection failed: ",e; 0}]
.gw.cep: @[hopen;5015;{[e] .log.warn "CEP connection failed: ",e; 0}]

$[.gw.hdb > 0 ; .log.info "HDB connected"; .log.info "HDB Not connected"]
$[.gw.rdb > 0 ; .log.info "RDB connected"; .log.info "RDB Not connected"]
$[.gw.cep > 0 ; .log.info "CEP connected"; .log.info "CEP Not connected"]

.gw.reconnect:{[]
    hdb:  @[.gw.hdb;"1+1";{[e] .log.err "Error connecting to hdb",e;0}];
    rdb:  @[.gw.rdb;"1+1";{[e] .log.err "Error connecting to Rdb",e;0}];
    cep:  @[.gw.cep;"1+1";{[e] .log.err "Error connecting to Cep",e;0}];
    if[(.gw.hdb=0 )or (hdb = 0);.gw.hdb:0;.log.err "HDB is down trying to reconnect"; .gw.hdb: @[hopen;5010;{[e] .log.warn "HDB connection failed: ",e; 0}]];
    if[(.gw.rdb=0) or (rdb = 0);.gw.rdb:0 ;.log.err "RDB is down trying to reconnect"; .gw.rdb: @[hopen;5011;{[e] .log.warn "RDB connection failed: ",e; 0}]];
    if[(.gw.cep=0) or (cep = 0);.gw.cep:0 ;.log.err "CEP is down trying to reconnect"; .gw.cep: @[hopen;5015;{[e] .log.warn "CEP connection failed: ",e; 0}]];
    }


.gw.getTradesBySym:{[s]
    dates: @[.gw.hdb;(`.hdb.getDates;::);{[e] .log.err "Error from HDB extratcing dates ",e;()}];
    hdb: raze {[s;d] @[.gw.hdb; (`.hdb.getTradesBySymDate; s; d); {[e] ()}]} [s] each dates;
    rdb: @[.gw.rdb;(`.rdb.getTradesBySym;s);{[e] .log.err "Error from RDB ",e;()}];
    :hdb,rdb
 }

.gw.getVWAP:{[s]
    dates: @[.gw.hdb;(`.hdb.getDates;::);{[e] .log.err "Error from HDB extratcing dates ",e;()}];
    hdb: raze {[s;d] @[.gw.hdb; (`.hdb.getVWAP; s; d); {[e] ()}]} [s] each dates;
    rdb: @[.gw.rdb;(`.rdb.getVWAP;s);{[e] .log.err "Error from RDB ",e;()}];
    :hdb,rdb
 }

.gw.getQuotesBySym:{[s]
    dates: @[.gw.hdb;(`.hdb.getDates;::);{[e] .log.err "Error extrating Dates ",e;()}];
    hdb: raze {[s;d] @[.gw.hdb;(`.hdb.getQuotesBySymDate;s;d);{[e] .log.err "Error from RDB",e;()}]} [s] each dates;
    rdb: @[.gw.rdb;(`.rdb.getQuotesBySym;s);{[e] .log.err "Error from RDB ",e;()}];
    :hdb,rdb
 }

.gw.getSyms:{[]
    hdb: @[.gw.hdb;(`.hdb.getSyms;::);{[e] .log.err "Cant load Syms ", e;()}];
    rdb: @[.gw.rdb;(`.rdb.getSyms;::);{[e] .log.err "Error from RDB ",e;()}];
    :distinct hdb,rdb
 }

.gw.getDates:{[]
    dates: @[.gw.hdb;(`.hdb.getDates;::);{[e] .log.err "Error from HDB extratcing dates ",e;()}];
    :distinct asc dates,.z.D
 }

.gw.getRowCounts:{[]
    tradesCount: @[.gw.hdb;"count trades";{[e] .log.err "Cant load hdb trade count ", e;0}] + @[.gw.rdb;"count trades";{[e] .log.err "Cant load rdb trade count ", e;0}] ;
    quotesCount: @[.gw.hdb;"count quotes";{[e] .log.err "Cant load hdb Quotes count ", e;0}] + @[.gw.rdb;"count quotes";{[e] .log.err "Cant load rdb Quotes count ", e;0}];
 :`trades`quotes!(tradesCount;quotesCount)
 }

.gw.getstats:{[]
    @[.gw.cep;"stats";{[e] -1"could'nt fetch stats ",e;()}]
 }

.gw.getStatsBySym:{[s]
    res: .gw.getstats[];
    select from res where sym = s
 }





