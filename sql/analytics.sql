-- Monthly sales trend with running total and year-over-year growth
WITH monthly_sales AS (
    SELECT 
        d.year,
        d.month,
        d.month_name,
        SUM(f.total_sales) AS monthly_revenue
    FROM fact_orders f
    JOIN dim_date d ON f.purchase_date_sk = d.date_sk
    GROUP BY d.year, d.month, d.month_name, d.date
),
monthly_with_lag AS (
    SELECT 
        year,
        month,
        month_name,
        monthly_revenue,
        LAG(monthly_revenue, 12) OVER (ORDER BY year, month) AS revenue_same_month_previous_year,
        SUM(monthly_revenue) OVER (ORDER BY year, month) AS running_total_sales
    FROM monthly_sales
)
SELECT 
    year,
    month,
    month_name,
    monthly_revenue,
    running_total_sales,
    revenue_same_month_previous_year,
    CASE 
        WHEN revenue_same_month_previous_year IS NULL THEN NULL
        ELSE ROUND(((monthly_revenue - revenue_same_month_previous_year) / revenue_same_month_previous_year) * 100, 2)
    END AS yoy_growth_percent
FROM monthly_with_lag
ORDER BY year, month;

-- Top 10 products by total sales
SELECT 
    p.product_category_name_english AS product_category,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    SUM(oi.price) AS total_revenue
FROM stg_order_items oi
JOIN dim_product p ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

-- Average delivery days per customer state
SELECT 
    c.customer_state,
    COUNT(f.order_id) AS num_orders,
    ROUND(AVG(f.delivery_days), 2) AS avg_delivery_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.delivery_days)::NUMERIC, 2) AS median_delivery_days
FROM fact_orders f
JOIN dim_customer c ON f.customer_sk = c.customer_sk
WHERE f.delivery_days IS NOT NULL AND f.delivery_days > 0
GROUP BY c.customer_state
ORDER BY avg_delivery_days;

-- Payment method usage by total sales
SELECT 
    p.payment_type,
    COUNT(DISTINCT f.order_id) AS num_orders,
    SUM(f.total_payment_value) AS total_value,
    ROUND(100.0 * SUM(f.total_payment_value) / SUM(SUM(f.total_payment_value)) OVER (), 2) AS percentage_of_total
FROM fact_orders f
JOIN dim_payment p ON f.payment_sk = p.payment_sk
GROUP BY p.payment_type
ORDER BY total_value DESC;

-- Customer Lifetime Value: total spend per unique customer, ranked, with running total
WITH customer_spend AS (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        SUM(f.total_sales) AS lifetime_value,
        COUNT(f.order_id) AS order_count,
        MIN(d.date) AS first_order_date,
        MAX(d.date) AS last_order_date
    FROM fact_orders f
    JOIN dim_customer c ON f.customer_sk = c.customer_sk
    JOIN dim_date d ON f.purchase_date_sk = d.date_sk
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT 
    customer_unique_id,
    customer_state,
    lifetime_value,
    order_count,
    first_order_date,
    last_order_date,
    RANK() OVER (ORDER BY lifetime_value DESC) AS clv_rank,
    PERCENT_RANK() OVER (ORDER BY lifetime_value) AS clv_percent_rank,
    SUM(lifetime_value) OVER (ORDER BY lifetime_value DESC ROWS UNBOUNDED PRECEDING) AS running_total_clv
FROM customer_spend
WHERE lifetime_value IS NOT NULL
ORDER BY lifetime_value DESC
LIMIT 20;