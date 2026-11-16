-- =====================================================================
-- 05_powerbi_views.sql
-- Views shaped as a star schema for Power BI:
--   fact : vw_fact_sales (one row per order line)
--   dims : vw_dim_customer, vw_dim_product
-- Connect Power BI to these views (Get Data > MySQL database), or use the
-- CSV exports in data/clean/.
-- =====================================================================
USE malaysia_ecommerce;

CREATE OR REPLACE VIEW vw_fact_sales AS
SELECT oi.order_item_id,
       o.order_id,
       o.order_date,
       o.customer_id,
       oi.product_id,
       o.payment_method,
       o.order_status,
       oi.quantity,
       oi.unit_price,
       oi.discount_pct,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2)                    AS net_revenue,
       ROUND(oi.quantity * p.unit_cost, 2)                                              AS total_cost,
       ROUND(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost), 2)    AS profit
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id;

CREATE OR REPLACE VIEW vw_dim_customer AS
SELECT cu.customer_id,
       cu.full_name,
       cu.age,
       CASE WHEN cu.age < 25 THEN '18-24'
            WHEN cu.age < 35 THEN '25-34'
            WHEN cu.age < 45 THEN '35-44'
            ELSE '45+' END AS age_group,
       s.state_name,
       r.region_name,
       cu.signup_date
FROM customers cu
JOIN states s  ON s.state_id = cu.state_id
JOIN regions r ON r.region_id = s.region_id;

CREATE OR REPLACE VIEW vw_dim_product AS
SELECT p.product_id,
       p.product_name,
       c.category_name,
       p.unit_price AS list_price,
       p.unit_cost
FROM products p
JOIN categories c ON c.category_id = p.category_id;
