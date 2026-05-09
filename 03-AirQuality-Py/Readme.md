# 🌫️ Air Quality Forecasting — 24-Hour PM2.5 Prediction with Deep Learning

> **End-to-end time-series forecasting project predicting hourly PM2.5 concentrations 24 hours ahead, using multivariate meteorological and pollutant data from 2013–2017. Six RNN architectures benchmarked against a naive baseline, with explicit analysis of when the model can — and cannot — be trusted.**

![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![TensorFlow](https://img.shields.io/badge/TensorFlow-FF6F00?style=flat&logo=tensorflow&logoColor=white)
![Keras](https://img.shields.io/badge/Keras-D00000?style=flat&logo=keras&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success)

---

## 📑 Table of Contents
1. [Problem Statement](#1-problem-statement)
2. [Headline Result](#2-headline-result)
3. [Approach](#3-approach)
4. [Model Architecture & Training](#4-model-architecture--training)
5. [Results](#5-results)
6. [Horizon-Wise Performance](#6-horizon-wise-performance)
7. [Model Behaviour & Failure Modes](#7-model-behaviour--failure-modes)
8. [Business Impact — Honest Framing](#8-business-impact--honest-framing)
9. [Deployment Considerations](#9-deployment-considerations)
10. [Limitations](#10-limitations)
11. [Tech Stack](#11-tech-stack)
12. [How to Run](#12-how-to-run)
13. [What I'd Do Next](#13-what-id-do-next)
14. [Author](#14-author)

---

## 1. Problem Statement

Air quality forecasting plays a critical role in public health and urban environmental planning. The challenge: given the previous 21 days of weather and pollutant readings, can we predict the next 24 hours of PM2.5 concentration accurately enough to support operational decisions like school closures, traffic restrictions, or hospital staffing?

Six Recurrent Neural Network (RNN) architectures were trained and benchmarked against a naive baseline, with the best model selected based on test performance, horizon-wise stability, and accuracy/complexity trade-off.

---

## 2. Headline Result

> **The best RNN reduces 24-hour MAE by ~35% versus a naive baseline (45.6 vs 69.8 µg/m³), with most reliable forecasts in the 0–12 hour window.**

But the headline number hides important behaviour: see [§7 Model Behaviour & Failure Modes](#7-model-behaviour--failure-modes) for an honest look at where the model breaks down. The short version: **good for directional near-term advisories, not yet good enough for high-stakes operational decisions on extreme-pollution days.**

---

## 3. Approach

### 🧹 Data Preprocessing
Hourly multivariate series spanning March 2013 to February 2017. Features include the target (PM2.5) plus PM10, SO2, NO2, CO, O3, temperature, pressure, dew point, wind speed, and rainfall. Missing values handled via forward-fill then back-fill to maintain temporal continuity. All features normalised with `MinMaxScaler` fit on training data only, with separate scalers for inputs and target.

### 🔧 Feature Engineering
Cyclic time encodings (`sin`/`cos` of hour-of-day and day-of-week) added so the network doesn't have to learn that hour 23 and hour 0 are adjacent. Exploratory analysis confirmed:
- **Heavy right-tail target distribution** — p50 ≈ 60, p95 ≈ 247, p99 ≈ 378 µg/m³ (extreme peak episodes are rare but high-magnitude)
- **Diurnal pattern** — average PM2.5 elevated at morning and evening rush hours
- **Pollutant correlations** — PM2.5 strongly correlated with PM10, CO, NO2; weak/inverse with wind speed

### 📦 Sequence Generation
Each training sample uses a **21-day lookback window (504 hours)** to predict the **next 24 hours** as a direct multi-step output. This captures multi-day pollution build-up and decay episodes.

### 🛡️ Leakage-Safe Split
- **Train:** all data ≤ 2015-12-31 23:00
- **Validation:** last 10% of training period (contiguous, time-ordered)
- **Test:** January 2016 (strict hold-out)

When forming test windows, the last 504 training hours are prepended so the first January-1 forecast has enough past context — using past data only, no leakage. **Final window counts:** Train = 8,286 · Val = 452 · Test = 265.

> **⚠️ Test set caveat:** 265 forecast windows is small. Differences of less than ~1 MAE between models may not be statistically significant.

---

## 4. Model Architecture & Training

### 🏆 Final Model
```
GRU(128) → Dense(24)
```

| Hyperparameter | Value |
|---|---|
| Optimiser | Adam |
| Loss | MAE |
| Batch size | 64 |
| Epochs | 100 (with EarlyStopping, patience=10) |
| Input shape | (504 timesteps, 13 features) |

### 🧪 Models Benchmarked

Six variants trained under identical conditions for an apples-to-apples comparison:

| # | Model | Rationale |
|---|---|---|
| 1 | LSTM-128 | Single-layer baseline; 128 units enough for diurnal + some multi-day structure |
| 2 | StackedLSTM 128→64 | Deeper temporal hierarchy (short cycles + longer regimes) |
| 3 | GRU-128 (efficient alt.) | GRUs simpler than LSTMs, often generalise better at similar capacity |
| 4 | LSTM-128 + Dropout(0.1) | Light regularisation when train < val loss suggests overfit |
| 5 | LSTM-128 (MSE loss) | Penalise large errors more — does it help peak prediction? |
| 6 | GRU-128 (no dropout) | Test whether dropout is restoring or restricting amplitude |

---

## 5. Results

| Rank | Model | Loss | Test MAE | Test RMSE |
|:---:|---|:---:|---:|---:|
| 🥇 | **GRU-128 (efficient alt.)** | MAE | **45.64** | **64.70** |
| 🥈 | GRU-128 (no dropout) | MAE | 46.06 | 65.09 |
| 🥉 | StackedLSTM 128→64 | MAE | 46.47 | **64.00** |
| 4 | LSTM-128 + Dropout(0.1) | MAE | 46.62 | 66.26 |
| 5 | LSTM-128 (capacity) | MAE | 49.42 | 68.44 |
| 6 | LSTM-128 (MSE for peaks) | MSE | 53.85 | 70.19 |
| — | Naive (repeat-last) | — | 69.75 | 98.52 |

### What the results tell us
- **GRU family wins.** Two GRU variants take the top two MAE positions; the GRU's simpler gating generalises better than LSTM at the same capacity, with fewer parameters.
- **MSE loss hurt accuracy.** It was meant to push peaks higher; in practice it widened average error without convincing peak gains.
- **Dropout effect was mixed.** Light regularisation didn't materially improve generalisation here — train and val losses tracked closely without it.
- **StackedLSTM was competitive but more expensive.** Marginally behind on MAE, slightly ahead on RMSE; not enough lift to justify the added complexity for this problem size.

> **Note on baseline strength:** The repeat-last naive baseline is a *weak* benchmark — it ignores the diurnal cycle and pollutant context entirely. A stronger baseline (seasonal naive, or a 7-day same-hour average) would close the gap to the GRU substantially. Beating naive by 35% is a real but modest result; see [Roadmap](#13-what-id-do-next).

---

## 6. Horizon-Wise Performance

Errors increase with lead time, as expected for direct multi-step forecasting:

| Lead time | MAE | RMSE |
|---:|---:|---:|
| 1 hour | **18.5** | 35.3 |
| 6 hours | 40.3 | 55.3 |
| 12 hours | ~46 | ~63 |
| 24 hours | ~53 | ~71 |

**Operational implication:**
- **0–6 h forecasts** are the most reliable and the best foundation for any operational use case.
- **6–12 h** are useful but should be communicated with growing uncertainty.
- **18–24 h** forecasts should carry explicit uncertainty bands (or be replaced with a probabilistic model — see Roadmap).

---

## 7. Model Behaviour & Failure Modes

> **This section is the most important part of the README. Aggregate metrics like "MAE = 45" hide what the model is actually doing on individual days.**

Inspecting the test-set predictions on consecutive days in January 2016 reveals a **regression-to-the-mean** failure mode:

### 🔴 Failure mode 1 — Under-calls extreme peak days
On Jan 1, actual PM2.5 ranges from 100–340 µg/m³ (a high-pollution episode). The model predicts a roughly flat 30–95 µg/m³ — it correctly identifies "elevated" but **massively under-states** the magnitude. On a real "Unhealthy" day, the model would communicate "Moderate" levels.

### 🔴 Failure mode 2 — Over-calls clean days
On Jan 2, actual PM2.5 sits at 5–20 µg/m³ (a clean day). The model predicts 50–325 µg/m³ — completely wrong direction. On a clean day, the model would falsely trigger advisories.

### Why this happens
The training distribution is dominated by mid-range readings, with extreme-high and extreme-low days under-represented. MAE loss further encourages the model to predict toward the conditional mean; trading peak fidelity for average accuracy is the optimal MAE strategy when peaks are rare.

### What this means for deployment
The model's headline MAE of ~46 µg/m³ is misleading without this context. The model is currently best understood as a **directional smoother** — useful for "is air quality trending up or down over the next 6 hours?" — not as a quantitative predictor on the days where the prediction matters most.

> **🚧 This is the single most important finding of the project, and it directly motivates the Roadmap items below — quantile forecasts to capture uncertainty on peaks, peak-aware loss functions, and ensemble approaches that don't optimise toward the mean.**

---

## 8. Business Impact — Honest Framing

### ✅ Where this model adds value today
- **Directional 0–6 hour advisories** — "is air quality likely to worsen or improve in the next 6 hours?"
- **Baseline for further model development** — clean pipeline, reproducible benchmark, validated splits
- **Trend awareness for non-operational uses** — research, education, public dashboards with uncertainty disclaimers

### ⛔ Where this model should *not* be deployed yet
- **Hospital staffing or clinic capacity decisions** — the under-prediction on peak days makes the model worse than useful for staff scheduling tied to pollution events
- **Hard threshold alerts** ("Unhealthy" / "Hazardous" categories) — the regression-to-mean behaviour will systematically miss the events the alert is designed to catch
- **Insurance, planning, or compliance use cases** requiring calibrated probabilities

### 📣 Communication strategy
Any operational use should:
1. Show **horizon-wise uncertainty bands**, not point forecasts
2. Include a **"recent observed peak"** reference so users can spot under-prediction
3. Be paired with a **rule-based fallback** ("if last 3 hours > X, override forecast")

This is the kind of operational caveat that a production deployment would absolutely require — it's not a weakness of the project; it's the thing the project surfaced clearly enough to act on.

---

## 9. Deployment Considerations

| Concern | Approach |
|---|---|
| **Data quality** | Monitor sensor uptime and gap rates; auto-apply forward-fill / back-fill; flag outages explicitly |
| **Drift detection** | Track rolling MAE/RMSE per horizon; retrain monthly or when drift exceeds threshold |
| **Calibration** | Apply validation-based scale correction to counter under-amplitude on extreme peaks |
| **Robustness** | Clip negative predictions, cap implausible spikes, fall back to naive when input window is incomplete |
| **Latency** | Keep inference under 1 second per forecast; log horizon-wise errors continuously |

---

## 10. Limitations

- **Single test month (Jan 2016, 265 windows).** Differences smaller than ~1 MAE between models may not be statistically significant. Cross-validated rolling-origin evaluation across multiple months would be more robust.
- **Single station.** No spatial signal sharing; performance may differ at locations with different emission profiles or weather regimes.
- **Weak baseline comparison.** Repeat-last is the lowest-effort baseline. Seasonal naive (24h lag) or a 7-day same-hour mean would be more honest comparisons and would likely close the gap to the GRU substantially.
- **Point estimates, no uncertainty.** No quantile forecasts or confidence intervals — operationally critical when the underlying process has heavy tails.
- **Regression to the mean on extremes.** See [§7](#7-model-behaviour--failure-modes). The model systematically under-predicts peaks and over-predicts troughs.
- **Static feature set.** No real-time external signals (traffic data, fire/dust events, regional transport) that often drive the events the model misses.

---

## 11. Tech Stack

| Tool | Purpose |
|---|---|
| **Python** (Pandas, NumPy) | Data wrangling, sequence generation |
| **TensorFlow / Keras** | RNN architectures (LSTM, GRU), EarlyStopping, training loop |
| **scikit-learn** | MinMaxScaler, MAE / RMSE metrics |
| **Matplotlib** | Diagnostics, horizon-wise error plots, real-vs-pred plots |

---

## 12. How to Run

### Prerequisites
```bash
pip install numpy pandas matplotlib scikit-learn tensorflow
```

### Steps
1. Place the dataset (`Task 3 Dataset Air Quality.csv`) in the same directory as the script.
2. Run the pipeline:
   ```bash
   python air_quality_forecast.py
   ```
3. The pipeline will:
   - Load and clean the data
   - Engineer cyclic time features
   - Build leakage-safe train / val / test splits with 504-hour bridging
   - Train all six RNN variants with EarlyStopping
   - Print the final results table sorted by MAE
   - Generate horizon-wise error and real-vs-pred diagnostic plots

---

## 13. What I'd Do Next

The Roadmap items below directly target the failure modes identified in [§7](#7-model-behaviour--failure-modes):

- [ ] **Quantile / probabilistic forecasts** — communicate uncertainty bands instead of point estimates; particularly important for peak days where the point estimate is most wrong
- [ ] **Peak-aware loss function** — weighted MAE or asymmetric loss that penalises under-prediction on high-pollution episodes more than over-prediction on clean days
- [ ] **Stronger baselines** — replace repeat-last with seasonal naive (24h lag) and 7-day same-hour mean; report all three for honest comparison
- [ ] **Multi-station modelling** — share signal across nearby monitors to improve robustness and capture regional-transport events
- [ ] **Rolling-origin cross-validation** — multiple test months instead of a single hold-out; tighter confidence intervals on model rankings
- [ ] **Operational dashboard** — translate horizon-wise errors into colour-coded alert tiers with explicit uncertainty for non-technical operators
- [ ] **Hybrid model** — combine the RNN with a peak-detection rule layer or a separate extreme-event classifier; route between them based on recent observations

---

## 14. Author

**Phuong Viet Dang (Jackie)**
📧 phuong.vietdang1912@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/phuongviet1912/) · [Portfolio](https://github.com/phuongvietdang1912-BA/business-analytics-portfolio)

Open to **Data Analyst, Business Analyst, and ML Engineer** roles.

