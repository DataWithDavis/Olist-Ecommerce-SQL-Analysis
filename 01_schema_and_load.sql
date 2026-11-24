-- =====================================================================
-- Olist E-Commerce SQL Analysis
-- 01_schema_and_load.sql : create the database, tables and load the CSVs
-- Dataset: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
-- Tool: MySQL 8 (MySQL Workbench)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;

-- ---------------------------------------------------------------------
-- 1. Dimension / master tables
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
  customer_id              CHAR(32) PRIMARY KEY,   -- one per order
  customer_unique_id       CHAR(32) NOT NULL,      -- the real customer
  customer_zip_code_prefix VARCHAR(5),
  customer_city            VARCHAR(100),
  customer_state           CHAR(2)
);

CREATE TABLE IF NOT EXISTS sellers (
  seller_id              CHAR(32) PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(5),
  seller_city            VARCHAR(100),
  seller_state           CHAR(2)
);

CREATE TABLE IF NOT EXISTS products (
  product_id                 CHAR(32) PRIMARY KEY,
  product_category_name      VARCHAR(100),
  product_name_lenght        INT,      -- spelling as in the source data
  product_description_lenght INT,
  product_photos_qty         INT,
  product_weight_g           INT,
  product_length_cm          INT,
  product_height_cm          INT,
  product_width_cm           INT
);

CREATE TABLE IF NOT EXISTS category_translation (
  product_category_name         VARCHAR(100) PRIMARY KEY,
  product_category_name_english VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- 2. Transaction tables
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  order_id                      CHAR(32) PRIMARY KEY,
  customer_id                   CHAR(32) NOT NULL,
  order_status                  VARCHAR(30),
  order_purchase_timestamp      DATETIME,
  order_approved_at             DATETIME,
  order_delivered_carrier_date  DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME,
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_purchase_date (order_purchase_timestamp)
);

CREATE TABLE IF NOT EXISTS order_items (
  order_id            CHAR(32) NOT NULL,
  order_item_id       INT NOT NULL,
  product_id          CHAR(32),
  seller_id           CHAR(32),
  shipping_limit_date DATETIME,
  price               DECIMAL(10,2),
  freight_value       DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id),
  INDEX idx_items_product (product_id),
  INDEX idx_items_seller (seller_id)
);

CREATE TABLE IF NOT EXISTS order_payments (
  order_id             CHAR(32) NOT NULL,
  payment_sequential   INT NOT NULL,
  payment_type         VARCHAR(30),
  payment_installments INT,
  payment_value        DECIMAL(10,2),
  PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in this dataset (814 review_ids repeat across
-- different orders). A PRIMARY KEY on review_id alone silently drops those
-- rows during LOAD DATA, so the key is (review_id, order_id).
CREATE TABLE IF NOT EXISTS order_reviews (
  review_id               CHAR(32) NOT NULL,
  order_id                CHAR(32) NOT NULL,
  review_score            INT,
  review_comment_title    TEXT,
  review_comment_message  TEXT,
  review_creation_date    DATETIME,
  review_answer_timestamp DATETIME,
  PRIMARY KEY (review_id, order_id),
  INDEX idx_reviews_order (order_id)
);

-- Repeated postal-code observations, so no unique key.
CREATE TABLE IF NOT EXISTS geolocation (
  geolocation_zip_code_prefix VARCHAR(5),
  geolocation_lat             DECIMAL(13,10),
  geolocation_lng             DECIMAL(13,10),
  geolocation_city            VARCHAR(100),
  geolocation_state           CHAR(2),
  INDEX idx_geo_zip (geolocation_zip_code_prefix)
);

-- ---------------------------------------------------------------------
-- 3. Load the CSV files
--    Change C:/olist_data/ to the folder where your CSV files are stored.
--    LOCAL = MySQL reads the file from your computer, not the server.
--    Needs: SET GLOBAL local_infile = 1;  and OPT_LOCAL_INFILE=1 in the
--    Workbench connection (Advanced -> Others).
-- ---------------------------------------------------------------------
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/olist_data/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/olist_data/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- Empty measurement fields become NULL instead of 0
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(@product_id, @category, @name_len, @desc_len, @photos, @weight, @length, @height, @width)
SET product_id                 = @product_id,
    product_category_name      = NULLIF(@category, ''),
    product_name_lenght        = NULLIF(@name_len, ''),
    product_description_lenght = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@length, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

-- This file uses Windows line endings (\r\n)
LOAD DATA LOCAL INFILE 'C:/olist_data/product_category_name_translation.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

-- Empty dates become NULL instead of 0000-00-00
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, order_status, @purchase, @approved, @carrier, @delivered, @estimated)
SET order_purchase_timestamp      = NULLIF(@purchase, ''),
    order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- This file uses Windows line endings (\r\n)
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(review_id, order_id, review_score, @title, @message, @created, @answered)
SET review_comment_title    = NULLIF(@title, ''),
    review_comment_message  = NULLIF(@message, ''),
    review_creation_date    = NULLIF(@created, ''),
    review_answer_timestamp = NULLIF(@answered, '');

LOAD DATA LOCAL INFILE 'C:/olist_data/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state);

-- ---------------------------------------------------------------------
-- 4. Verify the load: every diff must be 0
-- ---------------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS loaded_rows, 99441 AS expected_rows, COUNT(*) - 99441 AS diff FROM customers
UNION ALL SELECT 'sellers',              COUNT(*), 3095,   COUNT(*) - 3095   FROM sellers
UNION ALL SELECT 'products',             COUNT(*), 32951,  COUNT(*) - 32951  FROM products
UNION ALL SELECT 'category_translation', COUNT(*), 71,     COUNT(*) - 71     FROM category_translation
UNION ALL SELECT 'orders',               COUNT(*), 99441,  COUNT(*) - 99441  FROM orders
UNION ALL SELECT 'order_items',          COUNT(*), 112650, COUNT(*) - 112650 FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*), 103886, COUNT(*) - 103886 FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*), 99224,  COUNT(*) - 99224  FROM order_reviews;

SELECT COUNT(*) AS geolocation_rows FROM geolocation;
