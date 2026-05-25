/* =========================================================
   File: 07_load_dw.sql
   Purpose: Load dimensions and facts from the cleaned schema
   Project: Melbourne Public Transport Patronage Warehouse

   - Single transaction with rollback on failure.
   - Load order respects FK dependencies:
       dim_mode, dim_station, dim_day_type (independent)
       dim_date already loaded in file 06
       facts last (depend on dims)
   - Surrogate-key translation via JOINs to the dims.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

-- Pre-flight: dim_date must already be loaded (file 06)
IF (SELECT COUNT(*) FROM dw.dim_date) = 0
    THROW 50000, 'dim_date is empty. Run 06_dim_date_load.sql before this script.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Clear facts first (FK order), then dims (except dim_date) */
    DELETE FROM dw.fact_daytype_monthly;
    DELETE FROM dw.fact_station_annual;
    DELETE FROM dw.fact_monthly_mode;
    DELETE FROM dw.dim_day_type;
    DELETE FROM dw.dim_station;
    DELETE FROM dw.dim_mode;

    /* ---- dim_mode (from raw.mode_dim reference) ---- */
    INSERT INTO dw.dim_mode (mode_canonical, mode_label, network)
    SELECT mode_canonical, mode_label, network
    FROM raw.mode_dim;

    /* ---- dim_station (distinct stations across all years) ----
       A station can appear in multiple FY files; take its most
       recent attributes via ROW_NUMBER. */
    ;WITH ranked AS (
        SELECT
            stop_id, stop_name_clean, network, stop_lat, stop_long, is_border_nsw,
            ROW_NUMBER() OVER (
                PARTITION BY stop_id, network
                ORDER BY fin_year_start DESC
            ) AS rn
        FROM cleaned.stations
        WHERE stop_id IS NOT NULL
    )
    INSERT INTO dw.dim_station (stop_id, stop_name_clean, network, stop_lat, stop_long, is_border_nsw)
    SELECT stop_id, stop_name_clean, network, stop_lat, stop_long, is_border_nsw
    FROM ranked
    WHERE rn = 1;

    /* ---- dim_day_type (distinct combos) ---- */
    INSERT INTO dw.dim_day_type (day_of_week, day_type)
    SELECT DISTINCT day_of_week, day_type
    FROM cleaned.daytype_mode;

    /* ---- Fact 1: monthly mode ---- */
    INSERT INTO dw.fact_monthly_mode (date_key, mode_key, patronage)
    SELECT d.date_key, m.mode_key, c.patronage
    FROM cleaned.monthly_mode c
    JOIN dw.dim_date d ON c.month_start = d.month_start
    JOIN dw.dim_mode m ON c.mode_canonical = m.mode_canonical;

    /* ---- Fact 2: station annual ---- */
    INSERT INTO dw.fact_station_annual (
        station_key, fin_year_start, pax_annual, pax_weekday, pax_norm_weekday,
        pax_sch_hol_weekday, pax_saturday, pax_sunday, pax_pre_am_peak,
        pax_am_peak, pax_interpeak, pax_pm_peak, pax_pm_late
    )
    SELECT
        s.station_key, c.fin_year_start, c.pax_annual, c.pax_weekday, c.pax_norm_weekday,
        c.pax_sch_hol_weekday, c.pax_saturday, c.pax_sunday, c.pax_pre_am_peak,
        c.pax_am_peak, c.pax_interpeak, c.pax_pm_peak, c.pax_pm_late
    FROM cleaned.stations c
    JOIN dw.dim_station s ON c.stop_id = s.stop_id AND c.network = s.network
    WHERE c.stop_id IS NOT NULL;

    /* ---- Fact 3: day-type monthly ---- */
    INSERT INTO dw.fact_daytype_monthly (date_key, mode_key, day_type_key, pax_daily)
    SELECT d.date_key, m.mode_key, dt.day_type_key, c.pax_daily
    FROM cleaned.daytype_mode c
    JOIN dw.dim_date d ON c.month_start = d.month_start
    JOIN dw.dim_mode m ON c.mode_canonical = m.mode_canonical
    JOIN dw.dim_day_type dt
        ON ISNULL(c.day_of_week,'') = ISNULL(dt.day_of_week,'')
       AND ISNULL(c.day_type,'')    = ISNULL(dt.day_type,'');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* Post-load summary (outside transaction) */
DECLARE @mode INT, @station INT, @dt INT, @f1 BIGINT, @f2 BIGINT, @f3 BIGINT;
SELECT @mode = COUNT(*) FROM dw.dim_mode;
SELECT @station = COUNT(*) FROM dw.dim_station;
SELECT @dt = COUNT(*) FROM dw.dim_day_type;
SELECT @f1 = COUNT_BIG(*) FROM dw.fact_monthly_mode;
SELECT @f2 = COUNT_BIG(*) FROM dw.fact_station_annual;
SELECT @f3 = COUNT_BIG(*) FROM dw.fact_daytype_monthly;

PRINT '07_load_dw.sql complete.';
PRINT 'dim_mode:             ' + CAST(@mode AS VARCHAR(20));
PRINT 'dim_station:          ' + CAST(@station AS VARCHAR(20));
PRINT 'dim_day_type:         ' + CAST(@dt AS VARCHAR(20));
PRINT 'fact_monthly_mode:    ' + CAST(@f1 AS VARCHAR(20));
PRINT 'fact_station_annual:  ' + CAST(@f2 AS VARCHAR(20));
PRINT 'fact_daytype_monthly: ' + CAST(@f3 AS VARCHAR(20));
GO
