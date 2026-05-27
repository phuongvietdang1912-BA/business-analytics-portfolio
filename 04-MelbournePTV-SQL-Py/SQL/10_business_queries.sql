/* =========================================================
   File: 10_business_queries.sql
   Purpose: Business analysis queries
   Project: Melbourne Public Transport Patronage Warehouse

   Window-function-heavy by design - distinct from Instacart's
   aggregation-heavy queries. Each query answers a stakeholder
   question about COVID recovery.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

/* =========================================================
    
   Window: RANK patronage ascending within each mode.
   ========================================================= */
WITH ranked AS (
    SELECT mode_label, month_start, patronage,
           RANK() OVER (PARTITION BY mode_label ORDER BY patronage ASC) AS rk
    FROM analytics.v_monthly_mode
    WHERE patronage IS NOT NULL   -- ignore unreported months (NULL sorts as minimum)
)
SELECT mode_label, month_start AS trough_month, patronage AS trough_patronage
FROM ranked WHERE rk = 1
ORDER BY mode_label;
GO

/* =========================================================
   02) Latest recovery level by mode (% of 2018 baseline)
   ========================================================= */
WITH latest AS (
    SELECT mode_label, pct_of_2018_baseline, month_start,
           ROW_NUMBER() OVER (PARTITION BY mode_label ORDER BY month_start DESC) AS rn
    FROM analytics.v_mode_recovery_index
)
SELECT mode_label, month_start AS latest_month, pct_of_2018_baseline
FROM latest WHERE rn = 1
ORDER BY pct_of_2018_baseline DESC;
GO

/* =========================================================
   03) Month-over-month growth by mode
   Window: LAG to get previous month's patronage.
   ========================================================= */
SELECT
    mode_label,
    month_start,
    patronage,
    LAG(patronage) OVER (PARTITION BY mode_label ORDER BY month_start) AS prev_month,
    CAST(100.0 * (patronage - LAG(patronage) OVER (PARTITION BY mode_label ORDER BY month_start))
         / NULLIF(LAG(patronage) OVER (PARTITION BY mode_label ORDER BY month_start), 0)
         AS DECIMAL(6,1)) AS mom_pct_change
FROM analytics.v_monthly_mode
ORDER BY mode_label, month_start;
GO

/* =========================================================
   04) Year-over-year comparison by mode
   Window: LAG 12 months back.
   ========================================================= */
SELECT
    mode_label,
    month_start,
    patronage,
    LAG(patronage, 12) OVER (PARTITION BY mode_label ORDER BY month_start) AS same_month_prev_year,
    CAST(100.0 * (patronage - LAG(patronage,12) OVER (PARTITION BY mode_label ORDER BY month_start))
         / NULLIF(LAG(patronage,12) OVER (PARTITION BY mode_label ORDER BY month_start),0)
         AS DECIMAL(6,1)) AS yoy_pct_change
FROM analytics.v_monthly_mode
ORDER BY mode_label, month_start;
GO

/* =========================================================
   05) 3-month rolling average (smooths seasonality)
   Window: AVG over a moving frame.
   ========================================================= */
SELECT
    mode_label,
    month_start,
    patronage,
    CAST(AVG(patronage) OVER (
        PARTITION BY mode_label ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS BIGINT) AS rolling_3mo_avg
FROM analytics.v_monthly_mode
ORDER BY mode_label, month_start;
GO

/* =========================================================
   06) Recovery ranking: which mode recovered fastest?
   Compares latest recovery % across modes.
   ========================================================= */
WITH latest AS (
    SELECT mode_label, pct_of_2018_baseline,
           ROW_NUMBER() OVER (PARTITION BY mode_label ORDER BY month_start DESC) AS rn
    FROM analytics.v_mode_recovery_index
)
SELECT
    mode_label,
    pct_of_2018_baseline,
    RANK() OVER (ORDER BY pct_of_2018_baseline DESC) AS recovery_rank
FROM latest WHERE rn = 1
ORDER BY recovery_rank;
GO

/* =========================================================
   07) Top 20 busiest metro stations (latest year)
   ========================================================= */
SELECT TOP 20
    stop_name_clean,
    pax_annual,
    RANK() OVER (ORDER BY pax_annual DESC) AS busyness_rank
FROM analytics.v_station_latest
WHERE network = 'metro'
ORDER BY pax_annual DESC;
GO

/* =========================================================
   08) Station recovery: compare earliest vs latest FY
   Window: FIRST_VALUE / LAST_VALUE per station.
   ========================================================= */
WITH station_years AS (
    SELECT
        s.stop_name_clean,
        s.network,
        f.fin_year_start,
        f.pax_annual,
        FIRST_VALUE(f.pax_annual) OVER (
            PARTITION BY s.station_key ORDER BY f.fin_year_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS earliest_pax,
        LAST_VALUE(f.pax_annual) OVER (
            PARTITION BY s.station_key ORDER BY f.fin_year_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_pax
    FROM dw.fact_station_annual f
    JOIN dw.dim_station s ON f.station_key = s.station_key
)
SELECT DISTINCT
    stop_name_clean,
    network,
    earliest_pax,
    latest_pax,
    CAST(100.0 * latest_pax / NULLIF(earliest_pax,0) AS DECIMAL(6,1)) AS pct_of_earliest
FROM station_years
WHERE network = 'metro'
ORDER BY pct_of_earliest DESC;
GO

/* =========================================================
   09) Weekday vs weekend recovery (the WFH signal)
   Compares Normal Weekday vs Weekend recovery trajectory.
   ========================================================= */
SELECT
    mode_label,
    day_type,
    [year],
    AVG(avg_pax_daily) AS avg_daily_pax
FROM analytics.v_daytype_recovery
WHERE day_type IN ('Normal Weekday', 'Weekend')
GROUP BY mode_label, day_type, [year]
ORDER BY mode_label, day_type, [year];
GO

/* =========================================================
   10) Day-of-week recovery detail (is mid-week lagging?)
   Requires the day_of_week grain from Source 4.
   ========================================================= */
SELECT
    m.mode_label,
    dt.day_of_week,
    d.[year],
    AVG(f.pax_daily) AS avg_daily_pax
FROM dw.fact_daytype_monthly f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_mode m ON f.mode_key = m.mode_key
JOIN dw.dim_day_type dt ON f.day_type_key = dt.day_type_key
WHERE dt.day_of_week IS NOT NULL
  AND m.mode_canonical = 'metro_train'
GROUP BY m.mode_label, dt.day_of_week, d.[year]
ORDER BY d.[year],
    CASE dt.day_of_week
        WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6 WHEN 'Sunday' THEN 7 END;
GO

/* =========================================================
   11) Network share over time (metro vs regional)
   Window: share of total within each month.
   ========================================================= */
SELECT
    month_start,
    network,
    SUM(patronage) AS network_patronage,
    CAST(100.0 * SUM(patronage)
         / SUM(SUM(patronage)) OVER (PARTITION BY month_start)
         AS DECIMAL(6,1)) AS pct_of_month_total
FROM analytics.v_monthly_mode
GROUP BY month_start, network
ORDER BY month_start, network;
GO