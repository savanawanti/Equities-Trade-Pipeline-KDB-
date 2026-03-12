# Equities Trade Data Pipeline — KDB+/q

An end-to-end equities trade data pipeline built entirely in KDB+/q, simulating a production-grade system used on trading desks at investment banks and hedge funds. The pipeline ingests raw market data from CSV feeds, validates and cleans it, stores it in a date-partitioned Historical Database (HDB), and serves analytics queries used by traders and quants.

---

## Architecture

```
                        ┌──────────────────────────────────────────────────────────┐
                        │                    PIPELINE FLOW                         │
                        └──────────────────────────────────────────────────────────┘

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

                        ┌──────────────────────────────────────────┐
                        │         STORAGE ARCHITECTURE             │
                        └──────────────────────────────────────────┘

                        ┌──────────────┐     ┌──────────────┐
   Market Data ────────▶│     RDB      │     │     HDB      │
   (Today)              │  (In-Memory) │     │   (On-Disk)  │
                        │  50K trades  │     │  ~1M trades  │
                        └──────┬───────┘     └──────┬───────┘
                               │                     │
                               └──────┬──────────────┘
                                      │
                               ┌──────▼───────┐
                               │   Gateway    │
                               │ Query Layer  │
                               │ (RDB + HDB)  │
                               └──────────────┘
```

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
├── run.q                ← Master orchestrator — runs full pipeline
├── log.q                ← Logging utility (.log.info, .log.warn, .log.err)
├── dataGeneration.q     ← Generates 3.5M rows of synthetic market data
├── load.q               ← CSV ingestion with type casting (0: operator)
├── functions.q          ← Reusable cleaning functions (5 functions)
├── clean.q              ← Data validation & cleaning pipeline
├── hdb_build.q          ← Partitioned HDB construction
├── rdb.q                ← RDB simulation + gateway query function
├── analytics.q          ← VWAP, spreads, anomalies, exec quality, P&L
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
run.q
  ├── dataGeneration.q
  └── analytics.q
        └── hdb_build.q
              └── clean.q
                    ├── functions.q
                    └── load.q
```

---

## Cleaning Functions

| Function             | Description                                              | Approach                    |
|----------------------|----------------------------------------------------------|-----------------------------|
| `auditTable`         | Null count & percentage report for any table             | `each` over `flip`          |
| `dedup`              | Remove duplicate tradeIds, keep first occurrence         | `select by` with time sort  |
| `fillNulls[t;col]`   | Forward-fill nulls per sym group (dynamic column)        | Functional update + `fills` |
| `fixNegatives[t;col]`| Absolute value on negative sizes (dynamic column)        | Functional update + `abs`   |
| `removeZeroSize`     | Drop zero-size trades                                    | `select where`              |
| `filterTradingHours` | Keep only 09:30–16:00 records                            | `within` keyword            |

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
- Symbol enumeration with `.Q.en`
- `sym` file management (shared across tables)
- RDB simulation in `.rdb` namespace
- Gateway query pattern (RDB + HDB combined)
- Sorted attributes (`s#`) on sym column

**Advanced Joins**
- `lj` — Left join (refdata enrichment)
- `aj` — As-of join (trade execution quality vs. NBBO)

**Data Engineering**
- CSV ingestion with `0:` operator and type strings
- CSV export for analytics reports
- Data audit, dedup, forward-fill, range validation
- Reusable cleaning pipeline with composable functions

---

## How to Run

**Prerequisites:** KDB+ 4.x (KX Academy sandbox or local install)

```bash
cd ~/Equities\ Trade\ Pipeline
q run.q
```

This runs the full pipeline:
1. Generates 3.5M rows of synthetic market data
2. Loads and cleans data (removes ~100K dirty records)
3. Builds date-partitioned HDB with sym enumeration
4. Runs analytics and exports CSV reports

**Run individual components:**
```bash
q analytics.q          # Run analytics only (rebuilds HDB)
q rdb.q                # Launch RDB simulation + gateway
```

**Interactive queries after loading HDB:**
```q
\l hdb
select avg price by sym from trades where date = 2025.01.02
select count i by date from quotes
```

---

## Production Improvements

If this were a production system, the following enhancements would be made:

- **Incremental HDB builds** — only write new date partitions, skip existing ones
- **Tickerplant integration** — replace CSV ingestion with real-time tick capture
- **Error handling** — protected evaluation (` @` / `.` ) around all I/O operations
- **Parallel processing** — use `peach` for multi-threaded partition writes
- **Compression** — enable column compression for HDB storage savings
- **Permissions & access control** — role-based query restrictions
- **Monitoring** — heartbeat checks, memory usage tracking, query latency alerts

---

## Author

**Savan Awanti**

Master's in Data Analytics at Northeastern University, Boston. Passionate about data engineering, financial technology, and quantitative systems, with a focus on KDB+/q and its applications in capital markets. Holds KX Academy q1 and q2 certifications along with KDB+ Architecture and Introduction to KDB+ certifications.

Built as a capstone portfolio project to demonstrate junior-level KDB+/q development skills for equities trading desk roles.