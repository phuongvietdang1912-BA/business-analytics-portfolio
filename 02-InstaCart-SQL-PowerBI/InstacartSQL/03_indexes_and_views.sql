/* =========================================================
   File: 03_indexes_and_views.sql
   Purpose: Create raw indexes and unified view
   Project: Instacart Business Analytics Project

   CHANGES vs previous version:
     - Added: product_id indexes on both order_products tables.
              The fact load in file 07 joins on product_id; without
              these indexes the join scans 32M+ rows.
     - Added: SET NOCOUNT ON.
   ========================================================= */

SET NOCOUNT ON;
USE InstacartBA;
GO


/* -----------------------------
   Indexes on order_id (existing)
   ----------------------------- */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_raw_order_products_prior_order_id'
      AND object_id = OBJECT_ID('raw.order_products_prior')
)
CREATE INDEX IX_raw_order_products_prior_order_id
ON raw.order_products_prior(order_id);
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_raw_order_products_train_order_id'
      AND object_id = OBJECT_ID('raw.order_products_train')
)
CREATE INDEX IX_raw_order_products_train_order_id
ON raw.order_products_train(order_id);
GO


/* -----------------------------
   Indexes on product_id (NEW)
   Speeds up the dim_product join during ETL on 32M+ rows.
   ----------------------------- */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_raw_order_products_prior_product_id'
      AND object_id = OBJECT_ID('raw.order_products_prior')
)
CREATE INDEX IX_raw_order_products_prior_product_id
ON raw.order_products_prior(product_id);
GO


IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_raw_order_products_train_product_id'
      AND object_id = OBJECT_ID('raw.order_products_train')
)
CREATE INDEX IX_raw_order_products_train_product_id
ON raw.order_products_train(product_id);
GO


/* -----------------------------
   Unified view across prior + train.
   user_id is joined in from raw.orders so the fact load in
   file 07 doesn't need a separate join back to raw.orders.
   source_table flag enables lineage tracing.
   ----------------------------- */
CREATE OR ALTER VIEW raw.v_order_products_all
AS
SELECT
    op.order_id,
    op.product_id,
    o.user_id,
    op.add_to_cart_order,
    op.reordered,
    'prior' AS source_table
FROM raw.order_products_prior op
JOIN raw.orders o ON op.order_id = o.order_id

UNION ALL

SELECT
    op.order_id,
    op.product_id,
    o.user_id,
    op.add_to_cart_order,
    op.reordered,
    'train' AS source_table
FROM raw.order_products_train op
JOIN raw.orders o ON op.order_id = o.order_id;
GO

PRINT '03_indexes_and_views.sql complete: 4 raw indexes + 1 unified view.';
GO