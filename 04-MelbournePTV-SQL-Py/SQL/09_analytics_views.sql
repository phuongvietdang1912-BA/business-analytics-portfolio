/* =========================================================
   File: 09_analytics_views.sql
   Purpose: Denormalised recovery-analysis views
   Project: Melbourne Public Transport Patronage Warehouse

   The headline analytical layer. Recovery is expressed as a
   percentage of a pre-COVID baseline so modes of different
   sizes are comparable.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

/* ---- v_monthly_mode: denormalised monthly patronage ---- */
CREATE OR ALTER VIEW analytics.v_monthly_mode AS
SELECT
    d.month_start,
    d.[year],
    d.[month],
    d.is_covid_period,
    m.mode_canonical,
    m.mode_label,
    m.network,
    f.patronage
FROM dw.fact_monthly_mode f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_mode m ON f.mode_key = m.mode_key;
GO

/* ---- v_mode_recovery_index ----
   Indexes each month's patronage to the same calendar month in
   2018 (pre-COVID baseline) for each mode, so seasonality is
   controlled and recovery is comparable across modes.
   Uses a window function to grab the 2018 baseline per mode/month. */
CREATE OR ALTER VIEW analytics.v_mode_recovery_index AS
WITH base AS (
    SELECT mode_canonical, [month], patronage AS baseline_2018
    FROM analytics.v_monthly_mode
    WHERE [year] = 2018
)
SELECT
    v.month_start,
    v.[year],
    v.[month],
    v.mode_canonical,
    v.mode_label,
    v.network,
    v.patronage,
    b.baseline_2018,
    CAST(100.0 * v.patronage / NULLIF(b.baseline_2018, 0) AS DECIMAL(6,1)) AS pct_of_2018_baseline
FROM analytics.v_monthly_mode v
JOIN base b
    ON v.mode_canonical = b.mode_canonical
   AND v.[month] = b.[month]
WHERE v.patronage IS NOT NULL;   -- exclude unreported months (e.g. tram Jan 2026)
GO

/* ---- v_station_latest: most recent FY per station ---- */
CREATE OR ALTER VIEW analytics.v_station_latest AS
WITH ranked AS (
    SELECT
        s.stop_id, s.stop_name_clean, s.network, s.stop_lat, s.stop_long,
        f.fin_year_start, f.pax_annual,
        ROW_NUMBER() OVER (PARTITION BY s.station_key ORDER BY f.fin_year_start DESC) AS rn
    FROM dw.fact_station_annual f
    JOIN dw.dim_station s ON f.station_key = s.station_key
)
SELECT stop_id, stop_name_clean, network, stop_lat, stop_long, fin_year_start, pax_annual
FROM ranked
WHERE rn = 1;
GO

/* ---- v_daytype_recovery: weekday vs weekend recovery ---- */
CREATE OR ALTER VIEW analytics.v_daytype_recovery AS
SELECT
    d.month_start,
    d.[year],
    m.mode_label,
    m.network,
    dt.day_type,
    AVG(f.pax_daily) AS avg_pax_daily
FROM dw.fact_daytype_monthly f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_mode m ON f.mode_key = m.mode_key
JOIN dw.dim_day_type dt ON f.day_type_key = dt.day_type_key
GROUP BY d.month_start, d.[year], m.mode_label, m.network, dt.day_type;
GO

PRINT '09_analytics_views.sql complete: 4 views created.';
GO