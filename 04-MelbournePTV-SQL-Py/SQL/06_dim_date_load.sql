/* =========================================================
   File: 06_dim_date_load.sql
   Purpose: Populate the dim_date calendar dimension
   Project: Melbourne Public Transport Patronage Warehouse

   Builds one row per month across the full data range
   (Jan 2018 - Dec 2026) using a recursive CTE. The COVID
   flag marks Apr 2020 - Dec 2021 as the disruption window.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

/* DELETE not TRUNCATE: dim_date is referenced by FK constraints
   from the fact tables, and SQL Server blocks TRUNCATE on any
   FK-referenced table (even when the referencing tables are empty). */
DELETE FROM dw.dim_date;
GO

;WITH months AS (
    SELECT CAST('2018-01-01' AS DATE) AS month_start
    UNION ALL
    SELECT DATEADD(MONTH, 1, month_start)
    FROM months
    WHERE month_start < '2026-12-01'
)
INSERT INTO dw.dim_date (month_start, [year], [month], month_name, quarter, is_covid_period)
SELECT
    month_start,
    YEAR(month_start),
    MONTH(month_start),
    DATENAME(MONTH, month_start),
    DATEPART(QUARTER, month_start),
    CASE WHEN month_start BETWEEN '2020-04-01' AND '2021-12-01' THEN 1 ELSE 0 END
FROM months
OPTION (MAXRECURSION 200);
GO

PRINT '06_dim_date_load.sql complete: dim_date populated.';
SELECT COUNT(*) AS dim_date_rows FROM dw.dim_date;
GO