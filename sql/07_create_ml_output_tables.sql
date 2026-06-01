-- ML / forecast outputs for DBeaver (run after notebooks/03_forecasting_ml.ipynb exports CSVs).
-- Run: psql -d ecommerce -f sql/07_create_ml_output_tables.sql

DROP TABLE IF EXISTS ml_rf_feature_importance;
DROP TABLE IF EXISTS ml_rf_model_performance;
DROP TABLE IF EXISTS ml_forecast_result_monthly;
DROP TABLE IF EXISTS ml_forecast_result_daily;
DROP TABLE IF EXISTS ml_daily_business_metrics;

-- -----------------------------------------------------------------------------
-- ml_daily_business_metrics — daily delivered-order inputs (from notebook export)
-- -----------------------------------------------------------------------------
CREATE TABLE ml_daily_business_metrics (
    order_date         date PRIMARY KEY,
    orders             numeric NOT NULL,
    gmv                numeric NOT NULL,
    unique_customers   numeric NOT NULL
);

-- -----------------------------------------------------------------------------
-- ml_forecast_result_daily — recursive daily GMV forecast
-- -----------------------------------------------------------------------------
CREATE TABLE ml_forecast_result_daily (
    forecast_run_id                  text NOT NULL,
    generated_at                     timestamptz NOT NULL,
    order_date                       date NOT NULL,
    forecast_step                    integer NOT NULL,
    forecast_gmv                     numeric NOT NULL,
    forecast_orders                  numeric NOT NULL,
    forecast_daily_unique_customers  numeric NOT NULL,
    model                            text NOT NULL,
    PRIMARY KEY (forecast_run_id, order_date)
);

-- -----------------------------------------------------------------------------
-- ml_forecast_result_monthly — sum of daily forecasts by calendar month
-- -----------------------------------------------------------------------------
CREATE TABLE ml_forecast_result_monthly (
    month_start                              date NOT NULL,
    forecast_run_id                          text NOT NULL,
    generated_at                             timestamptz NOT NULL,
    forecast_gmv                             numeric NOT NULL,
    forecast_orders                          numeric NOT NULL,
    forecast_daily_unique_customers_sum      numeric NOT NULL,
    forecast_days                            integer NOT NULL,
    model                                    text NOT NULL,
    PRIMARY KEY (forecast_run_id, month_start)
);

-- -----------------------------------------------------------------------------
-- ml_rf_model_performance — holdout + CV metrics (long format)
-- -----------------------------------------------------------------------------
CREATE TABLE ml_rf_model_performance (
    forecast_run_id      text NOT NULL,
    model                text NOT NULL,
    best_params          text NOT NULL,
    test_split           text NOT NULL,
    cv_method            text NOT NULL,
    cv_splits            integer NOT NULL,
    cv_best_daily_rmse   numeric NOT NULL,
    train_start          date NOT NULL,
    train_end            date NOT NULL,
    test_start           date NOT NULL,
    test_end             date NOT NULL,
    train_rows           integer NOT NULL,
    test_rows            integer NOT NULL,
    monthly_test_rows    integer NOT NULL,
    metric_role          text NOT NULL,
    grain                text NOT NULL,
    metric               text NOT NULL,
    value                numeric NOT NULL,
    PRIMARY KEY (forecast_run_id, metric_role, grain, metric)
);

-- -----------------------------------------------------------------------------
-- ml_rf_feature_importance — one row per feature per model run
-- -----------------------------------------------------------------------------
CREATE TABLE ml_rf_feature_importance (
    forecast_run_id   text NOT NULL,
    generated_at      timestamptz NOT NULL,
    model             text NOT NULL,
    rank              integer NOT NULL,
    feature           text NOT NULL,
    importance        numeric NOT NULL,
    PRIMARY KEY (forecast_run_id, feature)
);

\copy ml_daily_business_metrics FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/processed/daily_business_metrics.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy ml_forecast_result_daily FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/output/forecast_result_daily.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy ml_forecast_result_monthly FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/output/forecast_result_monthly.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy ml_rf_model_performance FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/output/rf_model_performance.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy ml_rf_feature_importance FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/output/rf_feature_importance.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');
