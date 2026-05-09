# SQL Answers

> All queries were run against `cleaned_transactions.csv` loaded into SQLite as the `transactions` table, joined with `merchants` and `users` where needed.

---

## Q1

### Query
Count transactions by status — with percentage share added for context.

```sql
SELECT
    status,
    COUNT(*)                                            AS transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM transactions
GROUP BY status
ORDER BY transaction_count DESC;
```

### Result Summary

| status | transaction_count | pct_of_total |
|---|---|---|
| captured | 19 | 63.33% |
| failed | 7 | 23.33% |
| chargeback | 4 | 13.33% |

Just under two-thirds of all transactions ended up captured — which is the only status that actually generates revenue. The 23% failure rate is worth watching; a number that high often points to gateway issues or cards being declined at checkout. The 13% chargeback rate is genuinely alarming — industry benchmarks sit at 1% or below, and we're running thirteen times that. That's the most urgent thing this dataset is telling us.

---

## Q2

### Query
Total captured GMV by merchant — failures and chargebacks excluded since they never settled.

```sql
SELECT
    merchant_id,
    merchant_name,
    ROUND(SUM(amount_usd), 2) AS captured_gmv_usd
FROM transactions
WHERE status = 'captured'
GROUP BY merchant_id, merchant_name
ORDER BY captured_gmv_usd DESC;
```

### Result Summary

| merchant_id | merchant_name | captured_gmv_usd |
|---|---|---|
| M002 | Beta Stores | $33,431.00 |
| M001 | Alpha Mart | $29,984.50 |
| M004 | Delta Travels | $10,300.00 |
| M003 | City Pharma | $8,640.00 |

Beta Stores leads by a meaningful margin despite having the same number of transactions as Alpha Mart — it simply processes higher-value orders. Eco Home (M005) doesn't appear here at all because its only two transactions were a chargeback and a failed payment. That's a merchant with zero confirmed revenue in this period, which is a significant red flag for account health.

---

## Q3

### Query
Top 10 merchants by captured GMV — enriched with category and region for full context.

```sql
SELECT
    merchant_id, merchant_name, merchant_category, gateway_region,
    ROUND(SUM(amount_usd), 2) AS captured_gmv_usd,
    COUNT(*)                  AS captured_tx_count
FROM transactions
WHERE status = 'captured'
GROUP BY merchant_id, merchant_name, merchant_category, gateway_region
ORDER BY captured_gmv_usd DESC
LIMIT 10;
```

### Result Summary

| merchant_id | merchant_name | merchant_category | gateway_region | captured_gmv_usd | captured_tx_count |
|---|---|---|---|---|---|
| M002 | Beta Stores | Electronics | APAC | $33,431.00 | 7 |
| M001 | Alpha Mart | Grocery | APAC | $29,984.50 | 8 |
| M004 | Delta Travels | Travel | US | $10,300.00 | 2 |
| M003 | City Pharma | Healthcare | EU | $8,640.00 | 2 |

With only 5 merchants in this dataset, the LIMIT 10 returns all 4 that had any captured revenue. The two APAC merchants account for nearly 75% of all confirmed GMV combined — the business is heavily concentrated in that region. Delta Travels generates a strong average per transaction ($5,150) despite just two captures, which reflects its Travel category naturally having higher ticket sizes.

---

## Q4

### Query
Daily GMV and successful transaction count — with success rate percentage added.

```sql
SELECT
    transaction_date,
    COUNT(*)                                                    AS total_transactions,
    ROUND(SUM(amount_usd), 2)                                   AS total_gmv_usd,
    COUNT(CASE WHEN status = 'captured' THEN 1 END)             AS successful_count,
    ROUND(COUNT(CASE WHEN status = 'captured' THEN 1 END) * 100.0 / COUNT(*), 2) AS success_rate_pct
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date ASC;
```

### Result Summary

| date | total_tx | total_gmv_usd | successful_count | success_rate_pct |
|---|---|---|---|---|
| 2026-03-01 | 5 | $26,382.00 | 5 | 100.00% |
| 2026-03-02 | 6 | $25,049.00 | 3 | 50.00% |
| 2026-03-03 | 5 | $18,391.00 | 4 | 80.00% |
| 2026-03-04 | 5 | $16,420.00 | 4 | 80.00% |
| 2026-03-05 | 6 | $19,232.00 | 1 | 16.67% |
| 2026-03-06 | 3 | $10,606.00 | 2 | 66.67% |

March 1st was a perfect day — 5 for 5. Then things started to wobble. March 5th is the standout problem: 6 transactions but only 1 captured, for a 16.67% success rate. That's where U008's velocity spike happened (see Q7), contributing 3 failures and 1 chargeback in a single day. GMV has also been trending down since Day 1 — whether that's a real volume drop or just the week tapering off is worth monitoring with more data.

---

## Q5

### Query
Merchants with chargeback ratio above 1% — ordered by severity.

```sql
SELECT
    merchant_id, merchant_name,
    COUNT(*)                                                    AS total_transactions,
    COUNT(CASE WHEN status = 'chargeback' THEN 1 END)           AS chargeback_count,
    ROUND(COUNT(CASE WHEN status = 'chargeback' THEN 1 END) * 100.0 / COUNT(*), 2) AS chargeback_ratio_pct
FROM transactions
GROUP BY merchant_id, merchant_name
HAVING chargeback_ratio_pct > 1
ORDER BY chargeback_ratio_pct DESC;
```

