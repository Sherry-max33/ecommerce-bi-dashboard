-- Gold layer (run after sql/04_create_silver_tables.sql)
-- Conformed facts and dimensions for KPI logic (see docs/kpi_definitions.md).
-- Monthly / chart aggregates go in sql/06_create_dashboard_tables.sql.

DROP TABLE IF EXISTS gold_dataset_dates;
DROP TABLE IF EXISTS gold_dim_date;
DROP TABLE IF EXISTS gold_dim_product;
DROP TABLE IF EXISTS gold_dim_unique_customer;
DROP TABLE IF EXISTS gold_dim_customer;
DROP TABLE IF EXISTS gold_fact_order_reviews;
DROP TABLE IF EXISTS gold_fact_order_payments;
DROP TABLE IF EXISTS gold_fact_order_items;
DROP TABLE IF EXISTS gold_fact_orders;
DROP TABLE IF EXISTS gold_customer_rfm;
DROP TABLE IF EXISTS gold_customer_delivered_orders;


-- -----------------------------------------------------------------------------
-- gold_dataset_dates — as-of date for rolling windows (retention 3m / 6m)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_dataset_dates AS
SELECT
    MAX(o.order_purchase_timestamp)::date AS as_of_date,
    MAX(o.order_purchase_timestamp) AS as_of_timestamp
FROM silver_olist_orders_dataset o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL;


-- -----------------------------------------------------------------------------
-- gold_dim_date — calendar dimension for Power BI relationships
-- One row per calendar date in the order purchase date range.
-- -----------------------------------------------------------------------------
CREATE TABLE gold_dim_date AS
WITH date_bounds AS (
    SELECT
        MIN(order_purchase_timestamp)::date AS min_date,
        MAX(order_purchase_timestamp)::date AS max_date
    FROM silver_olist_orders_dataset
    WHERE order_purchase_timestamp IS NOT NULL
),
date_spine AS (
    SELECT generate_series(min_date, max_date, INTERVAL '1 day')::date AS date_day
    FROM date_bounds
)
SELECT
    date_day,
    TO_CHAR(date_day, 'YYYYMMDD')::integer AS date_key,
    EXTRACT(YEAR FROM date_day)::integer AS year,
    EXTRACT(QUARTER FROM date_day)::integer AS quarter,
    ('Q' || EXTRACT(QUARTER FROM date_day)::integer) AS quarter_label,
    EXTRACT(MONTH FROM date_day)::integer AS month,
    TO_CHAR(date_day, 'FMMonth') AS month_name,
    TO_CHAR(date_day, 'Mon') AS month_short_name,
    TO_CHAR(date_day, 'YYYY-MM') AS year_month,
    TO_CHAR(date_day, 'YYYYMM')::integer AS year_month_key,
    DATE_TRUNC('month', date_day)::date AS month_start_date,
    EXTRACT(WEEK FROM date_day)::integer AS week_of_year,
    EXTRACT(ISODOW FROM date_day)::integer AS day_of_week,
    TO_CHAR(date_day, 'FMDay') AS day_name,
    TO_CHAR(date_day, 'Dy') AS day_short_name,
    (EXTRACT(ISODOW FROM date_day)::integer IN (6, 7)) AS is_weekend
FROM date_spine;


-- -----------------------------------------------------------------------------
-- gold_dim_customer — customers + geo per zip prefix (AVG lat/lng, MODE city/state)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_dim_customer AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.geolocation_lat AS customer_geo_lat,
    g.geolocation_lng AS customer_geo_lng,
    g.geolocation_city AS customer_geo_city,
    g.geolocation_state AS customer_geo_state
FROM raw_olist_customers_dataset c
LEFT JOIN (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS geolocation_lat,
        AVG(geolocation_lng) AS geolocation_lng,
        MODE() WITHIN GROUP (ORDER BY geolocation_city) AS geolocation_city,
        MODE() WITHIN GROUP (ORDER BY geolocation_state) AS geolocation_state
    FROM silver_olist_geolocation_dedup
    GROUP BY geolocation_zip_code_prefix
) g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;


