# Data Sources

This document is the source of truth for every dataset used in this project. Read this before downloading anything.

## Summary

| # | Dataset | Grain | Rows | Years | Cols |
|---|---|---|---|---|---|
| 1 | Monthly PT patronage by mode | month × mode (wide) | ~100 | 2018–2026 | 7 + junk |
| 2 | Annual metro train station patronage | station × FY | ~2,000 | FY19-20 → FY24-25 | 15 |
| 3 | Annual regional train station patronage | station × FY | ~700 | FY20-21 → FY23-24 | 6 |
| 4 | Monthly avg patronage by day-type by mode | month × day × mode (long) | ~3,000+ | 2018–2026 | 7 |

**Combined scale:** ~6,000 rows across 4 source schemas with three different grains (monthly mode-level, annual station-level, monthly day-type-mode). Mismatched grains and schemas are the engineering problem.

---

## Source 1 — Monthly patronage by mode

**Dataset page:** https://discover.data.vic.gov.au/dataset/monthly-public-transport-patronage-by-mode

**Direct CSV download:** https://opendata.transport.vic.gov.au/dataset/1ab35aa9-f21d-4f00-939b-60dade427d45/resource/74174b02-76bc-4d10-ae7c-401d90ef033c/download/monthly_public_transport_patronage_by_mode.csv

**Schema (wide format — 7 mode columns):**
```
Year, Month, Month name,
Metropolitan train, Metropolitan tram, Metropolitan bus,
Regional train, Regional coach, Regional bus
```

**Coverage:** Jan 2018 → Jan 2026 (~97 data rows + trailing junk)

**Known quirks (real-world mess we have to handle):**
- BOM character at start of file (`\ufeff`)
- 7 EMPTY trailing comma-only columns on every row (CSV writer quirk)
- 12+ trailing blank rows at end of file
- Numbers like `"16,809,932"` — quoted with thousand-separator commas
- Wide format — needs UNPIVOT into long for warehouse
- COVID crater clearly visible: April 2020 Metro Train = 2.1M (vs 22M in April 2018) — a major analytical signal

**Save as:** `data/raw/monthly_patronage_by_mode.csv`

---

## Source 2 — Annual metro train station patronage

**Dataset page:** https://discover.data.vic.gov.au/dataset/annual-metropolitan-train-station-patronage-station-entries

**Direct CSV downloads (download all 6 years):**

| Year | URL |
|---|---|
| FY24-25 | https://opendata.transport.vic.gov.au/dataset/2fa2cdfa-84f1-455e-b6c9-058b92774b34/resource/c9507eb5-aa48-4a43-aa09-c10a24d1f2fe/download/annual_metropolitan_train_station_entries_fy_2024_2025.csv |
| FY23-24 | https://opendata.transport.vic.gov.au/dataset/2fa2cdfa-84f1-455e-b6c9-058b92774b34/resource/57faf356-36a3-4bbe-87fe-f0f05d1b8996/download/annual_metropolitan_train_station_entries_fy_2023_2024.csv |
| FY22-23 | (find on the dataset page above) |
| FY21-22 | (find on the dataset page above) |
| FY20-21 | (find on the dataset page above) |
| FY19-20 | https://vicroadsopendatastorehouse.vicroads.vic.gov.au/opendata/Public_Transport/Patronage/Annual%20metropolitan%20train%20station%20entries/Annual%20metropolitan%20train%20station%20entries%202019-20.csv |

**Schema (15 columns — station-level with time bands):**
```
Fin_year, Stop_ID, Stop_name, Stop_lat, Stop_long,
Pax_annual, Pax_weekday, Pax_norm_weekday, Pax_sch_hol_weekday,
Pax_Saturday, Pax_Sunday,
Pax_pre_AM_peak, Pax_AM_peak, Pax_interpeak, Pax_PM_peak, Pax_PM_late
```

**Coverage:** ~220 stations × 6 years ≈ 1,300 rows

**Known quirks:**
- BOM at start of file
- Patronage values rounded to nearest 50 (privacy protection); values <50 rounded UP to 50 (creates artificial floor)
- Station name "Flinders Street" vs "Flinders St" possible across years (need to confirm)
- Stop_ID is the natural key for stations
- **Schema MISMATCH** with regional dataset (15 cols vs 6 cols) — see Source 3

**Save as:** `data/raw/metro_stations_fy_2019_2020.csv`, `..._fy_2020_2021.csv`, etc.

---

## Source 3 — Annual regional train station patronage

**Dataset page:** https://discover.data.vic.gov.au/dataset/annual-regional-train-station-patronage-station-entries

**Direct CSV downloads:**

