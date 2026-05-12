-- ============================================================
-- FILE    : 02_feature_engineering.sql
-- PROJECT : E-Commerce Customer Churn Analysis
-- DATASET : Olist Brazilian E-Commerce (Kaggle)
-- PURPOSE : Build master table, engineer RFM features,
--           create delivery analysis table, and generate
--           the final churn table used for Python modelling
-- AUTHOR  : Sachith B
-- NOTE    : Run 01_data_cleaning.sql before this file
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- STEP 1: Build master table
-- Joins customers, orders, payments, reviews, and product
-- categories into a single denormalised table.
-- This is the base table for all EDA in Python.
--
-- Key design decisions:
-- • Payments are aggregated at order level (SUM) because one
--   order can have multiple payment entries (installments)
-- • Reviews use LEFT JOIN — not all orders have a review
-- • Product category uses English names via translation table
-- ────────────────────────────────────────────────────────────

CREATE TABLE master_table AS
SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    p.total_payment,
    r.review_score,
    pc.product_category_name

FROM customers c

JOIN orders_dataset o
    ON c.customer_id = o.customer_id

-- Aggregate payments at order level — one order can have
-- multiple payment rows (e.g. credit card + voucher)
JOIN (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
) p ON o.order_id = p.order_id

-- LEFT JOIN because many orders have no review (64% missing)
LEFT JOIN order_reviews r
    ON o.order_id = r.order_id

-- Subquery to get product category per order via order_items
JOIN (
    SELECT
        oi.order_id,
        op.product_category_name
    FROM order_items oi
    JOIN olist_products op
        ON oi.product_id = op.product_id
) oi ON o.order_id = oi.order_id

-- Translate Portuguese category names to English
JOIN product_category_name pc
    ON oi.product_category_name = pc.product_category_name_english;


-- ────────────────────────────────────────────────────────────
-- STEP 2: Quick validation on master_table
-- Sanity checks before building RFM features
-- ────────────────────────────────────────────────────────────

-- Total orders in master table
SELECT COUNT(*) AS total_orders
FROM master_table;

-- Total revenue across all orders
SELECT ROUND(SUM(total_payment), 2) AS total_revenue
FROM master_table;

-- Average revenue per order
SELECT ROUND(SUM(total_payment) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM master_table;

-- Top 10 product categories by order volume
SELECT
    product_category_name,
    COUNT(*) AS total_orders
FROM master_table
GROUP BY product_category_name
ORDER BY total_orders DESC
LIMIT 10;


-- ────────────────────────────────────────────────────────────
-- STEP 3: Build RFM table
-- RFM = Recency, Frequency, Monetary — standard framework
-- for measuring customer engagement and purchase behaviour.
--
-- Reference date: 2018-10-01
-- Chosen as 1 month after the last order in the dataset
-- (Sep 2018) to avoid recency = 0 for the most recent buyers.
--
-- Recency  : Days since last purchase (higher = less active)
-- Frequency: Total number of orders placed
-- Monetary : Total amount spent across all orders
-- ────────────────────────────────────────────────────────────

CREATE TABLE rfm_table AS
SELECT
    customer_unique_id,
    DATEDIFF('2018-10-01', last_purchase) AS recency,
    total_orders                          AS frequency,
    total_spent                           AS monetary,
    avg_review
FROM customer_summary;


-- ────────────────────────────────────────────────────────────
-- STEP 4: Build delivery analysis table
-- Analyses whether delivery speed correlates with churn.
-- delivery_days = days from order approval to actual delivery.
--
-- Filters out rows where timestamps are NULL or zero-dated
-- ('0000-00-00') to avoid negative or nonsensical durations.
-- ────────────────────────────────────────────────────────────

CREATE TABLE order_delivery_analysis AS
SELECT
    o.order_id,
    r.review_score,
    DATE(o.order_approved_at)             AS approved_date,
    DATE(o.order_delivered_customer_date) AS delivered_date,
    DATEDIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_approved_at)
    )                                     AS delivery_days

FROM orders_dataset o

LEFT JOIN order_reviews r
    ON o.order_id = r.order_id

-- Exclude rows with missing or invalid timestamps
WHERE
    o.order_approved_at IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_approved_at             != '0000-00-00 00:00:00'
    AND o.order_delivered_customer_date != '0000-00-00 00:00:00';


-- ────────────────────────────────────────────────────────────
-- STEP 5: Create final churn table
-- Applies the churn definition on top of the RFM table.
--
-- Churn definition: recency > 180 days = churned (churn = 1)
-- Rationale: Products in this dataset are non-daily-use items
-- (furniture, electronics, etc.). A customer not ordering in
-- 6 months is a strong signal they have disengaged.
-- This threshold was chosen based on product category context,
-- not a universal rule — it would need validation with actual
-- business retention data in a production setting.
-- ────────────────────────────────────────────────────────────

CREATE TABLE final_churn AS
SELECT
    *,
    CASE
        WHEN recency > 180 THEN 1
        ELSE 0
    END AS churn
FROM rfm_table;


-- ────────────────────────────────────────────────────────────
-- STEP 6: Final validation — churn distribution
-- This output should match the Python EDA results:
-- ~77.4% churned (churn = 1), ~22.6% retained (churn = 0)
-- ────────────────────────────────────────────────────────────

SELECT
    churn,
    COUNT(*)                                                  AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)       AS pct_of_total
FROM final_churn
GROUP BY churn
ORDER BY churn;
