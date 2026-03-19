# Equities Trade Data Pipeline — KDB+/q

An end-to-end equities trade data pipeline built entirely in KDB+/q, simulating a production-grade system used on trading desks at investment banks and hedge funds. The pipeline ingests raw market data from CSV feeds, validates and cleans it, stores it in a date-partitioned Historical Database (HDB), serves analytics queries, and extends into a multi-process IPC architecture with separate HDB, RDB, and Gateway processes.

---

## Architecture

### Level 1 — Batch Pipeline

```
  ┌─────────────┐     ┌───────────────┐     ┌────────────────┐     ┌─────────────┐
  │  Phase 1    │────▶│   Phase 2     │────▶│    Phase 3     │────▶│  Phase 4    │
  │ Data Gen    │     │ Clean & Enrich│     │ HDB + RDB Arch │     │ Analytics   │
  │             │     │               │     │                │     │             │
  │ 3.5M rows   │     │ Null fill     │     │ Partitioned DB │     │ VWAP        │
  │ 4 CSV files │     │ Dedup         │     │ Sym enumeration│     │ Spread      │
  │ Dirty data  │     │ Fix negatives │     │ Splayed tables │     │ Anomaly     │
  │ injected    │     │ Range filter  │     │ RDB + Gateway  │     │ Exec Quality│
  └─────────────┘     └───────────────┘     └────────────────┘     │ P&L Report  │
                                                                    └─────────────┘
```

### Level 2 — IPC Multi-Process Architecture

```
  ┌──────────────────┐          ┌──────────────────┐
  │   HDB Process    │          │   RDB Process    │
  │   (hdb_proc.q)   │          │  (rdb_proc.q)    │
  │   Port 5010      │          │   Port 5011      │
  │                  │          │                  │
  │  .hdb.get*()     │          │  .rdb.get*()     │
  │  Historical data │          │  Today's data    │
  │  On-disk (HDB)   │          │  In-memory       │
  └────────┬─────────┘          └────────┬─────────┘
           │                              │
           │    ┌──────────────────┐      │
           └───▶│    Gateway       │◀─────┘
                │    (gw.q)        │
                │    Port 5020     │
                │                  │
                │  .gw.get*()      │
                │  Query routing   │
                │  Error handling  │
                └────────┬─────────┘
                         │
                    Traders / Quants
                    connect here
```

**How it works:**
- **HDB Process** loads the partitioned database from disk and serves historical queries via namespaced `.hdb.*` functions
- **RDB Process** generates today's data in-memory (50K trades, 100K quotes) and serves real-time queries via `.rdb.*` functions
- **Gateway** connects to both over IPC (TCP/IP), routes queries, combines results, and handles process failures gracefully
- **EOD (End of Day):** `.rdb.eod` cleans and saves today's RDB data as a new HDB partition, then clears RDB memory

**HDB Structure on Disk:**
```
hdb/
├── sym                          ← symbol enumeration file
├── 2025.01.02/
│   ├── trades/
│   │   ├── .d                   ← column order
│   │   ├── sym                  ← enumerated (stored as ints)
│   │   ├── time, price, size    ← binary column files
│   │   └── ...
│   └── quotes/
│       └── ...
├── 2025.01.03/
├── 2025.01.04/
├── 2025.01.05/
└── 2025.01.06/
```

---

## Datasets

| Table     | Rows      | Description                            | Key Columns                           |
|-----------|-----------|----------------------------------------|---------------------------------------|
| trades    | 1,000,000 | Equity trade executions                | tradeId, sym, price, size, side       |
| quotes    | 2,000,000 | NBBO (National Best Bid/Offer) quotes  | sym, bid, ask, bsize, asize           |
| orders    | 500,000   | Order submissions                      | orderId, sym, orderType, limitPrice   |
| refdata   | 50        | Instrument reference data              | sym, sector, base_price, exchange     |

**Coverage:** 50 symbols across Tech, Finance, Media, Crypto, Gaming, and Travel sectors over 5 trading days.

