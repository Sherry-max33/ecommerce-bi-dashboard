-- =============================================================================
-- Data validation (run in DBeaver after 02_load_raw_data.sql)
-- Part 1: Structural Validation — whether data was imported successfully and completely
-- =============================================================================
-- Expected CSV row counts match Olist source files in data/raw/.
-- Re-run the row-count block below if you replace the CSVs.


-- -----------------------------------------------------------------------------
-- 1.1 Row Count — CSV row count vs table row count
-- -----------------------------------------------------------------------------
WITH expected_rows AS (
    SELECT *
    FROM (
        VALUES
            ('olist_customers_dataset.csv', 'raw_olist_customers_dataset', 99441::bigint),
            ('olist_geolocation_dataset.csv', 'raw_olist_geolocation_dataset', 1000163::bigint),
            ('olist_order_items_dataset.csv', 'raw_olist_order_items_dataset', 112650::bigint),
            ('olist_order_payments_dataset.csv', 'raw_olist_order_payments_dataset', 103886::bigint),
            ('olist_order_reviews_dataset.csv', 'raw_olist_order_reviews_dataset', 99224::bigint),
            ('olist_orders_dataset.csv', 'raw_olist_orders_dataset', 99441::bigint),
            ('olist_products_dataset.csv', 'raw_olist_products_dataset', 32951::bigint),
            ('olist_sellers_dataset.csv', 'raw_olist_sellers_dataset', 3095::bigint),
            ('product_category_name_translation.csv', 'raw_product_category_name_translation', 71::bigint)
    ) AS v(csv_file, table_name, csv_row_count)
),
table_rows AS (
    SELECT 'raw_olist_customers_dataset' AS table_name, COUNT(*)::bigint AS table_row_count
    FROM raw_olist_customers_dataset
    UNION ALL
    SELECT 'raw_olist_geolocation_dataset', COUNT(*)::bigint FROM raw_olist_geolocation_dataset
    UNION ALL
    SELECT 'raw_olist_order_items_dataset', COUNT(*)::bigint FROM raw_olist_order_items_dataset
    UNION ALL
    SELECT 'raw_olist_order_payments_dataset', COUNT(*)::bigint FROM raw_olist_order_payments_dataset
    UNION ALL
    SELECT 'raw_olist_order_reviews_dataset', COUNT(*)::bigint FROM raw_olist_order_reviews_dataset
    UNION ALL
    SELECT 'raw_olist_orders_dataset', COUNT(*)::bigint FROM raw_olist_orders_dataset
    UNION ALL
    SELECT 'raw_olist_products_dataset', COUNT(*)::bigint FROM raw_olist_products_dataset
    UNION ALL
    SELECT 'raw_olist_sellers_dataset', COUNT(*)::bigint FROM raw_olist_sellers_dataset
    UNION ALL
    SELECT 'raw_product_category_name_translation', COUNT(*)::bigint
    FROM raw_product_category_name_translation
)
SELECT
    e.csv_file,
    e.table_name,
    e.csv_row_count,
    t.table_row_count,
    t.table_row_count - e.csv_row_count AS row_diff,
    CASE
        WHEN t.table_row_count IS NULL THEN 'FAIL (table missing or empty)'
        WHEN t.table_row_count = e.csv_row_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM expected_rows e
LEFT JOIN table_rows t ON e.table_name = t.table_name
ORDER BY e.csv_file;


-- -----------------------------------------------------------------------------
-- 1.1 Summary — row count pass / fail counts
-- -----------------------------------------------------------------------------
WITH expected_rows AS (
    SELECT *
    FROM (
        VALUES
            ('raw_olist_customers_dataset', 99441::bigint),
            ('raw_olist_geolocation_dataset', 1000163::bigint),
            ('raw_olist_order_items_dataset', 112650::bigint),
            ('raw_olist_order_payments_dataset', 103886::bigint),
            ('raw_olist_order_reviews_dataset', 99224::bigint),
            ('raw_olist_orders_dataset', 99441::bigint),
            ('raw_olist_products_dataset', 32951::bigint),
            ('raw_olist_sellers_dataset', 3095::bigint),
            ('raw_product_category_name_translation', 71::bigint)
    ) AS v(table_name, csv_row_count)
),
table_rows AS (
    SELECT 'raw_olist_customers_dataset' AS table_name, COUNT(*)::bigint AS table_row_count
    FROM raw_olist_customers_dataset
    UNION ALL SELECT 'raw_olist_geolocation_dataset', COUNT(*)::bigint FROM raw_olist_geolocation_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', COUNT(*)::bigint FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_payments_dataset', COUNT(*)::bigint FROM raw_olist_order_payments_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', COUNT(*)::bigint FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', COUNT(*)::bigint FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', COUNT(*)::bigint FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_sellers_dataset', COUNT(*)::bigint FROM raw_olist_sellers_dataset
    UNION ALL SELECT 'raw_product_category_name_translation', COUNT(*)::bigint
    FROM raw_product_category_name_translation
),
checks AS (
    SELECT
        CASE
            WHEN t.table_row_count IS NULL OR t.table_row_count <> e.csv_row_count THEN 'FAIL'
            ELSE 'PASS'
        END AS status
    FROM expected_rows e
    LEFT JOIN table_rows t ON e.table_name = t.table_name
)
SELECT
    COUNT(*) FILTER (WHERE status = 'PASS') AS pass_count,
    COUNT(*) FILTER (WHERE status = 'FAIL') AS fail_count,
    COUNT(*) AS total_tables,
    CASE WHEN COUNT(*) FILTER (WHERE status = 'FAIL') = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status
FROM checks;


-- -----------------------------------------------------------------------------
-- 1.2 Column count — CSV column count vs table column count
-- -----------------------------------------------------------------------------
WITH expected_col_count AS (
    SELECT *
    FROM (
        VALUES
            ('olist_customers_dataset.csv', 'raw_olist_customers_dataset', 5),
            ('olist_geolocation_dataset.csv', 'raw_olist_geolocation_dataset', 5),
            ('olist_order_items_dataset.csv', 'raw_olist_order_items_dataset', 7),
            ('olist_order_payments_dataset.csv', 'raw_olist_order_payments_dataset', 5),
            ('olist_order_reviews_dataset.csv', 'raw_olist_order_reviews_dataset', 7),
            ('olist_orders_dataset.csv', 'raw_olist_orders_dataset', 8),
            ('olist_products_dataset.csv', 'raw_olist_products_dataset', 9),
            ('olist_sellers_dataset.csv', 'raw_olist_sellers_dataset', 4),
            ('product_category_name_translation.csv', 'raw_product_category_name_translation', 2)
    ) AS v(csv_file, table_name, csv_column_count)
),
actual_col_count AS (
    SELECT
        c.table_name,
        COUNT(*)::int AS table_column_count
    FROM information_schema.columns c
    WHERE c.table_schema = current_schema()
      AND c.table_name LIKE 'raw\_%' ESCAPE '\'
    GROUP BY c.table_name
)
SELECT
    e.csv_file,
    e.table_name,
    e.csv_column_count,
    a.table_column_count,
    COALESCE(a.table_column_count, 0) - e.csv_column_count AS column_diff,
    CASE
        WHEN a.table_column_count IS NULL THEN 'FAIL (table not found)'
        WHEN a.table_column_count = e.csv_column_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM expected_col_count e
LEFT JOIN actual_col_count a ON e.table_name = a.table_name
ORDER BY e.csv_file;


