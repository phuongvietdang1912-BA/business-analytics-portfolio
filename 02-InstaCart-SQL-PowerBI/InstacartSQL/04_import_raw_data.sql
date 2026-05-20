/* =========================================================
   File: 04_import_raw_data.sql
   Purpose: Import CSV files into raw tables
   Project: Instacart Business Analytics Project

   CHANGES vs previous version:
     - FIXED: removed hard-coded path to author's machine.
              Replaced with empty default + THROW guard so
              missing-path failures are explicit, not confusing.
     - Added: comment on Kaggle file naming (double underscore).
     - Added: SET NOCOUNT ON.

   Notes:
   - SET @BasePath at the top before running
   - If ROWTERMINATOR = '0x0A' fails, try '0x0D0A'
   - FORMAT = 'CSV' is used because products.csv contains
     commas inside product names
   - Kaggle file order_products__prior.csv uses DOUBLE
     underscore. Verify your local copies match.
   ========================================================= */

SET NOCOUNT ON;
USE InstacartBA;

-- -----------------------------------------------------------------------------
-- CONFIGURATION: SET THIS BEFORE RUNNING
-- Example: N'C:\Data\Instacart\'   (must end with trailing backslash)
-- -----------------------------------------------------------------------------
DECLARE @BasePath NVARCHAR(500) = N'C:\YourPath\InstaCart\';
DECLARE @sql NVARCHAR(MAX);

-- Fail loudly if user forgot to set the path.
IF @BasePath = N'' OR @BasePath IS NULL
BEGIN
    THROW 50000,
        'Set @BasePath at the top of 04_import_raw_data.sql to the directory containing the Instacart CSV files before running. Example: N''C:\Data\Instacart\''',
        1;
END;

/* Optional clean reload */
TRUNCATE TABLE raw.order_products_train;
TRUNCATE TABLE raw.order_products_prior;
TRUNCATE TABLE raw.orders;
TRUNCATE TABLE raw.products;
TRUNCATE TABLE raw.aisles;
TRUNCATE TABLE raw.departments;

/* departments.csv */
SET @sql = N'
BULK INSERT raw.departments
FROM ''' + @BasePath + N'departments.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.departments';

/* aisles.csv */
SET @sql = N'
BULK INSERT raw.aisles
FROM ''' + @BasePath + N'aisles.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.aisles';

/* products.csv */
SET @sql = N'
BULK INSERT raw.products
FROM ''' + @BasePath + N'products.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.products';

/* orders.csv - KEEPNULLS preserves NULL in days_since_prior_order */
SET @sql = N'
BULK INSERT raw.orders
FROM ''' + @BasePath + N'orders.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    KEEPNULLS,
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.orders';

/* order_products__prior.csv  (NOTE: DOUBLE underscore on Kaggle) */
SET @sql = N'
BULK INSERT raw.order_products_prior
FROM ''' + @BasePath + N'order_products__prior.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.order_products_prior';

/* order_products__train.csv  (NOTE: DOUBLE underscore on Kaggle) */
SET @sql = N'
BULK INSERT raw.order_products_train
FROM ''' + @BasePath + N'order_products__train.csv''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    ROWTERMINATOR = ''0x0A'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @sql;
PRINT 'Loaded raw.order_products_train';

PRINT '04_import_raw_data.sql complete: all 6 raw tables loaded.';
GO