**Injected Data Quality Issues (cleaned in Phase 2):**
- ~2% null prices in trades (~20,000 rows)
- ~1% duplicate tradeIds (~5,000 rows)
- ~0.5% zero-size trades (~5,000 rows)
- ~2% null bids in quotes (~40,000 rows)
- ~1% negative bid sizes in quotes (~20,000 rows)
- ~0.5% out-of-hours timestamps in quotes (~10,000 rows)

---

## Project Structure

```
Equities Trade Pipeline/
│
├── run.q                ← Master orchestrator — runs full Level 1 pipeline
├── log.q                ← Logging utility (.log.info, .log.warn, .log.err)
├── dataGeneration.q     ← Generates 3.5M rows of synthetic market data
├── load.q               ← CSV ingestion with type casting (0: operator)
├── functions.q          ← Reusable cleaning functions (5 functions)
├── clean.q              ← Data validation & cleaning pipeline
├── hdb_build.q          ← Partitioned HDB construction
├── rdb.q                ← RDB simulation + gateway query function (Level 1)
├── analytics.q          ← VWAP, spreads, anomalies, exec quality, P&L
│
├── hdb_proc.q           ← Level 2: HDB process — serves .hdb.* queries (port 5010)
├── rdb_proc.q           ← Level 2: RDB process — in-memory data, .rdb.* queries (port 5011)
├── gw.q                 ← Level 2: Gateway — routes queries across HDB + RDB (port 5020)
├── TCP_IP_testing.txt   ← Level 2: IPC learning notes and experiments
├── rdb_execution on q server.txt  ← RDB execution log
│
├── data/                ← Generated CSV files
│   ├── trades.csv
│   ├── quotes.csv
│   ├── orders.csv
│   └── refdata.csv
│
├── hdb/                 ← Partitioned Historical Database
│   ├── sym
│   └── YYYY.MM.DD/
│       ├── trades/
│       └── quotes/
│
├── reports/             ← Analytics output (CSV)
│   ├── aggerateResult.csv
│   ├── ExecutionQuality.csv
│   └── PLReport.csv
│
└── README.md
```

**Dependency Chain:**
```
Level 1 (batch):                  Level 2 (multi-process):
q run.q                           Terminal 1: q hdb_proc.q -p 5010
  ├── log.q                       Terminal 2: q rdb_proc.q -p 5011
  ├── dataGeneration.q            Terminal 3: q gw.q -p 5020
  └── analytics.q                 Terminal 4: client connects to 5020
        └── hdb_build.q
              └── clean.q
                    ├── functions.q
                    └── load.q
```

---

## Level 2 — API Reference

### HDB Process (Port 5010)

| Function                         | Description                              | Parameters     |
|----------------------------------|------------------------------------------|----------------|
| `.hdb.getTradesBySymDate[s;d]`   | Trades for a symbol on a specific date   | sym, date      |
| `.hdb.getTradesBySym[s]`         | All historical trades for a symbol       | sym            |
| `.hdb.getQuotesBySymDate[s;d]`   | Quotes for a symbol on a specific date   | sym, date      |
| `.hdb.getVWAP[s;d]`             | VWAP for a symbol on a specific date     | sym, date      |
| `.hdb.getDates[]`               | All available partition dates             | none           |
| `.hdb.getSyms[]`                | All distinct symbols in HDB              | none           |

### RDB Process (Port 5011)

| Function                     | Description                                | Parameters     |
|------------------------------|--------------------------------------------|----------------|
| `.rdb.getTradesBySym[s]`     | Today's trades for a symbol                | sym            |
| `.rdb.getQuotesBySym[s]`     | Today's quotes for a symbol                | sym            |
| `.rdb.getVWAP[s]`           | Today's VWAP for a symbol                  | sym            |
| `.rdb.getDate[]`            | Today's date                                | none           |
| `.rdb.getSyms[]`            | All distinct symbols in RDB                | none           |
| `.rdb.getRowCounts[]`       | Trade and quote row counts                  | none           |
| `.rdb.insertTrade[data]`    | Insert new trade rows                       | table data     |
| `.rdb.eod[]`                | End-of-day: clean, save to HDB, clear RDB  | none           |