-- -----------------------------------------------------------------------------
-- 1.2 Schema check — column names and order match DDL
--     (misaligned / missing / extra columns appear as FAIL)
-- -----------------------------------------------------------------------------
WITH expected_schema AS (
    SELECT *
    FROM (
        VALUES
            ('raw_olist_customers_dataset', 1, 'customer_id'),
            ('raw_olist_customers_dataset', 2, 'customer_unique_id'),
            ('raw_olist_customers_dataset', 3, 'customer_zip_code_prefix'),
            ('raw_olist_customers_dataset', 4, 'customer_city'),
            ('raw_olist_customers_dataset', 5, 'customer_state'),
            ('raw_olist_geolocation_dataset', 1, 'geolocation_zip_code_prefix'),
            ('raw_olist_geolocation_dataset', 2, 'geolocation_lat'),
            ('raw_olist_geolocation_dataset', 3, 'geolocation_lng'),
            ('raw_olist_geolocation_dataset', 4, 'geolocation_city'),
            ('raw_olist_geolocation_dataset', 5, 'geolocation_state'),
            ('raw_olist_order_items_dataset', 1, 'order_id'),
            ('raw_olist_order_items_dataset', 2, 'order_item_id'),
            ('raw_olist_order_items_dataset', 3, 'product_id'),
            ('raw_olist_order_items_dataset', 4, 'seller_id'),
            ('raw_olist_order_items_dataset', 5, 'shipping_limit_date'),
            ('raw_olist_order_items_dataset', 6, 'price'),
            ('raw_olist_order_items_dataset', 7, 'freight_value'),
            ('raw_olist_order_payments_dataset', 1, 'order_id'),
            ('raw_olist_order_payments_dataset', 2, 'payment_sequential'),
            ('raw_olist_order_payments_dataset', 3, 'payment_type'),
            ('raw_olist_order_payments_dataset', 4, 'payment_installments'),
            ('raw_olist_order_payments_dataset', 5, 'payment_value'),
            ('raw_olist_order_reviews_dataset', 1, 'review_id'),
            ('raw_olist_order_reviews_dataset', 2, 'order_id'),
            ('raw_olist_order_reviews_dataset', 3, 'review_score'),
            ('raw_olist_order_reviews_dataset', 4, 'review_comment_title'),
            ('raw_olist_order_reviews_dataset', 5, 'review_comment_message'),
            ('raw_olist_order_reviews_dataset', 6, 'review_creation_date'),
            ('raw_olist_order_reviews_dataset', 7, 'review_answer_timestamp'),
            ('raw_olist_orders_dataset', 1, 'order_id'),
            ('raw_olist_orders_dataset', 2, 'customer_id'),
            ('raw_olist_orders_dataset', 3, 'order_status'),
            ('raw_olist_orders_dataset', 4, 'order_purchase_timestamp'),
            ('raw_olist_orders_dataset', 5, 'order_approved_at'),
            ('raw_olist_orders_dataset', 6, 'order_delivered_carrier_date'),
            ('raw_olist_orders_dataset', 7, 'order_delivered_customer_date'),
            ('raw_olist_orders_dataset', 8, 'order_estimated_delivery_date'),
            ('raw_olist_products_dataset', 1, 'product_id'),
            ('raw_olist_products_dataset', 2, 'product_category_name'),
            ('raw_olist_products_dataset', 3, 'product_name_lenght'),
            ('raw_olist_products_dataset', 4, 'product_description_lenght'),
            ('raw_olist_products_dataset', 5, 'product_photos_qty'),
            ('raw_olist_products_dataset', 6, 'product_weight_g'),
            ('raw_olist_products_dataset', 7, 'product_length_cm'),
            ('raw_olist_products_dataset', 8, 'product_height_cm'),
            ('raw_olist_products_dataset', 9, 'product_width_cm'),
            ('raw_olist_sellers_dataset', 1, 'seller_id'),
            ('raw_olist_sellers_dataset', 2, 'seller_zip_code_prefix'),
            ('raw_olist_sellers_dataset', 3, 'seller_city'),
            ('raw_olist_sellers_dataset', 4, 'seller_state'),
            ('raw_product_category_name_translation', 1, 'product_category_name'),
            ('raw_product_category_name_translation', 2, 'product_category_name_english')
    ) AS v(table_name, expected_position, expected_column)
),
actual_schema AS (
    SELECT
        c.table_name,
        c.ordinal_position,
        c.column_name
    FROM information_schema.columns c
    WHERE c.table_schema = current_schema()
      AND c.table_name LIKE 'raw\_%' ESCAPE '\'
)
SELECT
    COALESCE(e.table_name, a.table_name) AS table_name,
    e.expected_position,
    e.expected_column,
    a.ordinal_position AS actual_position,
    a.column_name AS actual_column,
    CASE
        WHEN e.expected_column IS NULL THEN 'FAIL (extra column in table)'
        WHEN a.column_name IS NULL THEN 'FAIL (missing column in table)'
        WHEN e.expected_position <> a.ordinal_position THEN 'FAIL (wrong column order)'
        WHEN e.expected_column <> a.column_name THEN 'FAIL (column name mismatch)'
        ELSE 'PASS'
    END AS status
FROM expected_schema e
FULL OUTER JOIN actual_schema a
    ON e.table_name = a.table_name
   AND e.expected_position = a.ordinal_position
WHERE
    e.expected_column IS NULL
    OR a.column_name IS NULL
    OR e.expected_position <> a.ordinal_position
    OR e.expected_column <> a.column_name
ORDER BY table_name, COALESCE(e.expected_position, a.ordinal_position);


-- -----------------------------------------------------------------------------
-- 1.2 Schema summary — returns 0 rows when OK; summary below shows PASS
-- -----------------------------------------------------------------------------
WITH expected_schema AS (
    SELECT table_name, expected_position, expected_column
    FROM (
        VALUES
            ('raw_olist_customers_dataset', 1, 'customer_id'),
            ('raw_olist_customers_dataset', 2, 'customer_unique_id'),
            ('raw_olist_customers_dataset', 3, 'customer_zip_code_prefix'),
            ('raw_olist_customers_dataset', 4, 'customer_city'),
            ('raw_olist_customers_dataset', 5, 'customer_state'),
            ('raw_olist_geolocation_dataset', 1, 'geolocation_zip_code_prefix'),
            ('raw_olist_geolocation_dataset', 2, 'geolocation_lat'),
            ('raw_olist_geolocation_dataset', 3, 'geolocation_lng'),
            ('raw_olist_geolocation_dataset', 4, 'geolocation_city'),
            ('raw_olist_geolocation_dataset', 5, 'geolocation_state'),
            ('raw_olist_order_items_dataset', 1, 'order_id'),
            ('raw_olist_order_items_dataset', 2, 'order_item_id'),
            ('raw_olist_order_items_dataset', 3, 'product_id'),
            ('raw_olist_order_items_dataset', 4, 'seller_id'),
            ('raw_olist_order_items_dataset', 5, 'shipping_limit_date'),
            ('raw_olist_order_items_dataset', 6, 'price'),
            ('raw_olist_order_items_dataset', 7, 'freight_value'),
            ('raw_olist_order_payments_dataset', 1, 'order_id'),
            ('raw_olist_order_payments_dataset', 2, 'payment_sequential'),
            ('raw_olist_order_payments_dataset', 3, 'payment_type'),
            ('raw_olist_order_payments_dataset', 4, 'payment_installments'),
            ('raw_olist_order_payments_dataset', 5, 'payment_value'),
            ('raw_olist_order_reviews_dataset', 1, 'review_id'),
            ('raw_olist_order_reviews_dataset', 2, 'order_id'),
            ('raw_olist_order_reviews_dataset', 3, 'review_score'),
            ('raw_olist_order_reviews_dataset', 4, 'review_comment_title'),
            ('raw_olist_order_reviews_dataset', 5, 'review_comment_message'),
            ('raw_olist_order_reviews_dataset', 6, 'review_creation_date'),
            ('raw_olist_order_reviews_dataset', 7, 'review_answer_timestamp'),
            ('raw_olist_orders_dataset', 1, 'order_id'),
            ('raw_olist_orders_dataset', 2, 'customer_id'),
            ('raw_olist_orders_dataset', 3, 'order_status'),
            ('raw_olist_orders_dataset', 4, 'order_purchase_timestamp'),
            ('raw_olist_orders_dataset', 5, 'order_approved_at'),
            ('raw_olist_orders_dataset', 6, 'order_delivered_carrier_date'),
            ('raw_olist_orders_dataset', 7, 'order_delivered_customer_date'),
            ('raw_olist_orders_dataset', 8, 'order_estimated_delivery_date'),
            ('raw_olist_products_dataset', 1, 'product_id'),
            ('raw_olist_products_dataset', 2, 'product_category_name'),
            ('raw_olist_products_dataset', 3, 'product_name_lenght'),
            ('raw_olist_products_dataset', 4, 'product_description_lenght'),
            ('raw_olist_products_dataset', 5, 'product_photos_qty'),
            ('raw_olist_products_dataset', 6, 'product_weight_g'),
            ('raw_olist_products_dataset', 7, 'product_length_cm'),
            ('raw_olist_products_dataset', 8, 'product_height_cm'),
            ('raw_olist_products_dataset', 9, 'product_width_cm'),
            ('raw_olist_sellers_dataset', 1, 'seller_id'),
            ('raw_olist_sellers_dataset', 2, 'seller_zip_code_prefix'),
            ('raw_olist_sellers_dataset', 3, 'seller_city'),
            ('raw_olist_sellers_dataset', 4, 'seller_state'),
            ('raw_product_category_name_translation', 1, 'product_category_name'),
            ('raw_product_category_name_translation', 2, 'product_category_name_english')
    ) AS v(table_name, expected_position, expected_column)
),
actual_schema AS (
    SELECT c.table_name, c.ordinal_position, c.column_name
    FROM information_schema.columns c
    WHERE c.table_schema = current_schema()
      AND c.table_name LIKE 'raw\_%' ESCAPE '\'
),
mismatches AS (
    SELECT 1
    FROM expected_schema e
    FULL OUTER JOIN actual_schema a
        ON e.table_name = a.table_name
       AND e.expected_position = a.ordinal_position
    WHERE
        e.expected_column IS NULL
        OR a.column_name IS NULL
        OR e.expected_position <> a.ordinal_position
        OR e.expected_column <> a.column_name
    LIMIT 1
)
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM mismatches) THEN 'FAIL (see schema detail query above)'
        ELSE 'PASS'
    END AS schema_overall_status,
    (SELECT COUNT(*) FROM expected_schema) AS expected_column_definitions,
    (SELECT COUNT(*) FROM actual_schema) AS actual_column_definitions;


