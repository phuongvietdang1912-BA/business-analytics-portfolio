/* =========================================================
   File: 08_dw_validation.sql
   Purpose: Validate dimensional model
   Project: Instacart Business Analytics Project

   Notes:
   - This version is aligned with the star schema in file 06.
   - Fact table joins use surrogate keys: order_key, product_key, user_key.
   - Natural-key duplicate checks remain on dimension tables.
   - Spot checks are commented out to keep validation output clean.
   ========================================================= */

USE InstacartBA;
GO

/* =========================================================
   1) Row counts
   Purpose:
   Confirm every DW table has been loaded.
   ========================================================= */
SELECT 'dw.dim_department' AS table_name, COUNT_BIG(*) AS row_count FROM dw.dim_department
UNION ALL
SELECT 'dw.dim_aisle', COUNT_BIG(*) FROM dw.dim_aisle
UNION ALL
SELECT 'dw.dim_product', COUNT_BIG(*) FROM dw.dim_product
UNION ALL
SELECT 'dw.dim_user', COUNT_BIG(*) FROM dw.dim_user
UNION ALL
SELECT 'dw.dim_order', COUNT_BIG(*) FROM dw.dim_order
UNION ALL
SELECT 'dw.fact_order_item', COUNT_BIG(*) FROM dw.fact_order_item;
GO


/* =========================================================
   2) Optional spot checks
   Purpose:
   Useful during development, but commented out for clean
   validation output.

   Uncomment only when you want to manually inspect data.
   ========================================================= */

/*
SELECT TOP 10 * FROM dw.dim_department;
SELECT TOP 10 * FROM dw.dim_aisle;
SELECT TOP 10 * FROM dw.dim_product;
SELECT TOP 10 * FROM dw.dim_user;
SELECT TOP 10 * FROM dw.dim_order;
SELECT TOP 10 * FROM dw.fact_order_item;
GO
*/


/* =========================================================
   3) Dense surrogate key checks
   Purpose:
   Check whether surrogate keys are loaded cleanly from 1 to N.

   Expected:
   min_key = 1
   max_key = row_count
   is_dense = PASS

   Note:
   In real production databases, IDENTITY gaps are not always
   a problem. For this controlled portfolio ETL load, dense keys
   are a useful sanity check.
   ========================================================= */
SELECT
    'dw.dim_department' AS dim_name,
    MIN(department_key) AS min_key,
    MAX(department_key) AS max_key,
    COUNT_BIG(*) AS row_count,
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(department_key) = 1
         AND MAX(department_key) = COUNT_BIG(*)
        THEN 'PASS'
        ELSE 'CHECK'
    END AS dense_key_status
FROM dw.dim_department

UNION ALL

SELECT
    'dw.dim_aisle',
    MIN(aisle_key),
    MAX(aisle_key),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(aisle_key) = 1
         AND MAX(aisle_key) = COUNT_BIG(*)
        THEN 'PASS'
        ELSE 'CHECK'
    END
FROM dw.dim_aisle

UNION ALL

SELECT
    'dw.dim_product',
    MIN(product_key),
    MAX(product_key),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(product_key) = 1
         AND MAX(product_key) = COUNT_BIG(*)
        THEN 'PASS'
        ELSE 'CHECK'
    END
FROM dw.dim_product

UNION ALL

SELECT
    'dw.dim_user',
    MIN(user_key),
    MAX(user_key),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(user_key) = 1
         AND MAX(user_key) = COUNT_BIG(*)
        THEN 'PASS'
        ELSE 'CHECK'
    END
FROM dw.dim_user

UNION ALL

SELECT
    'dw.dim_order',
    MIN(order_key),
    MAX(order_key),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(order_key) = 1
         AND MAX(order_key) = COUNT_BIG(*)
        THEN 'PASS'
        ELSE 'CHECK'
    END
FROM dw.dim_order;
GO


/* =========================================================
   4) Raw vs DW row count comparison
   Purpose:
   Confirm that all raw order-product rows were loaded into
   the fact table.

   Improvement:
   Use variables so the raw unified view is counted once only.
   ========================================================= */
DECLARE @raw_rows BIGINT;
DECLARE @dw_rows BIGINT;

SELECT @raw_rows = COUNT_BIG(*)
FROM raw.v_order_products_all;

SELECT @dw_rows = COUNT_BIG(*)
FROM dw.fact_order_item;

SELECT
    @raw_rows AS raw_unified_rows,
    @dw_rows AS dw_fact_rows,
    @raw_rows - @dw_rows AS row_count_difference;
