/* =========================================================
   File: 08_validation.sql
   Purpose: Validate the warehouse load
   Project: Melbourne Public Transport Patronage Warehouse

   One pass/fail table. issue_count = 0 means PASS.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

-- Pre-flight
IF (SELECT COUNT_BIG(*) FROM dw.fact_monthly_mode) = 0
    THROW 50000, 'fact_monthly_mode empty. Run 07_load_dw.sql first.', 1;
GO

DROP TABLE IF EXISTS #v;
CREATE TABLE #v (
    check_name VARCHAR(150) NOT NULL,
    issue_count BIGINT NOT NULL,
    expected VARCHAR(100) NOT NULL,
    status AS (CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'CHECK' END)
);

/* Row counts */
INSERT INTO #v
SELECT 'dim_mode row count', 
    CASE WHEN COUNT_BIG(*) = 6 THEN 0 ELSE 1 END,
    '6 modes expected'
FROM dw.dim_mode;

/* Orphan FK: monthly_mode -> dims */
INSERT INTO #v
SELECT 'fact_monthly_mode orphan date_key', COUNT_BIG(*), '0 orphans'
FROM dw.fact_monthly_mode f LEFT JOIN dw.dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

INSERT INTO #v
SELECT 'fact_monthly_mode orphan mode_key', COUNT_BIG(*), '0 orphans'
FROM dw.fact_monthly_mode f LEFT JOIN dw.dim_mode m ON f.mode_key = m.mode_key
WHERE m.mode_key IS NULL;

/* Orphan FK: station_annual -> dim_station */
INSERT INTO #v
SELECT 'fact_station_annual orphan station_key', COUNT_BIG(*), '0 orphans'
FROM dw.fact_station_annual f LEFT JOIN dw.dim_station s ON f.station_key = s.station_key
WHERE s.station_key IS NULL;

/* Orphan FK: daytype_monthly -> dims */
INSERT INTO #v
SELECT 'fact_daytype_monthly orphan date_key', COUNT_BIG(*), '0 orphans'
FROM dw.fact_daytype_monthly f LEFT JOIN dw.dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

/* Negative patronage (data sanity) */
INSERT INTO #v
SELECT 'Negative patronage in fact_monthly_mode', COUNT_BIG(*), '0 negatives'
FROM dw.fact_monthly_mode WHERE patronage < 0;

/* Regional stations correctly have NULL time-band detail */
INSERT INTO #v
SELECT 'Regional stations with unexpected AM-peak detail', COUNT_BIG(*),
       '0 (regional should have NULL detail)'
FROM dw.fact_station_annual f
JOIN dw.dim_station s ON f.station_key = s.station_key
WHERE s.network = 'regional' AND f.pax_am_peak IS NOT NULL;

/* COVID trough sanity: April 2020 metro train should be far below Jan 2018 */
INSERT INTO #v
SELECT 'COVID trough sanity (Apr20 metro train < 50% of Jan18)', 
    CASE WHEN (
        (SELECT TOP 1 f.patronage FROM dw.fact_monthly_mode f
         JOIN dw.dim_date d ON f.date_key=d.date_key
         JOIN dw.dim_mode m ON f.mode_key=m.mode_key
         WHERE d.month_start='2020-04-01' AND m.mode_canonical='metro_train')
        <
        0.5 * (SELECT TOP 1 f.patronage FROM dw.fact_monthly_mode f
         JOIN dw.dim_date d ON f.date_key=d.date_key
         JOIN dw.dim_mode m ON f.mode_key=m.mode_key
         WHERE d.month_start='2018-01-01' AND m.mode_canonical='metro_train')
    ) THEN 0 ELSE 1 END,
    'Apr 2020 should show COVID collapse';

SELECT check_name, issue_count, expected, status
FROM #v
ORDER BY CASE WHEN status='CHECK' THEN 1 ELSE 2 END, check_name;

SELECT COUNT(*) AS total_checks,
       SUM(CASE WHEN status='PASS' THEN 1 ELSE 0 END) AS passed,
       SUM(CASE WHEN status='CHECK' THEN 1 ELSE 0 END) AS failed
FROM #v;
GO
