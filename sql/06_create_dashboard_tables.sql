-- Dashboard layer (run after sql/05_create_gold_tables.sql)
-- Pre-aggregated marts for Power BI; logic aligned with docs/kpi_definitions.md.
--
-- KPI index (see docs/kpi_definitions.md):
--   1  GMV                    SUM(price + freight_value), delivered
--   2  Total Orders           COUNT(DISTINCT order_id), delivered
--   3  AOV                    GMV / Total Orders (same period)
--   4  Repeat Purchase Rate   customer_unique_id; lifetime / 3m / 6m
--   5  Delivery Delay Rate    delayed / valid delivered (dates + no inconsistency)
--   6  Average Review Score   AVG(review_score), delivered orders
--   7  Installment Usage      orders with payment_installments > 1 / delivered
--   8  Actual Payment         SUM(payment_value), delivered

DROP TABLE IF EXISTS dash_retention_monthly;
DROP TABLE IF EXISTS dash_retention_snapshot;
DROP TABLE IF EXISTS dash_category_monthly;
DROP TABLE IF EXISTS dash_kpi_daily;
DROP TABLE IF EXISTS dash_kpi_monthly;


-- -----------------------------------------------------------------------------
-- dash_kpi_monthly — monthly by order_purchase_month (delivered only)
-- KPI 4 is in dash_retention_*; KPI 9 is in dash_category_monthly.
--
-- Column → KPI:
--   report_month                  — period key
--   gmv                           — KPI 1  GMV (SUM price + freight)
--   total_orders                  — KPI 2  Total Orders (COUNT DISTINCT order_id)
--   aov                           — KPI 3  AOV (gmv / total_orders)
--   actual_payment                — KPI 8  Actual Payment (SUM payment_value)
--   delivered_orders              — KPI 2 / KPI 7 denominator
--   delivery_delay_denominator    — KPI 5 denominator (valid delivery dates)
--   delayed_orders                — KPI 5 numerator
--   delivery_delay_rate           — KPI 5  Delivery Delay Rate
--   review_count                  — KPI 6 helper (review rows)
--   avg_review_score              — KPI 6  Average Review Score
--   installment_orders            — KPI 7 numerator (payment_installments > 1)
--   installment_usage_rate        — KPI 7  Payment Installment Usage
-- -----------------------------------------------------------------------------
CREATE TABLE dash_kpi_monthly AS
WITH items AS (
    SELECT
        i.order_purchase_month AS report_month,
        SUM(i.line_gmv) AS gmv,
        COUNT(DISTINCT i.order_id) AS total_orders
    FROM gold_fact_order_items i
    WHERE i.is_delivered
      AND i.order_purchase_month IS NOT NULL
    GROUP BY i.order_purchase_month
),
payments AS (
    SELECT
        p.order_purchase_month AS report_month,
        SUM(p.payment_value) AS actual_payment
    FROM gold_fact_order_payments p
    WHERE p.is_delivered
      AND p.order_purchase_month IS NOT NULL
    GROUP BY p.order_purchase_month
),
orders AS (
    SELECT
        o.order_purchase_month AS report_month,
        COUNT(*) FILTER (WHERE o.is_delivered) AS delivered_orders,
        COUNT(*) FILTER (WHERE o.is_valid_for_delivery_delay_kpi) AS delivery_delay_denominator,
        COUNT(*) FILTER (WHERE o.is_delayed) AS delayed_orders,
        COUNT(*) FILTER (WHERE o.is_delivered AND o.uses_installments) AS installment_orders
    FROM gold_fact_orders o
    WHERE o.order_purchase_month IS NOT NULL
    GROUP BY o.order_purchase_month
),
reviews AS (
    SELECT
        r.order_purchase_month AS report_month,
        COUNT(*) AS review_count,
        AVG(r.review_score) AS avg_review_score
    FROM gold_fact_order_reviews r
    WHERE r.order_purchase_month IS NOT NULL
    GROUP BY r.order_purchase_month
),
months AS (
    SELECT DISTINCT o.order_purchase_month AS report_month
    FROM gold_fact_orders o
    WHERE o.is_delivered
      AND o.order_purchase_month IS NOT NULL
)
SELECT
    m.report_month,
    COALESCE(i.gmv, 0) AS gmv,
    COALESCE(i.total_orders, 0) AS total_orders,
    CASE
        WHEN COALESCE(i.total_orders, 0) > 0
        THEN COALESCE(i.gmv, 0) / i.total_orders
    END AS aov,
    COALESCE(p.actual_payment, 0) AS actual_payment,
    COALESCE(o.delivered_orders, 0) AS delivered_orders,
    COALESCE(o.delivery_delay_denominator, 0) AS delivery_delay_denominator,
    COALESCE(o.delayed_orders, 0) AS delayed_orders,
    CASE
        WHEN COALESCE(o.delivery_delay_denominator, 0) > 0
        THEN o.delayed_orders::numeric / o.delivery_delay_denominator
    END AS delivery_delay_rate,
    COALESCE(rv.review_count, 0) AS review_count,
    rv.avg_review_score,
    COALESCE(o.installment_orders, 0) AS installment_orders,
    CASE
        WHEN COALESCE(o.delivered_orders, 0) > 0
        THEN o.installment_orders::numeric / o.delivered_orders
    END AS installment_usage_rate