-- -----------------------------------------------------------------------------
-- 1.3 Delimiter / parse sanity — timestamps parsed (all NULL may indicate delimiter misalignment)
-- -----------------------------------------------------------------------------
SELECT 'raw_olist_order_items_dataset.shipping_limit_date' AS check_name,
       COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS null_count,
       COUNT(*) AS total_rows,
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END AS status
FROM raw_olist_order_items_dataset
UNION ALL
SELECT 'raw_olist_order_reviews_dataset.review_creation_date',
       COUNT(*) FILTER (WHERE review_creation_date IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE review_creation_date IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_reviews_dataset
UNION ALL
SELECT 'raw_olist_order_reviews_dataset.review_answer_timestamp',
       COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_reviews_dataset
UNION ALL
SELECT 'raw_olist_orders_dataset.order_purchase_timestamp',
       COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'raw_olist_orders_dataset.order_approved_at',
       COUNT(*) FILTER (WHERE order_approved_at IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_approved_at IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'raw_olist_orders_dataset.order_delivered_carrier_date',
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'raw_olist_orders_dataset.order_delivered_customer_date',
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'raw_olist_orders_dataset.order_estimated_delivery_date',
       COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) = COUNT(*) THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset;


-- =============================================================================
-- Part 2: Completeness Validation — key fields are complete
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 2.1a Null Check — Critical ID columns (any NULL → FAIL)
-- -----------------------------------------------------------------------------
SELECT 'critical_id' AS check_type,
       'raw_olist_orders_dataset.order_id' AS check_name,
       COUNT(*) FILTER (WHERE order_id IS NULL) AS null_count,
       COUNT(*) AS total_rows,
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END AS status
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_orders_dataset.customer_id',
       COUNT(*) FILTER (WHERE customer_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE customer_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_customers_dataset.customer_id',
       COUNT(*) FILTER (WHERE customer_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE customer_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_customers_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_customers_dataset.customer_unique_id',
       COUNT(*) FILTER (WHERE customer_unique_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE customer_unique_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_customers_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_items_dataset.order_id',
       COUNT(*) FILTER (WHERE order_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_items_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_items_dataset.product_id',
       COUNT(*) FILTER (WHERE product_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE product_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_items_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_items_dataset.seller_id',
       COUNT(*) FILTER (WHERE seller_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE seller_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_items_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_items_dataset.order_item_id',
       COUNT(*) FILTER (WHERE order_item_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_item_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_items_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_payments_dataset.order_id',
       COUNT(*) FILTER (WHERE order_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_payments_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_payments_dataset.payment_sequential',
       COUNT(*) FILTER (WHERE payment_sequential IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE payment_sequential IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_payments_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_reviews_dataset.review_id',
       COUNT(*) FILTER (WHERE review_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE review_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_reviews_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_order_reviews_dataset.order_id',
       COUNT(*) FILTER (WHERE order_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE order_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_reviews_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_products_dataset.product_id',
       COUNT(*) FILTER (WHERE product_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE product_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_products_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_sellers_dataset.seller_id',
       COUNT(*) FILTER (WHERE seller_id IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE seller_id IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_sellers_dataset
UNION ALL
SELECT 'critical_id',
       'raw_olist_geolocation_dataset.geolocation_zip_code_prefix',
       COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_geolocation_dataset
UNION ALL
SELECT 'critical_id',
       'raw_product_category_name_translation.product_category_name',
       COUNT(*) FILTER (WHERE product_category_name IS NULL),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (WHERE product_category_name IS NULL) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_product_category_name_translation;


-- -----------------------------------------------------------------------------
-- 2.1b Null Check — Business numeric columns (null_rate > 5% → FAIL)
-- -----------------------------------------------------------------------------
SELECT
    'business_numeric' AS check_type,
    check_name,
    null_count,
    total_rows,
    null_rate_pct,
    5.0 AS fail_threshold_pct,
    status
FROM (
    SELECT 'raw_olist_order_items_dataset.price' AS check_name,
           COUNT(*) FILTER (WHERE price IS NULL) AS null_count,
           COUNT(*) AS total_rows,
           ROUND(100.0 * COUNT(*) FILTER (WHERE price IS NULL) / NULLIF(COUNT(*), 0), 2) AS null_rate_pct,
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN 100.0 * COUNT(*) FILTER (WHERE price IS NULL) / NULLIF(COUNT(*), 0) > 5 THEN 'FAIL'
               ELSE 'PASS'
           END AS status
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_items_dataset.freight_value',
           COUNT(*) FILTER (WHERE freight_value IS NULL),
           COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE freight_value IS NULL) / NULLIF(COUNT(*), 0), 2),
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN 100.0 * COUNT(*) FILTER (WHERE freight_value IS NULL) / NULLIF(COUNT(*), 0) > 5 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_payments_dataset.payment_value',
           COUNT(*) FILTER (WHERE payment_value IS NULL),
           COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE payment_value IS NULL) / NULLIF(COUNT(*), 0), 2),
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN 100.0 * COUNT(*) FILTER (WHERE payment_value IS NULL) / NULLIF(COUNT(*), 0) > 5 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_order_payments_dataset
) business_numeric_checks;


-- =============================================================================
-- Part 3: Uniqueness Validation — primary / composite key duplicates
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 3.1 Primary Key Duplicate — single-column PK duplicates (duplicate groups → FAIL)
-- -----------------------------------------------------------------------------
SELECT 'primary_key' AS check_type,
       'raw_olist_orders_dataset.order_id' AS check_name,
       COUNT(*) AS duplicate_key_groups,
       COALESCE(SUM(cnt - 1), 0)::bigint AS duplicate_extra_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT order_id, COUNT(*) AS cnt
    FROM raw_olist_orders_dataset
    WHERE order_id IS NOT NULL
    GROUP BY order_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_olist_customers_dataset.customer_id',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT customer_id, COUNT(*) AS cnt
    FROM raw_olist_customers_dataset
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_olist_customers_dataset.customer_unique_id',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT customer_unique_id, COUNT(*) AS cnt
    FROM raw_olist_customers_dataset
    WHERE customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_olist_products_dataset.product_id',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT product_id, COUNT(*) AS cnt
    FROM raw_olist_products_dataset
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_olist_sellers_dataset.seller_id',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT seller_id, COUNT(*) AS cnt
    FROM raw_olist_sellers_dataset
    WHERE seller_id IS NOT NULL
    GROUP BY seller_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_olist_order_reviews_dataset.review_id',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT review_id, COUNT(*) AS cnt
    FROM raw_olist_order_reviews_dataset
    WHERE review_id IS NOT NULL
    GROUP BY review_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'primary_key',
       'raw_product_category_name_translation.product_category_name',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT product_category_name, COUNT(*) AS cnt
    FROM raw_product_category_name_translation
    WHERE product_category_name IS NOT NULL
    GROUP BY product_category_name
    HAVING COUNT(*) > 1
) d;


-- -----------------------------------------------------------------------------
-- 3.1b Review ID probe — review_id alone may not be PK; test (review_id, order_id)
-- -----------------------------------------------------------------------------
SELECT
    'id_probe' AS check_type,
    'raw_olist_order_reviews_dataset' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS distinct_review_id,
    (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT review_id, order_id
            FROM raw_olist_order_reviews_dataset
            WHERE review_id IS NOT NULL AND order_id IS NOT NULL
        ) pairs
    ) AS distinct_review_order_pairs,
    COUNT(*) - COUNT(DISTINCT review_id) AS duplicate_rows_by_review_id_only,
    COUNT(*) - (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT review_id, order_id
            FROM raw_olist_order_reviews_dataset
            WHERE review_id IS NOT NULL AND order_id IS NOT NULL
        ) pairs
    ) AS duplicate_rows_by_review_order_pair,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) = COUNT(DISTINCT review_id) THEN 'review_id alone is unique (PK candidate)'
        ELSE 'review_id alone is NOT unique'
    END AS review_id_uniqueness,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) = (
            SELECT COUNT(*)
            FROM (
                SELECT DISTINCT review_id, order_id
                FROM raw_olist_order_reviews_dataset
                WHERE review_id IS NOT NULL AND order_id IS NOT NULL
            ) pairs
        )
        THEN 'PASS — (review_id, order_id) is unique'
        ELSE 'FAIL — (review_id, order_id) has duplicates'
    END AS review_order_pair_uniqueness
FROM raw_olist_order_reviews_dataset;


-- -----------------------------------------------------------------------------
-- 3.2 Composite Key Duplicate — composite key duplicates (duplicate groups → FAIL)
-- -----------------------------------------------------------------------------
SELECT 'composite_key' AS check_type,
       'raw_olist_order_items_dataset (order_id, order_item_id)' AS check_name,
       COUNT(*) AS duplicate_key_groups,
       COALESCE(SUM(cnt - 1), 0)::bigint AS duplicate_extra_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT order_id, order_item_id, COUNT(*) AS cnt
    FROM raw_olist_order_items_dataset
    WHERE order_id IS NOT NULL AND order_item_id IS NOT NULL
    GROUP BY order_id, order_item_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'composite_key',
       'raw_olist_order_payments_dataset (order_id, payment_sequential)',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT order_id, payment_sequential, COUNT(*) AS cnt
    FROM raw_olist_order_payments_dataset
    WHERE order_id IS NOT NULL AND payment_sequential IS NOT NULL
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'composite_key',
       'raw_olist_order_reviews_dataset (review_id, order_id)',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT review_id, order_id, COUNT(*) AS cnt
    FROM raw_olist_order_reviews_dataset
    WHERE review_id IS NOT NULL AND order_id IS NOT NULL
    GROUP BY review_id, order_id
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'composite_key',
       'raw_olist_geolocation_dataset (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)',
       COUNT(*),
       COALESCE(SUM(cnt - 1), 0)::bigint,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, COUNT(*) AS cnt
    FROM raw_olist_geolocation_dataset
    WHERE geolocation_zip_code_prefix IS NOT NULL
      AND geolocation_lat IS NOT NULL
      AND geolocation_lng IS NOT NULL
    GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng
    HAVING COUNT(*) > 1
) d;


-- -----------------------------------------------------------------------------
-- 3.2b Geolocation key probe — run after 3.2 when (zip, lat, lng) still has duplicates
--     Test whether adding city + state makes rows unique
-- -----------------------------------------------------------------------------
SELECT
    'id_probe' AS check_type,
    'raw_olist_geolocation_dataset' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip,
    (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT
                geolocation_zip_code_prefix,
                geolocation_lat,
                geolocation_lng
            FROM raw_olist_geolocation_dataset
            WHERE geolocation_zip_code_prefix IS NOT NULL
              AND geolocation_lat IS NOT NULL
              AND geolocation_lng IS NOT NULL
        ) t
    ) AS distinct_zip_lat_lng,
    (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT
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
        ) t
    ) AS distinct_full_5_columns,
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) AS duplicate_rows_by_zip_only,
    COUNT(*) - (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT
                geolocation_zip_code_prefix,
                geolocation_lat,
                geolocation_lng
            FROM raw_olist_geolocation_dataset
            WHERE geolocation_zip_code_prefix IS NOT NULL
              AND geolocation_lat IS NOT NULL
              AND geolocation_lng IS NOT NULL
        ) t
    ) AS duplicate_rows_by_zip_lat_lng,
    COUNT(*) - (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT
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
        ) t
    ) AS duplicate_rows_by_full_5_columns,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) = COUNT(DISTINCT geolocation_zip_code_prefix) THEN 'zip alone is unique'
        ELSE 'zip alone is NOT unique'
    END AS zip_uniqueness,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) = (
            SELECT COUNT(*)
            FROM (
                SELECT DISTINCT
                    geolocation_zip_code_prefix,
                    geolocation_lat,
                    geolocation_lng
                FROM raw_olist_geolocation_dataset
                WHERE geolocation_zip_code_prefix IS NOT NULL
                  AND geolocation_lat IS NOT NULL
                  AND geolocation_lng IS NOT NULL
            ) t
        )
        THEN 'PASS — (zip, lat, lng) is unique'
        ELSE 'FAIL — (zip, lat, lng) has duplicates (see 3.2 duplicate_key_groups)'
    END AS zip_lat_lng_uniqueness,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) = (
            SELECT COUNT(*)
            FROM (
                SELECT DISTINCT
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
            ) t
        )
        THEN 'PASS — 5-column composite is unique'
        ELSE 'FAIL — 5-column composite still has duplicates'
    END AS full_5_column_uniqueness