### Gateway (Port 5020)

| Function                     | Description                                       | Parameters     |
|------------------------------|---------------------------------------------------|----------------|
| `.gw.getTradesBySym[s]`     | Combined trades across HDB + RDB                  | sym            |
| `.gw.getVWAP[s]`           | Combined VWAP across all dates + today             | sym            |
| `.gw.getQuotesBySym[s]`    | Combined quotes across HDB + RDB                  | sym            |
| `.gw.getSyms[]`            | Union of all symbols from HDB + RDB               | none           |
| `.gw.getDates[]`           | All dates (HDB partitions + today)                 | none           |
| `.gw.getRowCounts[]`       | Total row counts across both processes             | none           |
| `.gw.reconnect[]`          | Check and reconnect stale/dead handles             | none           |

---

## Cleaning Functions

| Function             | Description                                              | Approach                    |
|----------------------|----------------------------------------------------------|-----------------------------|
| `auditTable`         | Null count & percentage report for any table             | `each` over `flip`          |
| `dedup`              | Remove duplicate tradeIds, keep first occurrence         | `select by` with time sort  |
| `fillNulls[t;col]`   | Forward-fill nulls per sym group (dynamic column)        | Functional update + `fills` |
| `fixNegatives[t;col]`| Absolute value on negative sizes (dynamic column)        | Functional update + `abs`   |
| `removeZeroSize`     | Drop zero-size trades                                    | `select where`              |
| `filterTradingHours` | Keep only 09:30-16:00 records                            | `within` keyword            |

`fillNulls` and `fixNegatives` use **functional form** (`!` with 4 args) for dynamic column names — a key production KDB+ pattern.

---

## Analytics

| Analysis               | Description                                            | Key q Features Used          |
|------------------------|--------------------------------------------------------|------------------------------|
| **VWAP**               | Volume-weighted average price per sym/date             | `wavg`, `xbar` (5-min bins) |
| **Bid-Ask Spread**     | Spread statistics + liquidity ranking                  | `avg`, `med`, `xdesc`       |
| **Anomaly Detection**  | Z-score flagging with configurable threshold           | `avg`, `dev`, `abs`         |
| **Execution Quality**  | % of trades at fair prices vs. NBBO                    | `aj` (as-of join)           |
| **Daily P&L**          | Gross profit/loss per sym per day                      | Vector conditional `?[]`    |

---

## KDB+ Skills Demonstrated

**Core q Programming**
- Functions with multiple parameters, dynamic columns
- Functional form for `update` and `select` (`!` and `?` with 4 args)
- Vector conditionals, `each`, `fills`, `within`, `xbar`, `wavg`
- Logging with `.z.T` timestamps and namespaces

**qSQL**
- `select`, `update`, `exec`, `delete` with `by` and `where`
- Aggregations: `avg`, `sum`, `med`, `dev`, `max`, `min`, `count`
- Inline `where` filtering within aggregations

**KDB+ Architecture**
- Date-partitioned HDB with splayed tables
- Symbol enumeration with `.Q.en` (enumerates all symbol columns, not just sym)
- `sym` file management (shared across tables)
- RDB simulation in `.rdb` namespace
- Gateway query pattern (RDB + HDB combined)
- Sorted attributes (`s#`) on sym column

**IPC & Multi-Process Architecture (Level 2)**
- Separate HDB, RDB, and Gateway processes on dedicated ports
- TCP/IP communication via `hopen` (sync and async)
- Protected evaluation (`@[hopen; port; errorHandler]`) for resilient connections
- Namespaced API design (`.hdb.*`, `.rdb.*`, `.gw.*`)
- Gateway query routing — combines results from multiple processes
- Stale handle detection and automatic reconnection (`.gw.reconnect`)
- End-of-day lifecycle — RDB cleans, saves to HDB partition, clears memory

**Advanced Joins**
- `lj` — Left join (refdata enrichment)
- `aj` — As-of join (trade execution quality vs. NBBO)

