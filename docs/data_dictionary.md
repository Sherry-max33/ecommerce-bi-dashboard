# Data Dictionary

## Raw sources (`data/raw/`)

| File | Table | Description |
|------|-------|-------------|
| `olist_customers_dataset.csv` | `raw_olist_customers_dataset` | Customer IDs and location |
| `olist_geolocation_dataset.csv` | `raw_olist_geolocation_dataset` | Zip → lat/lng, city, state |
| `olist_order_items_dataset.csv` | `raw_olist_order_items_dataset` | Line items: price, freight, seller |
| `olist_order_payments_dataset.csv` | `raw_olist_order_payments_dataset` | Payments per order |
| `olist_order_reviews_dataset.csv` | `raw_olist_order_reviews_dataset` | Review scores and text |
| `olist_orders_dataset.csv` | `raw_olist_orders_dataset` | Order lifecycle timestamps |
| `olist_products_dataset.csv` | `raw_olist_products_dataset` | Product attributes |
| `olist_sellers_dataset.csv` | `raw_olist_sellers_dataset` | Seller location |
| `product_category_name_translation.csv` | `raw_product_category_name_translation` | PT → EN category names |

## Outputs

| Path | Description |
|------|-------------|
| `data/output/forecast_result.csv` | Model forecast export |
| `data/processed/` | Intermediate tables for ML |

See `sql/01_create_raw_tables.sql` for column-level types.
