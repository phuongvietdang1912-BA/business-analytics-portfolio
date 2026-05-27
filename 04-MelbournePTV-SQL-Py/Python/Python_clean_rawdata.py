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

FILE DISCOVERY
--------------
This script finds source files by PATTERN, not exact name. Government file
names vary ("monthly_public_transport_patronage_by_mode" vs
"monthly_patronage_by_mode"), so each source is located by matching keywords
in the filename. This means you can drop the files in as-downloaded without
renaming them.

USAGE
-----
    python clean_sources.py                       # uses default paths below
    python clean_sources.py --input X --output Y  # override

OUTPUTS (in --output dir)
-------------------------
    clean_monthly_mode.csv     (long: year, month, mode_canonical, patronage)
    clean_stations.csv         (unified metro + regional, NULLs for missing cols)
    clean_daytype_mode.csv     (long: year, month, day_of_week, day_type, mode_canonical, pax_daily)
    clean_mode_dim.csv         (canonical mode reference)
"""

import argparse
import glob
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
    "regionalcoach": "regional_coach",
}

MODE_LABELS = {
    "metro_train": "Metropolitan Train",
    "metro_tram": "Metropolitan Tram",
    "metro_bus": "Metropolitan Bus",
    "regional_train": "Regional Train",
    "regional_coach": "Regional Coach",
    "regional_bus": "Regional Bus",
}


# ---------------------------------------------------------------------------
# File discovery by pattern (robust to filename variations)
# ---------------------------------------------------------------------------

def find_one_file(input_dir, must_contain, must_not_contain=None):
    """Find exactly one CSV whose lowercase name contains ALL keywords in
    must_contain and NONE in must_not_contain. Raises a clear error listing
    what's actually in the folder if no unique match is found."""
    must_not_contain = must_not_contain or []
    candidates = []
    for p in glob.glob(str(Path(input_dir) / "*.csv")):
        name = Path(p).name.lower()
        if all(k in name for k in must_contain) and not any(k in name for k in must_not_contain):
            candidates.append(p)

    if len(candidates) == 1:
        return candidates[0]

    available = "\n  ".join(sorted(Path(p).name for p in glob.glob(str(Path(input_dir) / "*.csv"))))
    if len(candidates) == 0:
        raise FileNotFoundError(
            f"No file found matching keywords {must_contain} "
            f"(excluding {must_not_contain}).\nFiles in {input_dir}:\n  {available}"
        )
    raise FileNotFoundError(
        f"Multiple files matched keywords {must_contain}: "
        f"{[Path(c).name for c in candidates]}. Narrow the keywords."
    )


def find_files(input_dir, must_contain):
    """Find ALL CSVs whose lowercase name contains every keyword. For the
    multi-year station files. Returns a sorted list."""
    out = []
    for p in glob.glob(str(Path(input_dir) / "*.csv")):
        name = Path(p).name.lower()
        if all(k in name for k in must_contain):
            out.append(p)
    return sorted(out)


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

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
    return pd.read_csv(path, encoding="utf-8-sig", **kwargs)


# ---------------------------------------------------------------------------
# Source 1 - Monthly patronage by mode (WIDE -> LONG)
# ---------------------------------------------------------------------------

def clean_monthly_mode(input_dir, output_dir):
    path = find_one_file(
        input_dir,
        must_contain=["monthly", "patronage", "mode"],
        must_not_contain=["day_type", "day type", "average"],  # exclude Source 4
    )
    print(f"[1/4] Cleaning {Path(path).name}")

    df = read_csv_strip_bom(path, dtype=str)

    # Drop fully-empty columns (the trailing comma artefacts)
    df = df.dropna(axis=1, how="all")
    df = df.loc[:, [c for c in df.columns if c and not str(c).startswith("Unnamed")]]

    id_cols = [c for c in df.columns if c.strip().lower() in ("year", "month", "month name", "month_name")]
    mode_cols = [c for c in df.columns if c not in id_cols]

    # Find the Year column robustly
    year_col = next((c for c in df.columns if c.strip().lower() == "year"), None)
    month_col = next((c for c in df.columns if c.strip().lower() == "month"), None)

    # Drop trailing junk rows (blank/non-numeric Year)
    df = df[pd.to_numeric(df[year_col], errors="coerce").notna()].copy()

    long_df = df.melt(id_vars=id_cols, value_vars=mode_cols,
                      var_name="mode_raw", value_name="patronage_raw")

    long_df["year"] = pd.to_numeric(long_df[year_col], errors="coerce").astype("Int64")
    long_df["month"] = pd.to_numeric(long_df[month_col], errors="coerce").astype("Int64")
    long_df["mode_canonical"] = long_df["mode_raw"].apply(canon_mode)
    long_df["patronage"] = long_df["patronage_raw"].apply(parse_patronage_number).astype("Int64")

    unmapped = long_df[long_df["mode_canonical"].isna()]["mode_raw"].unique()
    if len(unmapped):
        print(f"  WARNING: unmapped modes (add to MODE_CANONICAL): {list(unmapped)}")

    out = long_df[["year", "month", "mode_canonical", "patronage"]].dropna(
        subset=["year", "month", "mode_canonical"])
    out_path = Path(output_dir) / "clean_monthly_mode.csv"
    out.to_csv(out_path, index=False)
    print(f"  -> {out_path.name}: {len(out):,} rows")
    return out


