
-- ── Step 1: Rename tables to readable names ─────────────────
ALTER TABLE `Project`.`olist_customers_dataset` 
    RENAME TO `Project`.`customers`;

ALTER TABLE `Project`.`olist_order_payments_dataset` 
    RENAME TO `Project`.`order_payments`;

ALTER TABLE `Project`.`olist_orders_dataset` 
    RENAME TO `Project`.`orders_dataset`;

ALTER TABLE `Project`.`mytable` 
    RENAME TO `Project`.`order_reviews`;

ALTER TABLE `Project`.`tableName` 
    RENAME TO `Project`.`product_category_name`;


-- ── Step 2: Add cleaned date columns to orders ──────────────
-- Raw timestamps contain '0000-00-00' nulls and need casting to DATE

ALTER TABLE orders_dataset
    ADD COLUMN approved_date DATE,
    ADD COLUMN delivered_date DATE;

-- Populate only where both timestamps are valid (not null, not zero-date)
UPDATE orders_dataset
SET 
    approved_date  = DATE(order_approved_at),
    delivered_date = DATE(order_delivered_customer_date)
WHERE 
    order_approved_at IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL
    AND order_approved_at != '0000-00-00 00:00:00'
    AND order_delivered_customer_date != '0000-00-00 00:00:00';


-- ── Step 3: Add has_review flag to rfm_table ────────────────
-- 64% of customers have no review — flag this explicitly
-- rather than leaving avg_review as NULL

UPDATE rfm_table
SET has_review = 
    CASE 
        WHEN avg_review IS NOT NULL THEN 1
        ELSE 0
    END;


-- ── Step 4: Data quality checks ─────────────────────────────
-- Run these to verify cleaning worked correctly

-- Check total orders loaded
SELECT COUNT(*) AS total_orders FROM orders_dataset;

-- Check for remaining invalid dates
SELECT COUNT(*) AS bad_dates
FROM orders_dataset
WHERE approved_date IS NULL 
   OR delivered_date IS NULL;

-- Check review coverage
SELECT 
    SUM(CASE WHEN avg_review IS NULL THEN 1 ELSE 0 END) AS no_review,
    COUNT(*) AS total_customers,
    ROUND(SUM(CASE WHEN avg_review IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) 
        AS pct_missing_review
FROM rfm_table;
