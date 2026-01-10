# Data

## Source

- RavenStack SaaS Subscription & Churn Analytics
- River @ Rivalytics
- Kaggle: `rivalytics/saas-subscription-and-churn-analytics-dataset`

## Tables

| File | Rows |
|---|---:|
| Accounts | 500 |
| Subscriptions | 5,000 |
| Feature usage | 25,000 |
| Support tickets | 2,000 |
| Churn events | 600 |

## Caveats

- `usage_id` has 21 duplicates, join through `subscription_id`
- Churn events are not account churn events one-for-one
- 13,198 usage rows predate signup. Bound every usage metric.
- Support feedback is canned text, not doing text analysis
