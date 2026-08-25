# Power BI

## Live Dashboard

[Open published report](https://app.powerbi.com/view?r=eyJrIjoiZTMzZTNhMjUtZjBkYS00NWUyLWJiMmYtOGE0MTBhZDliMmU5IiwidCI6IjI2Y2NmYmI0LTc4MTYtNGY0My1hMjM2LWI2ZmZmYjg0Y2ZjMSIsImMiOjEwfQ%3D%3D)

## Local File

```text
powerbi/ecommerce_dashboard_v2.pbix
```

The `.pbix` is ignored by git (large binary). Keep a local copy for edits; use the published link + screenshots for portfolio review.

## Pages

| # | Page | Screenshot |
|---|------|------------|
| 1 | Executive Overview | [`01_executive_overview.png`](screenshots/01_executive_overview.png) |
| 2 | Sales Performance | [`02_sales_performance.png`](screenshots/02_sales_performance.png) |
| 3 | Category Analysis | [`03_category_analysis.png`](screenshots/03_category_analysis.png) |
| 4 | Customer Snapshot | [`04_customer_snapshot.png`](screenshots/04_customer_snapshot.png) |
| 5 | Forecasting | [`05_forecasting.png`](screenshots/05_forecasting.png) |

## Data Model

Star-schema relationships used by the report:

```text
powerbi/screenshots/00_data_model.png
```

Core relationships:

- `gold_dim_date` → `gold_fact_orders` / `gold_fact_order_items`
- `gold_dim_customer` → `gold_fact_order_items` (state / city filters)
- `gold_dim_product` → category labels and rankings
- ML forecast tables feed the Forecasting page

## Screenshots

Dashboard pages only (not shown in the report UI):

```text
powerbi/screenshots/
├── 01_executive_overview.png
├── 02_sales_performance.png
├── 03_category_analysis.png
├── 04_customer_snapshot.png
└── 05_forecasting.png
```

Data model screenshot (architecture reference):

```text
powerbi/screenshots/00_data_model.png
```
