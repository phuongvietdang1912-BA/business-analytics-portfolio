# Data Dictionary

## Cleaned CSVs (output of python/clean_sources.py)

### clean_monthly_mode.csv
| Column | Type | Meaning |
|---|---|---|
| year | int | Calendar year |
| month | int | Calendar month (1–12) |
| mode_canonical | str | Canonical mode key (metro_train, metro_tram, etc.) |
| patronage | int | Total monthly boardings for that mode |

### clean_stations.csv
| Column | Type | Meaning |
|---|---|---|
| fin_year | str | Financial year label (e.g. FY24-25) |
| stop_id | int | Station natural key |
| stop_name | str | Original station name (with suffixes) |
| stop_name_clean | str | Normalised display name |
| stop_name_suffix | str | Parenthetical suffix if any |
| stop_lat / stop_long | decimal | Coordinates |
| network | str | 'metro' or 'regional' |
| is_border_nsw | bool | True if NSW-border station (e.g. Albury) |
| pax_annual | int | Total annual station entries |
| pax_weekday … pax_sunday | int | Daily avg by day type (metro only; NULL for regional) |
| pax_pre_am_peak … pax_pm_late | int | Daily avg by time band (metro only; NULL for regional) |

### clean_daytype_mode.csv
| Column | Type | Meaning |
|---|---|---|
| year, month | int | Calendar period |
| day_of_week | str | Monday … Sunday |
| day_type | str | Normal Weekday / School Holiday Weekday / Weekend |
| mode_canonical | str | Canonical mode key |
| pax_daily | int | Daily average patronage |

## Canonical mode keys

| Canonical | Source 1 spelling | Source 4 spelling |
|---|---|---|
| metro_train | Metropolitan train | MetroTrain |
| metro_tram | Metropolitan tram | Tram |
| metro_bus | Metropolitan bus | MetroBus |
| regional_train | Regional train | RegionalTrain |
| regional_bus | Regional bus | RegionalBus |
| regional_coach | Regional coach | (absent in Source 4) |

## Warehouse dimensions & facts

See README Section 6 for the full star schema. Key surrogate keys:
- `dim_date.date_key` — monthly grain
- `dim_mode.mode_key` — conformed across facts
- `dim_station.station_key` — unique per (stop_id, network)
- `dim_day_type.day_type_key` — day_of_week × day_type combos

## Known data quirks (handled)

| Quirk | Source | Handled in |
|---|---|---|
| BOM at file start | All | clean_sources.py (utf-8-sig) |
| 12+ trailing junk rows | Source 1 | clean_sources.py (Year numeric filter) |
| 7 empty trailing columns | Source 1 | clean_sources.py (dropna axis=1) |
| Quoted comma numbers "16,809,932" | Sources 1,2,3 | clean_sources.py (parse_patronage_number) |
| Wide format | Source 1 | clean_sources.py (melt/UNPIVOT) |
| 15-col vs 6-col schema | Sources 2 vs 3 | clean_sources.py (NULL-fill) + SQL fact |
| Mode vocabulary mismatch | Sources 1 vs 4 | clean_sources.py (MODE_CANONICAL) |
| Parenthetical station names | Source 3 | clean_sources.py (normalise_station_name) |
| NSW-border stations | Source 3 | clean_sources.py (is_border_nsw flag) |
| Patronage rounded to 50 | Sources 2,3 | documented limitation (not corrected) |
