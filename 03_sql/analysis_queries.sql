-- ============================================================
-- QuickPay FinTech — SQL Business Analysis
-- File        : analysis_queries.sql
-- Data source : cleaned_transactions.csv  (loaded as: transactions)
--               merchant_master.csv       (loaded as: merchants)
--               users.csv                 (loaded as: users)
-- Engine      : SQLite (compatible with PostgreSQL / MySQL with
--               minor adjustments to ROUND precision syntax)
-- Verison 0.1 - Initial version by Punith Tiwari @ 03/05/2026
-- ============================================================


-- ============================================================
-- TABLE SETUP  (run once to create tables from CSV)
-- If using SQLite CLI:
--   .mode csv
--   .import cleaned_transactions.csv transactions
--   .import merchant_master.csv      merchants
--   .import users.csv                users
-- ============================================================

--CHECK DATA IS LOADED PROPERLY BARE EYE
SELECT * FROM TRANSACTIONS;

--CHECK DATA IS LOADED PROPERLY BARE EYE
SELECT * FROM MERCHANTS;

--CHECK DATA IS LOADED PROPERLY BARE EYE
SELECT * FROM USERS;

--VERIFY COUNTS ARE MATCHING WITH FILES LOADED 30 FOR TRANSACTIONS
SELECT COUNT(*) FROM TRANSACTIONS;

--VERIFY COUNTS ARE MATCHING WITH FILES LOADED 5 FOR mermerchants
SELECT count(*) FROM MERCHANTS;

--VERIFY COUNTS ARE MATCHING WITH FILES LOADED 10 FOR mermerchants
SELECT count(*) FROM USERS;



-- ============================================================
-- Q1
-- Business question: How many transactions exist per status?
-- Purpose : Understand the overall health of the transaction
--           portfolio — what share is captured vs failed vs
--           chargeback. First thing any ops analyst checks.
-- ============================================================

SELECT
    status,
    COUNT(*)                                           AS transaction_count,
    -- percentage share of total for quick readability
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM transactions
GROUP BY status
ORDER BY transaction_count DESC;


-- ============================================================
-- Q2
-- Business question: What is the total captured GMV per merchant?
-- Purpose : Captured GMV (Gross Merchandise Value) is the actual
--           confirmed revenue. Failed and chargeback rows are
--           excluded — they never settled.
-- ============================================================

SELECT
    merchant_id,
    merchant_name,
    ROUND(SUM(amount_usd), 2)                         AS captured_gmv_usd
FROM transactions
WHERE status = 'captured'                   -- only settled transactions
GROUP BY merchant_id, merchant_name
ORDER BY captured_gmv_usd DESC;


-- ============================================================
-- Q3
-- Business question: Who are the top 10 merchants by captured GMV?
-- Purpose : Rankings help prioritise which merchant relationships
--           to protect and grow. With 5 merchants in this dataset
--           the full list is returned, but the query is
--           future-proofed with LIMIT 10.
-- ============================================================

SELECT
    merchant_id,
    merchant_name,
    merchant_category,
    gateway_region,
    ROUND(SUM(amount_usd), 2)                         AS captured_gmv_usd,
    COUNT(*)                                           AS captured_tx_count
FROM transactions
WHERE status = 'captured'
GROUP BY merchant_id, merchant_name, merchant_category, gateway_region
ORDER BY captured_gmv_usd DESC
LIMIT 10;


-- ============================================================
-- Q4
-- Business question: What does daily GMV and success count look like?
-- Purpose : Trend analysis — spot dips in volume or success rate
--           that might indicate gateway issues, fraud spikes, or
--           seasonal patterns. The March 5 dip is worth flagging.
-- ============================================================

SELECT
    transaction_date,
    COUNT(*)                                                    AS total_transactions,
    ROUND(SUM(amount_usd), 2)                                   AS total_gmv_usd,
    COUNT(CASE WHEN status = 'captured' THEN 1 END)             AS successful_count,
    ROUND(
        COUNT(CASE WHEN status = 'captured' THEN 1 END) * 100.0
        / COUNT(*),
    2)                                                          AS success_rate_pct
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date ASC;


