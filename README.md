# RavenStack — Growth & Retention Analysis

## Overview

- Synthetic B2B SaaS retention analysis
- 500 accounts, 5k subscriptions, 25k usage events, 2k tickets
- Account churn: 22.0%

## Findings

- DevTools 31.0%; event 30.2% vs partner 14.6%; 6–20 seats 25.0%
- Usage and most support metrics are weak churn signals
- Feature reasons lead churn events (19.0%), but feedback text is generic
- Need to finish ARR impact and product recommendation

## Work So Far

- SQL in `analysis/`
- Notebook + chart exports in `notebooks/` and `images/`
- `notes.md` is rough working notes

## Data Notes

- Account churn, subscription churn and churn events are different metrics
- Usage is bounded to signup → churn because the raw event dates are messy

Dataset credit: River @ Rivalytics on Kaggle.
