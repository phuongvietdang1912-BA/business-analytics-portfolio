/* =========================================================
   File: 01_database_setup.sql
   Purpose: Create database and schemas
   Project: Instacart Business Analytics Project
   ========================================================= */

IF DB_ID('InstacartBA') IS NULL
BEGIN
    CREATE DATABASE InstacartBA;
END
GO

USE InstacartBA;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
BEGIN
    EXEC('CREATE SCHEMA raw');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
BEGIN
    EXEC('CREATE SCHEMA dw');
END
GO