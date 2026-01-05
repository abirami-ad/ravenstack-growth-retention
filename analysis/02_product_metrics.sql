-- 02_product_metrics.sql
-- headline product health. every number here also lives on dashboard tab 1.
-- run: python analysis/run.py analysis/02_product_metrics.sql

-- topline KPIs, single row
SELECT
  count(*) AS accounts_total,
  sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) AS churned_accounts,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS account_churn_pct,
  sum(CASE WHEN is_trial THEN 1 ELSE 0 END) AS currently_trialing,
  (SELECT round(sum(mrr_amount)) FROM subscriptions WHERE NOT churn_flag) AS mrr_active,
  (SELECT round(sum(arr_amount)) FROM subscriptions WHERE NOT churn_flag) AS arr_active,
  (SELECT count(DISTINCT account_id) FROM subscriptions WHERE upgrade_flag) AS acct_ever_upgraded,
  round(100.0 * (SELECT count(DISTINCT account_id) FROM subscriptions WHERE upgrade_flag) / count(*), 1) AS upgrade_rate_pct
FROM accounts;

-- monthly new subscriptions + new MRR + churned MRR (revenue movement)
SELECT date_trunc('month', start_date)::DATE AS month,
  count(*) AS new_subs,
  round(sum(mrr_amount)) AS new_mrr,
  round(sum(CASE WHEN churn_flag THEN mrr_amount ELSE 0 END)) AS churned_mrr_same_cohort
FROM subscriptions
GROUP BY 1
ORDER BY 1;

-- monthly active accounts (activity based; usage bounded to post-signup,
-- pre-signup rows are a data artefact, see 01)
SELECT date_trunc('month', f.usage_date)::DATE AS month,
  count(DISTINCT a.account_id) AS active_accounts
FROM feature_usage f
JOIN subscriptions s USING (subscription_id)
JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
GROUP BY 1
ORDER BY 1;

-- account churn over time (by churn month, account-level churn only)
SELECT date_trunc('month', c.churn_date)::DATE AS month, count(DISTINCT c.account_id) AS accounts_churned
FROM churn_events c JOIN accounts a USING (account_id)
WHERE a.churn_flag
GROUP BY 1 ORDER BY 1;

-- expansion vs contraction (plan changes across an account's subscriptions)
WITH changes AS (
  SELECT account_id,
    sum(CASE WHEN upgrade_flag THEN 1 ELSE 0 END) AS ups,
    sum(CASE WHEN downgrade_flag THEN 1 ELSE 0 END) AS downs
  FROM subscriptions GROUP BY 1
)
SELECT
  count(*) AS accounts,
  sum(CASE WHEN ups > 0 THEN 1 ELSE 0 END) AS any_upgrade,
  sum(CASE WHEN downs > 0 THEN 1 ELSE 0 END) AS any_downgrade,
  sum(CASE WHEN ups > 0 AND downs > 0 THEN 1 ELSE 0 END) AS both
FROM changes;

-- MRR by plan, active vs churned subscriptions
SELECT plan_tier,
  round(sum(CASE WHEN churn_flag THEN 0 ELSE mrr_amount END)) AS active_mrr,
  round(sum(CASE WHEN churn_flag THEN mrr_amount ELSE 0 END)) AS churned_mrr
FROM subscriptions
GROUP BY 1
ORDER BY active_mrr DESC;

-- support load topline
SELECT count(*) AS tickets,
  round(count(*) * 1.0 / (SELECT count(*) FROM accounts), 2) AS tickets_per_acct,
  round(avg(resolution_time_hours), 1) AS avg_res_h,
  round(avg(first_response_time_minutes), 0) AS avg_frt_min,
  round(avg(satisfaction_score), 2) AS avg_csat,
  round(100.0 * sum(CASE WHEN escalation_flag THEN 1 ELSE 0 END) / count(*), 1) AS esc_pct
FROM support_tickets;