FROM raw_olist_geolocation_dataset;


-- =============================================================================
-- Part 4: Validity Validation — values are reasonable
-- =============================================================================
-- Olist purchase/review range approx. 2016-09 ~ 2018-10; shipping_limit_date may extend later (ship-by deadline)


-- -----------------------------------------------------------------------------
-- 4.1 Category Validation — categorical / status fields within allowed values
-- -----------------------------------------------------------------------------
SELECT 'category' AS check_type,
       'raw_olist_orders_dataset.order_status' AS check_name,
       COUNT(*) FILTER (
           WHERE order_status IS NOT NULL
             AND order_status NOT IN (
                 'created', 'approved', 'invoiced', 'processing',
                 'shipped', 'delivered', 'canceled', 'unavailable'
             )
       ) AS invalid_count,
       COUNT(*) AS total_rows,
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (
               WHERE order_status IS NOT NULL
                 AND order_status NOT IN (
                     'created', 'approved', 'invoiced', 'processing',
                     'shipped', 'delivered', 'canceled', 'unavailable'
                 )
           ) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END AS status
FROM raw_olist_orders_dataset
UNION ALL
SELECT 'category',
       'raw_olist_order_payments_dataset.payment_type',
       COUNT(*) FILTER (
           WHERE payment_type IS NOT NULL
             AND payment_type NOT IN (
                 'credit_card', 'boleto', 'voucher', 'debit_card', 'not_defined'
             )
       ),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (
               WHERE payment_type IS NOT NULL
                 AND payment_type NOT IN (
                     'credit_card', 'boleto', 'voucher', 'debit_card', 'not_defined'
                 )
           ) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_payments_dataset
