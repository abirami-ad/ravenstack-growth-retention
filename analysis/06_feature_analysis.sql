-- 06_feature_analysis.sql
-- product behaviour: usage vs churn (weak), features (weak), support (weak
-- except escalations). the point of this file is to show what DOESN'T explain
-- churn as much as what does. pre-churn activity only, no leakage.
-- (run like the others: python analysis/run.py 06_feature_analysis.sql)

-- account-level usage summary, retained vs churned.
-- window bounded to signup <= usage <= churn (pre-signup rows and post-churn
-- rows are both generator artefacts, see 01)
WITH churn_dt AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag
  GROUP BY 1, a.account_id
), usage AS (
  SELECT s.account_id,
    count(*) AS events,
    count(DISTINCT f.feature_name) AS distinct_features,
    sum(f.usage_count) AS total_usage_count,
    sum(f.usage_duration_secs) AS total_duration_secs,
    sum(f.error_count) AS total_errors,
    sum(CASE WHEN f.is_beta_feature THEN 1 ELSE 0 END) AS beta_events
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  LEFT JOIN churn_dt cd ON cd.account_id = s.account_id
  WHERE f.usage_date <= COALESCE(cd.churn_date, DATE '2024-12-31')
  GROUP BY 1
)
SELECT a.churn_flag,
  count(*) AS accounts,
  round(avg(events), 1) AS avg_events,
  round(avg(distinct_features), 1) AS avg_feats,
  round(avg(total_usage_count), 0) AS avg_usage_count,
  round(avg(total_duration_secs) / 3600, 1) AS avg_hours_used,
  round(avg(total_errors), 1) AS avg_errors,
  round(avg(beta_events), 1) AS avg_beta
FROM accounts a
JOIN usage u USING (account_id)
GROUP BY 1
ORDER BY 1;

-- is there a usage dip right before churn? (spoiler: no)
WITH cd AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag
  GROUP BY 1, a.account_id
), ev AS (
  SELECT s.account_id, f.usage_count,
    date_diff('day', cd.churn_date, f.usage_date) AS days_from_churn
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  JOIN cd ON cd.account_id = s.account_id
  WHERE f.usage_date <= cd.churn_date
)
SELECT
  round(avg(CASE WHEN days_from_churn BETWEEN -30 AND 0 THEN usage_count END), 1) AS avg_count_last_30d,
  round(avg(CASE WHEN days_from_churn BETWEEN -90 AND -31 THEN usage_count END), 1) AS avg_count_d31_90,
  round(avg(CASE WHEN days_from_churn BETWEEN -150 AND -91 THEN usage_count END), 1) AS avg_count_d91_150
FROM ev;

-- per-feature: adoption in first 60d vs churn, adopters vs non-adopters.
-- base = signups with 6+ months window. features are anonymized (feature_0..39),
-- so read this as "is ANY feature load-bearing" rather than which one
WITH base AS (
  SELECT account_id, churn_flag FROM accounts WHERE signup_date <= '2024-06-30'
), adopt AS (
  SELECT DISTINCT f.feature_name, s.account_id
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 60
)
SELECT f.feature_name,
  count(DISTINCT CASE WHEN ad.account_id IS NOT NULL THEN b.account_id END) AS adopters,
  round(100.0 * avg(CASE WHEN ad.account_id IS NOT NULL THEN b.churn_flag::INT END), 1) AS adopter_churn_pct,
  round(100.0 * avg(CASE WHEN ad.account_id IS NULL THEN b.churn_flag::INT END), 1) AS nonadopter_churn_pct
FROM (SELECT DISTINCT feature_name FROM adopt) f
CROSS JOIN base b
LEFT JOIN adopt ad ON ad.feature_name = f.feature_name AND ad.account_id = b.account_id
GROUP BY f.feature_name
ORDER BY adopter_churn_pct - nonadopter_churn_pct
LIMIT 10;

-- error rates: churned vs retained accounts
WITH cd AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag GROUP BY 1, a.account_id
), u AS (
  SELECT s.account_id, sum(f.error_count) AS errors, sum(f.usage_count) AS counts
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  LEFT JOIN cd ON cd.account_id = s.account_id
  WHERE f.usage_date <= COALESCE(cd.churn_date, DATE '2024-12-31')
  GROUP BY 1
)
SELECT a.churn_flag,
  round(avg(errors), 1) AS avg_errors,
  round(100.0 * sum(errors) / sum(counts), 2) AS errs_per_100_usage
FROM accounts a JOIN u USING (account_id)
GROUP BY 1
ORDER BY 1;

-- support experience: retained vs churned. satisfaction/times are a wash,
-- escalations are the one thing that moves
WITH t AS (
  SELECT account_id,
    count(*) AS tickets,
    avg(resolution_time_hours) AS avg_res_h,
    avg(first_response_time_minutes) AS avg_frt_min,
    avg(satisfaction_score) AS avg_csat,
    sum(CASE WHEN escalation_flag THEN 1 ELSE 0 END) AS escs
  FROM support_tickets GROUP BY 1
)
SELECT a.churn_flag,
  count(DISTINCT a.account_id) AS accts,
  round(avg(t.tickets), 2) AS avg_tickets,
  round(avg(t.avg_res_h), 1) AS avg_resolution_h,
  round(avg(t.avg_frt_min), 1) AS avg_first_response_min,
  round(avg(t.avg_csat), 2) AS avg_csat,
  round(avg(t.escs), 2) AS avg_escalations,
  round(100.0 * count(DISTINCT CASE WHEN t.escs > 0 THEN a.account_id END) / count(DISTINCT a.account_id), 1) AS pct_accts_escalated
FROM accounts a LEFT JOIN t USING (account_id)
GROUP BY 1
ORDER BY 1;

-- do escalations cluster before churn? timeline of escalated tickets vs churn date
WITH cd AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag GROUP BY 1, a.account_id
)
SELECT
  sum(CASE WHEN date_diff('day', cd.churn_date, t.submitted_at::DATE) BETWEEN -30 AND 0 THEN 1 ELSE 0 END) AS esc_last_30d,
  sum(CASE WHEN date_diff('day', cd.churn_date, t.submitted_at::DATE) BETWEEN -90 AND -31 THEN 1 ELSE 0 END) AS esc_d31_90,
  count(*) AS esc_total_pre_churn
FROM support_tickets t
JOIN cd USING (account_id)
WHERE t.escalation_flag AND t.submitted_at::DATE <= cd.churn_date;

-- beta usage vs churn (curiosity check, someone told me beta users stick more. they don't)
WITH cd AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag GROUP BY 1, a.account_id
), b AS (
  SELECT s.account_id,
    count(CASE WHEN f.is_beta_feature THEN 1 END) AS beta_events
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  LEFT JOIN cd ON cd.account_id = s.account_id
  WHERE f.usage_date <= COALESCE(cd.churn_date, DATE '2024-12-31')
  GROUP BY 1
)
SELECT a.churn_flag,
  round(100.0 * sum(CASE WHEN b.beta_events > 0 THEN 1 ELSE 0 END) / count(*), 1) AS pct_used_beta
FROM accounts a JOIN b USING (account_id)
GROUP BY 1 ORDER BY 1;
