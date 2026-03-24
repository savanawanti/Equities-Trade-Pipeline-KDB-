\l sym.q



.u.w: `trades`quotes!(();())

.u.jh: hopen `$":tick/",string .z.D

// called  by subs to get the current table schema and register themselves as subscribes 
// symlist is for filter option not implemented at.

.u.sub:{[tableName] 
    .u.w[tableName],: .z.w;
    :(tableName; value tableName)
 }

// Called by feed.q to send the data to subs
upd:{[table;data]
    .u.jh enlist (`upd;table;data);
    {[table;data;h] neg[h] (`upd;table;data)}[table;data] each .u.w[table];
 }

.u.end:{[]
    allSubs: distinct raze value .u.w;
    {[h] neg[h] (`.u.end;.z.D)} each allSubs;
    hclose .u.jh;
    .u.jh: hopen `$":tick/",string .z.D + 1;
 }