FROM months m
LEFT JOIN items i
    ON m.report_month = i.report_month
LEFT JOIN payments p
    ON m.report_month = p.report_month
LEFT JOIN orders o
    ON m.report_month = o.report_month
LEFT JOIN reviews rv
    ON m.report_month = rv.report_month
ORDER BY m.report_month;


-- -----------------------------------------------------------------------------
-- dash_kpi_daily — daily by order_purchase_date (delivered only)
--
-- Column → KPI:
--   report_date     — period key
--   gmv             — KPI 1  GMV
--   total_orders    — KPI 2  Total Orders
--   actual_payment  — KPI 8  Actual Payment
-- -----------------------------------------------------------------------------
CREATE TABLE dash_kpi_daily AS
WITH items AS (
    SELECT
        i.order_purchase_date AS report_date,
        SUM(i.line_gmv) AS gmv,
        COUNT(DISTINCT i.order_id) AS total_orders
    FROM gold_fact_order_items i
    WHERE i.is_delivered
      AND i.order_purchase_date IS NOT NULL
    GROUP BY i.order_purchase_date
),
payments AS (
    SELECT
        p.order_purchase_date AS report_date,
        SUM(p.payment_value) AS actual_payment
    FROM gold_fact_order_payments p
    WHERE p.is_delivered
      AND p.order_purchase_date IS NOT NULL
    GROUP BY p.order_purchase_date
),
days AS (
    SELECT report_date FROM items
    UNION
    SELECT report_date FROM payments
)
SELECT
    d.report_date,
    COALESCE(i.gmv, 0) AS gmv,
    COALESCE(i.total_orders, 0) AS total_orders,
    COALESCE(p.actual_payment, 0) AS actual_payment
FROM days d
LEFT JOIN items i
    ON d.report_date = i.report_date
LEFT JOIN payments p
    ON d.report_date = p.report_date
ORDER BY d.report_date;


-- -----------------------------------------------------------------------------
-- dash_category_monthly — KPI 9 Top Selling Category (monthly × category)
--   category_gmv — SUM(price + freight) by product_category_name_english
-- -----------------------------------------------------------------------------
CREATE TABLE dash_category_monthly AS
SELECT
    report_month,
    category,
    category_label,
    category_gmv,
    category_order_count,
    category_rank
