# QuickPaymentRepo Structure

## Overview
This repository has been reorganized to consolidate files from multiple branches into a unified, well-organized structure under the `repo-root` branch.

## Folder Organization

```
repo-root/
├── README.md                          # Main documentation
├── STRUCTURE.md                       # This file
│
├── 01_data/                           # Data phase - raw and processed
│   ├── raw/                           # Original data files
│   │   ├── transactions_raw.csv       # Raw transaction data
│   │   ├── merchant_master.csv        # Merchant reference data
│   │   ├── users.csv                  # User data
│   │   ├── ledger.csv                 # Ledger records
│   │   ├── gateway.csv                # Payment gateway data
│   │   ├── exchange_rates.csv         # Currency exchange rates
│   │   └── api_response_sample.json   # Sample API response
│   │
│   └── processed/                     # Cleaned and analyzed data
│       ├── cleaned_transactions.csv   # Data quality issues fixed
│       ├── api_normalized.csv         # Normalized API data
│       ├── reconciliation_report.csv  # Complete reconciliation analysis
│       ├── amount_mismatches.csv      # Amount discrepancies
│       ├── missing_in_gateway.csv     # Records missing from gateway
│       ├── missing_in_ledger.csv      # Records missing from ledger
│       ├── daily_summary.csv          # Daily aggregated metrics
│       ├── payment_method_breakdown.csv # Payment method analysis
│       ├── merchant_performance_summary.csv # Merchant performance metrics
│       ├── merchant_risk_summary.csv  # Merchant risk assessment
│       └── region_breakdown.csv       # Regional performance analysis
│
├── 02_spreadsheet/                    # Spreadsheet analysis phase
│   ├── spreadsheet_workbook.xlsx      # Analysis workbook
│   └── spreadsheet_answers.md         # Analysis documentation & answers
│
├── 03_sql/                            # SQL analysis phase
│   ├── analysis_queries.sql           # SQL queries for analysis
│   └── sql_answers.md                 # Query results & documentation
│
├── 04_python/                         # Python analysis phase
│   ├── fintech_pipeline.ipynb         # Jupyter notebook with Python analysis
│   └── summary_metrics.json           # Key metrics output
│
└── 05_visualization/                  # Visualization phase
    └── dashboard_link.txt             # Link to visualization dashboard
```

## Migration History

### Previous Structure
Files were scattered across multiple Git branches:
- `repo-root` — main branch
- `01_data`, `02_spreadsheet`, `03_sql`, `04_python`, `05_visualization` — phase-specific branches
- `raw`, `processed` — data-specific branches

### Current Structure (May 9, 2026)
All files have been **consolidated into `repo-root`** with a clear hierarchical folder structure:
- **01_data/** — Contains both raw and processed data
- **02_spreadsheet/** through **05_visualization/** — Phase-specific analysis folders

### Key Changes
✅ All files now accessible from a single branch (`repo-root`)
✅ Clear hierarchical organization by project phase
✅ Easier navigation and file discovery
✅ Better version control history on a single timeline
✅ Simplified collaboration — no need to switch branches for different phases

## How to Use

1. **Clone the repository:**
   ```bash
   git clone https://github.com/PunithTiwari/QuickPaymentRepo.git
   cd QuickPaymentRepo
   ```

2. **Access any phase's files directly:**
   ```bash
   # View raw data
   head -5 01_data/raw/transactions_raw.csv
   
   # Open spreadsheet analysis
   open 02_spreadsheet/spreadsheet_workbook.xlsx
   
   # Run SQL queries
   cat 03_sql/analysis_queries.sql
   
   # Execute Python notebook
   jupyter notebook 04_python/fintech_pipeline.ipynb
   ```

3. **Work with specific phases:**
   ```bash
   cd 01_data/processed
   ls -la  # List all processed data
   ```

## Branch Notes

The original phase-specific branches (`01_data`, `02_spreadsheet`, etc.) still exist on GitHub but are **no longer actively used**. 
All work should now be done on the `repo-root` branch.

If you need to reference historical commits from specific branches, you can still checkout them locally:
```bash
git checkout origin/02_spreadsheet
git checkout origin/04_python
```

But for new work, please use `repo-root`.

---
**Repository:** https://github.com/PunithTiwari/QuickPaymentRepo
**Last Updated:** May 9, 2026