-- -----------------------------------------------------------------------------
-- gold_dim_unique_customer — real customer dimension for Power BI relationships
-- Olist: customer_id is order-level; customer_unique_id is the real person.
-- One row per customer_unique_id, with representative location and lifecycle fields.
-- -----------------------------------------------------------------------------
CREATE TABLE gold_dim_unique_customer AS
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT c.customer_id) AS customer_id_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.order_id) FILTER (WHERE o.order_status = 'delivered') AS delivered_order_count,
    MIN(o.order_purchase_timestamp) AS first_order_purchase_timestamp,
    MAX(o.order_purchase_timestamp) AS last_order_purchase_timestamp,
    MIN(o.order_purchase_timestamp) FILTER (WHERE o.order_status = 'delivered') AS first_delivered_order_purchase_timestamp,
    MAX(o.order_purchase_timestamp) FILTER (WHERE o.order_status = 'delivered') AS last_delivered_order_purchase_timestamp,
    MODE() WITHIN GROUP (ORDER BY c.customer_zip_code_prefix) AS customer_zip_code_prefix,
    MODE() WITHIN GROUP (ORDER BY c.customer_city) AS customer_city,
    MODE() WITHIN GROUP (ORDER BY c.customer_state) AS customer_state,
    AVG(c.customer_geo_lat) AS customer_geo_lat,
    AVG(c.customer_geo_lng) AS customer_geo_lng,
    (COUNT(DISTINCT c.customer_id) > 1) AS has_multiple_customer_ids,
    (
        COUNT(DISTINCT c.customer_zip_code_prefix) > 1
        OR COUNT(DISTINCT c.customer_city) > 1
        OR COUNT(DISTINCT c.customer_state) > 1
    ) AS has_multiple_locations
FROM gold_dim_customer c
LEFT JOIN silver_olist_orders_dataset o
    ON c.customer_id = o.customer_id
WHERE c.customer_unique_id IS NOT NULL
GROUP BY c.customer_unique_id;


-- -----------------------------------------------------------------------------
-- gold_dim_product — product dimension for Power BI relationships
-- One row per product_id, with translated category and physical attributes.
-- -----------------------------------------------------------------------------
CREATE TABLE gold_dim_product AS
SELECT
    p.product_id,
    p.product_category_name,
    p.product_category_name_english AS category,
    INITCAP(REPLACE(COALESCE(p.product_category_name_english, 'unknown'), '_', ' ')) AS category_label,
    p.missing_translation_flag,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    CASE
        WHEN p.product_weight_g IS NOT NULL
        THEN p.product_weight_g / 1000.0
    END AS product_weight_kg,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    CASE
        WHEN p.product_length_cm IS NOT NULL
         AND p.product_height_cm IS NOT NULL
         AND p.product_width_cm IS NOT NULL
        THEN p.product_length_cm * p.product_height_cm * p.product_width_cm
    END AS product_volume_cm3
FROM silver_products_join_category_translation p;