FROM (
    SELECT
        i.order_purchase_month AS report_month,
        i.product_category_name_english AS category,
        i.product_category_label AS category_label,
        SUM(i.line_gmv) AS category_gmv,
        COUNT(DISTINCT i.order_id) AS category_order_count,
        ROW_NUMBER() OVER (
            PARTITION BY i.order_purchase_month
            ORDER BY SUM(i.line_gmv) DESC
        ) AS category_rank
    FROM gold_fact_order_items i
    WHERE i.is_delivered
      AND i.order_purchase_month IS NOT NULL
    GROUP BY
        i.order_purchase_month,
        i.product_category_name_english,
        i.product_category_label
) ranked
ORDER BY report_month, category_rank;


-- -----------------------------------------------------------------------------
-- dash_retention_snapshot — KPI 4 retention snapshot (dataset as-of)
--   metric_code:
--     lifetime_repeat_purchase
--     last_3m_returning_customer / last_6m_returning_customer
--     last_3m_repeat_purchase / last_6m_repeat_purchase
--   repeat_purchase_rate = returning_customers / total_customers (customer_unique_id)
-- -----------------------------------------------------------------------------
CREATE TABLE dash_retention_snapshot AS
WITH params AS (
    SELECT
        d.as_of_date,
        d.as_of_timestamp,
        d.as_of_timestamp - INTERVAL '3 months' AS window_3m_start,
        d.as_of_timestamp - INTERVAL '6 months' AS window_6m_start
    FROM gold_dataset_dates d
),
cust_lifetime AS (
    SELECT
        g.customer_unique_id,
        COUNT(DISTINCT g.order_id) AS delivered_order_count
    FROM gold_customer_delivered_orders g
    CROSS JOIN params p
    WHERE g.order_purchase_timestamp <= p.as_of_timestamp
    GROUP BY g.customer_unique_id
),
lifetime AS (
    SELECT
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE delivered_order_count > 1) AS returning_customers
    FROM cust_lifetime
),
in_window_3m AS (
    SELECT DISTINCT g.customer_unique_id
    FROM gold_customer_delivered_orders g
    CROSS JOIN params p
    WHERE g.order_purchase_timestamp > p.window_3m_start
      AND g.order_purchase_timestamp <= p.as_of_timestamp
),
before_window_3m AS (
    SELECT DISTINCT g.customer_unique_id
    FROM gold_customer_delivered_orders g
    CROSS JOIN params p
    WHERE g.order_purchase_timestamp <= p.window_3m_start
),
window_3m AS (
    SELECT
        (SELECT COUNT(*) FROM in_window_3m) AS total_customers,
        (
            SELECT COUNT(*)
            FROM in_window_3m iw
            INNER JOIN before_window_3m bw
                ON iw.customer_unique_id = bw.customer_unique_id
        ) AS returning_customers
),
in_window_6m AS (
    SELECT DISTINCT g.customer_unique_id
    FROM gold_customer_delivered_orders g
    CROSS JOIN params p
    WHERE g.order_purchase_timestamp > p.window_6m_start
      AND g.order_purchase_timestamp <= p.as_of_timestamp
),
before_window_6m AS (
    SELECT DISTINCT g.customer_unique_id
    FROM gold_customer_delivered_orders g
    CROSS JOIN params p
    WHERE g.order_purchase_timestamp <= p.window_6m_start
),
window_6m AS (
    SELECT
        (SELECT COUNT(*) FROM in_window_6m) AS total_customers,
        (
            SELECT COUNT(*)
            FROM in_window_6m iw
            INNER JOIN before_window_6m bw
                ON iw.customer_unique_id = bw.customer_unique_id
        ) AS returning_customers
),
repeat_3m AS (
    SELECT
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE window_order_count > 1) AS returning_customers
    FROM (
        SELECT
            g.customer_unique_id,
            COUNT(DISTINCT g.order_id) AS window_order_count
        FROM gold_customer_delivered_orders g
        CROSS JOIN params p
        WHERE g.order_purchase_timestamp > p.window_3m_start
          AND g.order_purchase_timestamp <= p.as_of_timestamp
        GROUP BY g.customer_unique_id
    ) t
),
repeat_6m AS (
    SELECT
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE window_order_count > 1) AS returning_customers
    FROM (
        SELECT
            g.customer_unique_id,
            COUNT(DISTINCT g.order_id) AS window_order_count
        FROM gold_customer_delivered_orders g
        CROSS JOIN params p
        WHERE g.order_purchase_timestamp > p.window_6m_start
          AND g.order_purchase_timestamp <= p.as_of_timestamp
        GROUP BY g.customer_unique_id
    ) t
)
SELECT
    p.as_of_date,
    p.as_of_timestamp,
    'lifetime_repeat_purchase' AS metric_code,
    l.total_customers,
    l.returning_customers,
    CASE
        WHEN l.total_customers > 0
        THEN l.returning_customers::numeric / l.total_customers
    END AS repeat_purchase_rate
