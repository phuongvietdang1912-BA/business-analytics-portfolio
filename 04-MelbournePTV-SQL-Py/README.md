# 🚆 Melbourne Public Transport Patronage - SQL Analytical Warehouse

> **End-to-end SQL warehouse integrating four Victorian Government public-transport datasets with mismatched grains and schemas, tracing Melbourne's post-COVID patronage recovery by mode, station, and day-type.**

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Multi-source](https://img.shields.io/badge/ETL-Multi--source%20integration-orange?style=flat)
![Kimball](https://img.shields.io/badge/Modelling-Kimball-1F77B4?style=flat)
![Data](https://img.shields.io/badge/Data-data.vic.gov.au-success?style=flat)
![Status](https://img.shields.io/badge/Status-In%20Progress-yellow)

---

## 📑 Table of Contents
1. [Problem Statement](#1-problem-statement)
2. [Headline Finding](#2-headline-finding)
3. [What This Project Demonstrates](#3-what-this-project-demonstrates)
4. [Data Sources](#4-data-sources)
5. [Architecture](#5-architecture)
6. [Data Model](#6-data-model)
7. [The Integration Challenge](#7-the-integration-challenge)
8. [Key Findings](#8-key-findings)
9. [Design Decisions](#9-design-decisions)
10. [Limitations](#10-limitations)
11. [How to Run](#11-how-to-run)
12. [Project Structure](#12-project-structure)
13. [Roadmap](#13-roadmap)
14. [Author](#14-author)

---

## 1. Problem Statement

Melbourne's public transport network carries hundreds of millions of trips a year across train, tram, bus, and coach. The COVID-19 pandemic caused an unprecedented collapse in patronage - and recovery has been uneven across modes, stations, and trip types.

The Department of Transport and Planning needs a unified analytical view to answer:
- **How fast is patronage recovering, and is it back to pre-COVID levels?**
- **Which modes recovered fastest - and which are lagging?**
- **At the station level, where is demand concentrated, and which stations are underperforming relative to pre-COVID?**
- **Has the *shape* of demand changed - e.g. weekday commuting vs weekend leisure travel?**

The challenge: the relevant data lives in **four separate published datasets** with **different grains and schemas** that don't naturally join. This project integrates them into a single warehouse and answers the questions above.

---

## 2. Headline Finding

> **Melbourne's public transport recovery is a story of two networks and two travel purposes.** By the most recent data, **regional rail has not only recovered but exceeded pre-COVID patronage (+9%)**, while the **metropolitan train network remains ~15% below** its 2018 baseline. The shortfall is concentrated in the weekday commute: **weekend metro travel recovered to ~89%** of pre-COVID, but **weekday travel plateaued at ~74%**. Within the working week, **Monday and Friday (~70%) lag Tuesday–Thursday (73–79%)** - the clearest data signature of Melbourne's shift to hybrid work, where office attendance now clusters mid-week.

*All recovery figures are descriptive comparisons to a 2018 baseline; they describe the pattern, not its cause (see [Limitations](#10-limitations)).*

---

## 3. What This Project Demonstrates

Skills **distinct from the Instacart SQL project** (the other warehouse in this portfolio):

| Skill | Instacart shows | This project shows |
|---|---|---|
| Source data | Single clean Kaggle dataset | **Four real government datasets**, different publishers/formats |
| Data quality | Validation harness on clean data | **Active cleaning** - BOM removal, junk-row stripping, quoted-comma number parsing, schema-drift handling |
| Grain | Single grain (order-item) | **Three mismatched grains reconciled** - monthly×mode, annual×station, monthly×daytype×mode |
| Schema integration | One schema | **Schema reconciliation** - metro (15 cols) vs regional (6 cols), cross-source vocabulary mapping |
| Transformation | Aggregation | **UNPIVOT** wide→long, **cross-source conformance**, derived recovery indices |
| SQL patterns | Star joins | **Window functions** for period-over-period, `LAG` for MoM/YoY, baseline-indexing for recovery % |

---

## 4. Data Sources

All four datasets are published by the Victorian Department of Transport and Planning under CC BY 4.0, available from [data.vic.gov.au](https://discover.data.vic.gov.au/). Full URLs, schemas, and known quirks are documented in [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md).

| # | Dataset | Grain | Approx rows |
|---|---|---|---|
| 1 | Monthly patronage by mode | month × mode (wide) | ~100 |
| 2 | Annual metro train station patronage | station × FY | ~1,300 |
| 3 | Annual regional train station patronage | station × FY | ~700 |
| 4 | Monthly avg patronage by day-type by mode | month × day × mode (long) | ~3,000 |

---

## 5. Architecture

```
4 source CSV groups ──▶ python/ ──▶ cleaned CSVs ──▶ raw schema
   (data.vic.gov.au)     (clean +      (canonical)    (landing)
                          conform)                         │
                                                           ▼
                                                  cleaned schema
                                                  (conformed)
                                                           │
                                                           ▼
                                                  dw schema (star)
                                                           │
                                                           ▼
                                                  analytics schema
                                                  (recovery views)
```

**Four-layer warehouse:**
- **raw** - landing zone, faithful to the cleaned CSVs (one table per source)
- **cleaned** - conformed: canonical mode names, normalised station names, unified grains where possible
- **dw** - Kimball star: shared dimensions (date, mode, station, day-type) + multiple fact tables
- **analytics** - denormalised recovery-index views for reporting and the headline analysis

---

## 6. Data Model

The design uses **conformed dimensions** shared across multiple fact tables - the core Kimball technique for integrating multiple sources.

### Shared dimensions
| Dimension | Grain | Sourced from |
|---|---|---|
| `dim_date` | One row per month | Generated calendar |
| `dim_mode` | One row per transport mode | Conformed across sources 1 & 4 |
| `dim_station` | One row per station | Sources 2 & 3 (metro + regional unified) |
| `dim_day_type` | One row per day-type | Source 4 |

### Fact tables
| Fact | Grain | Sourced from | Notes |
|---|---|---|---|
| `fact_monthly_mode` | month × mode | Source 1 | Total patronage; the COVID-recovery backbone |
| `fact_station_annual` | station × FY | Sources 2 & 3 | Station-level; metro has time-band detail, regional doesn't |
| `fact_daytype_monthly` | month × day-type × mode | Source 4 | Enables weekday-vs-weekend recovery analysis |

Three facts share `dim_mode` and `dim_date` - the conformed-dimension pattern that lets you analyse across grains.

---

## 7. The Integration Challenge

This is the heart of the project - the problems that make it real engineering rather than a tutorial.

### Challenge 1 - Wide vs long
Source 1 is wide (one column per mode). Source 4 is already long. The cleaning layer **UNPIVOTs** Source 1 into long format so both can feed `dim_mode` consistently.

### Challenge 2 - Schema mismatch (metro vs regional stations)
Source 2 (metro) has 15 columns including day-type and time-band breakdowns. Source 3 (regional) has 6 columns - annual total only. Unifying them means **regional rows carry NULLs** for the detail columns, documented explicitly rather than hidden.

### Challenge 3 - Vocabulary reconciliation
The same mode is named differently across sources: `"Metropolitan train"` (Source 1) vs `"MetroTrain"` (Source 4). The cleaning layer maps both to a canonical `metro_train`.

### Challenge 4 - Real CSV mess
- BOM (`\ufeff`) at the start of files
- 12+ trailing junk rows in Source 1
- Numbers quoted with thousand separators: `"16,809,932"`
- Station names with parenthetical suffixes: `"Melton Railway Station (Melton South)"`

### Challenge 5 - Grain reconciliation for recovery analysis
Monthly mode data and annual station data are at different time grains. The analytics layer handles this by computing recovery indices *within* each grain rather than forcing a false join.

---

## 8. Key Findings

### Finding 1 - The COVID collapse was near-total and universal

Every mode bottomed out during the 2020 lockdowns, losing the overwhelming majority of patronage at the trough:

| Mode | Trough month | Fell to (% of 2018 avg) |
|---|---|---|
| Metropolitan Tram | Aug 2020 | ~7% (−93%) |
| Metropolitan Train | Aug 2020 | ~9% (−91%) |
| Regional Train | Aug 2020 | ~13% (−87%) |
| Metropolitan Bus | Apr 2020 | ~15% (−85%) |

Metropolitan modes troughed in **August 2020** (Victoria's second-wave Stage 4 lockdown), while regional bus/coach troughed in **April 2020** (first lockdown) - Melbourne's metropolitan network was hit hardest by the *second* wave, not the first.

### Finding 2 - Recovery is led by regional rail and lagged by metropolitan rail

Latest patronage as a percentage of the 2018 baseline:

| Mode | Recovery (% of 2018) |
|---|---|
| Regional Train | **109%** - exceeded |
| Regional Bus | **107%** - exceeded |
| Metropolitan Bus | **101%** - recovered |
| Regional Coach | **95%** |
| Metropolitan Train | **85%** - lagging |
| Metropolitan Tram | **78%** - lagging |

The split is **metropolitan-vs-regional**, not a mode effect. Regional rail has fully rebounded - consistent with regional population growth during and after the pandemic - while the metropolitan commuter rail and tram networks remain well below pre-COVID levels.

### Finding 3 - The shortfall is the weekday commute, not travel in general

Metropolitan train recovery splits sharply by day type:

| Day type | Recovery (% of 2018) |
|---|---|
| Weekend (leisure) | **~89%** |
| Normal weekday (commute) | **~74%** |

Leisure travel has largely returned; the daily commute has not. The ~15-point gap is the structural signature of changed work patterns.

### Finding 4 - Within the week, Monday and Friday lag - the hybrid "anchor day" pattern

Metropolitan train recovery by day of week (2025 vs 2018):

| Day | Recovery |
|---|---|
| Monday | **70%** - lowest |
| Tuesday | 74% |
| Wednesday | 73% |
| Thursday | **79%** - highest weekday |
| Friday | **70%** |
| Saturday | 86% |
| Sunday | 82% |

The mid-week peak with Monday/Friday troughs is the textbook fingerprint of hybrid working: office attendance concentrates mid-week, with work-from-home clustering at the edges.

### Finding 5 - Regional's share of the network has grown

Regional modes' combined share of total patronage rose over the period as metropolitan recovery lagged - a structural shift in network composition, not just a temporary dip.

> **Note on station-level recovery (Query 08):** some stations return 1,000%+ "recovery" - these are new or rebuilt stations (e.g. East Pakenham, Union) with near-zero patronage in their opening year, not genuine growth. Extreme percentages are a small-denominator artefact, not a finding.

---

## 9. Design Decisions

- **Four-layer architecture** - cleaning is substantial here (multi-source conformance), so it earns its own layer rather than being folded into the load.
- **Conformed dimensions** - `dim_mode` and `dim_date` shared across three facts; the canonical Kimball multi-source pattern.
- **Multiple fact tables, not one** - the three grains are genuinely different; forcing them into one fact would either lose detail or fabricate rows.
- **NULLs for regional time-bands documented, not hidden** - honesty about what each source can and can't tell you.
- **Recovery indexed to a pre-COVID baseline** - analysis expresses patronage as % of a Feb-2020 (or FY18-19) baseline so modes of different sizes are comparable.
- **Patronage values rounded to 50 in source** - a privacy artefact in the station data noted as a known precision limit.

---

## 10. Limitations

- **Aggregated source data.** No individual trip records - all data is pre-aggregated by the publisher. Trip-level questions (journey chaining, individual behaviour) can't be answered.
- **Station rounding.** Station patronage is rounded to the nearest 50, with values <50 rounded up - this creates an artificial floor for very small stations.
- **Grain mismatch limits some cross-source analysis.** Monthly mode totals and annual station totals can't be cleanly joined at a single grain; the project analyses each at its native grain and links them conceptually, not via a forced join.
- **Mode coverage differs across sources.** Source 1 includes regional coach; Source 4 doesn't. Cross-source comparisons are limited to the common modes.
- **No causal layer.** Recovery patterns are descriptive. Attributing them to specific causes (work-from-home policy, fare changes) would require external data and causal design.
- **Recovery findings are descriptive, not causal.** The data shows weekday and Monday/Friday metropolitan patronage lag - it cannot *prove* hybrid work is the cause. Other contributors (regional population growth, fare or service changes, demographic shifts) are not separated out. Findings are phrased as "consistent with" hybrid work, not proof.
- **The most recent month is sometimes partially reported.** Tram patronage for the latest month (Jan 2026) was unpublished at extract time. Unreported (NULL) months are excluded from analysis rather than imputed, so "latest month" can differ by mode.

---

## 11. How to Run

### Prerequisites
- SQL Server 2019+ (or Azure SQL)
- Python 3.10+ with `pandas`
- The four source datasets - see [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) for download URLs

### Setup

```bash
# 1. Download the source CSVs into data/raw/ (see docs/DATA_SOURCES.md)

# 2. Clean and conform the sources
cd python/
python clean_sources.py --input ../data/raw/ --output ../data/cleaned/

# 3. Run the SQL files in order
01_database_setup.sql
02_raw_tables.sql
03_load_raw.sql
04_cleaning_layer.sql
05_dw_tables.sql
06_dim_date_load.sql
07_load_dw.sql
08_validation.sql
09_analytics_views.sql
10_business_queries.sql
```

---

## 12. Project Structure

```
04-Melbourne-Transport-SQL/
├── README.md
├── docs/
│   ├── DATA_SOURCES.md          # every source URL, schema, quirk
│   └── data_dictionary.md       # column meanings
├── python/
│   └── clean_sources.py         # clean + conform the 4 sources
├── sql/
│   ├── 01_database_setup.sql
│   ├── 02_raw_tables.sql
│   ├── 03_load_raw.sql
│   ├── 04_cleaning_layer.sql
│   ├── 05_dw_tables.sql
│   ├── 06_dim_date_load.sql
│   ├── 07_load_dw.sql
│   ├── 08_validation.sql
│   ├── 09_analytics_views.sql
│   └── 10_business_queries.sql
└── data/
    ├── raw/                     # downloaded source CSVs (gitignored)
    └── cleaned/                 # output of clean_sources.py
```

---

## 13. Roadmap

- [ ] Power BI dashboard on the recovery story (optional - Instacart already covers Power BI)
- [ ] Incremental monthly load as new data is published (the source updates monthly)
- [ ] Add bus route-level data if a granular source becomes available
- [ ] Spatial analysis using the station lat/long coordinates

---

## 14. Author

**Phuong Viet Dang (Jackie)**
📧 phuong.vietdang1912@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/phuongviet1912/) · [Portfolio](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio)

Open to **Data Analyst, Business Analyst, and BI Developer** roles in Melbourne.

> *Data source: Department of Transport and Planning, Victoria, licensed under CC BY 4.0.*
