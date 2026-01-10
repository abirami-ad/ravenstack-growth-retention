-- 04_retention_cohorts.sql
-- cohort retention, activity based (definition in analysis/README.md).
-- 2023 cohorts only for the full-matrix view: they get all 12 months of window.

-- cohort retention matrix, M0..M11, 2023 signup cohorts
WITH act AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('month', a.signup_date, f.usage_date) BETWEEN 0 AND 11
), coh AS (
  SELECT account_id, date_trunc('month', signup_date)::DATE AS cohort_month
  FROM accounts
  WHERE signup_date < '2024-01-01'
)
SELECT cohort_month,
  count(DISTINCT c.account_id) AS cohort_size,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 0 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m0,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 1 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m1,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 2 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m2,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 3 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m3,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 4 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m4,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 5 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m5,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 6 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m6,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 7 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m7,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 8 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m8,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 9 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m9,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 10 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m10,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 11 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m11
FROM coh c
LEFT JOIN act USING (account_id)
GROUP BY 1
ORDER BY 1;

-- pooled retention curve by referral source (2023 cohorts, equal 12-month window)
WITH act AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
), coh AS (
  SELECT account_id, referral_source FROM accounts WHERE signup_date < '2024-01-01'
)
SELECT referral_source,
  count(DISTINCT c.account_id) AS n,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 0 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m0,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 1 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m1,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 2 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m2,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 3 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m3,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 6 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m6,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 9 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m9,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 11 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m11
FROM coh c
LEFT JOIN act USING (account_id)
GROUP BY 1
ORDER BY 1;

-- same pooled curve by industry
WITH act AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
), coh AS (
  SELECT account_id, industry FROM accounts WHERE signup_date < '2024-01-01'
)
SELECT industry,
  count(DISTINCT c.account_id) AS n,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 0 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m0,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 3 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m3,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 6 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m6,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 9 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m9,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 11 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m11
FROM coh c
LEFT JOIN act USING (account_id)
GROUP BY 1
ORDER BY 1;

-- how fast do churners leave? tenure at churn, account-level churn only
WITH acct_churn AS (
  SELECT a.account_id, a.signup_date, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag
  GROUP BY 1, 2
)
SELECT
  count(*) AS n,
  round(avg(date_diff('day', signup_date, churn_date)), 0) AS avg_tenure_days,
  round(median(date_diff('day', signup_date, churn_date)), 0) AS median_tenure_days,
  round(100.0 * sum(CASE WHEN date_diff('day', signup_date, churn_date) <= 90 THEN 1 ELSE 0 END) / count(*), 1) AS pct_within_90d,
  round(100.0 * sum(CASE WHEN date_diff('day', signup_date, churn_date) <= 180 THEN 1 ELSE 0 END) / count(*), 1) AS pct_within_180d
FROM acct_churn;

-- churn month distribution (is it accelerating, or just more customers?)
select date_trunc('month', churn_date)::DATE as month, count(*) as acct_churns
from churn_events c join accounts a using (account_id)
where a.churn_flag group by 1 order by 1;

-- reactivations (win-back exists but small)
SELECT
  count(*) AS churn_events,
  sum(CASE WHEN is_reactivation THEN 1 ELSE 0 END) AS reactivations,
  round(100.0 * sum(CASE WHEN is_reactivation THEN 1 ELSE 0 END) / count(*), 1) AS reactivation_pct
FROM churn_events;

-- retention by team size (buckets used everywhere else in the analysis)
WITH act AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
), coh AS (
  SELECT account_id,
    CASE WHEN seats <= 5 THEN '1-5' WHEN seats <= 20 THEN '6-20'
         WHEN seats <= 50 THEN '21-50' ELSE '50+' END AS seat_bucket
  FROM accounts WHERE signup_date < '2024-01-01'
)
SELECT seat_bucket,
  count(DISTINCT c.account_id) AS n,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 0 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m0,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 6 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m6,
  round(100.0 * count(DISTINCT CASE WHEN month_index = 11 THEN c.account_id END) / count(DISTINCT c.account_id), 0) AS m11
FROM coh c
LEFT JOIN act USING (account_id)
GROUP BY 1 ORDER BY 1;
