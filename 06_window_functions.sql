-- =====================================================================
-- 06_window_functions.sql : rankings, running totals, month-over-month
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Q20. Top 10 products: ROW_NUMBER vs RANK vs DENSE_RANK
-- ---------------------------------------------------------------------
WITH product_sales AS (
    SELECT product_id, ROUND(SUM(price), 2) AS total_sales
    FROM order_items
    GROUP BY product_id
)
SELECT
    product_id,
    total_sales,
    ROW_NUMBER() OVER (ORDER BY total_sales DESC) AS row_num,
    RANK()       OVER (ORDER BY total_sales DESC) AS sales_rank,
    DENSE_RANK() OVER (ORDER BY total_sales DESC) AS dense_sales_rank
FROM product_sales
ORDER BY total_sales DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q21. Second-highest selling product
-- ---------------------------------------------------------------------
WITH product_sales AS (
    SELECT product_id, SUM(price) AS total_sales
    FROM order_items
    GROUP BY product_id
),
product_ranking AS (
    SELECT product_id, total_sales,
           DENSE_RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
    FROM product_sales
)
SELECT product_id, ROUND(total_sales, 2) AS total_sales, sales_rank
FROM product_ranking
WHERE sales_rank = 2;

-- ---------------------------------------------------------------------
-- Q22. Top 3 products for each seller (RANK with PARTITION BY)
-- ---------------------------------------------------------------------
WITH seller_product_sales AS (
    SELECT seller_id, product_id, SUM(price) AS total_sales
    FROM order_items
    GROUP BY seller_id, product_id
),
product_ranking AS (
    SELECT
        seller_id,
        product_id,
        total_sales,
        RANK() OVER (PARTITION BY seller_id ORDER BY total_sales DESC) AS product_rank
    FROM seller_product_sales
)
SELECT seller_id, product_id, ROUND(total_sales, 2) AS total_sales, product_rank
FROM product_ranking
WHERE product_rank <= 3
ORDER BY seller_id, product_rank;

-- ---------------------------------------------------------------------
-- Q23. Monthly sales with running total (delivered)
-- ---------------------------------------------------------------------
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        SUM(oi.price) AS total_sales
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT
    order_month,
    ROUND(total_sales, 2) AS monthly_sales,
    ROUND(SUM(total_sales) OVER (ORDER BY order_month
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_sales
FROM monthly_sales
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Q24. Month-over-month growth with LAG, next month with LEAD
-- 2016 months are tiny and Nov 2016 has no delivered orders, so growth
-- is only meaningful from 2017 onward: the query starts at Jan 2017.
-- Result: biggest jump Nov 2017 (+52.4%, Black Friday), followed by
--         Dec 2017 (-26.5%); sales flat around 0.85-0.98M per month in 2018
-- ---------------------------------------------------------------------
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        SUM(oi.price) AS total_sales
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),
sales_comparison AS (
    SELECT
        order_month,
        total_sales,
        LAG(total_sales)  OVER (ORDER BY order_month) AS previous_month_sales,
        LEAD(total_sales) OVER (ORDER BY order_month) AS next_month_sales
    FROM monthly_sales
)
SELECT
    order_month,
    ROUND(total_sales, 2)          AS current_month_sales,
    ROUND(previous_month_sales, 2) AS previous_month_sales,
    ROUND((total_sales - previous_month_sales) * 100.0 / NULLIF(previous_month_sales, 0), 2) AS mom_growth_percentage,
    ROUND(next_month_sales, 2)     AS next_month_sales
FROM sales_comparison
ORDER BY order_month;
