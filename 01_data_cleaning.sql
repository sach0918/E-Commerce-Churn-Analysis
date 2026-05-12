-- ============================================================
-- FILE    : 01_data_cleaning.sql
-- PROJECT : E-Commerce Customer Churn Analysis
-- DATASET : Olist Brazilian E-Commerce (Kaggle)
-- PURPOSE : Rename raw Kaggle tables to readable names,
--           clean date columns, add derived flags,
--           and validate data quality before feature engineering
-- AUTHOR  : Sachith B
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- STEP 1: Rename raw Kaggle tables to readable names
-- Raw table names from Kaggle are long and inconsistent.
-- Renaming makes all downstream queries cleaner and easier
-- to read.
-- ────────────────────────────────────────────────────────────

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


-- ────────────────────────────────────────────────────────────
-- STEP 2: Add cleaned date columns to orders_dataset
-- Raw timestamps contain '0000-00-00 00:00:00' zero-dates
-- and need to be cast to DATE for DATEDIFF calculations later.
-- We add new columns rather than overwriting raw data so the
-- original timestamps are preserved for audit purposes.
-- ────────────────────────────────────────────────────────────

ALTER TABLE orders_dataset
    ADD COLUMN approved_date  DATE,
    ADD COLUMN delivered_date DATE;

-- Populate only where both timestamps are valid:
-- excludes NULLs and MySQL zero-dates ('0000-00-00 00:00:00')
UPDATE orders_dataset
SET
    approved_date  = DATE(order_approved_at),
    delivered_date = DATE(order_delivered_customer_date)
WHERE
    order_approved_at IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL
    AND order_approved_at            != '0000-00-00 00:00:00'
    AND order_delivered_customer_date != '0000-00-00 00:00:00';


-- ────────────────────────────────────────────────────────────
-- STEP 3: Add has_review flag to rfm_table
-- 64% of customers left no review (avg_review = NULL).
-- Rather than leaving this as a silent NULL, we make it an
-- explicit binary feature so the model can treat "no review"
-- as a meaningful signal rather than missing data.
-- ────────────────────────────────────────────────────────────

UPDATE rfm_table
SET has_review =
    CASE
        WHEN avg_review IS NOT NULL THEN 1
        ELSE 0
    END;


-- ────────────────────────────────────────────────────────────
-- STEP 4: Data quality validation checks
-- Run these after cleaning to verify everything looks correct
-- before moving to feature engineering.
-- ────────────────────────────────────────────────────────────

-- 4a. Total orders loaded — should match raw Kaggle row count
SELECT COUNT(*) AS total_orders
FROM orders_dataset;

-- 4b. Check for remaining invalid or unpopulated dates
-- Any non-zero result here means the UPDATE in Step 2 missed rows
SELECT COUNT(*) AS rows_with_missing_dates
FROM orders_dataset
WHERE approved_date IS NULL
   OR delivered_date IS NULL;

-- 4c. Review coverage summary
-- Confirms the 64% missing review rate we found during EDA
SELECT
    COUNT(*)                                                        AS total_customers,
    SUM(CASE WHEN avg_review IS NULL THEN 1 ELSE 0 END)            AS customers_no_review,
    ROUND(
        SUM(CASE WHEN avg_review IS NULL THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                               AS pct_missing_review
FROM rfm_table;

-- 4d. Verify has_review flag was applied correctly
-- Both counts should add up to total_customers above
SELECT
    has_review,
    COUNT(*) AS total
FROM rfm_table
GROUP BY has_review;
