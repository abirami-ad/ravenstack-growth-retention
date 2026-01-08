-- 03_growth_activation.sql
-- the growth half: where do accounts come from, do trials convert, does early
-- behaviour predict anything. signup cohorts with >= 6 months of window only
-- for anything churn-flavoured (censoring rule in analysis/README.md).
-- run: python analysis/run.py analysis/03_growth_activation.sql

-- signups by referral source over time (are we leaning on a weak channel?)
SELECT date_trunc('year', signup_date)::DATE AS yr, referral_source, count(*) AS signups
FROM accounts
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- trial structure. most accounts' FIRST subscription is already paid, which
-- surprised me -- trials here are often mid-relationship, not top of funnel
SELECT
  sum(CASE WHEN first_sub_is_trial THEN 1 ELSE 0 END) AS trial_first_accounts,
  sum(CASE WHEN NOT first_sub_is_trial THEN 1 ELSE 0 END) AS paid_first_accounts,
  count(*) AS total
FROM (
  SELECT a.account_id,
    (SELECT s.is_trial FROM subscriptions s
      WHERE s.account_id = a.account_id
      ORDER BY s.start_date, s.subscription_id LIMIT 1) AS first_sub_is_trial
  FROM accounts a
);

-- trial -> paid conversion under the strict definition: earliest subscription is
-- a trial AND a paid subscription starts after it. mid-life trials (plan trials
-- on an existing customer) are NOT trial->paid conversions and polluting the
-- numbers with them is how you get >100% or negative-day conversions
WITH first_sub AS (
  SELECT a.account_id, s.start_date AS first_start
  FROM accounts a
  JOIN subscriptions s USING (account_id)
  QUALIFY row_number() OVER (PARTITION BY a.account_id ORDER BY s.start_date, s.subscription_id) = 1
), trial_first AS (
  -- 3 accounts fewer than the structure query above: their earliest date has
  -- both a trial AND a paid row, ambiguous, kicked out here
  SELECT fs.account_id, fs.first_start
  FROM first_sub fs
  JOIN subscriptions s ON s.account_id = fs.account_id AND s.start_date = fs.first_start
  WHERE s.is_trial
    -- if the earliest row is paid, this account didn't start in trial
    AND NOT EXISTS (
      SELECT 1 FROM subscriptions p
      WHERE p.account_id = fs.account_id AND p.start_date = fs.first_start AND NOT p.is_trial
    )
), first_paid AS (
  SELECT account_id, min(start_date) AS first_paid_start
  FROM subscriptions WHERE NOT is_trial GROUP BY 1
)
SELECT
  count(*) AS trial_first_accts,
  sum(CASE WHEN fp.first_paid_start > tf.first_start THEN 1 ELSE 0 END) AS converted,
  round(100.0 * sum(CASE WHEN fp.first_paid_start > tf.first_start THEN 1 ELSE 0 END) / count(*), 1) AS conversion_pct,
  round(avg(CASE WHEN fp.first_paid_start > tf.first_start THEN date_diff('day', tf.first_start, fp.first_paid_start) END), 1) AS avg_days_to_convert
FROM trial_first tf
LEFT JOIN first_paid fp USING (account_id);

-- upgrades by plan (who expands?)
SELECT s.plan_tier,
  count(DISTINCT s.account_id) AS accts,
  count(DISTINCT CASE WHEN s.upgrade_flag THEN s.account_id END) AS upgraded,
  round(100.0 * count(DISTINCT CASE WHEN s.upgrade_flag THEN s.account_id END) / count(DISTINCT s.account_id), 1) AS upgrade_pct
FROM subscriptions s
GROUP BY 1 ORDER BY 1;

-- activation sweep: distinct features used in first 30 days vs eventual churn
-- (signups before 2024-07 so everyone has 6+ months of observation)
-- lower bound matters. old version of this CTE was:
--   WHERE date_diff('day', a.signup_date, f.usage_date) <= 30
-- which quietly counted PRE-signup events (53% of the table predates signup, see 01)
WITH f30 AS (
  SELECT s.account_id, count(DISTINCT f.feature_name) AS feats
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 30
  GROUP BY 1
), base AS (
  SELECT a.account_id, a.churn_flag, COALESCE(feats, 0) AS feats_30d
  FROM accounts a LEFT JOIN f30 USING (account_id)
  WHERE a.signup_date <= '2024-06-30'
)
SELECT feats_30d, count(*) AS n,
  sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) AS churned,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM base
GROUP BY 1 ORDER BY 1;

-- same thing bucketed, bc raw counts get thin at the edges
WITH f30 AS (
  SELECT s.account_id, count(DISTINCT f.feature_name) AS feats
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 30
  GROUP BY 1
), base AS (
  SELECT a.account_id, a.churn_flag, COALESCE(feats, 0) AS feats_30d
  FROM accounts a LEFT JOIN f30 USING (account_id)
  WHERE a.signup_date <= '2024-06-30'
)
SELECT CASE
    WHEN feats_30d <= 2 THEN '0-2'
    WHEN feats_30d BETWEEN 3 AND 5 THEN '3-5'
    WHEN feats_30d BETWEEN 6 AND 10 THEN '6-10'
    WHEN feats_30d BETWEEN 11 AND 15 THEN '11-15'
    ELSE '16+' END AS breadth_bucket,
  count(*) AS n,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM base
GROUP BY 1
ORDER BY min(feats_30d);

-- first-30d usage intensity (events) vs churn, same base
WITH e30 AS (
  SELECT s.account_id, count(*) AS ev
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 30
  GROUP BY 1
), base AS (
  SELECT a.account_id, a.churn_flag, COALESCE(ev, 0) AS events_30d
  FROM accounts a LEFT JOIN e30 USING (account_id)
  WHERE a.signup_date <= '2024-06-30'
)
SELECT
  round(avg(CASE WHEN churn_flag THEN events_30d END), 1) AS avg_ev_churned,
  round(avg(CASE WHEN NOT churn_flag THEN events_30d END), 1) AS avg_ev_kept,
  round(median(CASE WHEN churn_flag THEN events_30d END), 1) AS med_ev_churned,
  round(median(CASE WHEN NOT churn_flag THEN events_30d END), 1) AS med_ev_kept
FROM base;

-- 30d -> 60d usage: does early usage persist (activation vs curiosity spike)?
-- TODO: revisit the 60d cutoff, no strong reason for it vs 45 or 90
WITH u AS (
  SELECT s.account_id,
    count(CASE WHEN date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 29 THEN 1 END) AS d0_30,
    count(CASE WHEN date_diff('day', a.signup_date, f.usage_date) BETWEEN 30 AND 59 THEN 1 END) AS d30_60
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  GROUP BY 1
)
SELECT
  sum(CASE WHEN d0_30 > 0 THEN 1 ELSE 0 END) AS used_first_30d,
  sum(CASE WHEN d0_30 > 0 AND d30_60 > 0 THEN 1 ELSE 0 END) AS also_used_next_30d,
  round(100.0 * sum(CASE WHEN d0_30 > 0 AND d30_60 > 0 THEN 1 ELSE 0 END) / NULLIF(sum(CASE WHEN d0_30 > 0 THEN 1 ELSE 0 END), 0), 1) AS pct_continued
FROM u;