### Result Summary

| merchant_id | merchant_name | total_transactions | chargeback_count | chargeback_ratio_pct |
|---|---|---|---|---|
| M005 | Eco Home | 2 | 1 | 50.00% |
| M004 | Delta Travels | 4 | 1 | 25.00% |
| M001 | Alpha Mart | 11 | 1 | 9.09% |
| M002 | Beta Stores | 11 | 1 | 9.09% |

Every single merchant with a chargeback is above the 1% threshold — none of them are even close to compliant. Eco Home at 50% is the most extreme, though it's worth noting they only had 2 transactions, so one chargeback hits hard statistically. Delta Travels at 25% is more credible as a signal given 4 transactions. Alpha Mart and Beta Stores at 9.09% are concerning given their higher volumes — one chargeback out of 11 transactions is less statistically fragile and more likely to represent a real pattern. City Pharma (M003) is the only clean merchant here with zero chargebacks.

---

## Q6

### Query
Regions with average risk score above 50 and more than 20 transactions.

```sql
SELECT
    gateway_region,
    COUNT(*)                   AS total_transactions,
    ROUND(AVG(risk_score), 2)  AS avg_risk_score,
    MIN(risk_score)            AS min_risk_score,
    MAX(risk_score)            AS max_risk_score
FROM transactions
GROUP BY gateway_region
HAVING avg_risk_score > 50
   AND total_transactions > 20
ORDER BY avg_risk_score DESC;
```

### Result Summary

| gateway_region | total_transactions | avg_risk_score | min_risk_score | max_risk_score |
|---|---|---|---|---|
| APAC | 22 | 65.27 | 46 | 86 |

Only APAC cleared both conditions. EU and US each had just 4 transactions, so they were filtered out by the `> 20` floor — not because their risk scores were low (EU averaged ~47.25, US averaged ~48.75) but because the sample size is too small to be statistically meaningful for regional policy decisions. APAC's average of 65.27 is notably elevated, with one transaction hitting a risk score of 86. With 22 transactions in scope, this isn't a statistical blip — APAC is genuinely the highest-risk corridor in this portfolio and warrants tighter monitoring.

---

## Q7

### Query
Users with 3 or more failed or chargeback transactions on the same day — enriched with user profile data.

```sql
SELECT
    t.user_id, u.user_name, u.risk_tier, t.transaction_date,
    COUNT(*)                       AS fail_or_cb_count,
    GROUP_CONCAT(t.status, ', ')   AS statuses_triggered
FROM transactions t
LEFT JOIN users u ON t.user_id = u.user_id
WHERE t.status IN ('failed', 'chargeback')
GROUP BY t.user_id, t.transaction_date
HAVING fail_or_cb_count >= 3
ORDER BY fail_or_cb_count DESC;
```

### Result Summary

| user_id | user_name | risk_tier | transaction_date | fail_or_cb_count | statuses_triggered |
|---|---|---|---|---|---|
| U008 | Ishaan Verma | high | 2026-03-05 | 4 | failed, failed, chargeback, failed |

One user, one date, four problem transactions. Ishaan Verma (U008) already sits in the `high` risk tier in the users table — and this behaviour confirms why. On March 5th alone he hit 3 failed payments and 1 chargeback across different merchants (Alpha Mart and Beta Stores), which is a textbook velocity attack pattern. Whether this is a compromised account, card testing, or deliberate fraud, this user needs to be reviewed and potentially suspended immediately. The fact that the risk system already categorised him as high-risk suggests the model is working — but action hasn't been taken yet.

---

## Q8

### Query
Chargeback count, unique affected users, and total chargeback amount by merchant.

```sql
SELECT
    t.merchant_id, t.merchant_name, t.merchant_category,
    COUNT(*)                   AS chargeback_count,
    COUNT(DISTINCT t.user_id)  AS unique_affected_users,
    ROUND(SUM(t.amount_usd), 2) AS total_chargeback_amount_usd,
    ROUND(AVG(t.amount_usd), 2) AS avg_chargeback_amount_usd
FROM transactions t
WHERE t.status = 'chargeback'
GROUP BY t.merchant_id, t.merchant_name, t.merchant_category
ORDER BY total_chargeback_amount_usd DESC;
```

### Result Summary

| merchant_id | merchant_name | merchant_category | chargeback_count | unique_affected_users | total_chargeback_amount_usd | avg_chargeback_amount_usd |
|---|---|---|---|---|---|---|
| M005 | Eco Home | Home | 1 | 1 | $6,649.00 | $6,649.00 |
| M001 | Alpha Mart | Grocery | 1 | 1 | $5,400.00 | $5,400.00 |
| M004 | Delta Travels | Travel | 1 | 1 | $2,500.00 | $2,500.00 |
| M002 | Beta Stores | Electronics | 1 | 1 | $1,711.00 | $1,711.00 |

Each merchant had exactly one chargeback from exactly one user — no repeat offenders at the merchant level. But the dollar exposure varies dramatically. Eco Home's single chargeback is worth $6,649, which is also its only chargeback-flagged transaction and represents the full value of that order. Alpha Mart's $5,400 chargeback was U008's transaction on March 2nd — the same user who then went on to wreak havoc on March 5th. The total chargeback exposure across the portfolio is **$16,260.00**, which is real money sitting in dispute and potentially unrecoverable.