-- ============================================================
-- Q5
-- Business question: Which merchants have a chargeback ratio above 1%?
-- Purpose : A chargeback ratio above 1% is a card network red flag.
--           Merchants consistently above this threshold risk losing
--           payment processing privileges. All 4 merchants with
--           chargebacks exceed 1% — Eco Home at 50% is critical.
-- ============================================================

SELECT
    merchant_id,
    merchant_name,
    COUNT(*)                                                      AS total_transactions,
    COUNT(CASE WHEN status = 'chargeback' THEN 1 END)            AS chargeback_count,
    ROUND(
        COUNT(CASE WHEN status = 'chargeback' THEN 1 END) * 100.0
        / COUNT(*),
    2)                                                            AS chargeback_ratio_pct
FROM transactions
GROUP BY merchant_id, merchant_name
HAVING chargeback_ratio_pct > 1
ORDER BY chargeback_ratio_pct DESC;


-- ============================================================
-- Q6
-- Business question: Which regions have average risk score > 50
--                    AND more than 20 transactions?
-- Purpose : Identifies high-volume, high-risk corridors that need
--           closer monitoring. The 20-transaction floor filters
--           out low-volume regions where one bad transaction can
--           skew the average misleadingly.
-- Note    : With 30 total rows, only APAC (22 transactions) clears
--           the 20-transaction threshold. EU (4) and US (4) do not.
--           This is expected for a dataset this size.
-- ============================================================

SELECT
    gateway_region,
    COUNT(*)                                          AS total_transactions,
    ROUND(AVG(risk_score), 2)                         AS avg_risk_score,
    -- include min/max for context on spread
    MIN(risk_score)                                   AS min_risk_score,
    MAX(risk_score)                                   AS max_risk_score
FROM transactions
GROUP BY gateway_region
HAVING avg_risk_score > 50
   AND total_transactions > 20
ORDER BY avg_risk_score DESC;


-- ============================================================
-- Q7
-- Business question: Which users had 3 or more failed or
--                    chargeback transactions on the same day?
-- Purpose : A velocity pattern — multiple failures on a single day
--           from one user suggests either a compromised account,
--           a brute-force card attempt, or a deliberate fraud test.
--           U008 on 2026-03-05 is a clear case to investigate.
-- ============================================================

SELECT
    t.user_id,
    u.user_name,
    u.risk_tier,
    t.transaction_date,
    COUNT(*)                                          AS fail_or_cb_count,
    -- list the specific statuses they triggered
    GROUP_CONCAT(t.status, ', ')                      AS statuses_triggered
FROM transactions t
LEFT JOIN users u
    ON t.user_id = u.user_id
WHERE t.status IN ('failed', 'chargeback')
GROUP BY t.user_id, t.transaction_date
HAVING fail_or_cb_count >= 3
ORDER BY fail_or_cb_count DESC;


-- ============================================================
-- Q8
-- Business question: What is the chargeback count, unique affected
--                    users, and chargeback amount per merchant?
-- Purpose : Helps the risk team understand both the frequency and
--           financial exposure of chargebacks per merchant, and
--           whether the same users are repeatedly filing chargebacks
--           (which could indicate organised fraud vs random disputes).
-- ============================================================

SELECT
    t.merchant_id,
    t.merchant_name,
    t.merchant_category,
    COUNT(*)                                          AS chargeback_count,
    COUNT(DISTINCT t.user_id)                         AS unique_affected_users,
    ROUND(SUM(t.amount_usd), 2)                       AS total_chargeback_amount_usd,
    -- average chargeback size helps size the risk per incident
    ROUND(AVG(t.amount_usd), 2)                       AS avg_chargeback_amount_usd
FROM transactions t
WHERE t.status = 'chargeback'
GROUP BY t.merchant_id, t.merchant_name, t.merchant_category
ORDER BY total_chargeback_amount_usd DESC;


-- ============================================================
-- END OF FILE
-- ============================================================
