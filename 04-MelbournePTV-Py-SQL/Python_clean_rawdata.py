"""
clean_sources.py
================
Cleans and conforms the four Victorian Government public-transport patronage
datasets into analysis-ready CSVs for loading into the SQL warehouse.

The four sources have different grains, schemas, and quirks. This script:
  1. Strips real-world mess (BOM, junk rows, quoted-comma numbers)
  2. UNPIVOTs the wide monthly-mode source into long format
  3. Unifies metro + regional station data despite their schema mismatch
  4. Conforms mode vocabulary across sources to a canonical set
  5. Writes clean CSVs ready for BULK INSERT

USAGE
-----
    python clean_sources.py --input ../data/raw/ --output ../data/cleaned/

INPUTS (in --input dir; see docs/DATA_SOURCES.md for download URLs)
-------------------------------------------------------------------
    monthly_patronage_by_mode.csv
    metro_stations_fy_*.csv          (multiple yearly files)
    regional_stations_fy_*.csv       (multiple yearly files)
    monthly_avg_by_daytype_mode.csv

OUTPUTS (in --output dir)
-------------------------
    clean_monthly_mode.csv           (long: year, month, mode_canonical, patronage)
    clean_stations.csv               (unified metro + regional, NULLs for missing cols)
    clean_daytype_mode.csv           (long: year, month, day_of_week, day_type, mode_canonical, pax_daily)
    clean_mode_dim.csv               (canonical mode reference)
"""

import argparse
import glob
import os
import re
from pathlib import Path

import pandas as pd


# ---------------------------------------------------------------------------
# Canonical mode vocabulary
# Maps every source spelling to one canonical key.
# ---------------------------------------------------------------------------
MODE_CANONICAL = {
    # Source 1 (monthly by mode) - wide column headers
    "metropolitan train": "metro_train",
    "metropolitan tram": "metro_tram",
    "metropolitan bus": "metro_bus",
    "regional train": "regional_train",
    "regional coach": "regional_coach",
    "regional bus": "regional_bus",
    # Source 4 (daytype) - compact names
    "metrotrain": "metro_train",
    "tram": "metro_tram",
    "metrobus": "metro_bus",
    "regionaltrain": "regional_train",
    "regionalbus": "regional_bus",
}

MODE_LABELS = {
    "metro_train": "Metropolitan Train",
    "metro_tram": "Metropolitan Tram",
    "metro_bus": "Metropolitan Bus",
    "regional_train": "Regional Train",
    "regional_coach": "Regional Coach",
    "regional_bus": "Regional Bus",
}


def canon_mode(raw):
    """Map a raw mode string to its canonical key. Returns None if unknown."""
    if raw is None:
        return None
    key = str(raw).strip().lower()
    return MODE_CANONICAL.get(key)


def parse_patronage_number(value):
    """Parse '16,809,932' or '  16809932 ' or '' into an int (or NA)."""
    if value is None:
        return pd.NA
    s = str(value).strip().replace(",", "").replace('"', "")
    if s == "" or s.lower() in ("nan", "none", "null"):
        return pd.NA
    try:
        return int(float(s))
    except (ValueError, TypeError):
        return pd.NA


def read_csv_strip_bom(path, **kwargs):
    """Read a CSV handling the BOM that Vic gov files start with."""
    # utf-8-sig transparently strips a leading BOM if present
    return pd.read_csv(path, encoding="utf-8-sig", **kwargs)


# ---------------------------------------------------------------------------
# Source 1 - Monthly patronage by mode (WIDE -> LONG)
# ---------------------------------------------------------------------------

