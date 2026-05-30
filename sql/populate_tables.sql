-- dim_customer: one row per unique customer_id (natural key)
INSERT INTO dim_customer (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM stg_customers
ON CONFLICT (customer_id) DO NOTHING;

-- dim_product
INSERT INTO dim_product (product_id, product_category_name, product_category_name_english, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT DISTINCT
    p.product_id,
    p.product_category_name,
    ct.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM stg_products p
LEFT JOIN stg_category_translation ct ON p.product_category_name = ct.product_category_name
ON CONFLICT (product_id) DO NOTHING;

-- dim_seller
INSERT INTO dim_seller (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT DISTINCT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM stg_sellers
ON CONFLICT (seller_id) DO NOTHING;

-- dim_payment
INSERT INTO dim_payment (payment_type)
SELECT DISTINCT payment_type FROM stg_payments
ON CONFLICT (payment_type) DO NOTHING;

-- dim_date
-- Create a temporary list of all distinct dates from all relevant columns
DROP TABLE IF EXISTS temp_all_dates;
CREATE TEMP TABLE temp_all_dates AS
SELECT DISTINCT DATE(order_purchase_timestamp) AS date FROM stg_orders
UNION
SELECT DISTINCT DATE(order_approved_at) FROM stg_orders WHERE order_approved_at IS NOT NULL
UNION
SELECT DISTINCT DATE(order_delivered_customer_date) FROM stg_orders WHERE order_delivered_customer_date IS NOT NULL
UNION
SELECT DISTINCT DATE(order_estimated_delivery_date) FROM stg_orders;

-- Insert into dim_date
INSERT INTO dim_date (date, year, quarter, month, month_name, day, day_of_week, week_of_year)
SELECT
    date,
    EXTRACT(YEAR FROM date)::INT AS year,
    EXTRACT(QUARTER FROM date)::INT AS quarter,
    EXTRACT(MONTH FROM date)::INT AS month,
    TO_CHAR(date, 'Month') AS month_name,
    EXTRACT(DAY FROM date)::INT AS day,
    EXTRACT(DOW FROM date)::INT AS day_of_week,  -- 0=Sunday, 6=Saturday
    EXTRACT(WEEK FROM date)::INT AS week_of_year
FROM temp_all_dates
ORDER BY date;

-- fact_orders
INSERT INTO fact_orders (
    order_id,
    customer_sk,
    payment_sk,
    purchase_date_sk,
    approved_date_sk,
    delivered_date_sk,
    estimated_date_sk,
    total_price,
    total_freight,
    total_sales,
    total_payment_value,
    review_score,
    order_status,
    delivery_days,
    num_items
)
SELECT
    o.order_id,
    c.customer_sk,
    pay.payment_sk,
    dp_pur.date_sk AS purchase_date_sk,
    dp_app.date_sk AS approved_date_sk,
    dp_del.date_sk AS delivered_date_sk,
    dp_est.date_sk AS estimated_date_sk,
    SUM(oi.price) AS total_price,
    SUM(oi.freight_value) AS total_freight,
    SUM(oi.price + oi.freight_value) AS total_sales,
    SUM(py.payment_value) AS total_payment_value,
    AVG(r.review_score)::INT AS review_score,  -- average review score per order (if multiple reviews? But one review per order normally)
    o.order_status,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))::INT AS delivery_days,
    COUNT(oi.order_item_id) AS num_items
FROM stg_orders o
JOIN stg_customers cust ON o.customer_id = cust.customer_id
JOIN dim_customer c ON cust.customer_id = c.customer_id
LEFT JOIN stg_order_items oi ON o.order_id = oi.order_id
LEFT JOIN stg_payments py ON o.order_id = py.order_id
LEFT JOIN dim_payment pay ON py.payment_type = pay.payment_type
LEFT JOIN stg_reviews r ON o.order_id = r.order_id
LEFT JOIN dim_date dp_pur ON DATE(o.order_purchase_timestamp) = dp_pur.date
LEFT JOIN dim_date dp_app ON DATE(o.order_approved_at) = dp_app.date
LEFT JOIN dim_date dp_del ON DATE(o.order_delivered_customer_date) = dp_del.date
LEFT JOIN dim_date dp_est ON DATE(o.order_estimated_delivery_date) = dp_est.date
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 
    o.order_id, c.customer_sk, pay.payment_sk, dp_pur.date_sk, dp_app.date_sk, 
    dp_del.date_sk, dp_est.date_sk, o.order_status, o.order_delivered_customer_date, 
    o.order_purchase_timestamp;