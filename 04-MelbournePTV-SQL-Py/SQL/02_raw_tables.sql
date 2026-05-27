/* =========================================================
   File: 02_raw_tables.sql
   Purpose: Create raw landing tables matching the cleaned CSVs
   Project: Melbourne Public Transport Patronage Warehouse

   Note: these tables match the OUTPUT of python/clean_sources.py
   (clean_monthly_mode.csv, clean_stations.csv, clean_daytype_mode.csv,
   clean_mode_dim.csv) - not the original government files. The Python
   layer does the messy parsing; SQL receives clean typed data.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

DROP TABLE IF EXISTS raw.monthly_mode;
DROP TABLE IF EXISTS raw.stations;
DROP TABLE IF EXISTS raw.daytype_mode;
DROP TABLE IF EXISTS raw.mode_dim;
GO

/* Source 1 - monthly patronage by mode (long format after UNPIVOT) */
CREATE TABLE raw.monthly_mode (
    [year]          INT          NOT NULL,
    [month]         INT          NOT NULL,
    mode_canonical  VARCHAR(30)  NOT NULL,
    patronage       BIGINT       NULL
);
GO

/* Sources 2 & 3 - unified station patronage.
   Detail columns are NULL for regional stations (schema mismatch). */
CREATE TABLE raw.stations (
    fin_year             VARCHAR(10)   NOT NULL,
    stop_id              INT           NULL,
    stop_name            NVARCHAR(200) NULL,
    stop_lat             DECIMAL(9,6)  NULL,
    stop_long            DECIMAL(9,6)  NULL,
    network              VARCHAR(10)   NOT NULL,   -- 'metro' | 'regional'
    pax_annual           BIGINT        NULL,
    pax_weekday          BIGINT        NULL,
    pax_norm_weekday     BIGINT        NULL,
    pax_sch_hol_weekday  BIGINT        NULL,
    pax_saturday         BIGINT        NULL,
    pax_sunday           BIGINT        NULL,
    pax_pre_am_peak      BIGINT        NULL,
    pax_am_peak          BIGINT        NULL,
    pax_interpeak        BIGINT        NULL,
    pax_pm_peak          BIGINT        NULL,
    pax_pm_late          BIGINT        NULL,
    stop_name_clean      NVARCHAR(200) NULL,
    stop_name_suffix     NVARCHAR(200) NULL,
    is_border_nsw        VARCHAR(10)   NULL        -- 'True'/'False' from pandas
);
GO

/* Source 4 - monthly avg by day-type by mode (long) */
CREATE TABLE raw.daytype_mode (
    [year]          INT          NOT NULL,
    [month]         INT          NOT NULL,
    day_of_week     VARCHAR(15)  NULL,
    day_type        VARCHAR(40)  NULL,
    mode_canonical  VARCHAR(30)  NOT NULL,
    pax_daily       BIGINT       NULL
);
GO

/* Mode reference dimension (from clean_mode_dim.csv) */
CREATE TABLE raw.mode_dim (
    mode_canonical  VARCHAR(30)  NOT NULL,
    mode_label      VARCHAR(50)  NOT NULL,
    network         VARCHAR(10)  NOT NULL
);
GO

PRINT '02_raw_tables.sql complete: 4 raw tables created.';
GO