FROM params p
CROSS JOIN lifetime l

UNION ALL

SELECT
    p.as_of_date,
    p.as_of_timestamp,
    'last_3m_returning_customer' AS metric_code,
    w3.total_customers,
    w3.returning_customers,
    CASE
        WHEN w3.total_customers > 0
        THEN w3.returning_customers::numeric / w3.total_customers
    END AS repeat_purchase_rate
FROM params p
CROSS JOIN window_3m w3

UNION ALL

SELECT
    p.as_of_date,
    p.as_of_timestamp,
    'last_6m_returning_customer' AS metric_code,
    w6.total_customers,
    w6.returning_customers,
    CASE
        WHEN w6.total_customers > 0
        THEN w6.returning_customers::numeric / w6.total_customers
    END AS repeat_purchase_rate
FROM params p
CROSS JOIN window_6m w6

UNION ALL

SELECT
    p.as_of_date,
    p.as_of_timestamp,
    'last_3m_repeat_purchase' AS metric_code,
    r3.total_customers,
    r3.returning_customers,
    CASE
        WHEN r3.total_customers > 0
        THEN r3.returning_customers::numeric / r3.total_customers
    END AS repeat_purchase_rate
FROM params p
CROSS JOIN repeat_3m r3

UNION ALL

SELECT
    p.as_of_date,
    p.as_of_timestamp,
    'last_6m_repeat_purchase' AS metric_code,
    r6.total_customers,
    r6.returning_customers,
    CASE
        WHEN r6.total_customers > 0
        THEN r6.returning_customers::numeric / r6.total_customers
    END AS repeat_purchase_rate
FROM params p
CROSS JOIN repeat_6m r6;


