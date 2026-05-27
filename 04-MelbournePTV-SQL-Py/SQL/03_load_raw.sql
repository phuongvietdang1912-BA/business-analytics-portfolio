/* =========================================================
   File: 03_load_raw.sql
   Purpose: BULK INSERT cleaned CSVs into raw tables
   Project: Melbourne Public Transport Patronage Warehouse

   This version hard-codes the full file paths directly (no
   variable, no dynamic SQL) so nothing can break on editing.

   If your folder differs, use Find & Replace in SSMS:
     Find:    C:\Users\Admin\Desktop\JRM\Melbourne PTV\data\cleaned\
     Replace: <your cleaned folder, ending with backslash>
   ========================================================= */

SET NOCOUNT ON;
USE MelbourneTransportDW;
GO

TRUNCATE TABLE raw.monthly_mode;
TRUNCATE TABLE raw.stations;
TRUNCATE TABLE raw.daytype_mode;
TRUNCATE TABLE raw.mode_dim;
GO

/* ---- monthly_mode ---- */
BULK INSERT raw.monthly_mode
FROM N'your path for clean_monthly_mode.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0d0a', CODEPAGE = '65001', KEEPNULLS, TABLOCK);
PRINT 'Loaded raw.monthly_mode';
GO

/* ---- stations ---- */
BULK INSERT raw.stations
FROM N'your path for clean_stations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0d0a', CODEPAGE = '65001', KEEPNULLS, TABLOCK);
PRINT 'Loaded raw.stations';
GO

/* ---- daytype_mode ---- */
BULK INSERT raw.daytype_mode
FROM N'your path for clean_daytype_mode.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0d0a', CODEPAGE = '65001', KEEPNULLS, TABLOCK);
PRINT 'Loaded raw.daytype_mode';
GO

/* ---- mode_dim ---- */
BULK INSERT raw.mode_dim
FROM N'your path for clean_mode_dim.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',',
      ROWTERMINATOR = '0x0d0a', CODEPAGE = '65001', TABLOCK);
PRINT 'Loaded raw.mode_dim';
GO

PRINT '03_load_raw.sql complete.';
GO
