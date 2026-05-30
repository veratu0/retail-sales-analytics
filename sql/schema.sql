-- ============================================
-- Star Schema for Olist Retail Analytics
-- Run this entire script at once in pgAdmin
-- ============================================

-- Drop everything in reverse dependency order (to avoid foreign key errors)
DROP TABLE IF EXISTS fact_orders CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_seller CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_payment CASCADE;
DROP TABLE IF EXISTS stg_orders CASCADE;
DROP TABLE IF EXISTS stg_customers CASCADE;
DROP TABLE IF EXISTS stg_products CASCADE;
DROP TABLE IF EXISTS stg_order_items CASCADE;
DROP TABLE IF EXISTS stg_sellers CASCADE;
DROP TABLE IF EXISTS stg_payments CASCADE;
DROP TABLE IF EXISTS stg_reviews CASCADE;
DROP TABLE IF EXISTS stg_category_translation CASCADE;

-- 1. Dimension: dim_customer
CREATE TABLE dim_customer (
    customer_sk SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(50),
    customer_state CHAR(2)
);

-- 2. Dimension: dim_product
CREATE TABLE dim_product (
    product_sk SERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE,
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- 3. Dimension: dim_seller
CREATE TABLE dim_seller (
    seller_sk SERIAL PRIMARY KEY,
    seller_id VARCHAR(50) UNIQUE,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(50),
    seller_state CHAR(2)
);

-- 4. Dimension: dim_date
CREATE TABLE dim_date (
    date_sk SERIAL PRIMARY KEY,
    date DATE UNIQUE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day INT,
    day_of_week INT,
    week_of_year INT
);

-- 5. Dimension: dim_payment
CREATE TABLE dim_payment (
    payment_sk SERIAL PRIMARY KEY,
    payment_type VARCHAR(20) UNIQUE
);

-- 6. Fact table: fact_orders (foreign keys added after creation)
CREATE TABLE fact_orders (
    order_sk SERIAL PRIMARY KEY,
    order_id VARCHAR(50),
    customer_sk INT,
    product_sk INT,
    seller_sk INT,
    payment_sk INT,
    purchase_date_sk INT,
    approved_date_sk INT,
    delivered_date_sk INT,
    estimated_date_sk INT,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    total_sales NUMERIC(10,2),
    payment_value NUMERIC(10,2),
    review_score INT,
    order_status VARCHAR(20),
    delivery_days INT
);

-- Add foreign key constraints after all dimension tables exist
ALTER TABLE fact_orders ADD CONSTRAINT fk_customer FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_product FOREIGN KEY (product_sk) REFERENCES dim_product(product_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_seller FOREIGN KEY (seller_sk) REFERENCES dim_seller(seller_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_payment FOREIGN KEY (payment_sk) REFERENCES dim_payment(payment_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_purchase_date FOREIGN KEY (purchase_date_sk) REFERENCES dim_date(date_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_approved_date FOREIGN KEY (approved_date_sk) REFERENCES dim_date(date_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_delivered_date FOREIGN KEY (delivered_date_sk) REFERENCES dim_date(date_sk);
ALTER TABLE fact_orders ADD CONSTRAINT fk_estimated_date FOREIGN KEY (estimated_date_sk) REFERENCES dim_date(date_sk);

-- ============================================
-- Staging tables (for raw CSV import)
-- ============================================

CREATE TABLE stg_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE stg_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(50),
    customer_state CHAR(2)
);

CREATE TABLE stg_products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

CREATE TABLE stg_order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2)
);

CREATE TABLE stg_sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(50),
    seller_state CHAR(2)
);

CREATE TABLE stg_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value NUMERIC(10,2)
);

CREATE TABLE stg_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title VARCHAR(200),
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE stg_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

-- Confirmation message
SELECT 'All tables created successfully!' AS status;