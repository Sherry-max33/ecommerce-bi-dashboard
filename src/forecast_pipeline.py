"""Forecast pipeline: reads from DB or processed data, writes data/output/forecast_result.csv."""

from pathlib import Path

import pandas as pd

from src.config import DATA_OUTPUT_DIR, DATA_PROCESSED_DIR


def run_forecast(input_path: Path | None = None) -> Path:
    """Placeholder forecast; replace with model from notebooks/03_forecasting_ml."""
    if input_path is None:
        input_path = DATA_PROCESSED_DIR / "monthly_revenue.csv"
    if not input_path.exists():
        raise FileNotFoundError(f"Input not found: {input_path}")

    df = pd.read_csv(input_path)
    out_path = DATA_OUTPUT_DIR / "forecast_result.csv"
    df.to_csv(out_path, index=False)
    return out_path


if __name__ == "__main__":
    try:
        path = run_forecast()
        print(f"Wrote {path}")
    except FileNotFoundError as err:
        print(err)
