# Equities Trade Data Pipeline — KDB+/q

An end-to-end equities trade data pipeline built entirely in KDB+/q, simulating a production-grade system used on trading desks at investment banks and hedge funds. The project spans three levels: a batch data pipeline (Level 1), a multi-process IPC architecture (Level 2), and a full real-time tick architecture with tickerplant, feed handler, and complex event processing (Level 3).

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
                └──────────────────┘
```

### Level 3 — Full Tick Architecture

```
  ┌──────────────┐
  │ Feed Handler │       Generates synthetic ticks on a timer
  │  (feed.q)    │       Publishes to Tickerplant
  │  No port     │
  └──────┬───────┘
         │ neg[h] (`upd; `trades; data)
         ▼
  ┌──────────────┐       Receives ticks from Feed Handler
  │ Tickerplant  │       Logs every message to journal file
  │  (tick.q)    │       Publishes to all subscribers
  │  Port 5012   │
  └──────┬───────┘
         │
         ├─────────────────────────────┐
         │                             │
         ▼                             ▼
  ┌──────────────┐              ┌──────────────┐
  │     RDB      │              │     CEP      │
  │ (rdb_proc.q) │              │  (cep.q)     │
  │  Port 5011   │              │  Port 5015   │
  │              │              │              │
  │ Subscribes   │              │ Subscribes   │
  │ to TP        │              │ to TP        │
  │ Accumulates  │              │ Incremental  │
  │ today's data │              │ rolling stats│
  │ EOD save     │              │ per symbol   │
  └──────┬───────┘              └──────────────┘
         │                             │
         │ EOD: save partition         │
         ▼                             │
  ┌──────────────┐                     │
  │   hdb/       │  On-disk            │
  │  (partitions │  partitioned        │
  │   on disk)   │  database           │
  └──────┬───────┘                     │
         │ \l hdb                      │
         ▼                             │
  ┌──────────────┐                     │
  │  HDB Process │                     │
  │ (hdb_proc.q) │                     │
  │  Port 5010   │                     │
  └──────────────┘                     │
         │                             │
         │    ┌──────────────────┐     │
         └───▶│    Gateway       │◀────┘
         ┌───▶│    (gw.q)        │
         │    │    Port 5020     │
     RDB─┘   └────────┬─────────┘
                       │
                  Traders / Quants
                  connect here
```

**Data Flow:**
1. Feed Handler generates trade and quote ticks every second
2. Tickerplant receives ticks, appends to journal file, publishes to RDB and CEP
3. RDB accumulates today's data in-memory
4. CEP computes rolling statistics (max, min, count, volume) per symbol using incremental aggregation
5. Gateway queries HDB (historical), RDB (today), and CEP (live stats), combining results
6. At end of day, RDB saves data as a new HDB partition and clears memory

**HDB Structure on Disk:**
```
hdb/
├── sym                          <- symbol enumeration file
├── 2025.01.02/
│   ├── trades/
│   │   ├── .d                   <- column order
│   │   ├── sym                  <- enumerated (stored as ints)
│   │   ├── time, price, size    <- binary column files
│   │   └── ...
│   └── quotes/
│       └── ...
├── 2025.01.03/
├── 2025.01.04/
├── 2025.01.05/
├── 2025.01.06/
└── YYYY.MM.DD/                  <- new partitions added by EOD
```

---

## Datasets

| Table     | Rows      | Description                            | Key Columns                           |
|-----------|-----------|----------------------------------------|---------------------------------------|
| trades    | 1,000,000 | Equity trade executions (Level 1)      | tradeId, sym, price, size, side       |
| quotes    | 2,000,000 | NBBO bid/ask quotes (Level 1)          | sym, bid, ask, bsize, asize           |
| orders    | 500,000   | Order submissions (Level 1)            | orderId, sym, orderType, limitPrice   |
| refdata   | 50        | Instrument reference data              | sym, sector, base_price, exchange     |

**Coverage:** 50 symbols across Tech, Finance, Media, Crypto, Gaming, and Travel sectors.

**Level 1 Injected Data Quality Issues (cleaned in Phase 2):**
- ~2% null prices in trades (~20,000 rows)
- ~1% duplicate tradeIds (~5,000 rows)
- ~0.5% zero-size trades (~5,000 rows)
- ~2% null bids in quotes (~40,000 rows)
- ~1% negative bid sizes in quotes (~20,000 rows)
- ~0.5% out-of-hours timestamps in quotes (~10,000 rows)

**Level 3 Live Data:**
- Feed handler generates 50 trades + 50 quotes per second
- RDB accumulates throughout the day
- EOD saves to HDB as a new date partition

---

## Project Structure

```
Equities Trade Pipeline/
│
│  --- Level 1: Batch Pipeline ---
├── run.q                <- Master orchestrator (runs full Level 1 pipeline)
├── log.q                <- Logging utility (.log.info, .log.warn, .log.err)
├── dataGeneration.q     <- Generates 3.5M rows of synthetic market data
├── load.q               <- CSV ingestion with type casting (0: operator)
├── functions.q          <- Reusable cleaning functions (5 functions)
├── clean.q              <- Data validation & cleaning pipeline
├── hdb_build.q          <- Partitioned HDB construction
├── analytics.q          <- VWAP, spreads, anomalies, exec quality, P&L
│
│  --- Level 2 & 3: Multi-Process Architecture ---
├── sym.q                <- Shared table schema definitions (trades, quotes)
├── tick.q               <- Tickerplant: pub/sub, journal, EOD trigger
├── feed.q               <- Feed Handler: timer-based tick generation
├── hdb_proc.q           <- HDB process: loads HDB, serves .hdb.* queries
├── rdb_proc.q           <- RDB process: subscribes to TP, accumulates data, EOD save
├── cep.q                <- CEP: incremental rolling analytics per symbol
├── gw.q                 <- Gateway: routes queries across HDB + RDB + CEP
│
│  --- Reference & Logs ---
├── rdb.q                <- Level 1 RDB simulation (standalone)
├── TCP_IP_testing.txt   <- IPC learning notes and experiments
├── rdb_execution on q server.txt  <- RDB execution log
│
│  --- Data & Output ---
├── data/                <- Generated CSV files (Level 1)
│   ├── trades.csv
│   ├── quotes.csv
│   ├── orders.csv
│   └── refdata.csv
│
├── hdb/                 <- Partitioned Historical Database
│   ├── sym
│   └── YYYY.MM.DD/
│       ├── trades/
│       └── quotes/
│
├── tick/                <- Journal files (one per day)
│
├── reports/             <- Analytics output (CSV)
│   ├── aggerateResult.csv
│   ├── ExecutionQuality.csv
│   └── PLReport.csv
│
└── README.md
```

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

### Level 3 — Full Tick Architecture

Launch each process in a **separate terminal**. Order matters — upstream processes must be running before downstream processes connect.

```bash
# Terminal 1: HDB process (loads partitioned database)
cd ~/Equities\ Trade\ Pipeline
q hdb_proc.q -p 5010