def clean_monthly_mode(input_dir, output_dir):
    path = Path(input_dir) / "monthly_patronage_by_mode.csv"
    print(f"[1/4] Cleaning {path.name}")

    # The file has 7 empty trailing columns and 12+ trailing junk rows.
    # Read everything as string first so we control parsing.
    df = read_csv_strip_bom(path, dtype=str)

    # Drop fully-empty columns (the trailing comma artefacts)
    df = df.dropna(axis=1, how="all")
    # Drop columns whose header is empty/unnamed
    df = df.loc[:, [c for c in df.columns if c and not str(c).startswith("Unnamed")]]

    # Identify the id columns vs the mode columns
    id_cols = ["Year", "Month", "Month name"]
    mode_cols = [c for c in df.columns if c not in id_cols]

    # Drop trailing junk rows: rows where Year is blank/non-numeric
    df = df[pd.to_numeric(df["Year"], errors="coerce").notna()].copy()

    # UNPIVOT wide -> long
    long_df = df.melt(
        id_vars=id_cols,
        value_vars=mode_cols,
        var_name="mode_raw",
        value_name="patronage_raw",
    )

    # Clean values
    long_df["year"] = pd.to_numeric(long_df["Year"], errors="coerce").astype("Int64")
    long_df["month"] = pd.to_numeric(long_df["Month"], errors="coerce").astype("Int64")
    long_df["mode_canonical"] = long_df["mode_raw"].apply(canon_mode)
    long_df["patronage"] = long_df["patronage_raw"].apply(parse_patronage_number).astype("Int64")

    # Flag any unmapped modes loudly
    unmapped = long_df[long_df["mode_canonical"].isna()]["mode_raw"].unique()
    if len(unmapped):
        print(f"  WARNING: unmapped modes (check MODE_CANONICAL): {list(unmapped)}")

    out = long_df[["year", "month", "mode_canonical", "patronage"]].dropna(
        subset=["year", "month", "mode_canonical"]
    )
    out_path = Path(output_dir) / "clean_monthly_mode.csv"
    out.to_csv(out_path, index=False)
    print(f"  -> {out_path.name}: {len(out):,} rows")
    return out


# ---------------------------------------------------------------------------
# Sources 2 & 3 - Station patronage (UNIFY metro 15-col + regional 6-col)
# ---------------------------------------------------------------------------

# Canonical unified station schema
STATION_COLS = [
    "fin_year", "stop_id", "stop_name", "stop_lat", "stop_long", "network",
    "pax_annual", "pax_weekday", "pax_norm_weekday", "pax_sch_hol_weekday",
    "pax_saturday", "pax_sunday",
    "pax_pre_am_peak", "pax_am_peak", "pax_interpeak", "pax_pm_peak", "pax_pm_late",
]

METRO_RENAME = {
    "Fin_year": "fin_year", "Stop_ID": "stop_id", "Stop_name": "stop_name",
    "Stop_lat": "stop_lat", "Stop_long": "stop_long",
    "Pax_annual": "pax_annual", "Pax_weekday": "pax_weekday",
    "Pax_norm_weekday": "pax_norm_weekday", "Pax_sch_hol_weekday": "pax_sch_hol_weekday",
    "Pax_Saturday": "pax_saturday", "Pax_Sunday": "pax_sunday",
    "Pax_pre_AM_peak": "pax_pre_am_peak", "Pax_AM_peak": "pax_am_peak",
    "Pax_interpeak": "pax_interpeak", "Pax_PM_peak": "pax_pm_peak",
    "Pax_PM_late": "pax_pm_late",
}

REGIONAL_RENAME = {
    "Fin_year": "fin_year", "Stop_ID": "stop_id", "Stop_name": "stop_name",
    "Stop_lat": "stop_lat", "Stop_long": "stop_long", "Pax_annual": "pax_annual",
}


def normalise_station_name(name):
    """'Melton Railway Station (Melton South)' -> ('Melton', 'Melton South' flagged).
    Keep full name but also strip ' Railway Station' noise for a clean display name.

    Known edge case: nested parentheses like 'Albury Railway Station (Albury (NSW))'
    don't get a clean suffix extraction because the regex matches the outermost
    closing paren. These are rare (border stations) and are separately caught by
    the is_border_nsw flag, so we don't over-engineer the regex for them.
    """
    if name is None:
        return None, None
    full = str(name).strip()
    # Extract parenthetical suffix if present
    paren = None
    m = re.search(r"\(([^)]*)\)\s*$", full)
    if m:
        paren = m.group(1).strip()
    # Clean display name: remove ' Railway Station' and trailing parenthetical
    display = re.sub(r"\s*\([^)]*\)\s*$", "", full)
    display = re.sub(r"\s+Railway Station$", "", display, flags=re.IGNORECASE).strip()
    return display, paren


