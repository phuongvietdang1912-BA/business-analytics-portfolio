/* =========================================================
   File: 05_dw_tables.sql
   Purpose: Create Kimball star schema (conformed dims + 3 facts)
   Project: Melbourne Public Transport Patronage Warehouse

   Design: conformed dimensions (dim_date, dim_mode) are SHARED
   across multiple fact tables - the core Kimball multi-source
   integration pattern. Three facts because the three sources
   have genuinely different grains.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

DROP TABLE IF EXISTS dw.fact_daytype_monthly;
DROP TABLE IF EXISTS dw.fact_station_annual;
DROP TABLE IF EXISTS dw.fact_monthly_mode;
DROP TABLE IF EXISTS dw.dim_day_type;
DROP TABLE IF EXISTS dw.dim_station;
DROP TABLE IF EXISTS dw.dim_mode;
DROP TABLE IF EXISTS dw.dim_date;
GO

/* ---- Conformed dimension: date (monthly grain) ---- */
CREATE TABLE dw.dim_date (
    date_key      INT IDENTITY(1,1) NOT NULL,
    month_start   DATE        NOT NULL,
    [year]        INT         NOT NULL,
    [month]       INT         NOT NULL,
    month_name    VARCHAR(15) NOT NULL,
    quarter       INT         NOT NULL,
    is_covid_period BIT       NOT NULL,   -- Apr 2020 - Dec 2021 flag
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key),
    CONSTRAINT UQ_dim_date UNIQUE (month_start)
);
GO

/* ---- Conformed dimension: mode ---- */
CREATE TABLE dw.dim_mode (
    mode_key       INT IDENTITY(1,1) NOT NULL,
    mode_canonical VARCHAR(30) NOT NULL,
    mode_label     VARCHAR(50) NOT NULL,
    network        VARCHAR(10) NOT NULL,
    CONSTRAINT PK_dim_mode PRIMARY KEY (mode_key),
    CONSTRAINT UQ_dim_mode UNIQUE (mode_canonical)
);
GO

/* ---- Dimension: station ---- */
CREATE TABLE dw.dim_station (
    station_key      INT IDENTITY(1,1) NOT NULL,
    stop_id          INT           NULL,
    stop_name_clean  NVARCHAR(200) NULL,
    network          VARCHAR(10)   NOT NULL,
    stop_lat         DECIMAL(9,6)  NULL,
    stop_long        DECIMAL(9,6)  NULL,
    is_border_nsw    BIT           NOT NULL,
    CONSTRAINT PK_dim_station PRIMARY KEY (station_key),
    CONSTRAINT UQ_dim_station UNIQUE (stop_id, network)
);
GO

/* ---- Dimension: day type ---- */
CREATE TABLE dw.dim_day_type (
    day_type_key  INT IDENTITY(1,1) NOT NULL,
    day_of_week   VARCHAR(15) NULL,
    day_type      VARCHAR(40) NULL,
    CONSTRAINT PK_dim_day_type PRIMARY KEY (day_type_key)
);
GO

/* ---- Fact 1: monthly patronage by mode (Source 1) ---- */
CREATE TABLE dw.fact_monthly_mode (
    fact_key   BIGINT IDENTITY(1,1) NOT NULL,
    date_key   INT    NOT NULL,
    mode_key   INT    NOT NULL,
    patronage  BIGINT NULL,
    CONSTRAINT PK_fact_monthly_mode PRIMARY KEY (fact_key),
    CONSTRAINT FK_fmm_date FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
    CONSTRAINT FK_fmm_mode FOREIGN KEY (mode_key) REFERENCES dw.dim_mode(mode_key)
);
GO

/* ---- Fact 2: annual station patronage (Sources 2 & 3) ----
   Detail measures (weekday/time-band) are NULL for regional. */
CREATE TABLE dw.fact_station_annual (
    fact_key            BIGINT IDENTITY(1,1) NOT NULL,
    station_key         INT NOT NULL,
    fin_year_start      INT NOT NULL,
    pax_annual          BIGINT NULL,
    pax_weekday         BIGINT NULL,
    pax_norm_weekday    BIGINT NULL,
    pax_sch_hol_weekday BIGINT NULL,
    pax_saturday        BIGINT NULL,
    pax_sunday          BIGINT NULL,
    pax_pre_am_peak     BIGINT NULL,
    pax_am_peak         BIGINT NULL,
    pax_interpeak       BIGINT NULL,
    pax_pm_peak         BIGINT NULL,
    pax_pm_late         BIGINT NULL,
    CONSTRAINT PK_fact_station_annual PRIMARY KEY (fact_key),
    CONSTRAINT FK_fsa_station FOREIGN KEY (station_key) REFERENCES dw.dim_station(station_key)
);
GO

/* ---- Fact 3: monthly avg by day-type by mode (Source 4) ---- */
CREATE TABLE dw.fact_daytype_monthly (
    fact_key      BIGINT IDENTITY(1,1) NOT NULL,
    date_key      INT NOT NULL,
    mode_key      INT NOT NULL,
    day_type_key  INT NOT NULL,
    pax_daily     BIGINT NULL,
    CONSTRAINT PK_fact_daytype_monthly PRIMARY KEY (fact_key),
    CONSTRAINT FK_fdm_date FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
    CONSTRAINT FK_fdm_mode FOREIGN KEY (mode_key) REFERENCES dw.dim_mode(mode_key),
    CONSTRAINT FK_fdm_daytype FOREIGN KEY (day_type_key) REFERENCES dw.dim_day_type(day_type_key)
);
GO

PRINT '05_dw_tables.sql complete: 4 dims + 3 facts created.';
GO