GO


/* =========================================================
   5) Validation summary
   Purpose:
   Return one clean pass/fail table instead of forcing the user
   to manually inspect many separate result panes.

   Rule:
   issue_count = 0 means PASS.
   issue_count > 0 means CHECK.
   ========================================================= */

DROP TABLE IF EXISTS #dw_validation_results;

CREATE TABLE #dw_validation_results (
    check_name VARCHAR(150) NOT NULL,
    issue_count BIGINT NOT NULL,
    expected_result VARCHAR(100) NOT NULL,
    status AS (
        CASE
            WHEN issue_count = 0 THEN 'PASS'
            ELSE 'CHECK'
        END
    )
);


/* -----------------------------
   5.1 Duplicate natural key checks
   Expected: 0
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Duplicate department_id in dw.dim_department',
    COUNT_BIG(*),
    '0 duplicate natural keys'
FROM (
    SELECT department_id
    FROM dw.dim_department
    GROUP BY department_id
    HAVING COUNT_BIG(*) > 1
) x;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Duplicate aisle_id in dw.dim_aisle',
    COUNT_BIG(*),
    '0 duplicate natural keys'
FROM (
    SELECT aisle_id
    FROM dw.dim_aisle
    GROUP BY aisle_id
    HAVING COUNT_BIG(*) > 1
) x;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Duplicate product_id in dw.dim_product',
    COUNT_BIG(*),
    '0 duplicate natural keys'
FROM (
    SELECT product_id
    FROM dw.dim_product
    GROUP BY product_id
    HAVING COUNT_BIG(*) > 1
) x;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Duplicate user_id in dw.dim_user',
    COUNT_BIG(*),
    '0 duplicate natural keys'
FROM (
    SELECT user_id
    FROM dw.dim_user
    GROUP BY user_id
    HAVING COUNT_BIG(*) > 1
) x;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Duplicate order_id in dw.dim_order',
    COUNT_BIG(*),
    '0 duplicate natural keys'
FROM (
    SELECT order_id
    FROM dw.dim_order
    GROUP BY order_id
    HAVING COUNT_BIG(*) > 1
) x;


/* -----------------------------
   5.2 Surrogate-key null check
   Expected: 0

   This is faster than a LEFT JOIN orphan check because it only
   scans the fact table.
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'NULL surrogate keys in dw.fact_order_item',
    COUNT_BIG(*),
    '0 fact rows with NULL order_key/product_key/user_key'
FROM dw.fact_order_item
WHERE order_key IS NULL
   OR product_key IS NULL
   OR user_key IS NULL;


/* -----------------------------
   5.3 Fact-to-dimension integrity checks
   Expected: 0
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Fact rows missing matching dim_order',
    COUNT_BIG(*),
    '0 orphan fact rows'
FROM dw.fact_order_item f
LEFT JOIN dw.dim_order o
    ON f.order_key = o.order_key
WHERE o.order_key IS NULL;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Fact rows missing matching dim_product',
    COUNT_BIG(*),
    '0 orphan fact rows'
FROM dw.fact_order_item f
LEFT JOIN dw.dim_product p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Fact rows missing matching dim_user',
    COUNT_BIG(*),
    '0 orphan fact rows'
FROM dw.fact_order_item f
LEFT JOIN dw.dim_user u
    ON f.user_key = u.user_key
WHERE u.user_key IS NULL;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Products missing matching dim_aisle',
    COUNT_BIG(*),
    '0 products without valid aisle_key'
FROM dw.dim_product p
LEFT JOIN dw.dim_aisle a
    ON p.aisle_key = a.aisle_key
WHERE a.aisle_key IS NULL;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Products missing matching dim_department',
    COUNT_BIG(*),
    '0 products without valid department_key'
FROM dw.dim_product p
LEFT JOIN dw.dim_department d
    ON p.department_key = d.department_key
WHERE d.department_key IS NULL;


/* -----------------------------
   5.4 DW range checks
   Expected: 0

   days_since_prior_order should be:
   - NULL for first orders
   - 0 to 30 for non-first orders
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Invalid order_dow in dw.dim_order',
    COUNT_BIG(*),
    '0 rows outside 0 to 6'
FROM dw.dim_order
WHERE order_dow NOT BETWEEN 0 AND 6;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Invalid order_hour_of_day in dw.dim_order',
    COUNT_BIG(*),
    '0 rows outside 0 to 23'
FROM dw.dim_order
WHERE order_hour_of_day NOT BETWEEN 0 AND 23;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Invalid days_since_prior_order in dw.dim_order',
    COUNT_BIG(*),
    '0 invalid rows: first orders should be NULL, later orders should be 0 to 30'
FROM dw.dim_order
WHERE
    (
        order_number = 1
        AND days_since_prior_order IS NOT NULL
    )
    OR
    (
        order_number > 1
        AND (
            days_since_prior_order IS NULL
            OR days_since_prior_order < 0
            OR days_since_prior_order > 30
        )
    );


/* -----------------------------
   5.5 Raw-to-DW value consistency check
   Expected: 0

   This confirms days_since_prior_order survived the raw-to-DW
   load correctly.
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Raw-to-DW mismatch: days_since_prior_order',
    COUNT_BIG(*),
    '0 mismatched values between raw.orders and dw.dim_order'
FROM raw.orders r
JOIN dw.dim_order o
    ON r.order_id = o.order_id
WHERE
    (
        r.days_since_prior_order <> o.days_since_prior_order
    )
    OR
    (
        r.days_since_prior_order IS NULL
        AND o.days_since_prior_order IS NOT NULL
    )
    OR
    (
        r.days_since_prior_order IS NOT NULL
        AND o.days_since_prior_order IS NULL
    );


/* -----------------------------
   5.6 Raw unified rows vs DW fact rows
   Expected: 0 difference
   ----------------------------- */

