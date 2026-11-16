-- =====================================================================
-- 04_analysis_queries.sql
-- 10 business questions answered with SQL.
-- Revenue = quantity * unit_price * (1 - discount), Completed orders only.
-- Techniques: JOINs, GROUP BY, CTEs, CASE, window functions (LAG, RANK,
-- SUM OVER, NTILE), date functions.
-- =====================================================================
USE malaysia_ecommerce;

-- Q1. What are total revenue, profit, orders and average order value (AOV)?
SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2)                        AS total_revenue,
       ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost)), 2)        AS total_profit,
       COUNT(DISTINCT o.order_id)                                                                 AS completed_orders,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.order_status = 'Completed';

-- Q2. How did revenue grow year over year?
SELECT YEAR(o.order_date) AS yr,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue,
       ROUND(100 * (SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct))
             / LAG(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct))) OVER (ORDER BY YEAR(o.order_date)) - 1), 1) AS yoy_growth_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY YEAR(o.order_date);

-- Q3. Monthly revenue trend with month-over-month growth
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue / LAG(revenue) OVER (ORDER BY month) - 1), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- Q4. Which categories bring the most revenue and the best profit margin?
SELECT c.category_name,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue,
       ROUND(100 * SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost))
                 / SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 1) AS margin_pct,
       ROUND(100 * SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct))
                 / SUM(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct))) OVER (), 1) AS revenue_share_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories c   ON c.category_id = p.category_id
WHERE o.order_status = 'Completed'
GROUP BY c.category_name
ORDER BY revenue DESC;

-- Q5. Top 10 products by revenue (with rank)
SELECT RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) DESC) AS rnk,
       p.product_name,
       c.category_name,
       SUM(oi.quantity) AS units_sold,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories c   ON c.category_id = p.category_id
WHERE o.order_status = 'Completed'
GROUP BY p.product_name, c.category_name
ORDER BY revenue DESC
LIMIT 10;

-- Q6. Revenue by region and state
SELECT r.region_name,
       s.state_name,
       COUNT(DISTINCT o.customer_id) AS customers,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN customers cu   ON cu.customer_id = o.customer_id
JOIN states s       ON s.state_id = cu.state_id
JOIN regions r      ON r.region_id = s.region_id
WHERE o.order_status = 'Completed'
GROUP BY r.region_name, s.state_name
ORDER BY revenue DESC;

-- Q7. How big are the 11.11 and 12.12 mega-sale days compared with a normal day?
WITH daily AS (
    SELECT o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_date
)
SELECT CASE WHEN DATE_FORMAT(order_date, '%m-%d') IN ('11-11','12-12') THEN 'Mega-sale day (11.11 / 12.12)'
            ELSE 'Normal day' END AS day_type,
       COUNT(*) AS days,
       ROUND(AVG(revenue), 2) AS avg_daily_revenue
FROM daily
GROUP BY day_type;

-- Q8. Payment methods: share of orders and cancellation rate
SELECT payment_method,
       COUNT(*) AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
       ROUND(100 * AVG(order_status = 'Cancelled'), 1) AS cancel_rate_pct
FROM orders
GROUP BY payment_method
ORDER BY orders DESC;

-- Q9. Repeat vs one-time customers, and how much revenue the top 10% of customers bring
WITH cust AS (
    SELECT o.customer_id,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.customer_id
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY revenue DESC) AS decile FROM cust
)
SELECT SUM(orders = 1)                                                     AS one_time_customers,
       SUM(orders > 1)                                                     AS repeat_customers,
       ROUND(100 * AVG(orders > 1), 1)                                     AS repeat_rate_pct,
       ROUND(100 * SUM(CASE WHEN decile = 1 THEN revenue END) / SUM(revenue), 1) AS top10pct_revenue_share
FROM ranked;

-- Q10. Average order value by customer age group
WITH order_totals AS (
    SELECT o.order_id, o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS order_value
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.customer_id
)
SELECT CASE WHEN cu.age < 25 THEN '18-24'
            WHEN cu.age < 35 THEN '25-34'
            WHEN cu.age < 45 THEN '35-44'
            ELSE '45+' END                 AS age_group,
       COUNT(*)                            AS orders,
       ROUND(AVG(ot.order_value), 2)       AS avg_order_value
FROM order_totals ot
JOIN customers cu ON cu.customer_id = ot.customer_id
GROUP BY age_group
ORDER BY age_group;