**Data Engineering**
- CSV ingestion with `0:` operator and type strings
- CSV export for analytics reports
- Data audit, dedup, forward-fill, range validation
- Reusable cleaning pipeline with composable functions

---

## Technical Notes

### Schema Design: tradeId and orderId as Symbols
`tradeId` and `orderId` are stored as KDB+ symbols rather than strings. In production, unique identifiers like trade IDs are typically stored as strings (char lists) because symbols are interned — every unique symbol is added to the global sym file and never garbage collected. For a project with 1M unique tradeIds, this bloats the sym file. Symbols are used here for simplicity and query convenience, but in a production system with billions of unique IDs, strings would be the correct choice.

### .Q.en Enumerates All Symbol Columns
`.Q.en` enumerates **every** symbol-type column in the table against the `hdb/sym` file — not just the `sym` column. This means `tradeId`, `orderId`, `exchange`, `broker`, `condition`, and `side` all get enumerated if they are symbol type. This is important to understand when inspecting the sym file contents.

### .hdb.getSyms Queries Data, Not the Sym File
`.hdb.getSyms` is implemented as `exec distinct sym from select sym from trades` rather than reading the sym file directly with `get`. The query approach only returns symbols that actually exist in the trade data, while reading the sym file would return every symbol ever enumerated — including values from other columns like broker codes and exchange names.

---

## How to Run

**Prerequisites:** KDB+ 4.x (KX Academy sandbox or local install)

### Level 1 — Full Batch Pipeline
```bash
cd ~/Equities\ Trade\ Pipeline
q run.q
```

This runs the full pipeline:
1. Generates 3.5M rows of synthetic market data
2. Loads and cleans data (removes ~100K dirty records)
3. Builds date-partitioned HDB with sym enumeration
4. Runs analytics and exports CSV reports to `reports/`

### Level 2 — IPC Multi-Process Architecture

Launch each process in a **separate terminal** (order matters):

```bash
# Terminal 1: Start HDB process (loads partitioned database)
q hdb_proc.q -p 5010

# Terminal 2: Start RDB process (generates today's in-memory data)
q rdb_proc.q -p 5011

# Terminal 3: Start Gateway (connects to HDB + RDB)
q gw.q -p 5020

# Terminal 4: Client — connect and query
q
h: hopen 5020
h (`.gw.getTradesBySym; `AAPL)
h (`.gw.getVWAP; `AAPL)
h (`.gw.getSyms; ::)
h (`.gw.getDates; ::)
h (`.gw.getRowCounts; ::)
```

### End-of-Day Process
```q
// From client connected to RDB (port 5011):
h: hopen 5011
h (`.rdb.eod; ::)          // RDB cleans, saves to HDB, clears memory

// Then tell HDB to reload:
hdb: hopen 5010
hdb "\\l hdb"               // HDB picks up the new partition
```

### Interactive queries after loading HDB:
```q
\l hdb
select avg price by sym from trades where date = 2025.01.02
select count i by date from quotes
```

---

## Production Improvements

If this were a production system, the following enhancements would be made:

- **Tickerplant integration** — replace CSV ingestion with real-time pub/sub tick capture
- **Journal-based recovery** — log all messages for RDB crash recovery
- **CEP (Complex Event Processing)** — real-time rolling analytics engine
- **Incremental HDB builds** — only write new date partitions, skip existing ones
- **Parallel processing** — use `peach` for multi-threaded partition writes
- **Compression** — enable column compression for HDB storage savings
- **Permissions & access control** — role-based query restrictions
- **Monitoring** — heartbeat checks, memory usage tracking, query latency alerts
- **Schema migration** — tradeId/orderId to string type for production-scale unique IDs

---

## Author

**Savan Awanti**

Master's in Data Analytics at Northeastern University, Boston. Passionate about data engineering, financial technology, and quantitative systems, with a focus on KDB+/q and its applications in capital markets. Holds KX Academy q-1, q-2, Introduction to KDB+, and KDB+ Architecture certifications.

Built as a capstone portfolio project to demonstrate junior-level KDB+/q development skills for equities trading desk roles.