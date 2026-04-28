# 📉 Telco Customer Churn Analysis

> **A Power BI portfolio project diagnosing $1.67M of annual revenue at risk and building a data-driven retention roadmap.**

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![DAX](https://img.shields.io/badge/DAX-1F77B4?style=flat)
![SQL](https://img.shields.io/badge/SQL-336791?style=flat&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success)

---

## 📑 Table of Contents
1. [Business Problem](#1-business-problem)
2. [Dataset Overview](#2-dataset-overview)
3. [Data Cleaning & Modelling](#3-data-cleaning--modelling)
4. [Key Metrics / KPIs](#4-key-metrics--kpis)
5. [Dashboard / Analysis](#5-dashboard--analysis)
6. [Key Insights](#6-key-insights)
7. [Business Recommendations](#7-business-recommendations)
8. [Tools Used](#8-tools-used)
9. [Links](#9-links)

---

## 1. Business Problem

A telecom provider is losing **roughly 1 in 4 customers (26.54%)** — well above typical industry churn benchmarks of 15–25%. With **$139.13K in monthly recurring revenue at risk (~$1.67M annualised)**, leadership lacks a clear, segment-level view of:

- 🔍 **Where** churn is concentrated (which customer profiles are leaving?)
- 💰 **How much** each segment is costing the business
- 🎯 **Which interventions** would most efficiently slow the loss

**Project goal:** Build a Power BI report that diagnoses the drivers of churn, quantifies revenue at risk by segment, and translates findings into prioritised retention recommendations.

---

## 2. Dataset Overview

**Source:** [IBM Telco Customer Churn Dataset](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) — a widely-used public benchmark dataset.

| Attribute | Value |
|---|---|
| **Rows** | 7,043 customers |
| **Columns** | 21 attributes |
| **Target Variable** | `Churn` (Yes / No) |
| **Time Frame** | Snapshot (point-in-time) |

### Field Groups

| Group | Fields |
|---|---|
| **Demographics** | `gender`, `SeniorCitizen`, `Partner`, `Dependents` |
| **Account** | `tenure`, `Contract`, `PaperlessBilling`, `PaymentMethod`, `MonthlyCharges`, `TotalCharges` |
| **Services** | `PhoneService`, `MultipleLines`, `InternetService`, `OnlineSecurity`, `OnlineBackup`, `DeviceProtection`, `TechSupport`, `StreamingTV`, `StreamingMovies` |
| **Target** | `Churn` |

---

## 3. Data Cleaning & Modelling

### 🧹 Cleaning Steps

| Issue | Resolution |
|---|---|
| `TotalCharges` stored as text with 11 blank rows (new customers, tenure = 0) | Converted to numeric; blanks set to `0` |
| `SeniorCitizen` stored as `0/1` integers | Converted to `Yes`/`No` label for readability |
| Continuous `tenure` field hard to segment visually | Bucketed into 6 tenure bands |
| Continuous `MonthlyCharges` field hard to segment visually | Bucketed into 4 charge bands |
| No combined risk identifier | Created `Risk Segment Short` (Tenure × Contract × Internet Service) |

### 🏗️ Calculated Columns (Power Query / DAX)

```dax
-- Tenure Band
Tenure Band =
SWITCH(
    TRUE(),
    Telco[tenure] <= 6,  "0-6 months",
    Telco[tenure] <= 12, "7-12 months",
    Telco[tenure] <= 24, "13-24 months",
    Telco[tenure] <= 48, "25-48 months",
    Telco[tenure] <= 60, "49-60 months",
    "60+ months"
)

-- Monthly Charge Band
Monthly Charge Band =
SWITCH(
    TRUE(),
    Telco[MonthlyCharges] < 30, "<$30",
    Telco[MonthlyCharges] < 60, "$30-$59",
    Telco[MonthlyCharges] < 90, "$60-$89",
    "$90+"
)

-- Risk Segment Short (composite key)
Risk Segment Short =
Telco[Tenure Band] & " | " &
IF(Telco[Contract] = "Month-to-month", "MTM", Telco[Contract]) & " | " &
Telco[InternetService]
```

### 📐 Data Model
Single fact table model — no star schema needed for a snapshot dataset of this size. Sort-by columns applied to `Tenure Band` and `Monthly Charge Band` for natural ordering on visuals.

---

## 4. Key Metrics / KPIs

Eight core DAX measures power the entire report:

```dax
Total Customers       = COUNTROWS( Telco )

Churned Customers     = CALCULATE( [Total Customers], Telco[Churn] = "Yes" )

Active Customers      = CALCULATE( [Total Customers], Telco[Churn] = "No" )

Churn Rate %          = DIVIDE( [Churned Customers], [Total Customers] )

Monthly Recurring Revenue =
    CALCULATE( SUM( Telco[MonthlyCharges] ), Telco[Churn] = "No" )

Revenue at Risk (p/m) =
    CALCULATE( SUM( Telco[MonthlyCharges] ), Telco[Churn] = "Yes" )

Avg Monthly Charge of Churned =
    CALCULATE( AVERAGE( Telco[MonthlyCharges] ), Telco[Churn] = "Yes" )

Churn Rate by Segment =
    DIVIDE(
        CALCULATE( [Churned Customers], ALLSELECTED( Telco ) ),
        CALCULATE( [Total Customers],   ALLSELECTED( Telco ) )
    )
```

### 📊 Headline Numbers

| KPI | Value |
|---|---|
| Total Customers | **7,043** |
| Churned Customers | **1,869** |
| Churn Rate | **26.54%** |
| Monthly Recurring Revenue | **$456.12K** |
| Revenue at Risk (p/m) | **$139.13K** |
| Annualised Revenue at Risk | **~$1.67M** |

---

## 5. Dashboard / Analysis

The Power BI report is structured as a **three-page narrative**, with four global slicers (Contract, Internet Service, Payment Method, Tenure Band) synchronised across all pages.

### 📄 Page 1 — Executive Overview
> **Audience:** Leadership · **Question answered:** *Where do we stand and where is the bleeding worst?*

![Executive Overview](images/01_executive_overview.png)

### 📄 Page 2 — Customer Segmentation Deep Dive
> **Audience:** Marketing & CX · **Question answered:** *Who is leaving and why?*

![Customer Segmentation](images/02_customer_segmentation.png)

### 📄 Page 3 — Churn Drivers & Revenue Risk
> **Audience:** Product & Finance · **Question answered:** *Where is the financial exposure concentrated?*

![Churn Drivers & Revenue Risk](images/03_churn_drivers_revenue_risk.png)

---

## 6. Key Insights

### 🔎 1. Tenure is the strongest single predictor of churn
Customers in their first 6 months churn at **52.94%** — nearly **8× the rate** of customers past 5 years (6.61%). The relationship is monotonic — every extra tenure bracket reduces churn.

| Tenure Band | Churn Rate | Revenue at Risk |
|---|---:|---:|
| 0–6 months | **52.94%** 🔴 | $50K |
| 7–12 months | 35.89% | $19K |
| 13–24 months | 28.71% | $23K |
| 25–48 months | 20.39% | $27K |
| 49–60 months | 14.42% | $11K |
| 60+ months | **6.61%** 🟢 | $9K |

### 🔎 2. Contract type compounds the risk
Month-to-month customers churn at **42.71%** — roughly **15×** the rate of two-year contracts (2.83%).

### 🔎 3. Payment friction is a hidden killer
Electronic check users churn at **45.29%** — nearly **3×** the autopay rate. Each billing cycle is effectively a re-purchase decision.

### 🔎 4. Fiber optic churns *more* than DSL — counterintuitive but explainable
Fiber optic = **41.89%** churn vs DSL = **18.96%**. Drilling deeper resolves it: fiber customers without online security churn at **49.36%** vs **21.81%** with it. The product is sold without the supporting service bundle.

### 🔎 5. Demographic vulnerability cohorts
| Group | Churn |
|---|---:|
| Senior citizens | 41.68% (vs 23.61%) |
| No partner | 32.96% (vs 19.66%) |
| No dependents | 31.28% (vs 15.45%) |

### 🔎 6. Risk is highly concentrated — the case for surgical retention
**Top 5 micro-segments = $103,987/month = ~75% of all revenue at risk.**

| Risk Segment | Churn % | Churned | Revenue at Risk |
|---|---:|---:|---:|
| 0–6 mo · MTM · Fiber optic | **74.15%** 🔴 | 459 | **$37,150** |
| 25–48 mo · MTM · Fiber optic | 43.38% | 226 | $20,762 |
| 13–24 mo · MTM · Fiber optic | 50.59% | 215 | $19,047 |
| 7–12 mo · MTM · Fiber optic | 61.95% | 184 | $16,028 |
| 0–6 mo · MTM · DSL | 49.49% | 245 | $10,999 |
| **Total (Top 5)** | **56.39%** | **1,329** | **$103,987** |

---

## 7. Business Recommendations

Five prioritised plays, sequenced by impact-vs-effort:

| # | Recommendation | Target Segment | Est. Impact (p/m) | Priority |
|---|---|---|---:|:---:|
| **R1** | 90-day onboarding programme (touchpoints at days 7/30/60/90) | All 0–6 mo customers | $15–20K | 🔴 Highest |
| **R2** | Contract migration incentive (free month to convert MTM → 12-mo) | MTM customers past 6 mo | $10–15K | 🔴 High |
| **R3** | Migrate electronic-check payers to autopay (one-time bill credit) | All ~2.4K e-check users | $10–15K | 🔴 High |
| **R4** | Bundle online security + tech support into fiber plans | All ~3.1K fiber customers | $20–35K | 🟠 Med-High |
| **R5** | Senior & single-household engagement programme | Seniors / no partner / no dependents | Smaller, longer-term | 🟡 Medium |

### 🎯 Combined Target
Reduce overall churn from **26.54% → <20%** within 12 months and recover **$35–55K/month** in revenue at risk within two quarters.

---

## 8. Tools Used

| Tool | Purpose |
|---|---|
| **Power BI Desktop** | Data modelling, DAX, dashboard build |
| **DAX** | All KPI measures and segment calculations |
| **Power Query (M)** | Data cleaning, type conversion, calculated columns |
| **Python (pandas)** | Initial exploratory data analysis |
| **SQL** | Source query and validation checks |
| **Microsoft Word** | Long-form business analytics report |
| **GitHub** | Project documentation and version control |

---

## 9. Links

- 📊 **Live Power BI Dashboard:** [View on Power BI Service](#) <!-- replace with your published link -->
- 📁 **GitHub Repository:** [github.com/your-username/telco-churn-analysis](#) <!-- replace -->
- 🐍 **Python EDA Notebook:** [`/notebooks/eda.ipynb`](#) <!-- replace -->
- 🗃️ **SQL Validation Queries:** [`/sql/validation.sql`](#) <!-- replace -->
- 📄 **Full Business Analytics Report (PDF/DOCX):** [`/reports/Telco_Churn_Analytics_Report.docx`](#) <!-- replace -->
- 📂 **Dataset:** [Kaggle — IBM Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)

---

## 📌 Project Structure

```
telco-churn-analysis/
├── data/
│   └── WA_Fn-UseC_-Telco-Customer-Churn.csv
├── notebooks/
│   └── eda.ipynb
├── sql/
│   └── validation.sql
├── powerbi/
│   └── Telco_Churn_Report.pbix
├── reports/
│   └── Telco_Churn_Analytics_Report.docx
├── images/
│   ├── 01_executive_overview.png
│   ├── 02_customer_segmentation.png
│   └── 03_churn_drivers_revenue_risk.png
└── README.md
```

---

## 🚀 Next Steps (Roadmap)

- [ ] Build a **predictive churn model** (logistic regression / XGBoost) for customer-level scoring
- [ ] Add **Customer Lifetime Value (CLV)** modelling to pair with churn probability
- [ ] Set up an **A/B testing framework** to validate retention plays before scale-up
- [ ] Connect to a live data source for **automated refresh**

---

## 👤 Author

**[Your Name]**
📧 your.email@example.com
🔗 [LinkedIn](#) · [Portfolio](#) · [GitHub](#)

⭐ *If you found this project useful, give it a star!*