# Terminal 2: Tickerplant (pub/sub hub + journal)
cd ~/Equities\ Trade\ Pipeline
q tick.q -p 5012

# Terminal 3: RDB (subscribes to TP, accumulates today's data)
cd ~/Equities\ Trade\ Pipeline
q rdb_proc.q -p 5011

# Terminal 4: CEP (subscribes to TP, computes rolling stats)
cd ~/Equities\ Trade\ Pipeline
q cep.q -p 5015

# Terminal 5: Gateway (connects to HDB + RDB + CEP)
cd ~/Equities\ Trade\ Pipeline
q gw.q -p 5020

# Terminal 6: Feed Handler (starts generating ticks)
cd ~/Equities\ Trade\ Pipeline
q feed.q

# Terminal 7: Client (connect and query)
cd ~/Equities\ Trade\ Pipeline
q
h: hopen 5020
h (`.gw.getTradesBySym; `AAPL)
h (`.gw.getVWAP; `AAPL)
h (`.gw.getSyms; ::)
h (`.gw.getDates; ::)
h (`.gw.getRowCounts; ::)
h (`.gw.getStats; ::)
```

### End-of-Day Process
```q
/ On the Tickerplant terminal:
.u.end[]

/ This triggers:
/ 1. RDB saves today's data as new HDB partition
/ 2. RDB clears in-memory tables
/ 3. Journal is closed and new one opened
/ 4. RDB starts accumulating fresh data from feed
```

---

## API Reference

### Tickerplant (Port 5012)

| Function         | Description                                    | Called By       |
|------------------|------------------------------------------------|-----------------|
| `upd[t;data]`    | Receive ticks, log to journal, publish to subs | Feed Handler    |
| `.u.sub[t]`      | Register subscriber for a table                | RDB, CEP        |
| `.u.end[d]`      | Trigger end-of-day on all subscribers           | Manual / Timer  |

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
| `upd[t;data]`                | Insert incoming ticks (called by TP)       | table, data    |
| `.rdb.getTradesBySym[s]`     | Today's trades for a symbol                | sym            |
| `.rdb.getQuotesBySym[s]`     | Today's quotes for a symbol                | sym            |
| `.rdb.getVWAP[s]`           | Today's VWAP for a symbol                  | sym            |
| `.rdb.getDate[]`            | Today's date                                | none           |
| `.rdb.getSyms[]`            | All distinct symbols in RDB                | none           |
| `.rdb.getRowCounts[]`       | Trade and quote row counts                  | none           |
| `.rdb.insertTrade[data]`    | Insert new trade rows                       | table data     |
| `.rdb.end[]`                | End-of-day: save to HDB, clear memory      | none           |
| `.u.end[d]`                 | Called by TP to trigger EOD                  | date           |

### CEP Process (Port 5015)

| Function         | Description                                         | Parameters     |
|------------------|-----------------------------------------------------|----------------|
| `upd[t;data]`    | Process incoming ticks, update rolling stats         | table, data    |
| `stats`          | Combined trade + quote stats (global variable)       | query directly |

**CEP Rolling Stats:**
- Trade stats per sym: max price, min price, total trades, total volume
- Quote stats per sym: max bid, min ask, total quotes, latest spread
- Stats update incrementally with each tick batch using the `+:` operator

### Gateway (Port 5020)

| Function                     | Description                                       | Parameters     |
|------------------------------|---------------------------------------------------|----------------|
| `.gw.getTradesBySym[s]`     | Combined trades across HDB + RDB                  | sym            |
| `.gw.getVWAP[s]`           | Combined VWAP across all dates + today             | sym            |
| `.gw.getQuotesBySym[s]`    | Combined quotes across HDB + RDB                  | sym            |
| `.gw.getSyms[]`            | Union of all symbols from HDB + RDB               | none           |
| `.gw.getDates[]`           | All dates (HDB partitions + today)                 | none           |
| `.gw.getRowCounts[]`       | Total row counts across both processes             | none           |
| `.gw.getStats[]`           | Live CEP rolling stats                             | none           |
| `.gw.getStatsBySym[s]`    | CEP stats for a specific symbol                    | sym            |
| `.gw.reconnect[]`          | Check and reconnect stale/dead handles             | none           |

---

## Cleaning Functions (Level 1)

| Function             | Description                                              | Approach                    |
|----------------------|----------------------------------------------------------|-----------------------------|
| `auditTable`         | Null count & percentage report for any table             | `each` over `flip`          |
| `dedup`              | Remove duplicate tradeIds, keep first occurrence         | `select by` with time sort  |
| `fillNulls[t;col]`   | Forward-fill nulls per sym group (dynamic column)        | Functional update + `fills` |
| `fixNegatives[t;col]`| Absolute value on negative sizes (dynamic column)        | Functional update + `abs`   |
| `removeZeroSize`     | Drop zero-size trades                                    | `select where`              |
| `filterTradingHours` | Keep only 09:30-16:00 records                            | `within` keyword            |

`fillNulls` and `fixNegatives` use **functional form** (`!` with 4 args) for dynamic column names.

---

## Analytics (Level 1)

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
- Closures and projections for passing variables into `each` iterations

**qSQL**
- `select`, `update`, `exec`, `delete` with `by` and `where`
- Aggregations: `avg`, `sum`, `med`, `dev`, `max`, `min`, `count`
- Inline `where` filtering within aggregations

**KDB+ Architecture**
- Date-partitioned HDB with splayed tables
- Symbol enumeration with `.Q.en` (enumerates all symbol columns, not just sym)
- `sym` file management (shared across tables)
- Sorted attributes (`s#`) on sym column