UNION ALL
SELECT 'category',
       'raw_olist_order_reviews_dataset.review_score (1-5)',
       COUNT(*) FILTER (
           WHERE review_score IS NOT NULL
             AND (review_score < 1 OR review_score > 5 OR review_score <> TRUNC(review_score))
       ),
       COUNT(*),
       CASE
           WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
           WHEN COUNT(*) FILTER (
               WHERE review_score IS NOT NULL
                 AND (review_score < 1 OR review_score > 5 OR review_score <> TRUNC(review_score))
           ) > 0 THEN 'FAIL'
           ELSE 'PASS'
       END
FROM raw_olist_order_reviews_dataset;


-- -----------------------------------------------------------------------------
-- 4.2a Numeric Range — amounts / installments (MIN/MAX only, manual review, no auto FAIL)
--     amounts / installments < 0 fail in 4.2b; >= 0 is valid (including payment_installments = 0)
-- -----------------------------------------------------------------------------
SELECT 'numeric_range' AS check_type,
       check_name,
       non_null_count,
       min_value,
       max_value,
       avg_value,
       'INFO (review min/max)' AS status
FROM (
    SELECT 'raw_olist_order_items_dataset.price' AS check_name,
           COUNT(price) AS non_null_count,
           MIN(price) AS min_value,
           MAX(price) AS max_value,
           ROUND(AVG(price)::numeric, 2) AS avg_value
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_items_dataset.freight_value',
           COUNT(freight_value),
           MIN(freight_value),
           MAX(freight_value),
           ROUND(AVG(freight_value)::numeric, 2)
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_payments_dataset.payment_value',
           COUNT(payment_value),
           MIN(payment_value),
           MAX(payment_value),
           ROUND(AVG(payment_value)::numeric, 2)
    FROM raw_olist_order_payments_dataset

    UNION ALL

    SELECT 'raw_olist_order_payments_dataset.payment_installments',
           COUNT(payment_installments),
           MIN(payment_installments),
           MAX(payment_installments),
           ROUND(AVG(payment_installments)::numeric, 2)
    FROM raw_olist_order_payments_dataset
) amount_ranges;


-- -----------------------------------------------------------------------------
-- 4.2b Numeric Validation — other hard rules (violations → FAIL)
-- -----------------------------------------------------------------------------
SELECT 'numeric' AS check_type,
       check_name,
       invalid_count,
       total_rows,
       invalid_rule,
       status
FROM (
    SELECT 'raw_olist_order_items_dataset.price < 0' AS check_name,
           COUNT(*) FILTER (WHERE price IS NOT NULL AND price < 0) AS invalid_count,
           COUNT(*) AS total_rows,
           'amount must be >= 0' AS invalid_rule,
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (WHERE price IS NOT NULL AND price < 0) > 0 THEN 'FAIL'
               ELSE 'PASS'
           END AS status
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_items_dataset.freight_value < 0',
           COUNT(*) FILTER (WHERE freight_value IS NOT NULL AND freight_value < 0),
           COUNT(*),
           'amount must be >= 0',
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (WHERE freight_value IS NOT NULL AND freight_value < 0) > 0 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_order_items_dataset

    UNION ALL

    SELECT 'raw_olist_order_payments_dataset.payment_value < 0',
           COUNT(*) FILTER (WHERE payment_value IS NOT NULL AND payment_value < 0),
           COUNT(*),
           'amount must be >= 0',
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (WHERE payment_value IS NOT NULL AND payment_value < 0) > 0 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_order_payments_dataset

    UNION ALL

    SELECT 'raw_olist_order_payments_dataset.payment_installments < 0',
           COUNT(*) FILTER (WHERE payment_installments IS NOT NULL AND payment_installments < 0),
           COUNT(*),
           'payment_installments must be >= 0',
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (WHERE payment_installments IS NOT NULL AND payment_installments < 0) > 0
               THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_order_payments_dataset

    UNION ALL

    SELECT 'raw_olist_products_dataset.product_weight_g < 0',
           COUNT(*) FILTER (WHERE product_weight_g IS NOT NULL AND product_weight_g < 0),
           COUNT(*),
           'negative value',
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (WHERE product_weight_g IS NOT NULL AND product_weight_g < 0) > 0 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_products_dataset

    UNION ALL

    SELECT 'raw_olist_geolocation_dataset.lat/lng out of Brazil range',
           COUNT(*) FILTER (
               WHERE (geolocation_lat IS NOT NULL AND (geolocation_lat < -35 OR geolocation_lat > 6))
                  OR (geolocation_lng IS NOT NULL AND (geolocation_lng < -75 OR geolocation_lng > -28))
           ),
           COUNT(*),
           'lat not in [-35,6] or lng not in [-75,-28]',
           CASE
               WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
               WHEN COUNT(*) FILTER (
                   WHERE (geolocation_lat IS NOT NULL AND (geolocation_lat < -35 OR geolocation_lat > 6))
                      OR (geolocation_lng IS NOT NULL AND (geolocation_lng < -75 OR geolocation_lng > -28))
               ) > 0 THEN 'FAIL'
               ELSE 'PASS'
           END
    FROM raw_olist_geolocation_dataset
) numeric_checks;


/* 4.2c Payment outlier - percentiles (manual review, no auto FAIL)
   In DBeaver: select from SELECT through the semicolon only (not dashed lines). */
SELECT
    'payment_outlier' AS check_type,
    'raw_olist_order_payments_dataset.payment_value' AS check_name,
    COUNT(*) AS total_rows,
    COUNT(payment_value) AS non_null_count,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value) AS median,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY payment_value) AS p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY payment_value) AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY payment_value) AS p99,
    MAX(payment_value) AS max_value,
    'INFO (review distribution)' AS status
FROM raw_olist_order_payments_dataset;


/* 4.2d Payment outlier - top payment_value records */
SELECT
    'payment_outlier' AS check_type,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM raw_olist_order_payments_dataset
ORDER BY payment_value DESC NULLS LAST
LIMIT 20;


/* 4.2e Payment outlier - top payments vs order line items (line-level detail) */
SELECT
    'payment_outlier' AS check_type,
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_value,
    i.order_item_id,
    i.price,
    i.freight_value,
    i.price + COALESCE(i.freight_value, 0) AS line_total
FROM raw_olist_order_payments_dataset p
JOIN raw_olist_order_items_dataset i ON p.order_id = i.order_id
ORDER BY p.payment_value DESC NULLS LAST, p.order_id, i.order_item_id
LIMIT 50;


/* 4.2f Payment outlier - top 20 orders: payment vs sum(price + freight) */
WITH top_payments AS (
    SELECT
        order_id,
        payment_value,
        payment_type,
        payment_sequential
    FROM raw_olist_order_payments_dataset
    WHERE payment_value IS NOT NULL
    ORDER BY payment_value DESC
    LIMIT 20
),
order_items_total AS (
    SELECT
        order_id,
        SUM(price + COALESCE(freight_value, 0)) AS items_amount,
        COUNT(*) AS item_count
    FROM raw_olist_order_items_dataset
    GROUP BY order_id
)
SELECT
    'payment_outlier' AS check_type,
    tp.order_id,
    tp.payment_sequential,
    tp.payment_type,
    tp.payment_value,
    oit.item_count,
    oit.items_amount,
    tp.payment_value - oit.items_amount AS payment_minus_items,
    ABS(tp.payment_value - oit.items_amount) AS abs_diff
FROM top_payments tp
LEFT JOIN order_items_total oit ON tp.order_id = oit.order_id
ORDER BY tp.payment_value DESC;


-- -----------------------------------------------------------------------------
-- 4.3 Timestamp Validation — MIN/MAX within plausible Olist date range
-- -----------------------------------------------------------------------------
SELECT
    'timestamp' AS check_type,
    check_name,
    min_timestamp,
    max_timestamp,
    expected_min,
    expected_max,
    CASE
        WHEN min_timestamp IS NULL AND max_timestamp IS NULL THEN 'SKIP (all null)'
        WHEN min_timestamp < expected_min OR max_timestamp > expected_max THEN 'FAIL'
        ELSE 'PASS'
    END AS status
