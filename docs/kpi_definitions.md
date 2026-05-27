# KPI Definitions

KPI framework for the Olist e-commerce analytics project. Gold / dashboard SQL (`sql/05_create_gold_tables.sql`, `sql/06_create_dashboard_tables.sql`) should implement these definitions consistently.

**Layer mapping (current repo):**

| Logical name | Table |
|--------------|-------|
| `orders` | `silver_olist_orders_dataset` |
| `order_items` | `raw_olist_order_items_dataset` |
| `order_payments` | `raw_olist_order_payments_dataset` |
| `customers` | `raw_olist_customers_dataset` |
| `order_reviews` | `raw_olist_order_reviews_dataset` |
| `products` | `silver_products_join_category_translation` |
| `geolocation` | `silver_olist_geolocation_dedup` |

**Shared filter (most sales / logistics KPIs):**

- `order_status = 'delivered'`
- Exclude `canceled`, `unavailable`
- For delivery-date metrics: `order_delivered_customer_date IS NOT NULL` and `is_delivery_inconsistency = false`
- **As-of date** for rolling windows: `MAX(order_purchase_timestamp)` in `orders` (dataset end date)

---

## 1. Gross Merchandise Value (GMV)

| Field | Definition |
|-------|------------|
| **Business purpose** | Measure total sales generated on the platform |
| **Formula** | `SUM(price + freight_value)` |
| **Granularity** | Daily / Weekly / Monthly |
| **Data source** | `order_items` + `orders` |
| **Filter logic** | Only delivered orders |
| **Exclude** | `canceled`, `unavailable` orders |
| **Visualization** | KPI card + monthly trend line |
| **Business insight** | Indicates overall platform sales performance |

