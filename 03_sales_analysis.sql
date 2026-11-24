-- =====================================================================
-- 03_sales_analysis.sql : revenue, categories, sellers, states, payments
-- Revenue = product price (order_items.price) unless stated otherwise.
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Q1. Overall business performance (delivered orders)
-- One order can have several items AND several payments. Joining
-- order_items and order_payments directly repeats rows and inflates
-- totals (payment value came out 28% too high: 19.78M instead of 15.42M).
-- So each table is first summed to one row per order in a CTE.
-- Result: 96,477 orders, 93,357 customers, payments 15.42M,
--         AOV 159.86, product sales 13.22M, avg item price 119.98
-- ---------------------------------------------------------------------
WITH order_payment AS (
    SELECT order_id, SUM(payment_value) AS order_payment
    FROM order_payments
    GROUP BY order_id
),
order_item AS (
    SELECT order_id, SUM(price) AS item_sales, COUNT(*) AS items
    FROM order_items
    GROUP BY order_id
)
SELECT
    COUNT(*)                                     AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)         AS total_customers,
    ROUND(SUM(op.order_payment), 2)              AS total_payment_value,
    ROUND(SUM(op.order_payment) / COUNT(*), 2)   AS average_order_value,
    ROUND(SUM(oi.item_sales), 2)                 AS total_product_sales,
    ROUND(SUM(oi.item_sales) / SUM(oi.items), 2) AS average_item_price
FROM orders AS o
INNER JOIN customers     AS c  ON o.customer_id = c.customer_id
INNER JOIN order_payment AS op ON o.order_id = op.order_id
INNER JOIN order_item    AS oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- ---------------------------------------------------------------------
-- Q2. Monthly sales and orders (delivered)
-- Result: peak in Nov 2017 (Black Friday): 987.8K sales, 7,289 orders
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    ROUND(SUM(oi.price), 2)    AS monthly_sales,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Q3. Top 10 product categories by sales
-- 13 products have a category with no English translation; COALESCE
-- falls back to the Portuguese name before 'Unknown'.
-- Result: health_beauty 9.3%, watches_gifts 8.9%, bed_bath_table 7.6%
-- ---------------------------------------------------------------------
SELECT
    COALESCE(ct.product_category_name_english,
             p.product_category_name,
             'Unknown')            AS product_category,
    ROUND(SUM(oi.price), 2)        AS total_sales,
    ROUND(SUM(oi.price) * 100.0 / (SELECT SUM(price) FROM order_items), 2) AS sales_share_pct,
    COUNT(DISTINCT oi.order_id)    AS total_orders
FROM order_items AS oi
INNER JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
GROUP BY product_category
ORDER BY total_sales DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4. Top 10 sellers by sales
-- ---------------------------------------------------------------------
SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    ROUND(SUM(oi.price), 2)     AS total_sales,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items AS oi
INNER JOIN sellers AS s
    ON oi.seller_id = s.seller_id
GROUP BY oi.seller_id, s.seller_city, s.seller_state
ORDER BY total_sales DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q5. Sales by customer state (delivered)
-- Result: SP 38.3% of sales; SP + RJ + MG = 63.3%
-- ---------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)           AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    ROUND(SUM(oi.price), 2)              AS total_sales
FROM orders AS o
INNER JOIN customers   AS c  ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_sales DESC;

-- ---------------------------------------------------------------------
-- Q6. Payment method mix
-- Result: credit card 78.3% of payment value, boleto 17.9%,
--         voucher 2.4%, debit card 1.4%
-- ---------------------------------------------------------------------
SELECT
    payment_type,
    COUNT(DISTINCT order_id)     AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(SUM(payment_value) * 100.0 / (SELECT SUM(payment_value) FROM order_payments), 2) AS value_share_pct,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- ---------------------------------------------------------------------
-- Q7. Average order value (all orders, from payments)
-- Result: 99,440 orders, AOV 160.99
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(SUM(payment_value) / COUNT(DISTINCT order_id), 2) AS average_order_value
FROM order_payments;