FROM (
    SELECT 'raw_olist_orders_dataset.order_purchase_timestamp' AS check_name,
           MIN(order_purchase_timestamp) AS min_timestamp,
           MAX(order_purchase_timestamp) AS max_timestamp,
           TIMESTAMP '2016-09-01' AS expected_min,
           TIMESTAMP '2018-10-31 23:59:59' AS expected_max
    FROM raw_olist_orders_dataset

    UNION ALL

    SELECT 'raw_olist_orders_dataset.order_approved_at',
           MIN(order_approved_at),
           MAX(order_approved_at),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2018-10-31 23:59:59'
    FROM raw_olist_orders_dataset
    WHERE order_approved_at IS NOT NULL

    UNION ALL

    SELECT 'raw_olist_orders_dataset.order_delivered_carrier_date',
           MIN(order_delivered_carrier_date),
           MAX(order_delivered_carrier_date),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2018-12-31 23:59:59'
    FROM raw_olist_orders_dataset
    WHERE order_delivered_carrier_date IS NOT NULL

    UNION ALL

    SELECT 'raw_olist_orders_dataset.order_delivered_customer_date',
           MIN(order_delivered_customer_date),
           MAX(order_delivered_customer_date),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2018-12-31 23:59:59'
    FROM raw_olist_orders_dataset
    WHERE order_delivered_customer_date IS NOT NULL

    UNION ALL

    SELECT 'raw_olist_orders_dataset.order_estimated_delivery_date',
           MIN(order_estimated_delivery_date),
           MAX(order_estimated_delivery_date),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2019-06-30 23:59:59'
    FROM raw_olist_orders_dataset
    WHERE order_estimated_delivery_date IS NOT NULL

    UNION ALL

    -- shipping_limit_date only: wider window (ship-by deadline can be after 2018 orders)
    SELECT 'raw_olist_order_items_dataset.shipping_limit_date',
           MIN(shipping_limit_date),
           MAX(shipping_limit_date),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2020-12-31 23:59:59'
    FROM raw_olist_order_items_dataset
    WHERE shipping_limit_date IS NOT NULL

    UNION ALL

    SELECT 'raw_olist_order_reviews_dataset.review_creation_date',
           MIN(review_creation_date),
           MAX(review_creation_date),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2018-12-31 23:59:59'
    FROM raw_olist_order_reviews_dataset
    WHERE review_creation_date IS NOT NULL

    UNION ALL

    SELECT 'raw_olist_order_reviews_dataset.review_answer_timestamp',
           MIN(review_answer_timestamp),
           MAX(review_answer_timestamp),
           TIMESTAMP '2016-09-01',
           TIMESTAMP '2019-06-30 23:59:59'
    FROM raw_olist_order_reviews_dataset
    WHERE review_answer_timestamp IS NOT NULL
) timestamp_checks;


-- =============================================================================
-- Part 5: Consistency Validation — cross-field / cross-table business logic
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 5.1 Business Logic — per order SUM(payment_value) vs SUM(price + freight_value)
--     tolerance 1.00 BRL; mismatch count only, no auto FAIL (manual review)
-- -----------------------------------------------------------------------------
WITH items_total AS (
    SELECT
        order_id,
        SUM(price + COALESCE(freight_value, 0)) AS items_amount
    FROM raw_olist_order_items_dataset
    WHERE order_id IS NOT NULL
    GROUP BY order_id
),
payments_total AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_amount
    FROM raw_olist_order_payments_dataset
    WHERE order_id IS NOT NULL
    GROUP BY order_id
),
order_amount_compare AS (
    SELECT
        COALESCE(i.order_id, p.order_id) AS order_id,
        i.items_amount,
        p.payment_amount,
        ABS(COALESCE(i.items_amount, 0) - COALESCE(p.payment_amount, 0)) AS amount_diff
    FROM items_total i
    FULL OUTER JOIN payments_total p ON i.order_id = p.order_id
)
SELECT
    'consistency' AS check_type,
    'order payment_amount vs sum(price+freight)' AS check_name,
    COUNT(*) FILTER (WHERE items_amount IS NULL OR payment_amount IS NULL) AS missing_side_count,
    COUNT(*) FILTER (
        WHERE items_amount IS NOT NULL
          AND payment_amount IS NOT NULL
          AND amount_diff > 1.00
    ) AS mismatch_count,
    COUNT(*) FILTER (WHERE items_amount IS NOT NULL AND payment_amount IS NOT NULL) AS compared_order_count,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE items_amount IS NOT NULL
              AND payment_amount IS NOT NULL
              AND amount_diff > 1.00
        ) / NULLIF(
            COUNT(*) FILTER (WHERE items_amount IS NOT NULL AND payment_amount IS NOT NULL),
            0
        ),
        2
    ) AS mismatch_rate_pct,
    1.00 AS tolerance_brl
FROM order_amount_compare;


-- -----------------------------------------------------------------------------
-- 5.2 Status vs Timestamp — delivered orders must have delivered_customer_date
-- -----------------------------------------------------------------------------
SELECT
    'consistency' AS check_type,
    'delivered status requires order_delivered_customer_date' AS check_name,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS violation_count,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_order_count,
    CASE
        WHEN COUNT(*) = 0 THEN 'SKIP (empty table)'
        WHEN COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NULL
        ) > 0
        THEN 'FAIL'
        ELSE 'PASS'
    END AS status
FROM raw_olist_orders_dataset;


-- =============================================================================
-- Part 6: Referential Integrity — foreign key check (child references parent)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 6.1 Orphan rows — child rows with no matching parent (orphan_count > 0 → FAIL)
-- -----------------------------------------------------------------------------
SELECT 'referential_integrity' AS check_type,
       check_name,
       orphan_count,
       child_rows_checked,
       CASE
           WHEN child_rows_checked = 0 THEN 'SKIP (nothing to check)'
           WHEN orphan_count > 0 THEN 'FAIL'
           ELSE 'PASS'
       END AS status
FROM (
    SELECT
        'raw_olist_orders_dataset.customer_id -> raw_olist_customers_dataset.customer_id' AS check_name,
        COUNT(*) FILTER (WHERE c.customer_id IS NULL) AS orphan_count,
        COUNT(*) AS child_rows_checked
    FROM raw_olist_orders_dataset o
    LEFT JOIN raw_olist_customers_dataset c ON o.customer_id = c.customer_id
    WHERE o.customer_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_order_items_dataset.order_id -> raw_olist_orders_dataset.order_id',
        COUNT(*) FILTER (WHERE parent.order_id IS NULL),
        COUNT(*)
    FROM raw_olist_order_items_dataset child
    LEFT JOIN raw_olist_orders_dataset parent ON child.order_id = parent.order_id
    WHERE child.order_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_order_items_dataset.product_id -> raw_olist_products_dataset.product_id',
        COUNT(*) FILTER (WHERE parent.product_id IS NULL),
        COUNT(*)
    FROM raw_olist_order_items_dataset child
    LEFT JOIN raw_olist_products_dataset parent ON child.product_id = parent.product_id
    WHERE child.product_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_order_items_dataset.seller_id -> raw_olist_sellers_dataset.seller_id',
        COUNT(*) FILTER (WHERE parent.seller_id IS NULL),
        COUNT(*)
    FROM raw_olist_order_items_dataset child
    LEFT JOIN raw_olist_sellers_dataset parent ON child.seller_id = parent.seller_id
    WHERE child.seller_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_order_payments_dataset.order_id -> raw_olist_orders_dataset.order_id',
        COUNT(*) FILTER (WHERE parent.order_id IS NULL),
        COUNT(*)
    FROM raw_olist_order_payments_dataset child
    LEFT JOIN raw_olist_orders_dataset parent ON child.order_id = parent.order_id
    WHERE child.order_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_order_reviews_dataset.order_id -> raw_olist_orders_dataset.order_id',
        COUNT(*) FILTER (WHERE parent.order_id IS NULL),
        COUNT(*)
    FROM raw_olist_order_reviews_dataset child
    LEFT JOIN raw_olist_orders_dataset parent ON child.order_id = parent.order_id
    WHERE child.order_id IS NOT NULL

    UNION ALL

    SELECT
        'raw_olist_products_dataset.product_category_name -> raw_product_category_name_translation.product_category_name',
        COUNT(*) FILTER (WHERE tr.product_category_name IS NULL),
        COUNT(*)
    FROM raw_olist_products_dataset p
    LEFT JOIN raw_product_category_name_translation tr
        ON p.product_category_name = tr.product_category_name
    WHERE p.product_category_name IS NOT NULL
) fk_checks;