**Note:** Shown alongside **Actual Payment** (#8) as a separate KPI (item value vs cash collected).

---

## 2. Total Orders

| Field | Definition |
|-------|------------|
| **Business purpose** | Measure number of completed customer purchases |
| **Formula** | `COUNT(DISTINCT order_id)` |
| **Granularity** | Daily / Monthly |
| **Data source** | `orders` |
| **Filter logic** | `order_status = 'delivered'` |
| **Visualization** | KPI card + time series |
| **Business insight** | Reflects transaction volume growth |

---

## 3. Average Order Value (AOV)

| Field | Definition |
|-------|------------|
| **Business purpose** | Understand customer spending behavior |
| **Formula** | `GMV / Total Orders` (same period and same delivered filter) |
| **Granularity** | Monthly |
| **Data source** | `orders` + `order_items` |
| **Visualization** | KPI card + trend |
| **Business insight** | Higher AOV may indicate stronger purchasing power |

---

## 4. Customer Retention / Repeat Purchase Rate

| Field | Definition |
|-------|------------|
| **Business purpose** | Measure repeat customer behavior |
| **Granularity** | Monthly trend + single as-of snapshot |
| **Data source** | `customers` + `orders` |
| **Visualization** | Line chart (five series) |
| **Business insight** | Strong retention implies healthier customer loyalty |

**Population key (all metrics):** `customer_unique_id` (not `customer_id`).

**Olist note:** `customer_id` on each order is unique (one id per order). Use `customer_unique_id` from `customers` (via `gold_customer_delivered_orders` or `gold_fact_orders`) to count real people for repeat purchase.

Report **five metrics** (aligned with `dash_retention_snapshot` and `dash_retention_monthly`):

| Metric code | Numerator (`returning_customers`) | Denominator (`total_customers`) | Rate |
|-------------|----------------------------------|----------------------------------|------|
| **`lifetime_repeat_purchase`** | `customer_unique_id` with lifetime delivered order count **> 1** | `customer_unique_id` with lifetime delivered order count **≥ 1** | Numerator ÷ Denominator |
| **`last_3m_returning_customer`** | Customers with ≥ 1 delivered order in last 3 months **and** ≥ 1 delivered order before 3-month window | Customers with ≥ 1 delivered order in last 3 months | Numerator ÷ Denominator |
| **`last_6m_returning_customer`** | Same as above with 6-month window | Customers with ≥ 1 delivered order in last 6 months | Numerator ÷ Denominator |
| **`last_3m_repeat_purchase`** | Customers with delivered order count **> 1** within last 3 months | Customers with ≥ 1 delivered order within last 3 months | Numerator ÷ Denominator |
| **`last_6m_repeat_purchase`** | Customers with delivered order count **> 1** within last 6 months | Customers with ≥ 1 delivered order within last 6 months | Numerator ÷ Denominator |

**Window definition (3m / 6m, as-of based):**

- `as_of_date` = `MAX(order_purchase_timestamp)` on delivered orders
- Last 3 months: `(as_of_date - interval '3 months', as_of_date]`
- “Before window”: `order_purchase_timestamp <= as_of_date - interval '3 months'` (6m analogous)
- Snapshot table: `dash_retention_snapshot` (single as-of date)
- Trend table: `dash_retention_monthly` (as-of at month end)

---

## 5. Delivery Delay Rate

| Field | Definition |
|-------|------------|
| **Business purpose** | Monitor logistics performance |
| **Formula** | `Delayed Orders / Total Delivered Orders` |
| **Delay logic** | `order_delivered_customer_date > order_estimated_delivery_date` |
| **Granularity** | Monthly |
| **Data source** | `orders` |
| **Filter logic** | `order_status = 'delivered'`, both dates not null, `is_delivery_inconsistency = false` |
| **Visualization** | Bar chart |
| **Business insight** | High delay rate may hurt customer satisfaction |

---

## 6. Average Review Score

| Field | Definition |
|-------|------------|
| **Business purpose** | Measure customer satisfaction |
| **Formula** | `AVG(review_score)` |
| **Granularity** | Monthly |
| **Data source** | `order_reviews` + `orders` |
| **Filter logic** | Join reviews to **delivered** orders only |
| **Visualization** | Gauge / trend |
| **Business insight** | Indicates customer experience quality |

---

## 7. Payment Installment Usage

| Field | Definition |
|-------|------------|
| **Business purpose** | Understand financing / payment behavior |
| **Formula** | `Orders using installments / Total Delivered Orders` |
| **Granularity** | Monthly |
| **Data source** | `order_payments` + `orders` |
| **Logic** | **Using installments:** delivered order has **any** payment row with `payment_installments > 1` |
| **Visualization** | Pie chart |
| **Business insight** | Indicates customer affordability preference |

**`payment_installments` meaning (Olist data):**

| Value | Meaning | Typical use in KPI |
|-------|---------|-------------------|
| **1** | Single payment / pay in full (default) | Not counted as “installment usage” |
| **> 1** | Multi-installment (mostly `credit_card`) | Numerator for #7 |
| **0** | Rare (2 rows in source); likely N/A on a secondary payment line — **not** the normal “single payment” code | Treat as data quirk; do not treat as installment |

See [Appendix: payment_installments check](#appendix-payment_installments-check) for SQL.

---

## 8. Actual Payment

| Field | Definition |
|-------|------------|
| **Business purpose** | Measure the actual amount paid by customers |
| **Formula** | `SUM(payment_value)` |
| **Granularity** | Daily / Weekly / Monthly |
| **Data source** | `order_payments` + `orders` |
| **Filter logic** | Only delivered orders |
| **Exclude** | `canceled`, `unavailable` orders |
| **Visualization** | KPI card + monthly trend line |
| **Business insight** | Reflects actual revenue collected (separate from GMV #1) |

---

## 9. Top Selling Category

| Field | Definition |
|-------|------------|
| **Business purpose** | Identify product categories contributing the most sales |
| **Formula** | `SUM(price + freight_value)` by category |
| **Category dimension** | `COALESCE(product_category_name_english, 'Unknown')` from `silver_products_join_category_translation` |
| **Granularity** | Monthly / category level |
| **Data source** | `order_items` + `products` + `orders` |
| **Filter logic** | Only delivered orders |
| **Exclude** | `canceled`, `unavailable` orders |
| **Visualization** | Bar chart / treemap |
| **Business insight** | Helps understand demand and marketing / inventory focus |

`missing_translation_flag` remains for QA; dashboards bucket untranslated categories as **Unknown**.

---

## Quick reference

| # | KPI | Core formula |
|---|-----|----------------|
| 1 | GMV | `SUM(price + freight_value)` on delivered orders |
| 2 | Total Orders | `COUNT(DISTINCT order_id)` delivered |
| 3 | AOV | GMV ÷ Total Orders |
| 4 | Retention / repeat metrics | 5 metrics: lifetime_repeat_purchase, last_3m_returning_customer, last_6m_returning_customer, last_3m_repeat_purchase, last_6m_repeat_purchase |
| 5 | Delivery Delay Rate | Delayed ÷ delivered (valid dates) |
| 6 | Average Review Score | `AVG(review_score)` on delivered orders |
| 7 | Payment Installment Usage | Delivered orders with any `payment_installments > 1` ÷ delivered orders |
| 8 | Actual Payment | `SUM(payment_value)` on delivered orders |
| 9 | Top Selling Category | `SUM(price + freight_value)` by `COALESCE(..., 'Unknown')` |

