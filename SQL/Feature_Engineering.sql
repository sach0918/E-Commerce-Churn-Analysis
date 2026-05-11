
-- ── Step 1: Build master table ──────────────────────────────
-- Joins customers, orders, payments, reviews, and product
-- categories into a single denormalised table for analysis

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

-- Aggregate payments at order level (one order can have multiple payments)
JOIN (
    SELECT order_id, SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
) p ON o.order_id = p.order_id

-- Left join reviews — not all orders have reviews
LEFT JOIN order_reviews r 
    ON o.order_id = r.order_id

-- Get product category per order
JOIN (
    SELECT oi.order_id, op.product_category_name
    FROM order_items oi
    JOIN olist_products op ON oi.product_id = op.product_id
) oi ON o.order_id = oi.order_id

JOIN product_category_name pc 
    ON oi.product_category_name = pc.product_category_name_english;


-- ── Step 2: Build RFM table ─────────────────────────────────
-- RFM = Recency, Frequency, Monetary
-- Reference date: 2018-10-01 (1 month after last order in dataset)
-- Recency: days since last purchase (higher = more likely churned)
-- Frequency: total number of orders placed
-- Monetary: total amount spent across all orders

CREATE TABLE rfm_table AS
SELECT 
    customer_unique_id,
    DATEDIFF('2018-10-01', last_purchase) AS recency,
    total_orders                          AS frequency,
    total_spent                           AS monetary,
    avg_review
FROM customer_summary;


-- ── Step 3: Build delivery analysis table ───────────────────
-- Used to analyse whether delivery time correlates with churn
-- delivery_days = days from order approval to delivery

CREATE TABLE order_delivery_analysis AS
SELECT 
    o.order_id,
    r.review_score,
    DATE(o.order_approved_at)              AS approved_date,
    DATE(o.order_delivered_customer_date)  AS delivered_date,
    DATEDIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_approved_at)
    ) AS delivery_days

FROM orders_dataset o
LEFT JOIN order_reviews r 
    ON o.order_id = r.order_id

WHERE 
    o.order_approved_at IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_approved_at != '0000-00-00 00:00:00'
    AND o.order_delivered_customer_date != '0000-00-00 00:00:00';


-- ── Step 4: Create final churn table ────────────────────────
-- Churn is defined as recency > 180 days
-- Rationale: products in this dataset are non-daily-use items;
-- a customer not ordering in 6 months is considered churned

CREATE TABLE final_churn AS
SELECT *,
    CASE 
        WHEN recency > 180 THEN 1
        ELSE 0
    END AS churn
FROM rfm_table;


-- ── Step 5: Validation queries ───────────────────────────────
-- Verify churn distribution matches Python analysis

SELECT 
    churn,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM final_churn
GROUP BY churn;

-- Top 10 product categories by order volume
SELECT 
    product_category_name,
    COUNT(*) AS total_orders
FROM master_table
GROUP BY product_category_name
ORDER BY total_orders DESC
LIMIT 10;

-- Average revenue per order
SELECT 
    ROUND(SUM(total_payment) / COUNT(DISTINCT order_id), 2) 
    AS avg_order_value
FROM master_table;
