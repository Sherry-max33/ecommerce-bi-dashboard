-- Silver layer (run after 01 + 02 load, optional after 03 validation)
-- Naming: silver_olist_* for 1:1 raw lineage; silver_products_join_* when join is the transform.
-- Other raw tables (customers, sellers, order_items, payments, reviews) stay as-is for joins.

DROP TABLE IF EXISTS silver_olist_geolocation_dedup;
DROP TABLE IF EXISTS silver_products_join_category_translation;
DROP TABLE IF EXISTS silver_olist_orders_dataset;


-- -----------------------------------------------------------------------------
-- silver_olist_geolocation_dedup — from raw_olist_geolocation_dataset, 5-col dedup
-- -----------------------------------------------------------------------------
CREATE TABLE silver_olist_geolocation_dedup AS
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM raw_olist_geolocation_dataset
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND geolocation_lat IS NOT NULL
  AND geolocation_lng IS NOT NULL
  AND geolocation_city IS NOT NULL
  AND geolocation_state IS NOT NULL
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state;


-- -----------------------------------------------------------------------------
-- silver_products_join_category_translation — products LEFT JOIN translation (Part 6)
--     (join result table; raw base: raw_olist_products_dataset)
-- -----------------------------------------------------------------------------
CREATE TABLE silver_products_join_category_translation AS
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(tr.product_category_name_english, 'Unknown') AS product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    (
        p.product_category_name IS NOT NULL
        AND tr.product_category_name IS NULL
    ) AS missing_translation_flag
FROM raw_olist_products_dataset p
LEFT JOIN raw_product_category_name_translation tr
    ON p.product_category_name = tr.product_category_name;


-- -----------------------------------------------------------------------------
-- silver_olist_orders_dataset — orders + delivery inconsistency flag (Part 5.2)
-- Timestamp nulls (approved / carrier / customer) are NOT imputed:
--   normal for canceled, in-transit, or not-yet-delivered orders (Part 8 ACCEPTABLE).
-- Filter by order_status or non-null timestamps in gold/KPI queries as needed.
-- -----------------------------------------------------------------------------
CREATE TABLE silver_olist_orders_dataset AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    (
        o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NULL
    ) AS is_delivery_inconsistency
FROM raw_olist_orders_dataset o;