def clean_stations(input_dir, output_dir):
    print("[2/4] Cleaning station files (metro + regional)")
    frames = []

    # Metro files (15-col)
    for path in sorted(glob.glob(str(Path(input_dir) / "metro_stations_fy_*.csv"))):
        df = read_csv_strip_bom(path, dtype=str)
        df = df.rename(columns=METRO_RENAME)
        df["network"] = "metro"
        frames.append(df)
        print(f"  metro:    {Path(path).name} ({len(df):,} rows)")

    # Regional files (6-col) - the schema mismatch
    for path in sorted(glob.glob(str(Path(input_dir) / "regional_stations_fy_*.csv"))):
        df = read_csv_strip_bom(path, dtype=str)
        df = df.rename(columns=REGIONAL_RENAME)
        df["network"] = "regional"
        # Add the missing detail columns as NA (documented, not hidden)
        for col in STATION_COLS:
            if col not in df.columns:
                df[col] = pd.NA
        frames.append(df)
        print(f"  regional: {Path(path).name} ({len(df):,} rows)")

    if not frames:
        print("  WARNING: no station files found.")
        return pd.DataFrame(columns=STATION_COLS)

    combined = pd.concat(frames, ignore_index=True)

    # Normalise station names
    names = combined["stop_name"].apply(normalise_station_name)
    combined["stop_name_clean"] = [n[0] for n in names]
    combined["stop_name_suffix"] = [n[1] for n in names]

    # Flag NSW-border stations (e.g. Albury)
    combined["is_border_nsw"] = combined["stop_name"].str.contains("NSW", case=False, na=False)

    # Parse all patronage columns
    pax_cols = [c for c in STATION_COLS if c.startswith("pax_")]
    for col in pax_cols:
        combined[col] = combined[col].apply(parse_patronage_number).astype("Int64")

    # Numeric lat/long
    combined["stop_lat"] = pd.to_numeric(combined["stop_lat"], errors="coerce")
    combined["stop_long"] = pd.to_numeric(combined["stop_long"], errors="coerce")
    combined["stop_id"] = pd.to_numeric(combined["stop_id"], errors="coerce").astype("Int64")

    out_cols = STATION_COLS + ["stop_name_clean", "stop_name_suffix", "is_border_nsw"]
    out = combined[out_cols]
    out_path = Path(output_dir) / "clean_stations.csv"
    out.to_csv(out_path, index=False)
    print(f"  -> {out_path.name}: {len(out):,} rows ({combined['network'].value_counts().to_dict()})")
    return out


# ---------------------------------------------------------------------------
# Source 4 - Monthly avg by day-type by mode (already long, just conform)
# ---------------------------------------------------------------------------

def clean_daytype_mode(input_dir, output_dir):
    path = Path(input_dir) / "monthly_avg_by_daytype_mode.csv"
    print(f"[3/4] Cleaning {path.name}")
    df = read_csv_strip_bom(path, dtype=str)

    # Normalise column names
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    df["year"] = pd.to_numeric(df["year"], errors="coerce").astype("Int64")
    df["month"] = pd.to_numeric(df["month"], errors="coerce").astype("Int64")
    df["mode_canonical"] = df["mode"].apply(canon_mode)
    df["pax_daily"] = df["pax_daily"].apply(parse_patronage_number).astype("Int64")

    # Standardise day_type and day_of_week capitalisation
    df["day_type"] = df["day_type"].str.strip()
    df["day_of_week"] = df["day_of_week"].str.strip()

    unmapped = df[df["mode_canonical"].isna()]["mode"].unique()
    if len(unmapped):
        print(f"  WARNING: unmapped modes: {list(unmapped)}")

    out = df[["year", "month", "day_of_week", "day_type", "mode_canonical", "pax_daily"]].dropna(
        subset=["year", "month", "mode_canonical"]
    )
    out_path = Path(output_dir) / "clean_daytype_mode.csv"
    out.to_csv(out_path, index=False)
    print(f"  -> {out_path.name}: {len(out):,} rows")
    return out


# ---------------------------------------------------------------------------
# Mode dimension reference
# ---------------------------------------------------------------------------

def write_mode_dim(output_dir):
    print("[4/4] Writing mode dimension reference")
    rows = [{"mode_canonical": k, "mode_label": v,
             "network": "metro" if k.startswith("metro") else "regional"}
            for k, v in MODE_LABELS.items()]
    out = pd.DataFrame(rows)
    out_path = Path(output_dir) / "clean_mode_dim.csv"
    out.to_csv(out_path, index=False)
    print(f"  -> {out_path.name}: {len(out):,} rows")
    return out


def main(input_dir, output_dir):
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    print(f"Input:  {input_dir}")
    print(f"Output: {output_dir}\n")

    clean_monthly_mode(input_dir, output_dir)
    clean_stations(input_dir, output_dir)
    clean_daytype_mode(input_dir, output_dir)
    write_mode_dim(output_dir)

    print("\nDone. Cleaned files ready for SQL load.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Directory with raw source CSVs")
    parser.add_argument("--output", required=True, help="Directory for cleaned CSVs")
    args = parser.parse_args()
    main(args.input, args.output)