-- =============================================================================
-- Part 7: Distribution — temporal distribution / trends
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 7.1 Time Trend — daily order counts by purchase date (overall distribution)
-- -----------------------------------------------------------------------------
SELECT
    'distribution' AS check_type,
    DATE(order_purchase_timestamp) AS order_date,
    COUNT(*) AS order_count
FROM raw_olist_orders_dataset
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY DATE(order_purchase_timestamp)
ORDER BY order_date;


-- -----------------------------------------------------------------------------
-- 7.2 Time Trend Check — days with zero orders (gaps within MIN~MAX date range)
-- -----------------------------------------------------------------------------
WITH daily_orders AS (
    SELECT
        DATE(order_purchase_timestamp) AS order_date,
        COUNT(*) AS order_count
    FROM raw_olist_orders_dataset
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE(order_purchase_timestamp)
),
date_spine AS (
    SELECT generate_series(
        (SELECT MIN(order_date) FROM daily_orders),
        (SELECT MAX(order_date) FROM daily_orders),
        INTERVAL '1 day'
    )::date AS order_date
)
SELECT
    'distribution' AS check_type,
    s.order_date,
    COALESCE(d.order_count, 0) AS order_count
FROM date_spine s
LEFT JOIN daily_orders d ON s.order_date = d.order_date
WHERE COALESCE(d.order_count, 0) = 0
ORDER BY s.order_date;


-- -----------------------------------------------------------------------------
-- 7.3 Time Trend Summary — missing-day count summary
-- -----------------------------------------------------------------------------
WITH daily_orders AS (
    SELECT
        DATE(order_purchase_timestamp) AS order_date,
        COUNT(*) AS order_count
    FROM raw_olist_orders_dataset
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE(order_purchase_timestamp)
),
date_spine AS (
    SELECT generate_series(
        (SELECT MIN(order_date) FROM daily_orders),
        (SELECT MAX(order_date) FROM daily_orders),
        INTERVAL '1 day'
    )::date AS order_date
),
missing_days AS (
    SELECT s.order_date
    FROM date_spine s
    LEFT JOIN daily_orders d ON s.order_date = d.order_date
    WHERE COALESCE(d.order_count, 0) = 0
)
SELECT
    'distribution' AS check_type,
    'order_purchase_timestamp daily gap check' AS check_name,
    (SELECT MIN(order_date) FROM daily_orders) AS min_order_date,
    (SELECT MAX(order_date) FROM daily_orders) AS max_order_date,
    (SELECT COUNT(*) FROM date_spine) AS expected_days_in_range,
    (SELECT COUNT(*) FROM daily_orders) AS days_with_orders,
    (SELECT COUNT(*) FROM missing_days) AS missing_day_count,
    CASE
        WHEN (SELECT COUNT(*) FROM daily_orders) = 0 THEN 'SKIP (no order dates)'
        WHEN (SELECT COUNT(*) FROM missing_days) > 0 THEN 'FAIL'
        ELSE 'PASS'
    END AS status;


-- =============================================================================
-- Part 8: Prediction Readiness — per-feature missing rates (usability before modeling)
-- =============================================================================
-- null_rate_pct = 0 → READY | (0,5] → ACCEPTABLE | (5,50] → REVIEW | >50 → NOT_READY


-- Materialize to temp table for 8.1 / 8.2 / 8.3 (run Part 8 blocks in the same session)
DROP TABLE IF EXISTS _dq_feature_readiness;

CREATE TEMP TABLE _dq_feature_readiness AS
SELECT
    table_name,
    feature_name,
    null_count,
    total_rows,
    non_null_count,
    null_rate_pct,
    CASE
        WHEN total_rows = 0 THEN 'SKIP (empty table)'
        WHEN null_rate_pct = 0 THEN 'READY'
        WHEN null_rate_pct <= 5 THEN 'ACCEPTABLE'
        WHEN null_rate_pct <= 50 THEN 'REVIEW'
        ELSE 'NOT_READY'
    END AS readiness_status
