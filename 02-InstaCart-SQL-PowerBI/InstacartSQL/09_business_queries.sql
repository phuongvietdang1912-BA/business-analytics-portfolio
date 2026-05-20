/* =========================================================
   File: 09_business_queries.sql
   Purpose: Core business analysis queries
   Project: Instacart Business Analytics Project

   CHANGES vs previous version:
     - Q02: added eval_set filter to exclude test orders
            (test orders have no items in the fact, so
            including them in "total_orders" was misleading).
     - Q12: added eval_set filter and explanatory comment on
            why both prior and train are kept (customer history).
     - Q18: added lift formula as commented SQL extension.
            Raw co-occurrence overstates cross-sell strength;
            lift is the correct measure. Implementation is
            commented to avoid recomputing for the standard
            output but shown for analytical transparency.
     - Q18: added performance note (self-join is O(N^2)).
     - Q19: added explanatory comment that order_number = 1 is
            excluded by definition (no prior order to measure).
     - Added: SET NOCOUNT ON.

   Notes:
   - This file is aligned with the star schema in file 06.
   - Fact table joins use surrogate keys: order_key, product_key, user_key.
   - Natural keys (product_id, user_id, order_id) are descriptive only.
   - CTEs are used to avoid repeated CASE logic in Q06 and Q13.
   ========================================================= */

SET NOCOUNT ON;
USE InstacartBA;
GO


/* =========================================================
   01) KPI overview
   Purpose:
   Provide high-level performance metrics for the dataset.
   ========================================================= */
SELECT
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.user_key) AS total_users,
    COUNT(DISTINCT f.product_key) AS total_products_purchased,
    COUNT(*) AS total_order_items,
    CAST(
        COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT f.order_id), 0)
        AS DECIMAL(10,2)
    ) AS avg_basket_size,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS overall_reorder_rate
FROM dw.fact_order_item f;
GO


/* =========================================================
   02) Orders by weekday
   Purpose:
   Identify which day of week has the highest order volume.

   Note: filters to prior/train only. Test eval_set has no
   items in the fact table, so including those orders in
   "total_orders" would be misleading.
   ========================================================= */
SELECT
    o.order_dow,
    COUNT(*) AS total_orders
FROM dw.dim_order o
WHERE o.eval_set IN ('prior', 'train')
GROUP BY o.order_dow
ORDER BY o.order_dow;
GO


/* =========================================================
   03) Orders by hour
   Purpose:
   Identify peak ordering hours during the day.
   ========================================================= */
SELECT
    o.order_hour_of_day,
    COUNT(*) AS total_orders
FROM dw.dim_order o
WHERE o.eval_set IN ('prior', 'train')
GROUP BY o.order_hour_of_day
ORDER BY o.order_hour_of_day;
GO


/* =========================================================
   04) Orders by eval_set
   Purpose:
   Understand the split of orders across prior, train, and test.
   This query intentionally includes ALL eval_sets so we can
   see the distribution.
   ========================================================= */
SELECT
    o.eval_set,
    COUNT(*) AS total_orders
FROM dw.dim_order o
GROUP BY o.eval_set
ORDER BY total_orders DESC;
GO


/* =========================================================
   05) Average basket size by weekday
   Purpose:
   Compare how many items customers buy on average by weekday.
   ========================================================= */
SELECT
    o.order_dow,
    CAST(
        COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT f.order_id), 0)
        AS DECIMAL(10,2)
    ) AS avg_basket_size
FROM dw.fact_order_item f
JOIN dw.dim_order o
    ON f.order_key = o.order_key
GROUP BY o.order_dow
ORDER BY o.order_dow;
GO


/* =========================================================
   06) Basket size distribution
   Purpose:
   Show how many orders fall into each basket-size bucket.

   Basket size = number of items/products in one order.

   CTE logic:
   1. basket_size:    Calculates item count per order.
   2. basket_bucket:  Assigns each order to a readable bucket.
   3. Final SELECT:   Aggregates order count by bucket.
   ========================================================= */