| Year | URL |
|---|---|
| FY23-24 | https://opendata.transport.vic.gov.au/dataset/2d4f81dc-f56a-4bcf-8291-ee04fe9669e6/resource/f93a819a-351e-4242-a6f3-74d92cd682dc/download/annual_regional_train_station_entries_fy_2023_2024.csv |
| FY21-22 | https://opendata.transport.vic.gov.au/dataset/2d4f81dc-f56a-4bcf-8291-ee04fe9669e6/resource/92bcfc44-ed6d-44f3-8099-e409cfd102ae/download/annual_regional_train_station_entries_fy_2021_2022.csv |
| FY20-21 | https://opendata.transport.vic.gov.au/dataset/2d4f81dc-f56a-4bcf-8291-ee04fe9669e6/resource/84d65986-edde-4efd-b193-3c62d4ddad22/download/annual_regional_train_station_entries_fy_2020_2021.csv |
| FY24-25, FY22-23 | (find on the dataset page above if available) |

**Schema (6 columns — much narrower than metro):**
```
Fin_year, Stop_ID, Stop_name, Stop_lat, Stop_long, Pax_annual
```

**Coverage:** ~120 regional stations × 4+ years ≈ 500–700 rows

**Known quirks:**
- Station names have descriptive suffixes in parentheses: `"Melton Railway Station (Melton South)"`, `"Albury Railway Station (Albury (NSW))"` — needs name normalisation
- Includes Albury (technically NSW) — flag or filter
- No day-type or time-band breakdown (only `Pax_annual`)
- Need to handle the schema mismatch with metro: regional rows will have NULL for the day-type and time-band columns when unified

**Save as:** `data/raw/regional_stations_fy_*.csv`

---

## Source 4 — Monthly average patronage by day-type by mode

**Dataset page:** https://discover.data.vic.gov.au/dataset/monthly-average-patronage-by-day-type-and-by-mode

**Direct CSV download:** https://opendata.transport.vic.gov.au/dataset/3937e4b1-2423-4b62-9bf0-62d36277ac55/resource/2606a765-88f0-41c9-9b7c-76d3f2626a67/download/monthly_average_patronage_by_day_type_and_by_mode.csv

**Schema (7 columns — already long-format):**
```
Year, Month, Month_name, Day_of_week, Day_type, Mode, Pax_daily
```

Values:
- `Day_of_week`: Monday, Tuesday, ..., Sunday
- `Day_type`: Normal Weekday, School Holiday Weekday, Weekend
- `Mode`: MetroBus, MetroTrain, RegionalBus, RegionalTrain, Tram

**Coverage:** Jan 2018 → recent; long-format ≈ 2,000–3,000 rows

**Known quirks:**
- Mode names don't match Source 1 ("MetroTrain" here vs "Metropolitan train" in Source 1) — cross-source vocabulary reconciliation needed
- No regional coach (Source 1 has it; this one doesn't)
- This is the only source where day-of-week granularity exists, so it's the only way to answer "is Tuesday recovery faster than Monday?"

**Save as:** `data/raw/monthly_avg_by_daytype_mode.csv`

---

## Cross-source vocabulary mismatches we'll have to fix

The four datasets describe the same modes with different vocabularies. This is the kind of issue every analyst hits with multi-source data and is worth showcasing.

| Concept | Source 1 vocab | Source 4 vocab | Sources 2 & 3 |
|---|---|---|---|
| Metro train | "Metropolitan train" | "MetroTrain" | (station-level, no mode field) |
| Metro tram | "Metropolitan tram" | "Tram" | n/a |
| Metro bus | "Metropolitan bus" | "MetroBus" | n/a |
| Regional train | "Regional train" | "RegionalTrain" | (in Source 3) |
| Regional bus | "Regional bus" | "RegionalBus" | n/a |
| Regional coach | "Regional coach" | (absent) | n/a |

The cleaning layer's job: pick canonical names (lowercase snake-case probably: `metro_train`, `metro_tram`, etc.) and apply consistent mapping across sources.

---

## Download checklist

Run these in any order — they're all freely accessible CSV files.

- [ ] **1**: `monthly_patronage_by_mode.csv` (1 file)
- [ ] **2**: `metro_stations_fy_*.csv` (6 files — one per FY)
- [ ] **3**: `regional_stations_fy_*.csv` (4+ files — one per FY)
- [ ] **4**: `monthly_avg_by_daytype_mode.csv` (1 file)

**Total:** ~12 CSV files, all under 5 MB combined.

Save them all under `data/raw/` in this project directory.

---

## Why this dataset combination works for a SQL portfolio project

1. **Real Australian data** — not synthetic, not US, not Kaggle. Strong AU job-market signal.
2. **Real mess** — BOM characters, trailing junk rows, quoted comma-numbers, schema mismatches across sources, vocabulary inconsistencies. This is the kind of stuff every real BA hits weekly.
3. **Multi-source grain reconciliation** — monthly × mode vs annual × station vs monthly × day-type × mode. The dimensional design has to handle all three.
4. **COVID recovery narrative** — built-in headline arc that any reader instantly understands.
5. **Scale appropriate** — ~6,000 rows total. Big enough to justify a warehouse, small enough to develop on a laptop.
6. **Stable URLs** — Victorian government CKAN catalog, updated monthly with 2-month lag. Will still be there when a recruiter clicks the link in 6 months.