# ---------------------------------------------------------------------------
# Sources 2 & 3 - Station patronage (UNIFY metro 15-col + regional 6-col)
# ---------------------------------------------------------------------------

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
    """'Melton Railway Station (Melton South)' -> ('Melton', 'Melton South').

    Known edge case: nested parentheses like 'Albury Railway Station (Albury (NSW))'
    don't get a clean suffix; these are rare border stations and are separately
    caught by the is_border_nsw flag, so we don't over-engineer the regex.
    """
    if name is None:
        return None, None
    full = str(name).strip()
    paren = None
    m = re.search(r"\(([^)]*)\)\s*$", full)
    if m:
        paren = m.group(1).strip()
    display = re.sub(r"\s*\([^)]*\)\s*$", "", full)
    display = re.sub(r"\s+Railway Station$", "", display, flags=re.IGNORECASE).strip()
    return display, paren


def clean_stations(input_dir, output_dir):
    print("[2/4] Cleaning station files (metro + regional)")
    frames = []

    metro_files = find_files(input_dir, must_contain=["metropolitan", "station"])
    for path in metro_files:
        df = read_csv_strip_bom(path, dtype=str)
        df = df.rename(columns=METRO_RENAME)
        df["network"] = "metro"
        frames.append(df)
        print(f"  metro:    {Path(path).name} ({len(df):,} rows)")

    regional_files = find_files(input_dir, must_contain=["regional", "station"])
    for path in regional_files:
        df = read_csv_strip_bom(path, dtype=str)
        df = df.rename(columns=REGIONAL_RENAME)
        df["network"] = "regional"
        for col in STATION_COLS:
            if col not in df.columns:
                df[col] = pd.NA
        frames.append(df)
        print(f"  regional: {Path(path).name} ({len(df):,} rows)")

    if not frames:
        print("  WARNING: no station files found.")
        return pd.DataFrame(columns=STATION_COLS)

    combined = pd.concat(frames, ignore_index=True)

    names = combined["stop_name"].apply(normalise_station_name)
    combined["stop_name_clean"] = [n[0] for n in names]
    combined["stop_name_suffix"] = [n[1] for n in names]
    combined["is_border_nsw"] = combined["stop_name"].str.contains("NSW", case=False, na=False)

    pax_cols = [c for c in STATION_COLS if c.startswith("pax_")]
    for col in pax_cols:
        combined[col] = combined[col].apply(parse_patronage_number).astype("Int64")

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
    path = find_one_file(
        input_dir,
        must_contain=["average", "day_type", "mode"],
    ) if find_files(input_dir, ["average", "day_type", "mode"]) else find_one_file(
        input_dir,
        must_contain=["average", "day", "type", "mode"],
    )
    print(f"[3/4] Cleaning {Path(path).name}")
    df = read_csv_strip_bom(path, dtype=str)

    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    df["year"] = pd.to_numeric(df["year"], errors="coerce").astype("Int64")
    df["month"] = pd.to_numeric(df["month"], errors="coerce").astype("Int64")
    df["mode_canonical"] = df["mode"].apply(canon_mode)
    df["pax_daily"] = df["pax_daily"].apply(parse_patronage_number).astype("Int64")

    df["day_type"] = df["day_type"].str.strip()
    df["day_of_week"] = df["day_of_week"].str.strip()

    unmapped = df[df["mode_canonical"].isna()]["mode"].unique()
    if len(unmapped):
        print(f"  WARNING: unmapped modes: {list(unmapped)}")

    out = df[["year", "month", "day_of_week", "day_type", "mode_canonical", "pax_daily"]].dropna(
        subset=["year", "month", "mode_canonical"])
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
    # Default paths (your local setup). Override with --input / --output.
    DEFAULT_INPUT = r"C:\Users\Admin\Desktop\JRM\Melbourne PTV\data\raw"
    DEFAULT_OUTPUT = r"C:\Users\Admin\Desktop\JRM\Melbourne PTV\data\cleaned"

    parser = argparse.ArgumentParser(
        description="Clean and conform the four Melbourne PTV source datasets.")
    parser.add_argument("--input", default=DEFAULT_INPUT,
                        help=f"Directory with raw source CSVs (default: {DEFAULT_INPUT})")
    parser.add_argument("--output", default=DEFAULT_OUTPUT,
                        help=f"Directory for cleaned CSVs (default: {DEFAULT_OUTPUT})")
    args = parser.parse_args()
    main(args.input, args.output)