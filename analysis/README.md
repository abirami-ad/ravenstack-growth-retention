# Analysis

## Run

```bash
python analysis/run.py analysis/05_churn_segmentation.sql
```

## Metric Rules

| Metric | Result |
|---|---:|
| Account churn | 110 / 500 = 22.0% |
| Subscription churn | 486 / 5,000 = 9.7% |
| Churn events | 600 |

## Guardrails

- Account churn is the default
- Event rows are for reason-code analysis
- Use `signup_date <= usage_date <= churn_date` for churned accounts
- Small intersections are directional only

## Files

- `01_data_validation.sql`
- `02_product_metrics.sql`
- `03_growth_activation.sql`
- `04_retention_cohorts.sql`
- `05_churn_segmentation.sql`
- `06_feature_analysis.sql`
