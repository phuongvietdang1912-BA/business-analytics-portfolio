/* =========================================================
   File: 02_raw_tables.sql
   Purpose: Create raw/staging tables
   Project: Instacart Business Analytics Project
   ========================================================= */

USE InstacartBA;
GO

DROP TABLE IF EXISTS raw.order_products_train;
DROP TABLE IF EXISTS raw.order_products_prior;
DROP TABLE IF EXISTS raw.orders;
DROP TABLE IF EXISTS raw.products;
DROP TABLE IF EXISTS raw.aisles;
DROP TABLE IF EXISTS raw.departments;
GO

CREATE TABLE raw.orders (
    order_id INT NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    eval_set VARCHAR(10) NOT NULL,
    order_number INT NOT NULL,
    order_dow TINYINT NOT NULL,
    order_hour_of_day TINYINT NOT NULL,
    days_since_prior_order DECIMAL(5,2) NULL
);
GO

CREATE TABLE raw.order_products_prior (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    add_to_cart_order INT NOT NULL,
    reordered BIT NOT NULL,
    CONSTRAINT PK_raw_order_products_prior PRIMARY KEY (order_id, product_id)
);

CREATE TABLE raw.order_products_train (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    add_to_cart_order INT NOT NULL,
    reordered BIT NOT NULL
    CONSTRAINT PK_raw_order_products_train PRIMARY KEY (order_id, product_id)
);
GO

CREATE TABLE raw.products (
    product_id INT NOT NULL PRIMARY KEY,
    product_name NVARCHAR(255) NOT NULL,
    aisle_id INT NOT NULL,
    department_id INT NOT NULL
);
GO

CREATE TABLE raw.aisles (
    aisle_id INT NOT NULL PRIMARY KEY,
    aisle NVARCHAR(150) NOT NULL
);
GO

CREATE TABLE raw.departments (
    department_id INT NOT NULL PRIMARY KEY,
    department NVARCHAR(150) NOT NULL
);
GO