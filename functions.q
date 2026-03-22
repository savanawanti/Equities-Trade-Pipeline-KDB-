/This Function outputs the table null, perc of null values
auditTable: {[table] 
 t: table;
 nullValues:  {sum null x} each flip t;
 outTable: ([]
            column: cols t;
            nullValues: value nullValues;
            perNullValues: 100 * (value nullValues) % (count t));
            :outTable
 }

/Reusable Functions
/Function 1: "dedup" — Remove duplicate tradeIds. Keep the first occurrence.

dedup: { [t]
  before: count t;
  sorted: `date`time xdesc t;
  firstOccurence: `date`time xasc select by tradeId from sorted; 
  after: count firstOccurence;
  recordsEffected: before - after;
  0!firstOccurence
 }


/Function 2: "fillNulls" — Forward-fill null prices within each sym group.

fillNulls: {[t;col]
    before: sum null t[col];
    result: ![t;();(enlist `sym)!(enlist `sym); (enlist col)! (enlist(fills;col))];
    result2: result[where not null result[col]];
    after: sum null result2[col];
    :result2
 }

/Function 3: "fixNegatives" — Take absolute value of any negative size columns.

fixNegatives:{[t; col]
 before: sum t[col] < 0;
 result: ![t; (); 0b; (enlist col)!(enlist (abs; col))];
 after: sum result[col] < 0;
 :result
 }

/Function 4: "removeZeroSize" — Drop any rows where size = 0

removeZeroSize: {[t]
    before: count t;
    result: select from t where size <> 0;
    after: count result;
    :result
 }

/Function 5: "filterTradingHours" — Keep only rows where time is within 09:30:00.000 to 16:00:00.000.

filterTradingHours: {[t]
    before: count t;
    result: select from t where time within 09:30:00.000 16:00:00.000;
    after: count result;
    :result
 }