-- -----------------------------------------------------------------------------
-- dash_retention_monthly — KPI 4 retention monthly (five metric codes)
--   lifetime_repeat_purchase
--   last_3m_returning_customer / last_6m_returning_customer
--   last_3m_repeat_purchase / last_6m_repeat_purchase
-- -----------------------------------------------------------------------------
CREATE TABLE dash_retention_monthly AS
WITH month_spine AS (
    SELECT DISTINCT
        DATE_TRUNC('month', g.order_purchase_timestamp)::date AS report_month
    FROM gold_customer_delivered_orders g
),
month_as_of AS (
    SELECT
        m.report_month,
        MAX(g.order_purchase_timestamp) AS as_of_timestamp
    FROM month_spine m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp < m.report_month + INTERVAL '1 month'
    GROUP BY m.report_month
),
cust_lifetime AS (
    SELECT
        m.report_month,
        m.as_of_timestamp,
        g.customer_unique_id,
        COUNT(DISTINCT g.order_id) AS delivered_order_count
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp <= m.as_of_timestamp
    GROUP BY m.report_month, m.as_of_timestamp, g.customer_unique_id
),
lifetime_metrics AS (
    SELECT
        report_month,
        as_of_timestamp,
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE delivered_order_count > 1) AS returning_customers
    FROM cust_lifetime
    GROUP BY report_month, as_of_timestamp
),
in_window AS (
    SELECT DISTINCT
        m.report_month,
        m.as_of_timestamp,
        3 AS window_months,
        g.customer_unique_id
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp > m.as_of_timestamp - INTERVAL '3 months'
       AND g.order_purchase_timestamp <= m.as_of_timestamp
    UNION
    SELECT DISTINCT
        m.report_month,
        m.as_of_timestamp,
        6 AS window_months,
        g.customer_unique_id
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp > m.as_of_timestamp - INTERVAL '6 months'
       AND g.order_purchase_timestamp <= m.as_of_timestamp
),
before_window AS (
    SELECT DISTINCT
        m.report_month,
        3 AS window_months,
        g.customer_unique_id
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp <= m.as_of_timestamp - INTERVAL '3 months'
    UNION
    SELECT DISTINCT
        m.report_month,
        6 AS window_months,
        g.customer_unique_id
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp <= m.as_of_timestamp - INTERVAL '6 months'
),
window_metrics AS (
    SELECT
        iw.report_month,
        iw.as_of_timestamp,
        iw.window_months,
        COUNT(*) AS total_customers,
        COUNT(bw.customer_unique_id) AS returning_customers
    FROM in_window iw
    LEFT JOIN before_window bw
        ON iw.report_month = bw.report_month
       AND iw.window_months = bw.window_months
       AND iw.customer_unique_id = bw.customer_unique_id
    GROUP BY iw.report_month, iw.as_of_timestamp, iw.window_months
),
repeat_window AS (
    SELECT
        m.report_month,
        m.as_of_timestamp,
        3 AS window_months,
        g.customer_unique_id,
        COUNT(DISTINCT g.order_id) AS window_order_count
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp > m.as_of_timestamp - INTERVAL '3 months'
       AND g.order_purchase_timestamp <= m.as_of_timestamp
    GROUP BY m.report_month, m.as_of_timestamp, g.customer_unique_id
    UNION ALL
    SELECT
        m.report_month,
        m.as_of_timestamp,
        6 AS window_months,
        g.customer_unique_id,
        COUNT(DISTINCT g.order_id) AS window_order_count
    FROM month_as_of m
    INNER JOIN gold_customer_delivered_orders g
        ON g.order_purchase_timestamp > m.as_of_timestamp - INTERVAL '6 months'
       AND g.order_purchase_timestamp <= m.as_of_timestamp
    GROUP BY m.report_month, m.as_of_timestamp, g.customer_unique_id
),
repeat_window_metrics AS (
    SELECT
        rw.report_month,
        rw.as_of_timestamp,
        rw.window_months,
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE rw.window_order_count > 1) AS returning_customers
    FROM repeat_window rw
    GROUP BY rw.report_month, rw.as_of_timestamp, rw.window_months
)
SELECT
    report_month,
    as_of_timestamp,
    'lifetime_repeat_purchase' AS metric_code,
    total_customers,
    returning_customers,
    CASE
        WHEN total_customers > 0
        THEN returning_customers::numeric / total_customers
    END AS repeat_purchase_rate
FROM lifetime_metrics

UNION ALL

SELECT
    report_month,
    as_of_timestamp,
    ('last_' || window_months || 'm_returning_customer') AS metric_code,
    total_customers,
    returning_customers,
    CASE
        WHEN total_customers > 0
        THEN returning_customers::numeric / total_customers
    END AS repeat_purchase_rate
FROM window_metrics

UNION ALL

SELECT
    report_month,
    as_of_timestamp,
    ('last_' || window_months || 'm_repeat_purchase') AS metric_code,
    total_customers,
    returning_customers,
    CASE
        WHEN total_customers > 0
        THEN returning_customers::numeric / total_customers
    END AS repeat_purchase_rate
FROM repeat_window_metrics
ORDER BY report_month, metric_code;

