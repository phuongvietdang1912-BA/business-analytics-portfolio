/* =========================================================
   File: 03_load_raw.sql
   Purpose: BULK INSERT cleaned CSVs into raw tables
   Project: Melbourne Public Transport Patronage Warehouse

   Setup: set @BasePath to your data/cleaned/ directory
   (the output of python/clean_sources.py), ending with a
   trailing backslash. A THROW guard fails loudly if unset.
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

DECLARE @BasePath NVARCHAR(500) = N'';   -- e.g. N'C:\Data\MelbourneTransport\cleaned\'
DECLARE @sql NVARCHAR(MAX);

IF @BasePath = N'' OR @BasePath IS NULL
    THROW 50000, 'Set @BasePath to your data/cleaned/ directory before running.', 1;

TRUNCATE TABLE raw.monthly_mode;
TRUNCATE TABLE raw.stations;
TRUNCATE TABLE raw.daytype_mode;
TRUNCATE TABLE raw.mode_dim;

/* clean_monthly_mode.csv */
SET @sql = N'BULK INSERT raw.monthly_mode FROM ''' + @BasePath + N'clean_monthly_mode.csv''
    WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0A'',
          CODEPAGE=''65001'', KEEPNULLS, TABLOCK);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.monthly_mode';

/* clean_stations.csv */
SET @sql = N'BULK INSERT raw.stations FROM ''' + @BasePath + N'clean_stations.csv''
    WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0A'',
          CODEPAGE=''65001'', KEEPNULLS, TABLOCK);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.stations';

/* clean_daytype_mode.csv */
SET @sql = N'BULK INSERT raw.daytype_mode FROM ''' + @BasePath + N'clean_daytype_mode.csv''
    WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0A'',
          CODEPAGE=''65001'', KEEPNULLS, TABLOCK);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.daytype_mode';

/* clean_mode_dim.csv */
SET @sql = N'BULK INSERT raw.mode_dim FROM ''' + @BasePath + N'clean_mode_dim.csv''
    WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0A'',
          CODEPAGE=''65001'', TABLOCK);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.mode_dim';

PRINT '03_load_raw.sql complete.';
GO
