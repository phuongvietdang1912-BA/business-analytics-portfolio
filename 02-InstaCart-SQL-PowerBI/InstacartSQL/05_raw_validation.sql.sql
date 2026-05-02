/* =========================================================
   File: 05_raw_validation.sql
   Purpose: Validate raw imports
   Project: Instacart Business Analytics Project
   ========================================================= */

USE InstacartBA;
GO

/* -----------------------------
   Row counts
   ----------------------------- */
SELECT 'raw.departments' AS table_name, COUNT(*) AS row_count FROM raw.departments
UNION ALL
SELECT 'raw.aisles', COUNT(*) FROM raw.aisles
UNION ALL
SELECT 'raw.products', COUNT(*) FROM raw.products
UNION ALL
SELECT 'raw.orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 'raw.order_products_prior', COUNT(*) FROM raw.order_products_prior
UNION ALL
SELECT 'raw.order_products_train', COUNT(*) FROM raw.order_products_train;
GO

/* -----------------------------
   Top rows
   ----------------------------- */
SELECT TOP 10 * FROM raw.departments;
SELECT TOP 10 * FROM raw.aisles;
SELECT TOP 10 * FROM raw.products;
SELECT TOP 10 * FROM raw.orders;
SELECT TOP 10 * FROM raw.order_products_prior;
SELECT TOP 10 * FROM raw.order_products_train;
GO

/* -----------------------------
   Duplicate checks
   ----------------------------- */
SELECT order_id, COUNT(*) AS duplicate_count
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;
GO

SELECT product_id, COUNT(*) AS duplicate_count
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;
GO

SELECT aisle_id, COUNT(*) AS duplicate_count
FROM raw.aisles
GROUP BY aisle_id
HAVING COUNT(*) > 1;
GO

SELECT department_id, COUNT(*) AS duplicate_count
FROM raw.departments
GROUP BY department_id
HAVING COUNT(*) > 1;
GO

/* -----------------------------
   Null checks
   ----------------------------- */
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN eval_set IS NULL THEN 1 ELSE 0 END) AS null_eval_set,
    SUM(CASE WHEN order_number IS NULL THEN 1 ELSE 0 END) AS null_order_number,
    SUM(CASE WHEN order_dow IS NULL THEN 1 ELSE 0 END) AS null_order_dow,
    SUM(CASE WHEN order_hour_of_day IS NULL THEN 1 ELSE 0 END) AS null_order_hour_of_day
FROM raw.orders;
GO

SELECT
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS null_product_name,
    SUM(CASE WHEN aisle_id IS NULL THEN 1 ELSE 0 END) AS null_aisle_id,
    SUM(CASE WHEN department_id IS NULL THEN 1 ELSE 0 END) AS null_department_id
FROM raw.products;
GO

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN add_to_cart_order IS NULL THEN 1 ELSE 0 END) AS null_add_to_cart_order,
    SUM(CASE WHEN reordered IS NULL THEN 1 ELSE 0 END) AS null_reordered
FROM raw.order_products_prior;
GO

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN add_to_cart_order IS NULL THEN 1 ELSE 0 END) AS null_add_to_cart_order,
    SUM(CASE WHEN reordered IS NULL THEN 1 ELSE 0 END) AS null_reordered
FROM raw.order_products_train;
GO

/* -----------------------------
   Range checks
   ----------------------------- */
SELECT *
FROM raw.orders
WHERE order_dow NOT BETWEEN 0 AND 6
   OR order_hour_of_day NOT BETWEEN 0 AND 23;
GO

/* -----------------------------
   Orphan checks
   ----------------------------- */
SELECT COUNT(*) AS prior_rows_with_missing_order
FROM raw.order_products_prior p
LEFT JOIN raw.orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;
GO

SELECT COUNT(*) AS train_rows_with_missing_order
FROM raw.order_products_train t
LEFT JOIN raw.orders o
    ON t.order_id = o.order_id
WHERE o.order_id IS NULL;
GO

SELECT COUNT(*) AS prior_rows_with_missing_product
FROM raw.order_products_prior p
LEFT JOIN raw.products pr
    ON p.product_id = pr.product_id
WHERE pr.product_id IS NULL;
GO

SELECT COUNT(*) AS train_rows_with_missing_product
FROM raw.order_products_train t
LEFT JOIN raw.products pr
    ON t.product_id = pr.product_id
WHERE pr.product_id IS NULL;
GO

SELECT COUNT(*) AS products_with_missing_aisle
FROM raw.products p
LEFT JOIN raw.aisles a
    ON p.aisle_id = a.aisle_id
WHERE a.aisle_id IS NULL;
GO

SELECT COUNT(*) AS products_with_missing_department
FROM raw.products p
LEFT JOIN raw.departments d
    ON p.department_id = d.department_id
WHERE d.department_id IS NULL;
GO

/* -----------------------------
   Eval set distribution
   ----------------------------- */
SELECT
    eval_set,
    COUNT(*) AS order_count
FROM raw.orders
GROUP BY eval_set
ORDER BY order_count DESC;
GO

DROP TABLE IF EXISTS raw.validation_log;
GO

CREATE TABLE raw.validation_log (
    log_id        INT IDENTITY(1,1) PRIMARY KEY,
    run_id        UNIQUEIDENTIFIER NOT NULL,
    check_name    VARCHAR(100)     NOT NULL,
    check_type    VARCHAR(50)      NOT NULL,
    expected      VARCHAR(100)     NULL,
    actual        VARCHAR(100)     NULL,
    passed        BIT              NOT NULL,
    run_at        DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);
GO