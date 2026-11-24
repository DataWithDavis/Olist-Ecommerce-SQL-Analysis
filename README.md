# Olist E-Commerce SQL Analysis

**Late deliveries cost Olist its ratings: on-time orders average 4.29 stars, late orders 2.27, and 62% of late orders get a 1-2 star review.**

An end-to-end SQL analysis of ~100,000 orders from Olist, a Brazilian online marketplace, built entirely in **MySQL**. The project covers loading 8 relational tables, data quality checks, and 24 business questions on sales, delivery, reviews and customers, using JOINs, CTEs, CASE logic and window functions.

## Dataset

- **Source:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Period:** Sep 2016 - Oct 2018 (2016 and Sep-Oct 2018 are partial months)
- **Tables:** 8 core tables + geolocation

| Table | Rows | Key |
| --- | ---: | --- |
| orders | 99,441 | order_id |
| order_items | 112,650 | order_id + order_item_id |
| order_payments | 103,886 | order_id + payment_sequential |
| order_reviews | 99,224 | review_id + order_id |
| customers | 99,441 | customer_id |
| products | 32,951 | product_id |
| sellers | 3,095 | seller_id |
| category_translation | 71 | product_category_name |

## Key Findings

1. **Late delivery is the biggest driver of bad reviews.** 6.8% of delivered orders arrived after the promised date. Their average review is 2.27 stars vs 4.29 for on-time orders, and it keeps falling with the delay: 3.29 (1-3 days late), 2.11 (4-7 days), 1.70 (8+ days).
2. **Delivery speed depends heavily on location.** Average delivery is 12.5 days, but SP customers wait 8.7 days while RR, AP and AM wait 26-29 days. MA (17.4%) and CE (13.8%) have the highest share of late orders.
3. **Almost no customer comes back.** Only 3.12% of 96,096 customers placed more than one order, and one-time buyers bring 94.1% of revenue.
4. **Sales are concentrated in the South-East.** SP alone is 38.3% of product sales; SP, RJ and MG together are 63.3%.
5. **Top categories:** health & beauty (9.3%), watches & gifts (8.9%) and bed, bath & table (7.6%).
6. **Payments:** credit card carries 78.3% of payment value, boleto (bank slip) 17.9%.
7. **Seasonality:** sales jumped 52.4% in Nov 2017 (Black Friday), then fell 26.5% in December. Through 2018 monthly sales stayed flat at roughly 0.85-0.98M.
8. **Overall (delivered orders):** 96,477 orders, 15.42M in payments, average order value 159.86.

## Recommendations

1. **Fix delivery promises in slow regions.** Set more realistic estimated dates or add carrier capacity for the North and North-East (RR, AP, AM, MA, CE). Even 1-3 days of delay costs a full review star.
2. **Build a retention program.** With a 3% repeat rate, even a small lift in second purchases (post-delivery coupons, follow-up emails after a 5-star review) would add revenue without new acquisition cost.
3. **Prepare for November peaks.** Plan seller stock and logistics capacity ahead of Black Friday, when sales rose 52% and orders 63% in 2017.

## Data Quality Notes

- **review_id is not unique:** 814 review IDs repeat across different orders. A primary key on review_id alone makes `LOAD DATA` silently skip those rows, so the table key is (review_id, order_id).
- **Avoiding double counting:** an order can have several items and several payments. Joining both tables directly inflated payment value by 28% (19.78M instead of 15.42M), so each table is summed per order in a CTE before joining.
- **Late = by date, not timestamp:** estimated delivery dates are stored at midnight, so comparing full timestamps marks same-day deliveries as late (8.1%). Comparing dates gives the correct 6.8%.
- Empty dates and measurements are loaded as NULL (`NULLIF`) instead of `0000-00-00` / 0. 610 products have no category and are shown as "Unknown".

## Project Files

| File | What it does |
| --- | --- |
| [`01_schema_and_load.sql`](01_schema_and_load.sql) | Creates the database, tables, keys and indexes; loads the CSVs; verifies row counts |
| [`02_data_quality_checks.sql`](02_data_quality_checks.sql) | Missing values, duplicates, value ranges, distributions |
| [`03_sales_analysis.sql`](03_sales_analysis.sql) | Q1-Q7: overall KPIs, monthly sales, categories, sellers, states, payments, AOV |
| [`04_delivery_and_reviews.sql`](04_delivery_and_reviews.sql) | Q8-Q13: delivery time, late orders, state-level delivery, review scores vs delays |
| [`05_customer_analysis.sql`](05_customer_analysis.sql) | Q14-Q19: repeat customers, new vs returning, segments, customer lifetime value |
| [`06_window_functions.sql`](06_window_functions.sql) | Q20-Q24: ROW_NUMBER / RANK / DENSE_RANK, top 3 per seller, running total, LAG / LEAD growth |

## SQL Skills Used

- Table design with primary keys and indexes; bulk loading with `LOAD DATA` and `NULLIF`
- Multi-table `INNER` / `LEFT JOIN`s across up to 4 tables
- CTEs (`WITH`), subqueries, `CASE WHEN`, `COALESCE`
- Aggregations with `GROUP BY` / `HAVING`, date functions (`DATEDIFF`, `DATE_FORMAT`)
- Window functions: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `SUM() OVER`, `LAG`, `LEAD`, `PARTITION BY`

## How to Run

1. Download the CSV files from Kaggle into one folder.
2. In MySQL Workbench, run `SET GLOBAL local_infile = 1;` and add `OPT_LOCAL_INFILE=1` under the connection's Advanced -> Others.
3. In `01_schema_and_load.sql`, replace `C:/olist_data/` with your folder path and run the file. Every `diff` in the final check should be 0.
4. Run files `02` to `06` in order.

## Author

**Davis Wilson** - Data Analyst | SQL - Python - Power BI
[LinkedIn](https://www.linkedin.com/in/datawithdavis) - [GitHub](https://github.com/DataWithDavis)