WITH basket_size AS (
    SELECT
        f.order_id,
        COUNT(*) AS items_in_order
    FROM dw.fact_order_item f
    GROUP BY f.order_id
),
basket_bucket AS (
    SELECT
        order_id,
        items_in_order,
        CASE
            WHEN items_in_order = 1 THEN '1'
            WHEN items_in_order BETWEEN 2 AND 5 THEN '2-5'
            WHEN items_in_order BETWEEN 6 AND 10 THEN '6-10'
            WHEN items_in_order BETWEEN 11 AND 20 THEN '11-20'
            WHEN items_in_order BETWEEN 21 AND 50 THEN '21-50'
            ELSE '51+'
        END AS basket_size_bucket,
        CASE
            WHEN items_in_order = 1 THEN 1
            WHEN items_in_order BETWEEN 2 AND 5 THEN 2
            WHEN items_in_order BETWEEN 6 AND 10 THEN 3
            WHEN items_in_order BETWEEN 11 AND 20 THEN 4
            WHEN items_in_order BETWEEN 21 AND 50 THEN 5
            ELSE 6
        END AS sort_order
    FROM basket_size
)
SELECT
    basket_size_bucket,
    COUNT(*) AS order_count,
    CAST(
        COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS order_percentage
FROM basket_bucket
GROUP BY basket_size_bucket, sort_order
ORDER BY sort_order;
GO


/* =========================================================
   07) Top departments by item volume
   ========================================================= */
SELECT TOP 20
    d.department_name,
    COUNT(*) AS total_items
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
JOIN dw.dim_department d
    ON p.department_key = d.department_key
GROUP BY d.department_name
ORDER BY total_items DESC;
GO


/* =========================================================
   08) Reorder rate by department
   ========================================================= */
SELECT
    d.department_name,
    COUNT(*) AS total_items,
    SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) AS reordered_items,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS reorder_rate
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
JOIN dw.dim_department d
    ON p.department_key = d.department_key
GROUP BY d.department_name
ORDER BY reorder_rate DESC, total_items DESC;
GO


/* =========================================================
   09) Reorder rate by aisle
   HAVING COUNT(*) >= 1000 avoids misleading rates from small samples.
   ========================================================= */
SELECT TOP 25
    a.aisle_name,
    COUNT(*) AS total_items,
    SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) AS reordered_items,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS reorder_rate
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
JOIN dw.dim_aisle a
    ON p.aisle_key = a.aisle_key
GROUP BY a.aisle_name
HAVING COUNT(*) >= 1000
ORDER BY reorder_rate DESC, total_items DESC;
GO


/* =========================================================
   10) Top products by item volume
   ========================================================= */
SELECT TOP 25
    p.product_name,
    COUNT(*) AS total_items
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_items DESC;
GO


/* =========================================================
   11) Top reordered products
   HAVING COUNT(*) >= 100 avoids over-interpreting small samples.
   ========================================================= */
SELECT TOP 25
    p.product_name,
    COUNT(*) AS total_items,
    SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) AS reordered_items,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS reorder_rate
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate DESC, total_items DESC;
GO


/* =========================================================
   12) Reorder behavior by order number
   Purpose:
   Understand how reorder behavior changes as customers place
   more orders over time. This is the HEADLINE FINDING of the
   project: reorder rate climbs from 0% on order 1 to ~85%
   by order 5, then plateaus (5th-order loyalty inflection).

   Note: filtered to eval_set IN ('prior', 'train'). The prior
   and train labels are different stages of the same customer
   history; including both gives the complete reorder trajectory.
   Test eval_set is excluded because those orders have no items
   in the fact (they're prediction targets, not historical data).

   Note: order_number = 1 always has reorder rate = 0% by
   definition (no prior order to reorder from). This is a
   mathematical certainty, not a model output.
   ========================================================= */
SELECT
    o.order_number,
    COUNT(*) AS total_items,
    SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) AS reordered_items,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS reorder_rate
FROM dw.fact_order_item f
JOIN dw.dim_order o
    ON f.order_key = o.order_key
WHERE o.eval_set IN ('prior', 'train')
GROUP BY o.order_number
ORDER BY o.order_number;
GO


