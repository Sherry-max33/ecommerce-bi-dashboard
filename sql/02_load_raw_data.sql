-- Load raw CSVs into PostgreSQL.
-- Run: psql -f sql/02_load_raw_data.sql
-- Uses psql \copy (client-side) with absolute paths to data/raw.

\copy raw_olist_customers_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_geolocation_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_order_items_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_order_payments_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_order_reviews_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_orders_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_products_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_olist_sellers_dataset FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');

\copy raw_product_category_name_translation FROM '/Users/sherrywang/Desktop/ecommerce-bi-dashboard/data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', ESCAPE '"');
