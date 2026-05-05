# Instacart Business Analytics

End-to-end SQL + Power BI portfolio project analysing 3.4M Instacart orders to surface reorder behaviour, basket composition, and cross-sell opportunities for an online grocery retailer.

<img width="1293" height="727" alt="image" src="https://github.com/user-attachments/assets/bc9728fd-ffe2-406b-9ec5-80f8eaf09a7b" />

---

## Problem Statement

An online grocery retailer needs better visibility into customer reorder behaviour, basket composition, and category relationships in order to **improve repeat purchasing**, **support cross-sell opportunities**, and **design more effective product recommendation strategies**.

This project answers that need with a full data pipeline: from raw CSV files through to a star-schema data warehouse, validated business queries, and a four-page Power BI report.

---

## Skills Demonstrated

- **Database design** — star schema with surrogate keys, FK constraints, and dense-key validation
- **SQL (T-SQL)** — bulk imports, transactional ETL, validation harness, 20 business queries
- **Data modelling** — Kimball dimensional modelling (fact + 5 dimensions)
- **Data quality** — automated row-count, duplicate, null, range, orphan, and value-consistency checks
- **Power BI** — DAX measures, calculated columns, multi-page dashboard design
- **Business analysis** — translating raw data into commercial recommendations

---

## Key Findings

| # | Finding | Business implication |
|---|---|---|
| 1 | 59% overall reorder rate; climbs from 0% on order 1 to ~85% by order 5+ | Repeat purchasing is highly predictable once a customer crosses the 5-order threshold |
| 2 | **Produce + dairy eggs** is the #1 co-purchase pair (~1.8M orders) | Strong bundle candidate; produce appears in 6 of the top 10 pairs as the universal anchor category |
| 3 | Avg gap between orders is **11 days**; drops from ~15 to ~5 days as customers mature | Send reorder reminders on a fortnightly cadence; tighter for power users |
| 4 | Sundays/Mondays drive peak volume; 9 AM–5 PM is the active window | Schedule promotions and ad spend around this window |
| 5 | Pantry has high item volume but the lowest reorder rate (~37%) | Volume outlier — investigate whether pricing or selection is driving one-time purchases |

---

## Architecture

```
CSV files ──▶ raw schema ──▶ dw schema (star) ──▶ Power BI
              (staging)      (analytics)
                 │                │
                 ▼                ▼
          validation         validation
          (file 05)          (file 08)
```

Two-layer warehouse:

- **`raw` schema** — direct landing zone for the 6 source CSVs (orders, products, aisles, departments, prior, train). Mirrors the source files 1:1 with no transformation.
- **`dw` schema** — Kimball star schema. Surrogate keys, FK constraints, and a single fact table referencing 5 dimensions.

ETL runs inside a single transaction with full rollback on failure (file `07_load_dw.sql`).

---

## Data Model

<img width="1224" height="764" alt="image" src="https://github.com/user-attachments/assets/ef2725ed-d108-44df-a362-4f1c3ab58b0b" />

| Table | Type | Grain |
|---|---|---|
| `dw.fact_order_item` | Fact (factless / item-presence) | One row per product per order |
| `dw.dim_order` | Dimension | One row per order |
| `dw.dim_user` | Dimension | One row per customer |
| `dw.dim_product` | Dimension | One row per product |
| `dw.dim_aisle` | Dimension | One row per aisle |
| `dw.dim_department` | Dimension | One row per department |

The fact is intentionally factless: Instacart provides no price or quantity data, so `reordered` (BIT) and `add_to_cart_order` (INT) are stored as transactional attributes rather than additive measures. `order_id` is retained as a degenerate dimension.

---

## Dashboard

The Power BI report has four pages, each answering one analytical question.

### 1. Executive Overview
*"How is the business performing?"*

<img width="1295" height="736" alt="image" src="https://github.com/user-attachments/assets/d6169bc1-cdc8-4c9a-a61f-f6393a939780" />


KPIs, reorder behaviour curve, and order-timing patterns at a macro level.

### 2. Product & Category Insight
*"What do customers buy?"*

<img width="1300" height="732" alt="image" src="https://github.com/user-attachments/assets/e48b7ebd-f53b-4617-9d39-c7cbb34aa3fa" />


Department-level volume vs reorder rate, aisle-level loyalty rankings, and a scatter plot identifying the high-volume + high-loyalty sweet spot.

### 3. Customer Behavior
*"Who are the customers?"*

