-- =====================================================================
-- 05_customer_analysis.sql : repeat customers, segments, lifetime value
-- customer_id is created per order; customer_unique_id is the real
-- person, so every customer metric below uses customer_unique_id.
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Q14. Repeat vs one-time customers
-- Result: 96,096 customers; only 2,997 (3.12%) ordered more than once
-- ---------------------------------------------------------------------
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_customer_percentage
FROM (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders;

-- ---------------------------------------------------------------------
-- Q15. Monthly active customers and orders (delivered)
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    COUNT(DISTINCT o.order_id)           AS total_orders
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Q16. New vs returning customers by month (delivered)
-- New = the customer's first-ever order falls in that month
-- ---------------------------------------------------------------------
WITH customer_first_order AS (
    SELECT c.customer_unique_id, MIN(o.order_purchase_timestamp) AS first_order_date
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
monthly_customers AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        c.customer_unique_id
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), c.customer_unique_id
)
SELECT
    mc.order_month,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN mc.order_month =  DATE_FORMAT(cfo.first_order_date, '%Y-%m') THEN 1 ELSE 0 END) AS new_customers,
    SUM(CASE WHEN mc.order_month >  DATE_FORMAT(cfo.first_order_date, '%Y-%m') THEN 1 ELSE 0 END) AS returning_customers
FROM monthly_customers AS mc
INNER JOIN customer_first_order AS cfo
    ON mc.customer_unique_id = cfo.customer_unique_id
GROUP BY mc.order_month
ORDER BY mc.order_month;

-- ---------------------------------------------------------------------
-- Q17. Customer segments by number of orders
-- One-Time = 1 order, Regular = 2-3 orders, Loyal = 4+ orders
-- ---------------------------------------------------------------------
WITH customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customer'
            WHEN total_orders BETWEEN 2 AND 3 THEN 'Regular Customer'
            ELSE 'Loyal Customer'
        END AS customer_segment
    FROM customer_orders
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_segments), 2) AS customer_percentage
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_customers DESC;

-- ---------------------------------------------------------------------
-- Q18. Revenue contribution by customer segment
-- (payments only - no join to order_items, so no double counting)
-- Result: One-Time customers are 96.9% of customers and 94.1% of revenue;
--         Regular 3.1% / 5.7%; Loyal (4+ orders) just 49 customers
-- ---------------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(op.payment_value)      AS total_payment
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.customer_id = o.customer_id
    INNER JOIN order_payments AS op
        ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        customer_unique_id,
        total_payment,
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customer'
            WHEN total_orders BETWEEN 2 AND 3 THEN 'Regular Customer'
            ELSE 'Loyal Customer'
        END AS customer_segment
    FROM customer_orders
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_payment), 2) AS total_revenue,
    ROUND(SUM(total_payment) * 100.0 / (SELECT SUM(total_payment) FROM customer_segments), 2) AS revenue_percentage,
    ROUND(AVG(total_payment), 2) AS avg_lifetime_value
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- ---------------------------------------------------------------------
-- Q19. Customer lifetime value (CLV): top 10 and overall average
-- Result: average CLV 166.59 across 96,095 paying customers
-- ---------------------------------------------------------------------
WITH customer_payments AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(op.payment_value)      AS lifetime_value
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_payments AS op
        ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
)
SELECT customer_unique_id, total_orders, ROUND(lifetime_value, 2) AS lifetime_value
FROM customer_payments
ORDER BY lifetime_value DESC
LIMIT 10;

WITH customer_payments AS (
    SELECT c.customer_unique_id, SUM(op.payment_value) AS lifetime_value
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_payments AS op
        ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                     AS total_customers,
    ROUND(AVG(lifetime_value), 2) AS average_customer_lifetime_value,
    ROUND(MAX(lifetime_value), 2) AS highest_customer_value,
    ROUND(MIN(lifetime_value), 2) AS lowest_customer_value
FROM customer_payments;