/* =========================================================
   13) User order frequency buckets
   Purpose:
   Segment customers by how many orders they have placed.
   ========================================================= */
WITH user_orders AS (
    SELECT
        o.user_key,
        COUNT(*) AS total_orders
    FROM dw.dim_order o
    GROUP BY o.user_key
),
user_order_bucket AS (
    SELECT
        user_key,
        total_orders,
        CASE
            WHEN total_orders = 1 THEN '1'
            WHEN total_orders BETWEEN 2 AND 5 THEN '2-5'
            WHEN total_orders BETWEEN 6 AND 10 THEN '6-10'
            WHEN total_orders BETWEEN 11 AND 20 THEN '11-20'
            ELSE '21+'
        END AS order_count_bucket,
        CASE
            WHEN total_orders = 1 THEN 1
            WHEN total_orders BETWEEN 2 AND 5 THEN 2
            WHEN total_orders BETWEEN 6 AND 10 THEN 3
            WHEN total_orders BETWEEN 11 AND 20 THEN 4
            ELSE 5
        END AS sort_order
    FROM user_orders
)
SELECT
    order_count_bucket,
    COUNT(*) AS user_count,
    CAST(
        COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS user_percentage
FROM user_order_bucket
GROUP BY order_count_bucket, sort_order
ORDER BY sort_order;
GO


/* =========================================================
   14) Top users by number of orders
   ========================================================= */
SELECT TOP 25
    u.user_id,
    COUNT(*) AS total_orders
FROM dw.dim_order o
JOIN dw.dim_user u
    ON o.user_key = u.user_key
GROUP BY u.user_id
ORDER BY total_orders DESC, u.user_id;
GO


/* =========================================================
   15) Early-cart products
   Lower avg_cart_position = added earlier = likely planned staple.
   ========================================================= */
SELECT TOP 25
    p.product_name,
    COUNT(*) AS total_occurrences,
    CAST(
        AVG(CAST(f.add_to_cart_order AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS avg_cart_position
FROM dw.fact_order_item f
JOIN dw.dim_product p
    ON f.product_key = p.product_key
GROUP BY p.product_name
HAVING COUNT(*) >= 500
ORDER BY avg_cart_position ASC, total_occurrences DESC;
GO


/* =========================================================
   16) Department activity by weekday
   ========================================================= */
SELECT
    d.department_name,
    o.order_dow,
    COUNT(*) AS total_items
FROM dw.fact_order_item f
JOIN dw.dim_order o
    ON f.order_key = o.order_key
JOIN dw.dim_product p
    ON f.product_key = p.product_key
JOIN dw.dim_department d
    ON p.department_key = d.department_key
GROUP BY d.department_name, o.order_dow
ORDER BY d.department_name, o.order_dow;
GO


/* =========================================================
   17) Orders heatmap: weekday x hour
   ========================================================= */
SELECT
    o.order_dow,
    o.order_hour_of_day,
    COUNT(*) AS total_orders
FROM dw.dim_order o
GROUP BY o.order_dow, o.order_hour_of_day
ORDER BY o.order_dow, o.order_hour_of_day;
GO


/* =========================================================
   18) Department pair frequency within the same order
   Purpose:
   Identify department pairs that commonly appear together.

   IMPORTANT INTERPRETATION CAVEAT:
   This query measures RAW CO-OCCURRENCE, not LIFT. Two
   departments appearing together a lot doesn't necessarily
   mean they have a true cross-sell relationship - it may
   just mean they're both popular and bought independently.

   The correct measure for genuine cross-sell strength is LIFT:
     lift(A, B) = P(A AND B) / (P(A) * P(B))
   Pairs with lift > 1 are bought together more than chance
   would predict. Lift normalises by individual popularity,
   so universally bought categories don't dominate.

   See commented "Q18b - LIFT calculation" below for the
   implementation. The standard query (this one) is kept
   for reference, but operational cross-sell decisions
   should use the lift version.

   Performance note: this is a self-join over 3.4M orders.
   The department_key < department_key filter avoids A-B/B-A
   duplicates, but it's still O(orders * departments^2)
   per order. Query may take several minutes to run.
   ========================================================= */
WITH order_department AS (
    SELECT DISTINCT
        f.order_id,
        p.department_key
    FROM dw.fact_order_item f
    JOIN dw.dim_product p
        ON f.product_key = p.product_key
)
SELECT TOP 25
    d1.department_name AS department_1,
    d2.department_name AS department_2,
    COUNT(*) AS pair_order_count
FROM order_department od1
JOIN order_department od2
    ON od1.order_id = od2.order_id
   AND od1.department_key < od2.department_key
JOIN dw.dim_department d1
    ON od1.department_key = d1.department_key
JOIN dw.dim_department d2
    ON od2.department_key = d2.department_key
GROUP BY d1.department_name, d2.department_name
ORDER BY pair_order_count DESC;
GO


/* =========================================================
   Q18b) Department pair LIFT (commented - high cost)
   Lift = P(A AND B) / (P(A) * P(B))
   Pairs with lift > 1 are bought together more than chance.

   Uncomment to compute. Adds 2 extra full-table scans on top
   of the self-join, so expect significantly longer runtime
   than Q18.
   ========================================================= */
/*
WITH order_department AS (
    SELECT DISTINCT
        f.order_id,
        p.department_key
    FROM dw.fact_order_item f
    JOIN dw.dim_product p
        ON f.product_key = p.product_key
),
total_orders AS (
    SELECT CAST(COUNT(DISTINCT order_id) AS DECIMAL(20,6)) AS n
    FROM order_department
),
dept_freq AS (
    SELECT
        department_key,
        CAST(COUNT(*) AS DECIMAL(20,6)) AS dept_order_count
    FROM order_department
    GROUP BY department_key
),
pair_freq AS (
    SELECT
        od1.department_key AS dept1_key,
        od2.department_key AS dept2_key,
        CAST(COUNT(*) AS DECIMAL(20,6)) AS pair_order_count
    FROM order_department od1
    JOIN order_department od2
        ON od1.order_id = od2.order_id
       AND od1.department_key < od2.department_key
    GROUP BY od1.department_key, od2.department_key
)
SELECT TOP 25
    d1.department_name AS department_1,
    d2.department_name AS department_2,
    pf.pair_order_count,
    CAST(
        (pf.pair_order_count / t.n)
        /
        ((df1.dept_order_count / t.n) * (df2.dept_order_count / t.n))
        AS DECIMAL(10,4)
    ) AS lift
FROM pair_freq pf
JOIN dept_freq df1 ON pf.dept1_key = df1.department_key
JOIN dept_freq df2 ON pf.dept2_key = df2.department_key
JOIN dw.dim_department d1 ON pf.dept1_key = d1.department_key
JOIN dw.dim_department d2 ON pf.dept2_key = d2.department_key
CROSS JOIN total_orders t
WHERE pf.pair_order_count >= 1000
ORDER BY lift DESC;
*/


/* =========================================================
   19) Average days since prior order by order number
   Purpose:
   Understand the average time gap between customer orders.

   Note: output starts at order_number = 2.
   order_number = 1 is excluded because days_since_prior_order
   is always NULL for a customer's first order (no prior
   order to measure from).
   ========================================================= */
SELECT
    o.order_number,
    CAST(
        AVG(CAST(o.days_since_prior_order AS DECIMAL(10,2)))
        AS DECIMAL(10,2)
    ) AS avg_days_since_prior_order
FROM dw.dim_order o
WHERE o.days_since_prior_order IS NOT NULL
GROUP BY o.order_number
ORDER BY o.order_number;
GO


/* =========================================================
   20) Reorder rate by weekday and hour
   ========================================================= */
SELECT
    o.order_dow,
    o.order_hour_of_day,
    COUNT(*) AS total_items,
    SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) AS reordered_items,
    CAST(
        SUM(CASE WHEN f.reordered = 1 THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,4)
    ) AS reorder_rate
FROM dw.fact_order_item f
JOIN dw.dim_order o
    ON f.order_key = o.order_key
GROUP BY o.order_dow, o.order_hour_of_day
ORDER BY o.order_dow, o.order_hour_of_day;
GO