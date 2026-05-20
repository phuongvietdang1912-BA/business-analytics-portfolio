/* =========================================================
   File: 07_load_dw.sql
   Purpose: Load dimensions and fact table from raw schema
   Project: Instacart Business Analytics Project

   CHANGES vs previous version:
     - FIXED: PRINT block placement bug. The DECLARE/SELECT/PRINT
              statements were inside the TRY block AFTER the
              COMMIT - if any post-commit SELECT failed, the CATCH
              would try to ROLLBACK an already-committed transaction.
              Moved the entire summary block outside END CATCH.
     - Added: SET NOCOUNT ON.
     - Added: row-count assertion before COMMIT (catches silently
              short loads).
     - Added: pre-flight check that file 06 has been run.

   Design notes:
   - All loads run inside a single transaction. If anything
     fails, the entire DW is rolled back to empty rather than
     left in a half-loaded state.
   - Load ORDER is dictated by FK dependencies:
       department, aisle, user  -> independent, load first
       product                  -> needs aisle + department
       order                    -> needs user
       fact                     -> needs order + product + user
   - TRUNCATE order is the REVERSE of load order: fact first.
   - Dim loads that reference other dims JOIN to those dims
     to translate natural keys (xxx_id) into surrogate keys
     (xxx_key). Core surrogate-key pattern.
   - Fact load uses raw.v_order_products_all (from file 03)
     which includes user_id - no extra join to raw.orders.
   ========================================================= */

SET NOCOUNT ON;
USE InstacartBA;
GO

-- Pre-flight check: ensure file 06 has been run before this one.
IF OBJECT_ID('dw.fact_order_item', 'U') IS NULL
BEGIN
    THROW 50000,
        'dw.fact_order_item does not exist. Run 06_dw_tables.sql before this script.',
        1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Drop FKs so the bulk load isn't slowed by row-by-row validation.
    -- Constraints are recreated WITH CHECK at the end, which validates
    -- the entire loaded dataset in one pass.
    ALTER TABLE dw.fact_order_item DROP CONSTRAINT FK_fact_order_item_order;
    ALTER TABLE dw.fact_order_item DROP CONSTRAINT FK_fact_order_item_product;
    ALTER TABLE dw.fact_order_item DROP CONSTRAINT FK_fact_order_item_user;
    ALTER TABLE dw.dim_product     DROP CONSTRAINT FK_dim_product_aisle;
    ALTER TABLE dw.dim_product     DROP CONSTRAINT FK_dim_product_department;
    ALTER TABLE dw.dim_order       DROP CONSTRAINT FK_dim_order_user;

    /* -----------------------------
       Truncate now that FKs are dropped.
       ----------------------------- */
    TRUNCATE TABLE dw.fact_order_item;
    TRUNCATE TABLE dw.dim_order;
    TRUNCATE TABLE dw.dim_product;
    TRUNCATE TABLE dw.dim_user;
    TRUNCATE TABLE dw.dim_aisle;
    TRUNCATE TABLE dw.dim_department;

    /* =========================================================
       1) dim_department
       ========================================================= */
    INSERT INTO dw.dim_department (department_id, department_name)
    SELECT
        department_id,
        department
    FROM raw.departments;

    /* =========================================================
       2) dim_aisle
       ========================================================= */
    INSERT INTO dw.dim_aisle (aisle_id, aisle_name)
    SELECT
        aisle_id,
        aisle
    FROM raw.aisles;

    /* =========================================================
       3) dim_user
       - DISTINCT because raw.orders has many rows per user.
       ========================================================= */
    INSERT INTO dw.dim_user (user_id)
    SELECT DISTINCT
        user_id
    FROM raw.orders;

    /* =========================================================
       4) dim_product
       - INNER JOIN is intentional: a product pointing at a
         missing aisle/department should fail loudly.
       ========================================================= */
    INSERT INTO dw.dim_product (product_id, product_name, aisle_key, department_key)
    SELECT
        p.product_id,
        p.product_name,
        da.aisle_key,
        dd.department_key
    FROM raw.products p
    JOIN dw.dim_aisle      da ON p.aisle_id      = da.aisle_id
    JOIN dw.dim_department dd ON p.department_id = dd.department_id;

    /* =========================================================
       5) dim_order
       ========================================================= */
    INSERT INTO dw.dim_order (
        order_id,
        user_key,
        eval_set,
        order_number,
        order_dow,
        order_hour_of_day,
        days_since_prior_order
    )
    SELECT
        o.order_id,
        du.user_key,
        o.eval_set,
        o.order_number,
        o.order_dow,
        o.order_hour_of_day,
        o.days_since_prior_order
    FROM raw.orders o
    JOIN dw.dim_user du ON o.user_id = du.user_id;

    /* =========================================================
       6) fact_order_item
       - Most join-heavy query in the project. Expected.
       - 'do_' alias: 'do' is contextually reserved in T-SQL.
       ========================================================= */
    INSERT INTO dw.fact_order_item (
        order_key,
        product_key,
        user_key,
        order_id,
        add_to_cart_order,
        reordered,
        source_table
    )
    SELECT
        do_.order_key,
        dp.product_key,
        du.user_key,
        v.order_id,
        v.add_to_cart_order,
        v.reordered,
        v.source_table
    FROM raw.v_order_products_all v
    JOIN dw.dim_order   do_ ON v.order_id   = do_.order_id
    JOIN dw.dim_product dp  ON v.product_id = dp.product_id
    JOIN dw.dim_user    du  ON v.user_id    = du.user_id;

    /* =========================================================
       Pre-commit assertion: fail loudly if the fact has fewer
       rows than the raw source. Catches silently dropped rows
       from INNER JOINs.
       ========================================================= */
    DECLARE @raw_unified_count BIGINT;
    DECLARE @fact_count        BIGINT;

    SELECT @raw_unified_count = COUNT_BIG(*) FROM raw.v_order_products_all;
    SELECT @fact_count        = COUNT_BIG(*) FROM dw.fact_order_item;

    IF @fact_count < @raw_unified_count
    BEGIN
        THROW 50001,
            'Fact table row count is less than raw source. Load may have silently dropped rows due to missing dim lookups.',
            1;
    END;

    /* =========================================================
       Re-add FKs WITH CHECK (validates existing data, not just
       future inserts).
       ========================================================= */
    ALTER TABLE dw.dim_order
    WITH CHECK ADD CONSTRAINT FK_dim_order_user
    FOREIGN KEY (user_key) REFERENCES dw.dim_user(user_key);

    ALTER TABLE dw.dim_product
    WITH CHECK ADD CONSTRAINT FK_dim_product_aisle
    FOREIGN KEY (aisle_key) REFERENCES dw.dim_aisle(aisle_key);

    ALTER TABLE dw.dim_product
    WITH CHECK ADD CONSTRAINT FK_dim_product_department
    FOREIGN KEY (department_key) REFERENCES dw.dim_department(department_key);

    ALTER TABLE dw.fact_order_item
    WITH CHECK ADD CONSTRAINT FK_fact_order_item_order
    FOREIGN KEY (order_key) REFERENCES dw.dim_order(order_key);

    ALTER TABLE dw.fact_order_item
    WITH CHECK ADD CONSTRAINT FK_fact_order_item_product
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key);

    ALTER TABLE dw.fact_order_item
    WITH CHECK ADD CONSTRAINT FK_fact_order_item_user
    FOREIGN KEY (user_key) REFERENCES dw.dim_user(user_key);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    /* If any statement above failed, roll back the entire
       transaction. The DW is left empty (TRUNCATE was inside
       the transaction too, so even the truncate is undone). */
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    /* Re-throw the original error. Without THROW, the CATCH
       block silently swallows the error and the script
       appears to succeed - exactly the wrong outcome. */
    THROW;
