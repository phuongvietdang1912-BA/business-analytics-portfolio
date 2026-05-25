/* =========================================================
   File: 04_cleaning_layer.sql
   Purpose: Conform raw data into the cleaned schema
   Project: Melbourne Public Transport Patronage Warehouse

   The Python layer did the heavy parsing. This SQL layer does
   the in-database conformance:
     - convert pandas 'True'/'False' text to BIT
     - derive a calendar date from year+month
     - derive a numeric fin_year_start for station data
     - final type tightening
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

DROP TABLE IF EXISTS cleaned.monthly_mode;
DROP TABLE IF EXISTS cleaned.stations;
DROP TABLE IF EXISTS cleaned.daytype_mode;
GO

/* ---- cleaned.monthly_mode ---- */
SELECT
    [year],
    [month],
    DATEFROMPARTS([year], [month], 1) AS month_start,
    mode_canonical,
    patronage
INTO cleaned.monthly_mode
FROM raw.monthly_mode;
GO

/* ---- cleaned.stations ----
   Convert is_border_nsw text to BIT; derive fin_year_start
   (e.g. 'FY24-25' -> 2024) for ordering and joins. */
SELECT
    fin_year,
    -- 'FY24-25' -> 2024 (calendar year the financial year starts)
    2000 + TRY_CAST(SUBSTRING(fin_year, 3, 2) AS INT) AS fin_year_start,
    stop_id,
    stop_name,
    stop_name_clean,
    stop_name_suffix,
    stop_lat,
    stop_long,
    network,
    CASE WHEN is_border_nsw = 'True' THEN 1 ELSE 0 END AS is_border_nsw,
    pax_annual,
    pax_weekday,
    pax_norm_weekday,
    pax_sch_hol_weekday,
    pax_saturday,
    pax_sunday,
    pax_pre_am_peak,
    pax_am_peak,
    pax_interpeak,
    pax_pm_peak,
    pax_pm_late
INTO cleaned.stations
FROM raw.stations;
GO

/* ---- cleaned.daytype_mode ---- */
SELECT
    [year],
    [month],
    DATEFROMPARTS([year], [month], 1) AS month_start,
    day_of_week,
    day_type,
    mode_canonical,
    pax_daily
INTO cleaned.daytype_mode
FROM raw.daytype_mode;
GO

PRINT '04_cleaning_layer.sql complete: 3 cleaned tables created.';
GO
