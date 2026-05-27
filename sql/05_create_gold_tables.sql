-- Gold layer (run after sql/04_create_silver_tables.sql)
-- Conformed facts and dimensions for KPI logic (see docs/kpi_definitions.md).
-- Monthly / chart aggregates go in sql/06_create_dashboard_tables.sql.

DROP TABLE IF EXISTS gold_dataset_dates;
DROP TABLE IF EXISTS gold_dim_customer;
DROP TABLE IF EXISTS gold_fact_order_reviews;
DROP TABLE IF EXISTS gold_fact_order_payments;
DROP TABLE IF EXISTS gold_fact_order_items;
DROP TABLE IF EXISTS gold_fact_orders;
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
-- Optional indexes (uncomment for faster dashboard / gold queries)
-- -----------------------------------------------------------------------------
-- CREATE INDEX idx_gold_fact_orders_purchase_month ON gold_fact_orders (order_purchase_month);
-- CREATE INDEX idx_gold_fact_orders_is_delivered ON gold_fact_orders (is_delivered);
-- CREATE INDEX idx_gold_fact_order_items_purchase_month ON gold_fact_order_items (order_purchase_month);
-- CREATE INDEX idx_gold_fact_order_items_is_delivered ON gold_fact_order_items (is_delivered);
-- CREATE INDEX idx_gold_customer_delivered_orders_customer ON gold_customer_delivered_orders (customer_id);
-- CREATE INDEX idx_gold_customer_delivered_orders_purchase_ts ON gold_customer_delivered_orders (order_purchase_timestamp);
