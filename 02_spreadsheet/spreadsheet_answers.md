# Spreadsheet Answers

---

## Cleaning Steps

##NOTE:Please view the steps as a 14+ years of working with Excel is writing it.  

When I first opened `transactions_raw.csv`, it was honestly a bit of a mess — the kind of data that's come through multiple hands without any real conventions in place. Here's what I found and fixed, in the order I worked through it.

**Merchant names** were all over the place. The same merchant appeared as `"alpha mart "`, `"ALPHA MART"`, `"Alpha  Mart"` (note the double space), and `" beta stores"`. I ran a two-pass clean: first `TRIM(PROPER(SUBSTITUTE(...)))` to strip whitespace and normalise case, then a nested `ISNUMBER(SEARCH(...))` lookup to snap every variation to its canonical name from `merchant_master.csv`. The SEARCH function is case-insensitive, which made this reliable.

**Status values** had three problems layered on top of each other — mixed case, trailing spaces, and embedded error codes (like `" failed e05 timeout "`). I stripped those down using a priority-ordered SEARCH chain: chargeback is checked first, then captured, then failed. The error codes in the failed entries were just noise and got dropped. Every row ended up with one of three clean values: `captured`, `failed`, or `chargeback`.

**Risk scores** were prefixed with either `"score:"` or `"risk-"` in about half the rows, with trailing spaces on several more. I wrote a three-branch IF formula to handle all variants — try it as a plain number first, then strip `score:` (7 characters), then strip `risk-` (6 characters). One row — T011 — had no risk score at all. Rather than drop the row or guess randomly, I filled it with the column median, which came out to **61**. That's a neutral, statistically grounded choice that doesn't distort any downstream risk calculations.

**Gateway region** was missing in 9 rows, and the values that did exist were inconsistent (`" APAC "`, `"apac"`, `" EU "`, `"us"`). I normalised with `UPPER(TRIM(...))` first. For the 9 nulls, I used a VLOOKUP against `merchant_master.csv` to pull each merchant's `default_region`. Since every null-region row belonged to a merchant that was already in master, every single gap got filled cleanly — no UNKNOWNs.

---

## Standardization Rules

| Field | Rule Applied |
|---|---|
| `merchant_name` | TRIM → collapse double spaces → PROPER → map to canonical via SEARCH |
| `status` | Strip → lowercase → priority map: chargeback > captured > failed |
| `risk_score` | Strip prefix (`score:` / `risk-`) → convert to integer → null → median (61) |
| `gateway_region` | TRIM → UPPER → nulls filled via merchant_master VLOOKUP |
| `transaction_date` | Already clean ISO format (YYYY-MM-DD) — no changes needed |
| `currency` | Already clean (INR / EUR / USD) — no changes needed |

---

## Lookup and Enrichment Logic

Three separate lookups were applied using the canonical merchant name as the join key:

**From `merchant_master.csv`:**
- `merchant_id` — M001 through M005
- `merchant_category` — Grocery, Electronics, Healthcare, Travel, Home
- `account_manager` — each merchant's dedicated manager

**From `exchange_rates.csv`:**
- Currency conversion used a date-matched INDEX/MATCH array formula joining on **both** `transaction_date` and `currency`. This matters because rates change daily — using a single average rate would introduce small but real inaccuracies. All 30 rows had matching rate entries, so no fallback was needed.

The conversion formula: `=D2 * INDEX(exchange_rates!$C$2:$C$19, MATCH(1, (exchange_rates!$A$2:$A$19=A2) * (exchange_rates!$B$2:$B$19=E2), 0))`
This must be entered as an array formula (Ctrl+Shift+Enter in Excel, or ARRAYFORMULA in Google Sheets).

---

## Final Answers

**Total raw rows:** 30

**Total cleaned rows:** 30 — no rows were dropped. Every record was recoverable through standardisation.

**Invalid or missing values handled:**
- 9 null `gateway_region` values → filled from merchant_master lookup
- 1 null `risk_score` (T011) → filled with column median (61)
- 13 dirty merchant name variants → resolved to 5 canonical names
- 10 distinct dirty status strings → collapsed to 3 standard values
- 30 risk_score values with mixed prefixes/spaces → all converted to clean integers
- Total null cells resolved: **10**

**Top region by GMV:** APAC — with a total of **$82,594.00 USD**, APAC dominates comfortably. This makes sense given that 22 of the 30 transactions belong to APAC merchants (Alpha Mart and Beta Stores).

**Number of high value transactions:** **7**
- T003 — Beta Stores / APAC / $6,069 ✓
- T007 — Alpha Mart / APAC / $5,400 ✓
- T010 — Beta Stores / APAC / $7,381 ✓
- T014 — Beta Stores / APAC / $5,640 ✓
- T020 — Alpha Mart / APAC / $6,136 ✓
- T024 — Eco Home / EU / $6,649 ✓
- T027 — Delta Travels / US / $7,200 ✓

**Number of high risk transactions:** **9**
Triggered by `risk_score ≥ 70` or `status = chargeback`. The overlap is intentional — a chargeback with a high risk score gets flagged by both conditions but still counts as 1 flag.

**Top merchant by captured GMV:** **Beta Stores** — $33,431.00 in confirmed captured revenue, edging out Alpha Mart ($29,984.50). Worth noting that Beta Stores also has the highest total GMV of any single merchant.

---

## Formula Samples

All formulas are documented in full in the `formula_samples` tab of the workbook, with plain-English explanations for each. Key ones worth calling out:

```excel
-- Canonical merchant name (nested SEARCH, case-insensitive)
=IF(ISNUMBER(SEARCH("alpha",B2)),"Alpha Mart",
 IF(ISNUMBER(SEARCH("beta",B2)),"Beta Stores",
 IF(ISNUMBER(SEARCH("city pharma",B2)),"City Pharma",
 IF(ISNUMBER(SEARCH("eco home",B2)),"Eco Home",
 IF(ISNUMBER(SEARCH("delta",B2)),"Delta Travels","Unknown")))))

-- Status standardisation
=IF(ISNUMBER(SEARCH("chargeback",F2)),"chargeback",
 IF(ISNUMBER(SEARCH("captured",F2)),"captured",
 IF(ISNUMBER(SEARCH("failed",F2)),"failed","unknown")))

-- Risk score prefix strip
=IF(ISNUMBER(VALUE(TRIM(G2))),VALUE(TRIM(G2)),
 IF(ISNUMBER(SEARCH("score:",G2)),VALUE(MID(G2,7,10)),
 IF(ISNUMBER(SEARCH("risk-",G2)),VALUE(MID(G2,6,10)),"")))

-- Date-matched currency conversion (array formula)
=D2 * INDEX(exchange_rates!$C$2:$C$19,
   MATCH(1,(exchange_rates!$A$2:$A$19=A2)*(exchange_rates!$B$2:$B$19=E2),0))

-- high_value_flag (region-tiered thresholds)
=IF(AND(L2="APAC",J2>5000),1,
 IF(AND(L2="EU",J2>6000),1,
 IF(AND(L2="US",J2>7000),1,0)))

-- high_risk_flag (either condition sufficient)
=IF(OR(K2>=70,I2="chargeback"),1,0)
```

The full formula reference with column mappings is in the `formula_samples` tab.
