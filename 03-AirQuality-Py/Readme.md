# Air Quality Forecasting — 24-Hour PM2.5 Prediction with Deep Learning

End-to-end time-series forecasting project predicting hourly PM2.5 concentrations 24 hours ahead, using multivariate meteorological and pollutant data from 2013-2017. Built to support real-time air pollution alerts, traffic and emissions management, and clinic capacity planning.

---

## Problem Statement

Air quality forecasting plays a critical role in public health and urban environmental planning. The challenge: given the previous 21 days of weather and pollutant readings, can we predict the next 24 hours of PM2.5 concentration accurately enough to support operational decisions like school closures, traffic restrictions, or hospital staffing?

Multiple Recurrent Neural Network (RNN) architectures were trained and benchmarked against a naive baseline, with the best model selected based on test performance and horizon-wise stability.

---

## Key Results

| Model | Test MAE | Test RMSE | Notes |
|---|---|---|---|
| **GRU-128 (no dropout)** | **45.33** | **64.49** | Selected final model |
| StackedLSTM 128 -> 64 | 45.42 | 64.97 | Close runner-up |
| GRU-128 (efficient alt.) | 45.61 | 64.74 | |
| LSTM-128 + Dropout(0.1) | 49.98 | 68.54 | |
| LSTM-128 (MSE loss) | 54.39 | 70.82 | |
| LSTM-128 (capacity) | 54.76 | 72.53 | |
| Naive (repeat-last) | 69.75 | 98.52 | Baseline |

**Headline:** the chosen GRU model reduces forecasting error by **~35-38% versus the naive baseline**, with reliable forecasts in the first 6-12 hours where operational decisions matter most.

---

## Approach

### Data Preprocessing
Hourly multivariate series spanning March 2013 to February 2017. Features include the target (PM2.5) plus PM10, SO2, NO2, CO, O3, temperature, pressure, dew point, wind speed, and rainfall. Missing values handled via forward-fill then back-fill to maintain temporal continuity. All features normalised with MinMaxScaler fit on training data only, with separate scalers for inputs and target.

### Feature Engineering
Cyclic time encodings (`sin/cos` of hour-of-day and day-of-week) added to capture diurnal and weekly seasonality. Exploratory analysis confirmed strong morning/evening rush-hour patterns and positive correlations between PM2.5 and other pollutants (PM10, CO, NO2).

### Sequence Generation
Each training sample uses a **21-day lookback window (504 hours)** to predict the **next 24 hours** as a direct multi-step output. This captures multi-day pollution build-up and decay episodes.

### Leakage-Safe Split
- **Train:** all data through 2015-12-31 23:00
- **Validation:** last 10% of training period (contiguous, time-ordered)
- **Test:** January 2016 (strict hold-out)

When forming test windows, the last 504 training hours are prepended so the first January-1 forecast has enough past context — using past data only, no leakage.

### Model Architecture (Final)
```
GRU(128) -> Dense(24)
```
- Optimiser: Adam
- Loss: MAE
- Batch size: 64
- Epochs: 100 with EarlyStopping (patience=10, restore best weights)
- Input shape: (504 timesteps, 13 features)

---

## Why GRU-128 Won

| Reason | Evidence |
|---|---|
| Best accuracy/complexity trade-off | Lowest test MAE/RMSE with fewer parameters than comparable LSTM |
| Smooth horizon-wise error profile | 1h MAE ~14.5 -> 24h MAE ~50-55, no sudden degradation |
| Generalises better than capacity-heavy alternatives | StackedLSTM was competitive but marginally behind |
| MAE loss outperformed MSE | MSE emphasised peaks but hurt overall accuracy |

---

## Horizon-Wise Performance

Errors increase with lead time, as expected for direct multi-step forecasting:

- **1-hour forecast:** MAE ~14.5, RMSE ~33
- **6-hour forecast:** MAE ~40, RMSE ~55
- **24-hour forecast:** MAE ~50-55, RMSE ~70-76

**Operational implication:** forecasts are most reliable in the first 6-12 hours, supporting near-term health advisories, traffic management, and clinic staffing decisions. Longer-lead forecasts (18-24h) should be communicated with higher uncertainty.

---

## Business Impact

- **Use cases:** next-day PM2.5 advisories, short-term traffic and emissions control, clinic capacity planning, school activity decisions
- **Value:** ~35-38% error reduction vs. naive baseline, especially in the 0-12h window where operational responses matter most
- **Communication strategy:** publish horizon-wise KPIs alongside health threshold bands (e.g., "Unhealthy" alerts) to guide decision-makers

---

## Deployment Considerations

- **Data quality:** monitor sensor uptime and gap rates; auto-apply forward-fill / back-fill and flag outages
- **Drift detection:** track rolling MAE/RMSE; retrain monthly or when drift exceeds threshold
- **Calibration:** optional validation-based scale correction to counter under-amplitude prediction on extreme peaks
- **Robustness:** clip negative predictions, cap implausible spikes, fall back to naive when inputs are incomplete
- **Latency:** keep inference under 1 second per forecast; log horizon-wise errors for continuous improvement

---

## Tech Stack

- **Python** — Pandas, NumPy
- **TensorFlow / Keras** — Sequential models, LSTM, GRU, EarlyStopping
- **scikit-learn** — MinMaxScaler, evaluation metrics
- **Matplotlib** — diagnostics and horizon plots

---

## How to Run

```bash
pip install numpy pandas matplotlib scikit-learn tensorflow
python air_quality_forecast.py
```

Place the dataset (`Task 3 Dataset Air Quality.csv`) in the same directory as the script. The pipeline will:
1. Load and clean the data
2. Engineer cyclic time features
3. Build leakage-safe train/val/test splits
4. Train all six RNN variants with EarlyStopping
5. Print the final results table sorted by MAE

---

## What I'd Do Next

- **Quantile / probabilistic forecasts** to communicate uncertainty bands instead of point estimates
- **Peak-aware loss** (e.g., weighted MAE) to improve performance on extreme pollution episodes
- **Multi-station modelling** to share signal across nearby monitors and improve robustness
- **Operational dashboard** that translates horizon-wise errors into colour-coded alert tiers for non-technical operators

---

## Project Structure

```
air-quality-forecasting/
├── README.md                    # This file
├── air_quality_forecast.py      # End-to-end Python pipeline
└── data/
    └── Task 3 Dataset Air Quality.csv   # (not committed; add locally)
```