**IPC & Multi-Process Architecture (Level 2)**
- Separate HDB, RDB, and Gateway processes on dedicated ports
- TCP/IP communication via `hopen` (synchronous and asynchronous)
- Protected evaluation (`@[hopen; port; errorHandler]`) for resilient connections
- Namespaced API design (`.hdb.*`, `.rdb.*`, `.gw.*`)
- Gateway query routing — combines results from multiple processes
- Stale handle detection and automatic reconnection (`.gw.reconnect`)

**Tick Architecture (Level 3)**
- Tickerplant with publish/subscribe pattern (`.u.sub`, `.u.w`)
- Journal file for crash recovery — every tick logged to disk before publishing
- Feed handler with timer-based tick generation (`.z.ts`)
- RDB subscribes to TP via `.u.sub`, accumulates data via `upd`
- CEP with incremental aggregation using `+:` operator — rolling stats without storing raw data
- End-of-day lifecycle — TP triggers `.u.end`, RDB saves to HDB partition, clears memory
- Gateway connects to HDB, RDB, and CEP — single query entry point

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

### Tickerplant upd Naming Convention
All subscriber processes (RDB, CEP) define their own local `upd` function. The Tickerplant publishes `neg[h] (`upd; t; data)` to each subscriber, which invokes the subscriber's own `upd` — not the TP's. Same function name, different processes, different implementations. The TP's `upd` logs and publishes. The RDB's `upd` inserts rows. The CEP's `upd` computes incremental stats.

### CEP Incremental Aggregation
CEP uses the `+:` operator on keyed tables for incremental stat updates. When a new batch arrives, `+:` merges the batch stats into the running totals — `max` keeps the running maximum, `sum` and `count` accumulate. This means CEP can handle unlimited data volume without growing memory, since it only stores aggregated stats, never raw ticks.

---

## Production Improvements

If this were a production system, the following enhancements would be made:

- **HDB auto-reload on EOD** — HDB process automatically reloads after RDB saves new partition
- **Journal replay** — RDB replays journal file on restart to recover mid-day state (`-11!`)
- **Symbol-level filtering** — `.u.sub` interface supports symbol lists; TP would filter before publishing
- **Timer-based batching** — TP buffers ticks and publishes in batches to reduce IPC overhead
- **Chained tickerplant** — fan-out to slow subscribers without impacting primary TP
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