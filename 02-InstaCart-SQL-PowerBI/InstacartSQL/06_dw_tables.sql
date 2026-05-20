/* =========================================================
   File: 06_dw_tables.sql
   Purpose: Create dimensional model tables (star schema)
   Project: Instacart Business Analytics Project

   CHANGES vs previous version:
     - REPLACED: single-column index on reordered (BIT) was
                 low-selectivity and unlikely to be used by
                 the optimiser. Replaced with a covering
                 composite index that supports the common
                 reorder-rate query pattern.
     - Added: design note explaining user_key on the fact
              as a deliberate denormalisation for query speed.
     - Added: clarification on "factless" terminology -
              this is event-grain with derived measures.
     - Added: SET NOCOUNT ON.

   Design notes:
   - Every dim has an IDENTITY surrogate key (xxx_key).
   - Natural keys (xxx_id) are kept on dims as descriptive
     attributes and for joins back to raw, but the FACT
     references dims via SURROGATE keys only.
   - dim_product stores aisle_key and department_key
     (not aisle_id / department_id) - it points UP the
     hierarchy via surrogate keys, same as the fact does.
   - order_id is kept on the fact as a "degenerate dimension"
     so we can count distinct orders without joining dim_order.
   - user_key is on the fact as a DELIBERATE DENORMALISATION
     (derivable via dim_order). Saves one join in every
     user-filtered analytical query - common production pattern.
   - fact_order_item is event-grain (one row per item per order)
     with derived measures - "factless" in strict Kimball terms
     because no stored measures, but basket size, reorder ratio,
     basket position are all derivable through aggregation.
     Instacart's public dataset has no price/quantity, hence
     no stored measures.
   - FK constraints are declared inline. They will be created
     empty (no rows yet), so no validation cost up front.
   ========================================================= */

SET NOCOUNT ON;
USE InstacartBA;
GO

/* -----------------------------
   Drop in reverse-dependency order:
   fact references dims, dim_product references aisle/dept,
   so children must go before parents.
   ----------------------------- */
DROP TABLE IF EXISTS dw.fact_order_item;
DROP TABLE IF EXISTS dw.dim_order;
DROP TABLE IF EXISTS dw.dim_user;
DROP TABLE IF EXISTS dw.dim_product;
DROP TABLE IF EXISTS dw.dim_aisle;
DROP TABLE IF EXISTS dw.dim_department;
GO

/* =========================================================
   dim_department
   - Top of the product hierarchy. References nothing.
   ========================================================= */
CREATE TABLE dw.dim_department (
    department_key  INT IDENTITY(1,1) NOT NULL,
    department_id   INT           NOT NULL,   -- natural key from raw
    department_name NVARCHAR(150) NOT NULL,
    CONSTRAINT PK_dim_department         PRIMARY KEY (department_key),
    CONSTRAINT UQ_dim_department_natural UNIQUE      (department_id)
);
GO

/* =========================================================
   dim_aisle
   - Same shape as dim_department. References nothing.
   ========================================================= */
CREATE TABLE dw.dim_aisle (
    aisle_key   INT IDENTITY(1,1) NOT NULL,
    aisle_id    INT           NOT NULL,
    aisle_name  NVARCHAR(150) NOT NULL,
    CONSTRAINT PK_dim_aisle         PRIMARY KEY (aisle_key),
    CONSTRAINT UQ_dim_aisle_natural UNIQUE      (aisle_id)
);
GO

/* =========================================================
   dim_product
   - References dim_aisle and dim_department via SURROGATE keys.
   - aisle_id / department_id are NOT stored here - they live
     on dim_aisle / dim_department as natural-key attributes.
   ========================================================= */
CREATE TABLE dw.dim_product (
    product_key     INT IDENTITY(1,1) NOT NULL,
    product_id      INT           NOT NULL,        -- natural key
    product_name    NVARCHAR(255) NOT NULL,
    aisle_key       INT           NOT NULL,        -- FK to dim_aisle
    department_key  INT           NOT NULL,        -- FK to dim_department
    CONSTRAINT PK_dim_product           PRIMARY KEY (product_key),
    CONSTRAINT UQ_dim_product_natural   UNIQUE      (product_id),
    CONSTRAINT FK_dim_product_aisle
        FOREIGN KEY (aisle_key)      REFERENCES dw.dim_aisle(aisle_key),
    CONSTRAINT FK_dim_product_department
        FOREIGN KEY (department_key) REFERENCES dw.dim_department(department_key)
);
GO

/* =========================================================
   dim_user
   - Just a user_id wrapper for now. Add demographics later
     if you ever enrich the data.
   ========================================================= */
CREATE TABLE dw.dim_user (
    user_key  INT IDENTITY(1,1) NOT NULL,
    user_id   INT NOT NULL,
    CONSTRAINT PK_dim_user         PRIMARY KEY (user_key),
    CONSTRAINT UQ_dim_user_natural UNIQUE      (user_id)
);
GO

