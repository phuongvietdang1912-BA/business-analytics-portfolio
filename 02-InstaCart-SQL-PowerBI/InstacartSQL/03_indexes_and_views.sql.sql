/* =========================================================
   File: 03_indexes_and_views.sql
   Purpose: Create raw indexes and unified view
   Project: Instacart Business Analytics Project
   ========================================================= */

USE InstacartBA;
GO


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