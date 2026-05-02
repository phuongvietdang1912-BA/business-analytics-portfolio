/* =========================================================
   File: 04_import_raw_data.sql
   Purpose: Import CSV files into raw tables
   Project: Instacart Business Analytics Project
   Notes:
   - Change @BasePath if your folder is different
   - If ROWTERMINATOR = '0x0A' fails, try '0x0D0A'
   - FORMAT = 'CSV' is used because products.csv can contain commas in names
   ========================================================= */

USE InstacartBA;

DECLARE @BasePath NVARCHAR(500) = N'C:\Users\Admin\Downloads\InstaCart Online Grocery Market Basket Analysis\';
DECLARE @sql NVARCHAR(MAX);

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

/* orders.csv */
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

/* order_products__prior.csv */
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

/* order_products__train.csv */
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
GO