\l sym.q
\l log.q



.u.w: `trades`quotes!(();())

.u.jpath: `$":tick/",string .z.D;
if[() ~ key .u.jpath;.u.journal: (); .log.info "New journal created"];
if[not () ~ key .u.jpath;
    .u.journal: get .u.jpath; .log.info "Existing journal loaded: ",string[count .u.journal]," records"];

// called  by subs to get the current table schema and register themselves as subscribes 
// symlist is for filter option not implemented at.

.u.sub:{[tableName] 
    .u.w[tableName],: .z.w;
    :(tableName; value tableName)
 }

// Called by feed.q to send the data to subs
upd:{[table;data]
    .u.journal,: enlist (table;data);
    .u.jpath set .u.journal;
    {[table;data;h] neg[h] (`upd;table;data)}[table;data] each .u.w[table];
 }

.u.end:{[]
    allSubs: distinct raze value .u.w;
    {[h] neg[h] (`.u.end;.z.D)} each allSubs;
    .u.jpath: `$":tick/",string .z.D;
 }