DECLARE @raw_count BIGINT;
DECLARE @fact_count BIGINT;

SELECT @raw_count = COUNT_BIG(*)
FROM raw.v_order_products_all;

SELECT @fact_count = COUNT_BIG(*)
FROM dw.fact_order_item;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Raw unified rows vs DW fact rows',
    ABS(@raw_count - @fact_count),
    '0 row count difference';


/* -----------------------------
   5.7 Dense surrogate key checks
   Expected: 0 issue flags

   issue_count = 1 means the dimension key is not dense.
   ----------------------------- */

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Dense surrogate key check: dw.dim_department',
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(department_key) = 1
         AND MAX(department_key) = COUNT_BIG(*)
        THEN 0 ELSE 1
    END,
    'min_key = 1 and max_key = row_count'
FROM dw.dim_department;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Dense surrogate key check: dw.dim_aisle',
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(aisle_key) = 1
         AND MAX(aisle_key) = COUNT_BIG(*)
        THEN 0 ELSE 1
    END,
    'min_key = 1 and max_key = row_count'
FROM dw.dim_aisle;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Dense surrogate key check: dw.dim_product',
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(product_key) = 1
         AND MAX(product_key) = COUNT_BIG(*)
        THEN 0 ELSE 1
    END,
    'min_key = 1 and max_key = row_count'
FROM dw.dim_product;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Dense surrogate key check: dw.dim_user',
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(user_key) = 1
         AND MAX(user_key) = COUNT_BIG(*)
        THEN 0 ELSE 1
    END,
    'min_key = 1 and max_key = row_count'
FROM dw.dim_user;

INSERT INTO #dw_validation_results (check_name, issue_count, expected_result)
SELECT
    'Dense surrogate key check: dw.dim_order',
    CASE
        WHEN COUNT_BIG(*) > 0
         AND MIN(order_key) = 1
         AND MAX(order_key) = COUNT_BIG(*)
        THEN 0 ELSE 1
    END,
    'min_key = 1 and max_key = row_count'
FROM dw.dim_order;


/* =========================================================
   6) Detailed validation results
   Purpose:
   Show every validation check with PASS/CHECK status.
   ========================================================= */
SELECT
    check_name,
    issue_count,
    expected_result,
    status
FROM #dw_validation_results
ORDER BY
    CASE WHEN status = 'CHECK' THEN 1 ELSE 2 END,
    check_name;


/* =========================================================
   7) Final validation summary
   Purpose:
   One clean summary to quickly confirm whether the DW is safe
   to use for business analysis.
   ========================================================= */
SELECT
    COUNT(*) AS total_checks,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS checks_passed,
    SUM(CASE WHEN status = 'CHECK' THEN 1 ELSE 0 END) AS checks_failed
FROM #dw_validation_results;


/* =========================================================
   Future improvement: fail loudly in deployment pipeline

   Do not enable this yet unless you want the script to stop
   automatically when validation fails.

   IF EXISTS (
       SELECT 1
       FROM #dw_validation_results
       WHERE issue_count > 0
   )
   BEGIN
       THROW 50001, 'DW validation failed. Review #dw_validation_results output.', 1;
   END
   ========================================================= */
GO