# 📉 Telco Customer Churn Analysis

> **A Power BI portfolio project diagnosing $1.67M of annual revenue at risk and building a data-driven retention roadmap.**

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![DAX](https://img.shields.io/badge/DAX-1F77B4?style=flat)
![Status](https://img.shields.io/badge/Status-Completed-success)

---

## 📑 Table of Contents
1. [Business Problem](#1-business-problem)
2. [Headline Finding](#2-headline-finding)
3. **[🔴 Live Dashboard](#-live-dashboard)** ← featured
4. [Dataset Overview](#3-dataset-overview)
5. [Data Cleaning & Modelling](#4-data-cleaning--modelling)
6. [Key Metrics / KPIs](#5-key-metrics--kpis)
7. [Dashboard / Analysis](#6-dashboard--analysis)
8. [Key Insights](#7-key-insights)
9. [Business Recommendations](#8-business-recommendations)
10. [Limitations](#9-limitations)
11. [Tools Used](#10-tools-used)
12. [Links](#11-links)

---

## 1. Business Problem

A telecom provider is losing **roughly 1 in 4 customers (26.54%)** - well above typical industry benchmarks of 15–25%. With **$139.13K in monthly recurring revenue at risk (~$1.67M annualised)**, leadership lacks a clear, segment-level view of:

- 🔍 **Where** churn is concentrated (which customer profiles are leaving?)
- 💰 **How much** each segment is costing the business
- 🎯 **Which interventions** would most efficiently slow the loss

**Project goal:** Build a Power BI report that diagnoses the drivers of churn, quantifies revenue at risk by segment, and translates findings into prioritised retention recommendations.

---

## 2. Headline Finding

> **75% of revenue at risk sits in just 5 customer micro-segments - accounting for 71% of all churned customers.**

| Risk Segment | Churn % | Churned | Revenue at Risk (p/m) |
|---|---:|---:|---:|
| 0–6 mo · MTM · Fiber optic | **74.15%** 🔴 | 459 | **$37,150** |
| 25–48 mo · MTM · Fiber optic | 43.38% | 226 | $20,762 |
| 13–24 mo · MTM · Fiber optic | 50.59% | 215 | $19,047 |
| 7–12 mo · MTM · Fiber optic | 61.95% | 184 | $16,028 |
| 0–6 mo · MTM · DSL | 49.49% | 245 | $10,999 |
| **Total (Top 5)** | **56.39%** | **1,329** | **$103,987** |

**Implication:** A surgical retention strategy targeting these five segments - rather than a broad-based programme - captures three quarters of the financial exposure with a fraction of the operational cost.

---

## 🔴 Live Dashboard

**👉 [View the interactive Power BI report]([https://app.powerbi.com/view?r=eyJrIjoiYzA1YzE4N2ItOTc1Yy00ZmMzLThkNjgtMjRkOGIxYzMwNGEzIiwidCI6IjIzMjYxY2E4LTZjMDAtNGRkOS05NGMxLWFmODE1ZDVkMmRmYyJ9](https://app.fabric.microsoft.com/view?r=eyJrIjoiMDlkYjYzY2QtMjRmZC00N2FjLThhZTAtZmNjMjQxMzkzZDgyIiwidCI6IjIzMjYxY2E4LTZjMDAtNGRkOS05NGMxLWFmODE1ZDVkMmRmYyJ9))**  (no install required).

*Best viewed on desktop. Loads in ~10 seconds.*

---

## 3. Dataset Overview

**Source:** [IBM Telco Customer Churn Dataset](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) - a widely-used public benchmark dataset.

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

## 4. Data Cleaning & Modelling

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

-- Risk Segment (composite identifier)
Risk Segment Short =
Telco[Tenure Band] & " | " &
IF(
    Telco[Contract] = "Month-to-month",
    "MTM",
    Telco[Contract]
) & " | " &
Telco[InternetService]

-- Online Security (cleaned)
OnlineSecurity Clean =
SWITCH(
    Telco[OnlineSecurity],
    "No internet service", "No internet",
    Telco[OnlineSecurity]
)

-- Tech Support (cleaned)
TechSupport Clean =
SWITCH(
    Telco[TechSupport],
    "No internet service", "No internet",
    Telco[TechSupport]
)
```

### 📐 Data Model
A single fact-table model is used here as a **deliberate design choice** - for a 7K-row point-in-time snapshot with no temporal or transactional grain, a star schema would add modelling overhead without analytical benefit. (For a Kimball star-schema implementation, see [Project 2 - Instacart](../02-InstaCart-SQL-PowerBI).) Sort-by columns are applied to `Tenure Band` and `Monthly Charge Band` for natural ordering on visuals.

---

## 5. Key Metrics / KPIs

Eight core DAX measures power the entire report:

```dax
Total Customers = DISTINCTCOUNT(Telco[customerID])

Churned Customers = CALCULATE([Total Customers], Telco[Churn] = "Yes")

Active Customers = CALCULATE([Total Customers], Telco[Churn] = "No")

Churn Rate % = DIVIDE([Churned Customers], [Total Customers])

Monthly Recurring Revenue =
CALCULATE(SUM(Telco[MonthlyCharges]), Telco[Churn] = "No")

Revenue at Risk (p/m) =
CALCULATE(SUM(Telco[MonthlyCharges]), Telco[Churn] = "Yes")

Annualised Revenue at Risk = [Revenue at Risk (p/m)] * 12

Avg Monthly Charge of Churned Customers =
CALCULATE(AVERAGE(Telco[MonthlyCharges]), Telco[Churn] = "Yes")

Churn Rate by Segment =
DIVIDE(
    CALCULATE([Churned Customers], ALLSELECTED(Telco)),
    CALCULATE([Total Customers],   ALLSELECTED(Telco))
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

## 6. Dashboard / Analysis

The Power BI report is structured as a **three-page narrative**, with four global slicers (Contract, Internet Service, Payment Method, Tenure Band).

### 📄 Page 1 - Executive Overview
> **Audience:** Leadership · **Question answered:** *Where do we stand and where is the bleeding worst?*

<img width="1519" height="852" alt="image" src="https://github.com/user-attachments/assets/652d8b85-7c00-4f63-abc9-372d690ae460" />

### 📄 Page 2 - Customer Segmentation Deep Dive
> **Audience:** Marketing & CX · **Question answered:** *Who is leaving and why?*

<img width="1520" height="850" alt="image" src="https://github.com/user-attachments/assets/080c84eb-d6a0-4a6b-ba6f-b82c8bf66114" />

### 📄 Page 3 - Churn Drivers & Revenue Risk
> **Audience:** Product & Finance · **Question answered:** *Where is the financial exposure concentrated?*

<img width="1516" height="853" alt="image" src="https://github.com/user-attachments/assets/9487824a-0952-4eeb-a346-5944faffe2ba" />

---

## 7. Key Insights

### 🔎 1. Tenure shows the steepest single-variable churn gradient
Customers in their first 6 months churn at **52.94%** vs **6.61%** at 5+ years - a **46-percentage-point absolute gap**. The relationship is monotonic: every additional tenure bracket reduces churn.

| Tenure Band | Churn Rate | Revenue at Risk |
|---|---:|---:|
| 0–6 months | **52.94%** 🔴 | $50K |
| 7–12 months | 35.89% | $19K |
| 13–24 months | 28.71% | $23K |
| 25–48 months | 20.39% | $27K |
| 49–60 months | 14.42% | $11K |
| 60+ months | **6.61%** 🟢 | $9K |

### 🔎 2. Contract type rivals tenure as a churn driver
Month-to-month customers churn at **42.71%** vs **2.83%** for two-year contracts - a **40-point absolute gap**, comparable in magnitude to the tenure effect. Tenure and contract type together explain most of the churn variance and likely interact (short-tenure customers are also far more likely to be MTM).

### 🔎 3. Payment friction is a hidden killer
Electronic-check users churn at **45.29%** vs **~16%** for autopay methods - a 29-point gap. Each billing cycle is effectively a re-purchase decision when payment isn't automated.

### 🔎 4. Fiber optic churns more than DSL - worth investigating, not assuming
Fiber optic = **41.89%** churn vs DSL = **18.96%**. A natural hypothesis is that fiber customers without bundled online security are under-served: those without it churn at **49.36%** vs **21.81%** with it.

> ⚠️ **Caveat:** This relationship is likely confounded with contract type, tenure, and monthly charges (fiber skews short-tenure / high-charge / MTM). Recommended next step is an **A/B test** of the security bundle on new fiber customers, controlling for contract and tenure, before assuming bundling causes retention.

### 🔎 5. Demographic vulnerability cohorts
| Group | Churn |
|---|---:|
| Senior citizens | 41.68% (vs 23.61%) |
| No partner | 32.96% (vs 19.66%) |
| No dependents | 31.28% (vs 15.45%) |

Demographics aren't directly actionable as a campaign target, but should be incorporated as **risk flags** in any predictive churn model (see Roadmap).

---

## 8. Business Recommendations

Four prioritised plays, sequenced by impact-vs-effort:

| # | Recommendation | Target Segment | Est. Impact (p/m) | Priority |
|---|---|---|---:|:---:|
| **R1** | 90-day onboarding programme (touchpoints at days 7/30/60/90) | All 0–6 mo customers | $15–20K | 🔴 Highest |
| **R2** | Contract migration incentive (free month to convert MTM → 12-mo) | MTM customers past 6 mo | $10–15K | 🔴 High |
| **R3** | Migrate electronic-check payers to autopay (one-time bill credit) | All ~2.4K e-check users | $10–15K | 🔴 High |
| **R4** | A/B test: bundle online security + tech support into fiber plans | New fiber customers (test cohort) | $20–35K | 🟠 Med-High |

> **📐 Impact estimation methodology:** Each estimate assumes a target reduction in segment churn (typically 20–35% relative) applied to current revenue at risk in the affected segment. Ranges reflect conservative-to-optimistic outcomes pending real-world A/B validation. Estimates are **directional**, not commitments - they exist to prioritise effort, not to forecast P&L.

### 🎯 Combined Target
Reduce overall churn from **26.54% → <20%** within 12 months and recover **$35–55K/month** in revenue at risk within two quarters.

---

## 9. Limitations

A few constraints to keep in mind when interpreting these findings:

- **Point-in-time snapshot.** No time dimension means we can't validate whether observed patterns are stable, seasonal, or trending - and we can't measure intervention impact over time without follow-up data.
- **No cost-of-acquisition data.** Revenue-at-risk numbers are gross, not net of CAC, so true Customer Lifetime Value impact can't be modelled here.
- **Benchmark dataset.** The IBM Telco dataset is a public learning benchmark; real-world telco churn drivers may differ in magnitude and may include drivers not captured here (network quality, customer service contacts, competitor pricing).
- **Single-variable analysis.** Insights are based on segmented descriptive statistics, not a multivariate model. The "Strongest predictor" question is left to the predictive modelling phase (see Roadmap).

**With richer data, the next questions I'd ask are:** customer-service contact history, NPS / CSAT trajectories, network outage exposure by customer, and competitor switching events. These typically explain the residual variance that demographics and account features can't.

---

## 10. Tools Used

| Tool | Purpose |
|---|---|
| **Power BI Desktop** | Data modelling, DAX, dashboard build |
| **DAX** | All KPI measures and segment calculations |
| **Power Query (M)** | Data cleaning, type conversion, calculated columns |
| **Microsoft Word** | Long-form business analytics report |
| **GitHub** | Project documentation and version control |

---

## 11. Links

- 📁 **Project Folder:** [`01-Telco-project`](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio/tree/main/01-Telco-project)
- 📄 **Full Business Analytics Report (PDF):** [View Report](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio/blob/main/01-Telco-project/Telco%20Churn%20Report.pdf)
- 📂 **Dataset:** [Kaggle - IBM Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)
- 🔴 **Live Dashboard**: [View the interactive Power BI report](https://app.fabric.microsoft.com/view?r=eyJrIjoiMDlkYjYzY2QtMjRmZC00N2FjLThhZTAtZmNjMjQxMzkzZDgyIiwidCI6IjIzMjYxY2E4LTZjMDAtNGRkOS05NGMxLWFmODE1ZDVkMmRmYyJ9)

---

## 📌 Project Structure

```
01-Telco-project/
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

- [ ] Build a **predictive churn model** (logistic regression / XGBoost) for customer-level scoring, with feature importance to formally rank churn drivers
- [ ] Add **Customer Lifetime Value (CLV)** modelling to pair with churn probability
- [ ] Set up an **A/B testing framework** to validate retention plays before scale-up - starting with the fiber + online-security bundle (R4)
- [ ] Connect to a live data source for **automated refresh**

---

## 👤 Author

**Phuong Viet Dang**
📧 phuong.vietdang1912@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/phuongviet1912/) · [Portfolio](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio)

