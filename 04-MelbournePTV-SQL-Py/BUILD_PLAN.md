# Build Plan — Melbourne Transport SQL Warehouse

## Files (all built — this is the full project)

```
MelbourneTransportSQL/
├── README.md                    ✅ project face
├── docs/
│   ├── DATA_SOURCES.md          ✅ every URL, schema, quirk
│   ├── BUILD_PLAN.md            ✅ this file
│   └── data_dictionary.md       ✅ column meanings
├── python/
│   └── clean_sources.py         ✅ smoke-tested
└── sql/
    ├── 01_database_setup.sql    ✅
    ├── 02_raw_tables.sql        ✅
    ├── 03_load_raw.sql          ✅
    ├── 04_cleaning_layer.sql    ✅
    ├── 05_dw_tables.sql         ✅
    ├── 06_dim_date_load.sql     ✅
    ├── 07_load_dw.sql           ✅
    ├── 08_validation.sql        ✅
    ├── 09_analytics_views.sql   ✅
    └── 10_business_queries.sql  ✅
```

## Your execution sequence

### Step 1 — Download data (30 min)
Follow `docs/DATA_SOURCES.md`. Download ~12 CSVs into `data/raw/`.

### Step 2 — Run the cleaner (5 min)
```bash
cd python/
pip install pandas
python clean_sources.py --input ../data/raw/ --output ../data/cleaned/
```
Check the console output: it reports row counts and warns about any unmapped modes. If you see "WARNING: unmapped modes", a source has a mode-name spelling not in `MODE_CANONICAL` — add it to the dict and re-run.

### Step 3 — Run the SQL (15 min)
Open SSMS / Azure Data Studio. Run files 01–10 in order. Before running file 03, set `@BasePath` to your `data/cleaned/` directory.

### Step 4 — Verify (5 min)
File 08 (validation) should show all checks PASS. File 10 returns the analysis.

### Step 5 — Find the headline (1-2 hrs)
Run file 10's queries. The strongest finding is probably one of:
- Query 02/06: which mode recovered fastest as % of 2018
- Query 09: weekday vs weekend recovery gap (WFH signal)
- Query 10: is mid-week (Tue–Thu) lagging Mon/Fri (hybrid-work signal)

Whatever the data shows, write it up in README Section 2 and Section 8.

### Step 6 — Polish + push (1-2 hrs)
- Schema diagram (Mermaid in README, or dbdiagram.io)
- Verify README links
- Push to GitHub
- Add to portfolio index

## Interview defence — the 5 questions

**1. "Why is this different from your Instacart SQL project?"**
> Instacart was a single clean Kaggle source — the work was dimensional modelling and ETL. This is four separate government datasets with mismatched grains and schemas — the work is multi-source integration and active cleaning. Different muscle: conformed dimensions, schema reconciliation, vocabulary mapping across sources.

**2. "Why four layers (raw/cleaned/dw/analytics)?"**
> The cleaning is substantial — BOM, junk rows, quoted-comma numbers, a 15-col-vs-6-col schema mismatch, and mode names spelled differently across sources. That deserves its own conformance layer rather than being hidden inside the load. raw stays faithful to source; cleaned is conformed; dw is the star; analytics holds the recovery-index views.

**3. "How did you handle the schema mismatch between metro and regional stations?"**
> Metro has 15 columns including time-band detail; regional has 6 — annual total only. I unified them into one fact table where regional rows carry NULL for the detail columns. I documented that explicitly rather than dropping the detail or fabricating regional values. The validation harness even checks that regional rows correctly have NULL time-band data.

**4. "What's a conformed dimension and where did you use one?"**
> A dimension shared across multiple fact tables so they can be analysed consistently. Here, dim_date and dim_mode are conformed across three facts — monthly-mode, station-annual, and daytype-monthly. That's what lets me compare, say, overall mode recovery against day-type recovery using the same mode and time definitions.

**5. "What's the main limitation?"**
> Everything is pre-aggregated by the publisher — no trip-level records. So I can analyse patronage trends but not individual journeys or trip-chaining. And the three grains can't be cleanly joined into one — monthly mode totals vs annual station totals — so I analyse each at its native grain rather than forcing a false join. The recovery findings are also descriptive, not causal: I can show weekday patronage lagged weekend, but proving work-from-home *caused* it needs external data.

## What to skip if short on time

Must-have: cleaner runs, files 01–08 run, validation passes, 5+ window-function queries.
Nice-to-have: all 11 business queries, the station recovery FIRST_VALUE/LAST_VALUE query.
Skip: dashboard (Instacart already covers Power BI), spatial analysis with lat/long.
