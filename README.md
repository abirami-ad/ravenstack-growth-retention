# RavenStack — Growth & Retention Analysis

## Scope

- Synthetic B2B SaaS retention analysis
- 500 accounts across subscriptions, usage, support and churn data
- Account churn is the headline metric: 22.0%

## Findings So Far

- DevTools: 31.0% churn
- Event source: 30.2%; partner: 14.6%
- 6–20 seats: 25.0%
- Plan tier is mostly flat
- Usage volume doesn't look very different for churned accounts

## Important Data Fix

- 53% of raw usage rows predate account signup
- Early activation / active-account queries now use `signup_date <= usage_date`
- Churned account usage also stops at the last churn date

## Next

- Cohorts
- Revenue exposure
- Feature / support checks

Dataset: River @ Rivalytics on Kaggle.