-- -----------------------------------------------------------------------------
-- gold_fact_orders — order grain (KPIs: orders, delay, payments, installments, reviews)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_fact_orders AS
WITH order_items_agg AS (
    SELECT
        oi.order_id,
        COUNT(*) AS order_item_count,
        SUM(oi.price + COALESCE(oi.freight_value, 0)) AS order_gmv
    FROM raw_olist_order_items_dataset oi
    GROUP BY oi.order_id
),
order_payments_agg AS (
    SELECT
        p.order_id,
        COUNT(*) AS payment_row_count,
        SUM(p.payment_value) AS order_payment_total,
        BOOL_OR(p.payment_installments > 1) AS uses_installments
    FROM raw_olist_order_payments_dataset p
    GROUP BY p.order_id
),
-- Reviews: order_id and review_id are not unique alone; (review_id, order_id) is the row key.
-- Aggregate to order grain so this fact stays one row per order_id.
order_reviews_agg AS (
    SELECT
        r.order_id,
        COUNT(*) AS order_review_count,
        AVG(r.review_score) AS order_avg_review_score,
        MIN(r.review_creation_date) AS order_first_review_creation_date,
        MAX(r.review_creation_date) AS order_last_review_creation_date
    FROM raw_olist_order_reviews_dataset r
    WHERE r.order_id IS NOT NULL
    GROUP BY r.order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_purchase_month,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.is_delivery_inconsistency,
    (o.order_status = 'delivered') AS is_delivered,
    (
        o.order_status = 'delivered'
        AND NOT o.is_delivery_inconsistency
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
    ) AS is_valid_for_delivery_delay_kpi,
    (
        o.order_status = 'delivered'
        AND NOT o.is_delivery_inconsistency
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
        AND o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) AS is_delayed,
    COALESCE(oi.order_item_count, 0) AS order_item_count,
    COALESCE(oi.order_gmv, 0) AS order_gmv,
    COALESCE(op.payment_row_count, 0) AS payment_row_count,
    COALESCE(op.order_payment_total, 0) AS order_payment_total,
    COALESCE(op.uses_installments, false) AS uses_installments,
    COALESCE(rv.order_review_count, 0) AS order_review_count,
    rv.order_avg_review_score,
    rv.order_first_review_creation_date,
    rv.order_last_review_creation_date,
    (COALESCE(rv.order_review_count, 0) > 0) AS has_review
FROM silver_olist_orders_dataset o
LEFT JOIN raw_olist_customers_dataset c
    ON o.customer_id = c.customer_id
LEFT JOIN order_items_agg oi
    ON o.order_id = oi.order_id
LEFT JOIN order_payments_agg op
    ON o.order_id = op.order_id
LEFT JOIN order_reviews_agg rv
    ON o.order_id = rv.order_id;


-- -----------------------------------------------------------------------------
-- gold_fact_order_items — line-item grain (KPIs: GMV, top category, AOV numerator)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + COALESCE(oi.freight_value, 0) AS line_gmv,
    o.order_id IS NOT NULL AS has_order,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_purchase_month,
    o.customer_id,
    (o.order_status = 'delivered') AS is_delivered,
    o.is_delivery_inconsistency,
    p.product_category_name,
    p.product_category_name_english,
    INITCAP(REPLACE(COALESCE(p.product_category_name_english, 'unknown'), '_', ' ')) AS product_category_label,
    p.missing_translation_flag
FROM raw_olist_order_items_dataset oi
LEFT JOIN silver_olist_orders_dataset o
    ON oi.order_id = o.order_id
LEFT JOIN silver_products_join_category_translation p
    ON oi.product_id = p.product_id;


-- -----------------------------------------------------------------------------
-- gold_fact_order_payments — payment line grain (KPI: actual payment drill-down)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_fact_order_payments AS
SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    (p.payment_installments > 1) AS is_installment_payment,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_purchase_month,
    (o.order_status = 'delivered') AS is_delivered
FROM raw_olist_order_payments_dataset p
LEFT JOIN silver_olist_orders_dataset o
    ON p.order_id = o.order_id;


-- -----------------------------------------------------------------------------
-- gold_fact_order_reviews — one row per (review_id, order_id); use for KPI #6 AVG(review_score)
-- -----------------------------------------------------------------------------
CREATE TABLE gold_fact_order_reviews AS
SELECT
    r.review_id,
    r.order_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_purchase_month
FROM raw_olist_order_reviews_dataset r
INNER JOIN silver_olist_orders_dataset o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- -----------------------------------------------------------------------------
-- gold_customer_delivered_orders — one row per delivered order (KPI #4 repeat purchase)
-- Olist: customer_id is 1:1 with order_id; customer_unique_id is the real person.
-- Retention metrics must use customer_unique_id (2,801 repeat buyers on delivered orders).
-- -----------------------------------------------------------------------------
CREATE TABLE gold_customer_delivered_orders AS
SELECT
    c.customer_unique_id,
    o.customer_id,
    o.order_id,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS order_purchase_date
FROM silver_olist_orders_dataset o
INNER JOIN raw_olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND c.customer_unique_id IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL;


-- -----------------------------------------------------------------------------
-- gold_customer_rfm — customer-level RFM segmentation for Power BI
-- One row per customer_unique_id; delivered orders only.
-- -----------------------------------------------------------------------------
CREATE TABLE gold_customer_rfm AS
WITH customer_metrics AS (
    SELECT
        o.customer_unique_id,
        MAX(o.order_purchase_date) AS last_order_date,
        (d.as_of_date - MAX(o.order_purchase_date))::integer AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        SUM(o.order_gmv) AS monetary_gmv,
        SUM(o.order_gmv) / NULLIF(COUNT(DISTINCT o.order_id), 0) AS avg_order_value
    FROM gold_fact_orders o
    CROSS JOIN gold_dataset_dates d
    WHERE o.is_delivered
      AND o.customer_unique_id IS NOT NULL
      AND o.order_purchase_date IS NOT NULL
    GROUP BY
        o.customer_unique_id,
        d.as_of_date
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        last_order_date,
        recency_days,
        frequency_orders,
        monetary_gmv,
        avg_order_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        CASE
            WHEN frequency_orders >= 5 THEN 5
            WHEN frequency_orders = 4 THEN 4
            WHEN frequency_orders = 3 THEN 3
            WHEN frequency_orders = 2 THEN 2
            ELSE 1
        END AS f_score,
        NTILE(5) OVER (ORDER BY monetary_gmv ASC) AS m_score
    FROM customer_metrics
)
SELECT
    customer_unique_id,
    last_order_date,
    recency_days,
    frequency_orders,
    monetary_gmv,
    avg_order_value,
    r_score,
    f_score,
    m_score,
    (r_score * 100 + f_score * 10 + m_score) AS rfm_code,
    (r_score * 0.5 + f_score * 0.3 + m_score * 0.2) AS rfm_weighted_score,
    CASE
        WHEN r_score >= 4 AND frequency_orders >= 2 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND frequency_orders >= 2 THEN 'Loyal Customers'
        WHEN r_score <= 2 AND (frequency_orders >= 2 OR m_score >= 3) THEN 'At Risk'
        WHEN r_score <= 2 AND frequency_orders = 1 AND m_score <= 2 THEN 'Hibernating'
        WHEN r_score >= 3 AND frequency_orders = 1 AND m_score >= 4 THEN 'High-Value Customers'
        WHEN r_score >= 4 AND frequency_orders = 1 THEN 'Recent Customers'
        ELSE 'Other Customers'
    END AS customer_segment
FROM rfm_scores;


-- -----------------------------------------------------------------------------
-- Optional indexes (uncomment for faster dashboard / gold queries)
-- -----------------------------------------------------------------------------
-- CREATE INDEX idx_gold_dim_date_date_day ON gold_dim_date (date_day);
-- CREATE INDEX idx_gold_dim_product_product_id ON gold_dim_product (product_id);
-- CREATE INDEX idx_gold_dim_unique_customer_unique_id ON gold_dim_unique_customer (customer_unique_id);
-- CREATE INDEX idx_gold_customer_rfm_unique_id ON gold_customer_rfm (customer_unique_id);
-- CREATE INDEX idx_gold_customer_rfm_segment ON gold_customer_rfm (customer_segment);
-- CREATE INDEX idx_gold_fact_orders_purchase_month ON gold_fact_orders (order_purchase_month);
-- CREATE INDEX idx_gold_fact_orders_is_delivered ON gold_fact_orders (is_delivered);
-- CREATE INDEX idx_gold_fact_order_items_purchase_month ON gold_fact_order_items (order_purchase_month);
-- CREATE INDEX idx_gold_fact_order_items_is_delivered ON gold_fact_order_items (is_delivered);
-- CREATE INDEX idx_gold_customer_delivered_orders_customer ON gold_customer_delivered_orders (customer_id);
-- CREATE INDEX idx_gold_customer_delivered_orders_purchase_ts ON gold_customer_delivered_orders (order_purchase_timestamp);