END CATCH;
GO

/* =========================================================
   Post-load summary (OUTSIDE the transaction).
   Moved here from inside the TRY block: if a SELECT COUNT(*)
   fails after COMMIT, we don't want CATCH attempting to
   rollback an already-committed transaction.
   ========================================================= */
DECLARE
    @cnt_dept    INT,
    @cnt_aisle   INT,
    @cnt_user    INT,
    @cnt_product INT,
    @cnt_order   INT,
    @cnt_fact    BIGINT;

SELECT @cnt_dept    = COUNT(*) FROM dw.dim_department;
SELECT @cnt_aisle   = COUNT(*) FROM dw.dim_aisle;
SELECT @cnt_user    = COUNT(*) FROM dw.dim_user;
SELECT @cnt_product = COUNT(*) FROM dw.dim_product;
SELECT @cnt_order   = COUNT(*) FROM dw.dim_order;
SELECT @cnt_fact    = COUNT_BIG(*) FROM dw.fact_order_item;

PRINT '07_load_dw.sql complete.';
PRINT 'dim_department:  ' + CAST(@cnt_dept    AS VARCHAR(20));
PRINT 'dim_aisle:       ' + CAST(@cnt_aisle   AS VARCHAR(20));
PRINT 'dim_user:        ' + CAST(@cnt_user    AS VARCHAR(20));
PRINT 'dim_product:     ' + CAST(@cnt_product AS VARCHAR(20));
PRINT 'dim_order:       ' + CAST(@cnt_order   AS VARCHAR(20));
PRINT 'fact_order_item: ' + CAST(@cnt_fact    AS VARCHAR(20));
GO