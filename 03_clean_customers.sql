-- =====================================================================
-- 03_clean_customers.sql
-- Cleans the raw customer data in stg_customers_raw and loads it into
-- the customers table.
-- Problems in the raw data:
--   1. Duplicate rows (same customer entered more than once)
--   2. Inconsistent state names ('KL', 'selangor', 'Pulau Pinang', 'Johor Bahru'...)
--   3. Extra spaces in names and states
--   4. Upper-case emails and blank emails
-- =====================================================================
USE malaysia_ecommerce;

-- ---------- Step 1: profile the raw data ----------
SELECT COUNT(*)                                        AS raw_rows,
       COUNT(DISTINCT customer_id)                     AS unique_customers,
       COUNT(*) - COUNT(DISTINCT customer_id)          AS duplicate_rows,
       SUM(email IS NULL OR TRIM(email) = '')          AS blank_emails,
       SUM(state NOT IN (SELECT state_name FROM states)) AS non_standard_states
FROM stg_customers_raw;

-- ---------- Step 2: clean, standardise and de-duplicate ----------
INSERT INTO customers (customer_id, full_name, email, age, state_id, signup_date)
SELECT c.customer_id,
       c.full_name,
       c.email,
       c.age,
       s.state_id,
       c.signup_date
FROM (
    SELECT customer_id,
           TRIM(full_name)                                  AS full_name,
           NULLIF(LOWER(TRIM(email)), '')                   AS email,
           age,
           CASE LOWER(TRIM(state))
                WHEN 'kl'           THEN 'Kuala Lumpur'
                WHEN 'pulau pinang' THEN 'Penang'
                WHEN 'johor bahru'  THEN 'Johor'
                ELSE TRIM(state)
           END                                              AS state_clean,
           CAST(signup_date AS DATE)                        AS signup_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS rn
    FROM stg_customers_raw
) AS c
JOIN states s ON LOWER(s.state_name) = LOWER(c.state_clean)
WHERE c.rn = 1;            -- keep one row per customer

-- ---------- Step 3: validate the result ----------
SELECT (SELECT COUNT(*) FROM stg_customers_raw)                 AS raw_rows,
       (SELECT COUNT(*) FROM customers)                         AS clean_rows,
       (SELECT COUNT(*) FROM stg_customers_raw)
         - (SELECT COUNT(*) FROM customers)                     AS rows_removed,
       (SELECT COUNT(*) FROM customers WHERE email IS NULL)     AS customers_without_email;

-- Every customer must map to a valid state (expect 0)
SELECT COUNT(*) AS customers_missing_state
FROM stg_customers_raw r
LEFT JOIN customers c ON c.customer_id = r.customer_id
WHERE c.customer_id IS NULL;
