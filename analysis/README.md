# Analysis

## Run

```bash
python analysis/run.py analysis/05_churn_segmentation.sql
```

## Churn

| Metric | Result |
|---|---:|
| Account churn | 110 / 500 = 22.0% |
| Subscription churn | 486 / 5,000 = 9.7% |
| Churn events | 600 |

Using account churn by default. Event rows are for reasons, not the main rate.

## Queries

- `01_data_validation.sql`
- `02_product_metrics.sql`
- `03_growth_activation.sql`
- `05_churn_segmentation.sql`