FROM (
    SELECT 'raw_olist_customers_dataset' AS table_name, 'customer_id' AS feature_name,
           COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_count, COUNT(*) AS total_rows,
           COUNT(customer_id) AS non_null_count,
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_id IS NULL) / NULLIF(COUNT(*), 0), 2) AS null_rate_pct
    FROM raw_olist_customers_dataset
    UNION ALL SELECT 'raw_olist_customers_dataset', 'customer_unique_id',
           COUNT(*) FILTER (WHERE customer_unique_id IS NULL), COUNT(*), COUNT(customer_unique_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_unique_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_customers_dataset
    UNION ALL SELECT 'raw_olist_customers_dataset', 'customer_zip_code_prefix',
           COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL), COUNT(*), COUNT(customer_zip_code_prefix),
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_customers_dataset
    UNION ALL SELECT 'raw_olist_customers_dataset', 'customer_city',
           COUNT(*) FILTER (WHERE customer_city IS NULL), COUNT(*), COUNT(customer_city),
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_city IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_customers_dataset
    UNION ALL SELECT 'raw_olist_customers_dataset', 'customer_state',
           COUNT(*) FILTER (WHERE customer_state IS NULL), COUNT(*), COUNT(customer_state),
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_state IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_customers_dataset

    UNION ALL SELECT 'raw_olist_geolocation_dataset', 'geolocation_zip_code_prefix',
           COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL), COUNT(*), COUNT(geolocation_zip_code_prefix),
           ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_geolocation_dataset
    UNION ALL SELECT 'raw_olist_geolocation_dataset', 'geolocation_lat',
           COUNT(*) FILTER (WHERE geolocation_lat IS NULL), COUNT(*), COUNT(geolocation_lat),
           ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_lat IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_geolocation_dataset
    UNION ALL SELECT 'raw_olist_geolocation_dataset', 'geolocation_lng',
           COUNT(*) FILTER (WHERE geolocation_lng IS NULL), COUNT(*), COUNT(geolocation_lng),
           ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_lng IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_geolocation_dataset
    UNION ALL SELECT 'raw_olist_geolocation_dataset', 'geolocation_city',
           COUNT(*) FILTER (WHERE geolocation_city IS NULL), COUNT(*), COUNT(geolocation_city),
           ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_city IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_geolocation_dataset
    UNION ALL SELECT 'raw_olist_geolocation_dataset', 'geolocation_state',
           COUNT(*) FILTER (WHERE geolocation_state IS NULL), COUNT(*), COUNT(geolocation_state),
           ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_state IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_geolocation_dataset

    UNION ALL SELECT 'raw_olist_order_items_dataset', 'order_id',
           COUNT(*) FILTER (WHERE order_id IS NULL), COUNT(*), COUNT(order_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'order_item_id',
           COUNT(*) FILTER (WHERE order_item_id IS NULL), COUNT(*), COUNT(order_item_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_item_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'product_id',
           COUNT(*) FILTER (WHERE product_id IS NULL), COUNT(*), COUNT(product_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'seller_id',
           COUNT(*) FILTER (WHERE seller_id IS NULL), COUNT(*), COUNT(seller_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE seller_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'shipping_limit_date',
           COUNT(*) FILTER (WHERE shipping_limit_date IS NULL), COUNT(*), COUNT(shipping_limit_date),
           ROUND(100.0 * COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'price',
           COUNT(*) FILTER (WHERE price IS NULL), COUNT(*), COUNT(price),
           ROUND(100.0 * COUNT(*) FILTER (WHERE price IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset
    UNION ALL SELECT 'raw_olist_order_items_dataset', 'freight_value',
           COUNT(*) FILTER (WHERE freight_value IS NULL), COUNT(*), COUNT(freight_value),
           ROUND(100.0 * COUNT(*) FILTER (WHERE freight_value IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_items_dataset

    UNION ALL SELECT 'raw_olist_order_payments_dataset', 'order_id',
           COUNT(*) FILTER (WHERE order_id IS NULL), COUNT(*), COUNT(order_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_payments_dataset
    UNION ALL SELECT 'raw_olist_order_payments_dataset', 'payment_sequential',
           COUNT(*) FILTER (WHERE payment_sequential IS NULL), COUNT(*), COUNT(payment_sequential),
           ROUND(100.0 * COUNT(*) FILTER (WHERE payment_sequential IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_payments_dataset
    UNION ALL SELECT 'raw_olist_order_payments_dataset', 'payment_type',
           COUNT(*) FILTER (WHERE payment_type IS NULL), COUNT(*), COUNT(payment_type),
           ROUND(100.0 * COUNT(*) FILTER (WHERE payment_type IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_payments_dataset
    UNION ALL SELECT 'raw_olist_order_payments_dataset', 'payment_installments',
           COUNT(*) FILTER (WHERE payment_installments IS NULL), COUNT(*), COUNT(payment_installments),
           ROUND(100.0 * COUNT(*) FILTER (WHERE payment_installments IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_payments_dataset
    UNION ALL SELECT 'raw_olist_order_payments_dataset', 'payment_value',
           COUNT(*) FILTER (WHERE payment_value IS NULL), COUNT(*), COUNT(payment_value),
           ROUND(100.0 * COUNT(*) FILTER (WHERE payment_value IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_payments_dataset

    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_id',
           COUNT(*) FILTER (WHERE review_id IS NULL), COUNT(*), COUNT(review_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'order_id',
           COUNT(*) FILTER (WHERE order_id IS NULL), COUNT(*), COUNT(order_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_score',
           COUNT(*) FILTER (WHERE review_score IS NULL), COUNT(*), COUNT(review_score),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_score IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_comment_title',
           COUNT(*) FILTER (WHERE review_comment_title IS NULL), COUNT(*), COUNT(review_comment_title),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_comment_title IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_comment_message',
           COUNT(*) FILTER (WHERE review_comment_message IS NULL), COUNT(*), COUNT(review_comment_message),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_comment_message IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_creation_date',
           COUNT(*) FILTER (WHERE review_creation_date IS NULL), COUNT(*), COUNT(review_creation_date),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_creation_date IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset
    UNION ALL SELECT 'raw_olist_order_reviews_dataset', 'review_answer_timestamp',
           COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL), COUNT(*), COUNT(review_answer_timestamp),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_order_reviews_dataset

    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_id',
           COUNT(*) FILTER (WHERE order_id IS NULL), COUNT(*), COUNT(order_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'customer_id',
           COUNT(*) FILTER (WHERE customer_id IS NULL), COUNT(*), COUNT(customer_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE customer_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_status',
           COUNT(*) FILTER (WHERE order_status IS NULL), COUNT(*), COUNT(order_status),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_status IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_purchase_timestamp',
           COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL), COUNT(*), COUNT(order_purchase_timestamp),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_approved_at',
           COUNT(*) FILTER (WHERE order_approved_at IS NULL), COUNT(*), COUNT(order_approved_at),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_approved_at IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_delivered_carrier_date',
           COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL), COUNT(*), COUNT(order_delivered_carrier_date),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_delivered_customer_date',
           COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL), COUNT(*), COUNT(order_delivered_customer_date),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset
    UNION ALL SELECT 'raw_olist_orders_dataset', 'order_estimated_delivery_date',
           COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL), COUNT(*), COUNT(order_estimated_delivery_date),
           ROUND(100.0 * COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_orders_dataset

    UNION ALL SELECT 'raw_olist_products_dataset', 'product_id',
           COUNT(*) FILTER (WHERE product_id IS NULL), COUNT(*), COUNT(product_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_category_name',
           COUNT(*) FILTER (WHERE product_category_name IS NULL), COUNT(*), COUNT(product_category_name),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_category_name IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_name_lenght',
           COUNT(*) FILTER (WHERE product_name_lenght IS NULL), COUNT(*), COUNT(product_name_lenght),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_name_lenght IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_description_lenght',
           COUNT(*) FILTER (WHERE product_description_lenght IS NULL), COUNT(*), COUNT(product_description_lenght),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_description_lenght IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_photos_qty',
           COUNT(*) FILTER (WHERE product_photos_qty IS NULL), COUNT(*), COUNT(product_photos_qty),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_photos_qty IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_weight_g',
           COUNT(*) FILTER (WHERE product_weight_g IS NULL), COUNT(*), COUNT(product_weight_g),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_weight_g IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_length_cm',
           COUNT(*) FILTER (WHERE product_length_cm IS NULL), COUNT(*), COUNT(product_length_cm),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_length_cm IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_height_cm',
           COUNT(*) FILTER (WHERE product_height_cm IS NULL), COUNT(*), COUNT(product_height_cm),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_height_cm IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset
    UNION ALL SELECT 'raw_olist_products_dataset', 'product_width_cm',
           COUNT(*) FILTER (WHERE product_width_cm IS NULL), COUNT(*), COUNT(product_width_cm),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_width_cm IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_products_dataset

    UNION ALL SELECT 'raw_olist_sellers_dataset', 'seller_id',
           COUNT(*) FILTER (WHERE seller_id IS NULL), COUNT(*), COUNT(seller_id),
           ROUND(100.0 * COUNT(*) FILTER (WHERE seller_id IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_sellers_dataset
    UNION ALL SELECT 'raw_olist_sellers_dataset', 'seller_zip_code_prefix',
           COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL), COUNT(*), COUNT(seller_zip_code_prefix),
           ROUND(100.0 * COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_sellers_dataset
    UNION ALL SELECT 'raw_olist_sellers_dataset', 'seller_city',
           COUNT(*) FILTER (WHERE seller_city IS NULL), COUNT(*), COUNT(seller_city),
           ROUND(100.0 * COUNT(*) FILTER (WHERE seller_city IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_sellers_dataset
    UNION ALL SELECT 'raw_olist_sellers_dataset', 'seller_state',
           COUNT(*) FILTER (WHERE seller_state IS NULL), COUNT(*), COUNT(seller_state),
           ROUND(100.0 * COUNT(*) FILTER (WHERE seller_state IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_olist_sellers_dataset

    UNION ALL SELECT 'raw_product_category_name_translation', 'product_category_name',
           COUNT(*) FILTER (WHERE product_category_name IS NULL), COUNT(*), COUNT(product_category_name),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_category_name IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_product_category_name_translation
    UNION ALL SELECT 'raw_product_category_name_translation', 'product_category_name_english',
           COUNT(*) FILTER (WHERE product_category_name_english IS NULL), COUNT(*), COUNT(product_category_name_english),
           ROUND(100.0 * COUNT(*) FILTER (WHERE product_category_name_english IS NULL) / NULLIF(COUNT(*), 0), 2)
    FROM raw_product_category_name_translation
) feature_missing_rates;


-- -----------------------------------------------------------------------------
-- 8.1 Feature missing rate — all raw table columns
-- -----------------------------------------------------------------------------
SELECT
    'prediction_readiness' AS check_type,
    table_name,
    feature_name,
    null_count,
    total_rows,
    non_null_count,
    null_rate_pct,
    readiness_status
FROM _dq_feature_readiness
ORDER BY table_name, feature_name;


-- -----------------------------------------------------------------------------
-- 8.2 Prediction Readiness Summary — feature count by readiness status
-- -----------------------------------------------------------------------------
SELECT
    readiness_status,
    COUNT(*) AS feature_count
FROM _dq_feature_readiness
GROUP BY readiness_status
ORDER BY readiness_status;


-- -----------------------------------------------------------------------------
-- 8.3 High-missing features — null_rate_pct > 5% (priority review for modeling)
-- -----------------------------------------------------------------------------
SELECT
    'prediction_readiness' AS check_type,
    table_name,
    feature_name,
    null_count,
    total_rows,
    null_rate_pct,
    readiness_status
FROM _dq_feature_readiness
WHERE null_rate_pct > 5
ORDER BY null_rate_pct DESC, table_name, feature_name;
