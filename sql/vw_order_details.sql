CREATE OR REPLACE VIEW vw_order_details AS
SELECT
    f.order_id,
    c.customer_unique_id,
    c.customer_state,
    f.total_sales,
    f.total_payment_value,
    f.review_score,
    f.delivery_days,
    f.num_items,
    d.year AS purchase_year,
    d.month AS purchase_month
FROM fact_orders f
JOIN dim_customer c ON f.customer_sk = c.customer_sk
JOIN dim_date d ON f.purchase_date_sk = d.date_sk;