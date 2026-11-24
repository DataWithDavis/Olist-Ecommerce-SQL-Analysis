-- =====================================================================
-- 04_delivery_and_reviews.sql : delivery speed, late orders, reviews
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Q8. Average delivery time (purchase -> customer), delivered orders
-- Result: 96,470 orders, 12.5 days on average
-- ---------------------------------------------------------------------
SELECT
    COUNT(*) AS total_delivered_orders,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2) AS avg_delivery_days,
    MIN(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))           AS min_delivery_days,
    MAX(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))           AS max_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- ---------------------------------------------------------------------
-- Q9. On-time vs late deliveries
-- The estimated date is stored as midnight (00:00:00), so comparing full
-- timestamps marks an order delivered ON the estimated day as late.
-- Comparing DATE() values fixes that (8.1% -> 6.8% late).
-- Result: 93.2% on time, 6.8% late
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN DATE(order_delivered_customer_date) <= DATE(order_estimated_delivery_date)
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM orders
           WHERE order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL), 2) AS percentage
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

-- ---------------------------------------------------------------------
-- Q10. Delivery time and late % by customer state
-- Result: fastest SP 8.7 days; slowest RR 29.3, AP 27.2, AM 26.4 days.
--         Highest late % (states with 500+ orders): MA 17.4%, CE 13.8%
-- ---------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(AVG(CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
                   THEN 1 ELSE 0 END) * 100, 1) AS late_pct
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- ---------------------------------------------------------------------
-- Q11. Average review score by order status
-- ---------------------------------------------------------------------
SELECT
    o.order_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM orders AS o
INNER JOIN order_reviews AS r
    ON o.order_id = r.order_id
GROUP BY o.order_status
ORDER BY total_reviews DESC;

-- ---------------------------------------------------------------------
-- Q12. Do late deliveries get worse reviews?  (headline finding)
-- Reviews are averaged per order first, so an order with two reviews
-- is counted once.
-- Result: on time 4.29 stars vs late 2.27 stars;
--         62.4% of late orders get 1-2 stars vs 9.2% of on-time orders
-- ---------------------------------------------------------------------
WITH order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    CASE
        WHEN DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100, 1) AS pct_1_2_stars
FROM orders AS o
INNER JOIN order_review AS r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;

-- ---------------------------------------------------------------------
-- Q13. Review score by how late the order was
-- Result: on time 4.29 | 1-3 days late 3.29 | 4-7 days 2.11 | 8+ days 1.70
-- ---------------------------------------------------------------------
WITH order_review AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
),
delay AS (
    SELECT
        order_id,
        DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN d.days_late <= 0 THEN '1. On time'
        WHEN d.days_late <= 3 THEN '2. 1-3 days late'
        WHEN d.days_late <= 7 THEN '3. 4-7 days late'
        ELSE '4. 8+ days late'
    END AS delay_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM delay AS d
INNER JOIN order_review AS r
    ON d.order_id = r.order_id
GROUP BY delay_bucket
ORDER BY delay_bucket;
