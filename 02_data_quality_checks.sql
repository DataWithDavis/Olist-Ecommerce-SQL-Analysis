-- =====================================================================
-- 02_data_quality_checks.sql : missing values, duplicates and ranges
-- Run after 01_schema_and_load.sql. Results noted as comments.
-- =====================================================================
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------
-- Duplicate customer IDs (expect none)
SELECT customer_id, COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Missing values
SELECT
    COUNT(*)                  AS total_rows,
    SUM(customer_id IS NULL)  AS missing_customer_id,
    SUM(customer_city IS NULL)  AS missing_city,
    SUM(customer_state IS NULL) AS missing_state
FROM customers;

-- ---------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------
-- Order status distribution
-- Result: delivered 96,478 (97.0%), shipped 1,107, canceled 625, unavailable 609
SELECT order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Date range
-- Result: 2016-09-04 to 2018-10-17 (Sep-Dec 2016 and Sep-Oct 2018 are partial)
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- Missing values
-- Result: 160 orders never approved, 2,965 without a delivery date
--         (mostly shipped / canceled / unavailable orders)
SELECT
    COUNT(*)                                AS total_rows,
    SUM(order_purchase_timestamp IS NULL)      AS missing_purchase_date,
    SUM(order_approved_at IS NULL)             AS missing_approved_date,
    SUM(order_delivered_carrier_date IS NULL)  AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_date
FROM orders;

-- ---------------------------------------------------------------------
-- Order items
-- ---------------------------------------------------------------------
-- Missing values
SELECT
    COUNT(*)                AS total_rows,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(seller_id IS NULL)  AS missing_seller_id,
    SUM(price IS NULL)      AS missing_price,
    SUM(freight_value IS NULL) AS missing_freight
FROM order_items;

-- Price and freight ranges
-- Result: price 0.85 to 6,735 (avg 120.65); freight 0 to 409.68 (avg 20.03)
SELECT
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price,
    ROUND(AVG(price), 2) AS average_price,
    MIN(freight_value) AS minimum_freight,
    MAX(freight_value) AS maximum_freight,
    ROUND(AVG(freight_value), 2) AS average_freight
FROM order_items;

-- ---------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------
-- Missing values
-- Result: 610 products have no category (shown as 'Unknown' in analysis)
SELECT
    COUNT(*)                           AS total_rows,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_photos_qty IS NULL)    AS missing_photos,
    SUM(product_weight_g IS NULL)      AS missing_weight
FROM products;

-- Products per category
SELECT product_category_name, COUNT(*) AS total_products
FROM products
GROUP BY product_category_name
ORDER BY total_products DESC;

-- Categories that have no English translation
SELECT DISTINCT p.product_category_name
FROM products AS p
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- ---------------------------------------------------------------------
-- Sellers
-- ---------------------------------------------------------------------
-- Sellers by state
-- Result: SP 1,849 of 3,095 sellers (60%)
SELECT seller_state, COUNT(*) AS total_sellers
FROM sellers
GROUP BY seller_state
ORDER BY total_sellers DESC;

-- ---------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------
-- Duplicate payment records (expect none)
SELECT order_id, payment_sequential, COUNT(*) AS duplicate_count
FROM order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------
-- review_id repeats across orders, which is why the table key is
-- (review_id, order_id). Result: 814 repeated review_ids
SELECT COUNT(*) - COUNT(DISTINCT review_id) AS repeated_review_ids
FROM order_reviews;

-- Missing values
-- Result: most reviews have no text (87,656 no title, 58,247 no message)
SELECT
    COUNT(*)                            AS total_rows,
    SUM(review_score IS NULL)           AS missing_review_score,
    SUM(review_comment_title IS NULL)   AS missing_title,
    SUM(review_comment_message IS NULL) AS missing_message
FROM order_reviews;

-- Review score distribution
-- Result: 5 stars 57.8%, 4 stars 19.3%, 1 star 11.5%
SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_reviews), 2) AS percentage
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- ---------------------------------------------------------------------
-- Geolocation
-- ---------------------------------------------------------------------
SELECT
    MIN(geolocation_lat) AS min_latitude,
    MAX(geolocation_lat) AS max_latitude,
    MIN(geolocation_lng) AS min_longitude,
    MAX(geolocation_lng) AS max_longitude
FROM geolocation;