/* =========================================================
   dim_order
   - References dim_user via SURROGATE key.
   - Carries time-of-order attributes (order_dow, order_hour_of_day)
     as a known simplification - strict Kimball would put these
     in a dim_time. Documented as a deliberate trade-off.
   ========================================================= */
CREATE TABLE dw.dim_order (
    order_key              INT IDENTITY(1,1) NOT NULL,
    order_id               INT          NOT NULL,    -- natural key
    user_key               INT          NOT NULL,    -- FK to dim_user
    eval_set               VARCHAR(10)  NOT NULL,
    order_number           INT          NOT NULL,
    order_dow              TINYINT      NOT NULL,
    order_hour_of_day      TINYINT      NOT NULL,
    days_since_prior_order DECIMAL(5,2) NULL,
    CONSTRAINT PK_dim_order         PRIMARY KEY (order_key),
    CONSTRAINT UQ_dim_order_natural UNIQUE      (order_id),
    CONSTRAINT FK_dim_order_user
        FOREIGN KEY (user_key) REFERENCES dw.dim_user(user_key)
);
GO

/* =========================================================
   fact_order_item
   - Grain: one row per product in one order.
   - Surrogate keys to all three dims.
   - order_id retained as a degenerate dimension (lets us
     count distinct orders without joining dim_order).
   - user_key is a deliberate denormalisation (derivable via
     dim_order). Saves one join in every user-filtered query.
   - source_table tracks whether the row came from the
     prior or train CSV - useful for filtering, not modelling.
   ========================================================= */
CREATE TABLE dw.fact_order_item (
    fact_order_item_key BIGINT IDENTITY(1,1) NOT NULL,
    order_key           INT NOT NULL,           -- FK to dim_order
    product_key         INT NOT NULL,           -- FK to dim_product
    user_key            INT NOT NULL,           -- FK to dim_user (denormalised)
    order_id            INT NOT NULL,           -- degenerate dimension
    add_to_cart_order   INT NOT NULL,
    reordered           BIT NOT NULL,
    source_table        VARCHAR(10) NOT NULL,
    CONSTRAINT PK_fact_order_item PRIMARY KEY (fact_order_item_key),
    CONSTRAINT FK_fact_order_item_order
        FOREIGN KEY (order_key)   REFERENCES dw.dim_order(order_key),
    CONSTRAINT FK_fact_order_item_product
        FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    CONSTRAINT FK_fact_order_item_user
        FOREIGN KEY (user_key)    REFERENCES dw.dim_user(user_key)
);
GO

/* =========================================================
   Indexes
   - PK and UNIQUE constraints already create indexes; the
     ones below are for join/filter columns that aren't
     covered by those.
   - Fact gets indexes on every FK column for fast star joins.
   ========================================================= */

/* dim_product - aisle_key and department_key are FKs; index
   them so dim-to-dim joins are fast. */
CREATE INDEX IX_dim_product_aisle_key
    ON dw.dim_product(aisle_key);
GO

CREATE INDEX IX_dim_product_department_key
    ON dw.dim_product(department_key);
GO

/* dim_order - user_key is the FK; everything else is filter columns
   used by the business queries (DOW, hour, eval_set, order_number). */
CREATE INDEX IX_dim_order_user_key
    ON dw.dim_order(user_key);
GO

CREATE INDEX IX_dim_order_eval_set
    ON dw.dim_order(eval_set);
GO

CREATE INDEX IX_dim_order_order_number
    ON dw.dim_order(order_number);
GO

CREATE INDEX IX_dim_order_order_dow
    ON dw.dim_order(order_dow);
GO

CREATE INDEX IX_dim_order_order_hour_of_day
    ON dw.dim_order(order_hour_of_day);
GO

/* fact_order_item - index every FK for star-join performance. */
CREATE INDEX IX_fact_order_item_order_key
    ON dw.fact_order_item(order_key);
GO

CREATE INDEX IX_fact_order_item_product_key
    ON dw.fact_order_item(product_key);
GO

CREATE INDEX IX_fact_order_item_user_key
    ON dw.fact_order_item(user_key);
GO

CREATE INDEX IX_fact_order_item_order_id
    ON dw.fact_order_item(order_id);
GO

/* Covering composite index for reorder analysis (REPLACES old
   single-column BIT index). A standalone index on reordered (BIT)
   has only two distinct values and is rarely used by the optimiser.
   Including order_key and product_key in the index covers the most
   common reorder-rate-by-X queries without a fact-table seek. */
CREATE INDEX IX_fact_order_item_reordered_cover
    ON dw.fact_order_item(reordered)
    INCLUDE (order_key, product_key);
GO

PRINT '06_dw_tables.sql complete: star schema created (5 dims + 1 fact + indexes).';
GO