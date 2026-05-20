# 🛒 Instacart Business Analytics

> **End-to-end SQL + Power BI portfolio project analysing 3.4M Instacart orders to surface reorder behaviour, basket composition, and cross-sell opportunities for an online grocery retailer.**

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Kimball](https://img.shields.io/badge/Modelling-Kimball-1F77B4?style=flat)
![Status](https://img.shields.io/badge/Status-Completed-success)

<img width="1518" height="850" alt="image" src="https://github.com/user-attachments/assets/4b539d98-7511-4fd6-a008-62a66a1eaa51" />


---

## 📑 Table of Contents
1. [Problem Statement](#1-problem-statement)
2. [Headline Finding](#2-headline-finding)
3. [Skills Demonstrated](#3-skills-demonstrated)
4. [Architecture](#4-architecture)
5. [Data Model](#5-data-model)
6. [Key Findings](#6-key-findings)
7. [Business Recommendations](#7-business-recommendations)
8. [Dashboard](#8-dashboard)
9. [Design Decisions Worth Noting](#9-design-decisions-worth-noting)
10. [Limitations](#10-limitations)
11. [How to Run](#11-how-to-run)
12. [Project Structure](#12-project-structure)
13. [What I'd Do Next](#13-what-id-do-next)
14. [Author](#14-author)

---

## 1. Problem Statement

An online grocery retailer needs better visibility into customer reorder behaviour, basket composition, and category relationships in order to **improve repeat purchasing**, **support cross-sell opportunities**, and **design more effective product recommendation strategies**.

This project answers that need with a full data pipeline: from raw CSV files through to a star-schema data warehouse, validated business queries, and a four-page Power BI report.

---

## 2. Headline Finding

> **A customer's 5th order is the loyalty inflection point - reorder rate climbs from 0% on order 1 to ~85% by order 5, then plateaus.**

This single finding reframes acquisition economics: the cost of getting a new customer to their **5th order** is the cost of converting them into a long-term reorder customer. Everything before order 5 is high-risk; everything after is high-margin and high-retention. Marketing spend, onboarding incentives, and reorder-reminder cadence should all be sized around this threshold.

---

## 3. Skills Demonstrated

- **Database design** - star schema with surrogate keys, FK constraints, and dense-key validation
- **SQL (T-SQL)** - bulk imports, transactional ETL, validation harness, 20 business queries
- **Data modelling** - Kimball dimensional modelling (fact + 5 dimensions)
- **Data quality** - automated row-count, duplicate, null, range, orphan, and value-consistency checks at both raw and DW layers
- **Power BI** - DAX measures, calculated columns, multi-page dashboard design
- **Business analysis** - translating raw data into commercial recommendations

---

## 4. Architecture

```
CSV files ──▶ raw schema ──▶ dw schema (star) ──▶ Power BI
              (staging)      (analytics)
                 │                │
                 ▼                ▼
          validation         validation
          (file 05)          (file 08)
```

**Two-layer warehouse:**

- **`raw` schema** - direct landing zone for the 6 source CSVs (orders, products, aisles, departments, prior, train). Mirrors the source files 1:1 with no transformation.
- **`dw` schema** - Kimball star schema. Surrogate keys, FK constraints, and a single fact table referencing 5 dimensions.

ETL runs inside a single transaction with full rollback on failure (file `07_load_dw.sql`).

### 🛡️ Validation Harness

Every layer is gated by automated checks. The load is not considered complete unless both validation files pass.

| Layer | File | Checks |
|---|---|---|
| Raw | `05_raw_validation.sql` | Row counts vs source CSV, null checks on PKs, duplicate detection, value-range sanity (e.g. `order_hour_of_day` ∈ [0,23]) |
| DW | `08_dw_validation.sql` | Row count parity raw → dw, orphan FK detection, dense surrogate-key check (gap-free IDENTITY load), value-consistency on dim joins |

This validation-first approach is what allows the DW load to run as a single transaction with confident rollback semantics.

---

## 5. Data Model

<img width="1224" height="764" alt="Star schema diagram" src="https://github.com/user-attachments/assets/ef2725ed-d108-44df-a362-4f1c3ab58b0b" />

| Table | Type | Grain |
|---|---|---|
| `dw.fact_order_item` | Fact (event-grain) | One row per product per order |
| `dw.dim_order` | Dimension | One row per order |
| `dw.dim_user` | Dimension | One row per customer |
| `dw.dim_product` | Dimension | One row per product |
| `dw.dim_aisle` | Dimension | One row per aisle |
| `dw.dim_department` | Dimension | One row per department |

The fact is **event-grain** (one row per item-in-order). Instacart provides no price or quantity data, so additive measures are *derived* through aggregation rather than stored - basket size, reorder ratio, basket position, and order frequency all fall out of `COUNT` / `AVG` over the fact. `reordered` (BIT) and `add_to_cart_order` (INT) are the source-level transactional attributes; `order_id` is retained as a degenerate dimension.

> **Note on terminology:** "Reorder rate" in this project = **% of items in a given order that the customer has previously purchased** (the dataset's `reordered` flag, aggregated). This is distinct from customer-level retention or product-level repeat-purchase rate.

---

## 6. Key Findings

| # | Finding | Business implication |
|---|---|---|
| 1 | **Reorder rate climbs from 0% (order 1) → ~85% (order 5+)**; overall blended rate is 59% | Order 5 is the loyalty inflection point - onboarding economics should be sized around getting customers to that threshold |
| 2 | **Produce + dairy eggs** is the most frequent department co-purchase (~1.8M orders); produce appears in 6 of the top 10 pairs | Produce is the universal anchor category. ⚠️ *Frequency alone overstates cross-sell strength - see caveat below* |
| 3 | Average gap between orders is **11 days**, contracting from ~15 to ~5 days as customers mature | Reorder reminder cadence should be **personalised by tenure**, not set globally |
| 4 | Sundays/Mondays drive peak volume; 9 AM–5 PM is the active window | Schedule promotions and ad spend around this window (note: day-of-week mapping is inferred - see Limitations) |
| 5 | Pantry has high item volume but the lowest reorder rate (~37%) | ⚠️ *Likely driven by replenishment cycle (pantry items last months), not weak loyalty - needs lifecycle-adjusted analysis before acting* |

### ⚠️ Caveat on co-purchase rankings

The Top-10 pair list is ranked by **raw co-occurrence**, which favours pairs of universally-popular categories (produce + dairy are bought by *everyone*, so they co-occur whether or not there's a true associative relationship). For a defensible cross-sell strategy, the proper metric is **lift**:

```
lift(A,B) = P(A ∩ B) / ( P(A) × P(B) )
```

Pairs with `lift > 1` indicate a true associative relationship beyond chance. Computing lift across all department pairs is the natural next step (see Roadmap) and would likely re-rank the top pairs significantly - surfacing genuinely complementary categories that raw co-occurrence hides.

---

## 7. Business Recommendations

Five plays derived directly from the findings, sequenced by impact-vs-effort:

| # | Recommendation | Driver Finding | Priority |
|---|---|---|:---:|
| **R1** | Build a "first-5-orders" onboarding journey with progressive incentives at orders 1, 3, and 5 | Finding 1 (loyalty inflection) | 🔴 Highest |
| **R2** | Personalise reorder reminder cadence by customer tenure (~15 days for new customers, ~5 for power users) instead of a single global trigger | Finding 3 (cadence contracts) | 🔴 High |
| **R3** | Compute department-pair **lift** and re-rank cross-sell candidates; prioritise high-lift pairs over high-frequency pairs for bundle pricing | Finding 2 (co-occurrence caveat) | 🟠 Med-High |
| **R4** | Investigate pantry segment with a **replenishment-adjusted** reorder metric before acting on the low rate | Finding 5 (pantry interpretation) | 🟡 Medium |
| **R5** | Concentrate paid promotion spend in the Sun/Mon × 9AM–5PM window | Finding 4 (peak window) | 🟢 Quick win |

> **📐 Note on impact estimation:** Unlike a transactional dataset with revenue, the Instacart sample lacks price and quantity, so financial impact estimates aren't computed here. Recommendations are sized by **strategic priority** and **finding strength**, not dollar projection. With pricing data, R1 (first-5-orders programme) would be the natural candidate for revenue modelling - onboarding-funnel uplift is the most measurable lever.

---

## 8. Dashboard

The Power BI report has four pages, each answering one analytical question.

The report has been published: [InstaCart Report](https://app.powerbi.com/view?r=eyJrIjoiYzA1YzE4N2ItOTc1Yy00ZmMzLThkNjgtMjRkOGIxYzMwNGEzIiwidCI6IjIzMjYxY2E4LTZjMDAtNGRkOS05NGMxLWFmODE1ZDVkMmRmYyJ9)

### 📄 Page 1 - Executive Overview
> *"How is the business performing?"*

<img width="1518" height="850" alt="image" src="https://github.com/user-attachments/assets/307950f9-25d9-465f-8a17-06f8ad2a9f5b" />

KPIs, reorder behaviour curve, and order-timing patterns at a macro level.

### 📄 Page 2 - Product & Category Insight
> *"What do customers buy?"*

<img width="1517" height="848" alt="image" src="https://github.com/user-attachments/assets/ea565663-979f-45f9-a814-67ee41273266" />

Department-level volume vs reorder rate, aisle-level loyalty rankings, and a scatter plot identifying the high-volume + high-loyalty sweet spot.

### 📄 Page 3 - Customer Behaviour
> *"Who are the customers?"*

<img width="1517" height="849" alt="image" src="https://github.com/user-attachments/assets/27d1ea0e-3000-4f9a-8154-58d11a677fbf" />

Customer segmentation by lifetime order count, reorder cadence, and how reorder gaps shrink as customers mature.

### 📄 Page 4 - Basket & Recommendations
> *"How do they buy together - and what should we do?"*

<img width="1518" height="849" alt="image" src="https://github.com/user-attachments/assets/6ce685ba-6c21-497b-8757-7a0f2fda8858" />


Department co-purchase pairs (cross-sell candidates), basket size distribution, and products that consistently appear early in the cart (planned staples).

---

## 9. Design Decisions Worth Noting

- **Two-layer warehouse (`raw` + `dw`)** rather than transforming on import. Keeps the source layer auditable and the analytics layer clean.
- **Transactional ETL with rollback** - the load either fully succeeds or leaves the DW empty. No half-loaded states.
- **FK constraints dropped during load, recreated after** - avoids per-row FK validation cost on a multi-million-row insert.
- **Time-of-order attributes on `dim_order`** rather than a separate `dim_time`. Documented as a deliberate simplification; `dim_time` is on the Roadmap.
- **Event-grain fact, no stored measures** - Instacart provides no price/quantity, so the fact stores presence; measures are derived.
- **Dense surrogate key validation** - sanity check that the IDENTITY load is gap-free (useful for a controlled portfolio load; relaxed in production).

---

## 10. Limitations

A few constraints to keep in mind when interpreting these findings:

- **Sample dataset, not full history.** The Instacart Kaggle release is an anonymised sample (~200K customers), not the full Instacart customer base. Findings are directional, not company-wide truths.
- **No price or quantity data.** All analysis is on item-presence, not basket value. Financial impact (revenue, margin, CLV) cannot be computed from this dataset.
- **No product lifecycle data.** When products were added to or removed from the catalogue isn't captured, so longitudinal product-level analysis is constrained.
- **Day-of-week mapping is inferred.** The dataset uses `order_dow` (0–6) without an official mapping; "Sunday/Monday" peaks follow the most common Kaggle convention but cannot be confirmed against the source.
- **Reorder rate ≠ customer retention.** The reorder metric measures item-level repurchase within an order, not whether customers return at all. Customer-level retention requires a separate cohort analysis.
- **No causal layer.** All findings are descriptive. Whether bundling produce + dairy *causes* incremental basket size, or whether the Sun/Mon peak *causes* higher per-order revenue, would need experimental validation.

---

## 11. How to Run

### Prerequisites
- SQL Server 2019+ (or Azure SQL)
- SQL Server Management Studio (SSMS) or Azure Data Studio
- Power BI Desktop
- The Instacart Online Grocery Basket Analysis dataset from Kaggle: <https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset>
- The `.pbix` file is available on request via LinkedIn or email (see Author).

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
   09_business_queries.sql     (optional - runs analysis queries directly)
   ```

4. **Open the Power BI file** (`powerbi/instacart_analytics.pbix`) and update the SQL Server connection to point at your local `InstacartBA` database.

---

## 12. Project Structure

```
02-InstaCart-SQL-PowerBI/
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

## 13. What I'd Do Next

- [ ] **Compute department-pair lift** in `09_business_queries.sql` and re-rank cross-sell candidates - the highest-impact analytical upgrade available
- [ ] **Replenishment-adjusted reorder metric** - re-evaluate pantry and other low-frequency categories against expected lifecycle, not raw 30-day reorder rate
- [ ] **Customer-level cohort analysis** - measure retention curves by acquisition cohort, not just item-level reorder
- [ ] **Promote `dim_time`** - split `order_dow` and `order_hour_of_day` into a proper time dimension
- [ ] **Incremental load pattern** - current ETL is full-refresh; production would need merge / change-tracking
- [ ] **dbt or SSIS migration** - orchestrated pipeline with dependencies, lineage, and tests
- [ ] **Predictive layer** - train a reorder-prediction model on the `train` eval set

---

## 14. Author

**Phuong Viet Dang (Jackie)**
📧 phuong.vietdang1912@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/phuongviet1912/) · [Portfolio](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio)

Open to **Data Analyst, Business Analyst, and BI Developer** roles.

⭐ *If you found this project useful, give it a star!*