<img width="1294" height="734" alt="image" src="https://github.com/user-attachments/assets/dc286542-a7f7-4403-85cf-22ace25c9f69" />

Customer segmentation by lifetime order count, reorder cadence, and how reorder gaps shrink as customers mature.

### 4. Basket & Recommendations
*"How do they buy together — and what should we do?"*

<img width="1303" height="723" alt="image" src="https://github.com/user-attachments/assets/d9c0f0b1-f2fd-4d0b-9708-9ff187cf46fd" />

Department co-purchase pairs (cross-sell candidates), basket size distribution, and products that consistently appear early in the cart (planned staples).

---

## Project Structure

```
instacart-business-analytics/
├── README.md
├── sql/
│   ├── 01_database_setup.sql        # Database + schemas
│   ├── 02_raw_tables.sql            # Raw/staging tables
│   ├── 03_indexes_and_views.sql     # Raw indexes + unified view
│   ├── 04_import_raw_data.sql       # BULK INSERT from CSVs
│   ├── 05_raw_validation.sql        # Raw layer data quality checks
│   ├── 06_dw_tables.sql             # Star schema DDL
│   ├── 07_load_dw.sql               # Transactional ETL: raw → DW
│   ├── 08_dw_validation.sql         # DW layer validation harness
│   └── 09_business_queries.sql      # 20 business analysis queries
├── powerbi/
│   └── instacart_analytics.pbix
└── images/
    ├── 01_executive_overview.png
    ├── 02_product_category.png
    ├── 03_customer_behavior.png
    ├── 04_basket_recommendations.png
    └── star_schema.png
```

---

## How to Run

### Prerequisites
- SQL Server 2019+ (or Azure SQL)
- SQL Server Management Studio (SSMS) or Azure Data Studio
- Power BI Desktop
- The Instacart Online Grocery Basket Analysis dataset from Kaggle: <https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset>
- The .pbix file is available on request via [LinkedIn / email].

### Setup

1. **Download the dataset** and unzip the 6 CSV files to a local folder.

2. **Update the file path** in `sql/04_import_raw_data.sql`:
   ```sql
   DECLARE @BasePath NVARCHAR(500) = N'C:\YourPath\InstaCart\';
   ```

3. **Run the SQL files in order:**
   ```
   01_database_setup.sql
   02_raw_tables.sql
   03_indexes_and_views.sql
   04_import_raw_data.sql
   05_raw_validation.sql       (verify all checks pass)
   06_dw_tables.sql
   07_load_dw.sql
   08_dw_validation.sql        (verify all checks pass)
   09_business_queries.sql     (optional — runs analysis queries directly)
   ```

4. **Open the Power BI file** (`powerbi/instacart_analytics.pbix`) and update the SQL Server connection to point at your local `InstacartBA` database.

---

## Tech Stack

- **SQL Server** — relational database
- **T-SQL** — DDL, ETL, validation, business queries
- **Power BI Desktop** — dashboard and DAX measures
- **Kimball dimensional modelling** — star schema design

---

## Design Decisions Worth Noting

- **Two-layer warehouse (`raw` + `dw`)** rather than transforming on import. Keeps the source layer auditable and the analytics layer clean.
- **Transactional ETL with rollback** — the load either fully succeeds or leaves the DW empty. No half-loaded states.
- **FK constraints dropped during load, recreated after** — avoids per-row FK validation cost on a multi-million-row insert.
- **Time-of-order attributes on `dim_order`** rather than a separate `dim_time`. Documented as a deliberate simplification trade-off.
- **Factless fact table** — Instacart provides no price/quantity, so the fact stores presence, not measures.
- **Dense surrogate key validation** — sanity check that the IDENTITY load is gap-free (useful for a controlled portfolio load; relaxed in production).

---

## What I'd Do Next

- **Recommendations page** — translate findings into specific business actions (bundle pricing, reminder timing, cross-sell rules)
- **Time dimension** — promote `order_dow` and `order_hour_of_day` into a proper `dim_time`
- **Incremental load pattern** — current ETL is full-refresh; production would need merge / change-tracking
- **dbt or SSIS migration** — current ETL is a single SQL file; a real pipeline would split this into orchestrated steps
- **Predictive layer** — train a reorder-prediction model on the `train` eval set

---

## Author

**\<Phuong Viet Dang (Jackie)\>**
[LinkedIn]((https://www.linkedin.com/in/phuongviet1912/)) · [GitHub](https://github.com/your-handle) · \<phuong.vietdang1912@gmail.com\>

Open to data analyst / data engineer roles.
