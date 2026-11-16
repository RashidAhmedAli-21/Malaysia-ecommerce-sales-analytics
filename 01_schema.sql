-- =====================================================================
-- 01_schema.sql
-- Malaysia E-Commerce Sales Analytics : database schema (MySQL 8 / MariaDB)
-- Design: normalised to 3NF. Lookup tables (regions, states, categories)
-- remove repeated text from the fact tables.
-- =====================================================================

DROP DATABASE IF EXISTS malaysia_ecommerce;
CREATE DATABASE malaysia_ecommerce CHARACTER SET utf8mb4;
USE malaysia_ecommerce;

-- ---------- Lookup tables ----------
CREATE TABLE regions (
    region_id    TINYINT      PRIMARY KEY,
    region_name  VARCHAR(30)  NOT NULL UNIQUE
);

CREATE TABLE states (
    state_id     TINYINT      PRIMARY KEY,
    state_name   VARCHAR(30)  NOT NULL UNIQUE,
    region_id    TINYINT      NOT NULL,
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

CREATE TABLE categories (
    category_id    SMALLINT     PRIMARY KEY,
    category_name  VARCHAR(40)  NOT NULL UNIQUE
);

-- ---------- Core tables ----------
CREATE TABLE customers (
    customer_id  INT           PRIMARY KEY,
    full_name    VARCHAR(80)   NOT NULL,
    email        VARCHAR(120)  NULL UNIQUE,      -- NULL allowed: some customers never gave an email
    age          TINYINT       CHECK (age BETWEEN 16 AND 100),
    state_id     TINYINT       NOT NULL,
    signup_date  DATE          NOT NULL,
    FOREIGN KEY (state_id) REFERENCES states(state_id)
);

CREATE TABLE products (
    product_id    INT            PRIMARY KEY,
    product_name  VARCHAR(80)    NOT NULL,
    category_id   SMALLINT       NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL CHECK (unit_price > 0),
    unit_cost     DECIMAL(10,2)  NOT NULL CHECK (unit_cost > 0),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE orders (
    order_id        INT          PRIMARY KEY,
    customer_id     INT          NOT NULL,
    order_date      DATE         NOT NULL,
    payment_method  VARCHAR(30)  NOT NULL,
    order_status    ENUM('Completed','Cancelled','Returned') NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_orders_date (order_date),
    INDEX idx_orders_customer (customer_id)
);

CREATE TABLE order_items (
    order_item_id  INT            PRIMARY KEY,
    order_id       INT            NOT NULL,
    product_id     INT            NOT NULL,
    quantity       SMALLINT       NOT NULL CHECK (quantity > 0),
    unit_price     DECIMAL(10,2)  NOT NULL,   -- price at time of sale
    discount_pct   DECIMAL(4,2)   NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 0.9),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_items_order (order_id),
    INDEX idx_items_product (product_id)
);

-- ---------- Staging table for raw, uncleaned customer data ----------
CREATE TABLE stg_customers_raw (
    customer_id  INT,
    full_name    VARCHAR(100),
    email        VARCHAR(150),
    age          INT,
    state        VARCHAR(50),
    signup_date  VARCHAR(20)
);

-- ---------- Reference data ----------
INSERT INTO regions VALUES
 (1,'Central'),(2,'Northern'),(3,'Southern'),(4,'East Coast'),(5,'East Malaysia');

INSERT INTO states VALUES
 (1,'Kuala Lumpur',1),(2,'Selangor',1),(3,'Putrajaya',1),
 (4,'Penang',2),(5,'Kedah',2),(6,'Perak',2),(7,'Perlis',2),
 (8,'Johor',3),(9,'Melaka',3),(10,'Negeri Sembilan',3),
 (11,'Pahang',4),(12,'Terengganu',4),(13,'Kelantan',4),
 (14,'Sabah',5),(15,'Sarawak',5),(16,'Labuan',5);
