# E-Commerce Analytics Project

End-to-end analytics on Brazilian e-commerce (Olist) data: PostgreSQL warehouse (raw → silver → gold), Python pipelines, forecasting, and Power BI dashboards.

## Project structure

```
e_commerce_BI/
├── data/
│   ├── raw/           # Source CSVs (unchanged)
│   ├── processed/     # Intermediate Python outputs
│   └── output/        # forecast_result.csv, exports
├── sql/               # DDL, loads, validation, marts
├── notebooks/         # EDA, KPIs, ML, insights
├── powerbi/           # Dashboard (.pbix) and screenshots
├── src/               # Extract, load, forecast scripts
└── docs/              # Business context, dictionary, KPIs
```

## Setup

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Copy environment variables (see `src/config.py`) into `.env`:

```
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=ecommerce
POSTGRES_USER=your_user
POSTGRES_PASSWORD=your_password
```

## Database

From project root:

```bash
psql -d ecommerce -f sql/01_create_raw_tables.sql
psql -d ecommerce -f sql/02_load_raw_data.sql
psql -d ecommerce -f sql/03_data_validation.sql
psql -d ecommerce -f sql/04_create_silver_tables.sql
psql -d ecommerce -f sql/05_create_gold_tables.sql
psql -d ecommerce -f sql/06_create_dashboard_tables.sql
```

Or use the loader:

```bash
python -m src.load_to_postgres
```

## Notebooks

Run in order: `01_pandas_eda` → `02_kpi_testing` → `03_forecasting_ml` → `04_business_insights`.

## License

Educational / portfolio use. Olist dataset terms apply to source data.
