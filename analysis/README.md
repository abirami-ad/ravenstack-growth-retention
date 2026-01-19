# Analysis

## Run Queries

```bash
python analysis/run.py analysis/05_churn_segmentation.sql
```

`run.py` loads the raw CSVs into DuckDB views first.

## Metric Rules

| Metric | Definition | Result |
|---|---|---|
| Account churn | `accounts.churn_flag = true` | 110/500 = 22.0% |
| Subscription churn | `subscriptions.churn_flag = true` | 486/5,000 = 9.7% |
| Churn events | Rows in `churn_events` | 600 |

## Guardrails

- Use account churn unless a query says otherwise
- Churn events are for reason-code analysis, not the headline churn denominator
- Bound usage to `signup_date <= usage_date <= churn_date` for churned accounts
- Treat n<30 intersections as directional

## Files

- `01_data_validation.sql` — keys, nulls, date checks, data issues
- `02_product_metrics.sql` — health, revenue, support
- `03_growth_activation.sql` — trial structure, upgrades, activation sweep
- `04_retention_cohorts.sql` — cohorts and tenure
- `05_churn_segmentation.sql` — segments, reasons, revenue exposure
- `06_feature_analysis.sql` — product behavior and support comparisons
