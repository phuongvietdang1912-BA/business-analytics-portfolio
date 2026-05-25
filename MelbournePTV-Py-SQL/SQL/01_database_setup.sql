/* =========================================================
   File: 01_database_setup.sql
   Purpose: Create database and four-layer schemas
   Project: Melbourne Public Transport Patronage Warehouse
   ========================================================= */

SET NOCOUNT ON;

IF DB_ID('MelbourneTransportDW') IS NULL
BEGIN
    CREATE DATABASE MelbourneTransportDW;
END
GO

USE MelbourneTransportDW;
GO

/* Four-layer design:
     raw       - landing zone, faithful to cleaned CSVs
     cleaned   - conformed (canonical modes, unified grains)
     dw        - Kimball star (conformed dims + 3 facts)
     analytics - recovery-index views for reporting   */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
    EXEC('CREATE SCHEMA raw');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cleaned')
    EXEC('CREATE SCHEMA cleaned');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

PRINT '01_database_setup.sql complete: 4 schemas created.';
GO
