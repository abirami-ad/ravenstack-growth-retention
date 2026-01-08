-- 05_churn_segmentation.sql
-- where is churn concentrated + what it costs. account-level churn unless noted.
-- run: python analysis/run.py analysis/05_churn_segmentation.sql

-- churn by industry
SELECT industry,
  count(*) AS accounts,
  sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) AS churned,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM accounts
GROUP BY 1
ORDER BY churn_pct DESC;

-- churn by referral source
SELECT referral_source,
  count(*) AS accounts,
  sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) AS churned,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM accounts
GROUP BY 1
ORDER BY churn_pct DESC;

-- churn by team size bucket
select CASE WHEN seats <= 5 THEN '1-5' WHEN seats <= 20 THEN '6-20'
       WHEN seats <= 50 THEN '21-50' ELSE '50+' END as seat_bucket,
  count(*) as accounts,
  sum(case when churn_flag then 1 else 0 end) as churned,
  round(100.0 * sum(case when churn_flag then 1 else 0 end) / count(*), 2) as churn_pct
from accounts
group by 1 order by churn_pct desc;

-- churn by plan (account's initial plan) -- basically flat, thats the finding
SELECT plan_tier,
  count(*) AS accounts,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM accounts
GROUP BY 1
ORDER BY churn_pct DESC;

-- crossing the two biggest signals: industry x referral.
-- intersection sizes drop fast, treat small cells as directional only
SELECT industry, referral_source,
  count(*) AS n,
  round(100.0 * sum(CASE WHEN churn_flag THEN 1 ELSE 0 END) / count(*), 1) AS churn_pct
FROM accounts
GROUP BY 1, 2
HAVING count(*) >= 15  -- below this the % means nothing
ORDER BY churn_pct DESC
LIMIT 12;

-- revenue impact: ARR on churned subscriptions, by plan.
-- churn RATES are flat across plans, revenue at risk very much is not
SELECT plan_tier,
  count(*) AS churned_subs,
  round(sum(mrr_amount)) AS mrr_lost,
  round(sum(arr_amount)) AS arr_lost,
  round(100.0 * sum(arr_amount) / (SELECT sum(arr_amount) FROM subscriptions WHERE churn_flag), 1) AS share_of_arr_lost_pct
FROM subscriptions
WHERE churn_flag
GROUP BY 1
ORDER BY arr_lost DESC;

-- ARR at risk by industry (churned subs)
SELECT a.industry,
  round(sum(s.arr_amount)) AS arr_lost,
  count(DISTINCT s.account_id) AS accts_losing
FROM subscriptions s
JOIN accounts a USING (account_id)
WHERE s.churn_flag
GROUP BY 1
ORDER BY arr_lost DESC;

-- stated churn reasons, all 600 events (reasons only exist at event level)
SELECT reason_code,
  count(*) AS events,
  round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM churn_events
GROUP BY 1
ORDER BY events DESC;

-- reasons x plan (account's intial plan). Basic leads with support,
-- Enterprise leads with features
SELECT a.plan_tier, c.reason_code, count(*) AS events
FROM churn_events c
JOIN accounts a USING (account_id)
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- refunds and win-back context
SELECT
  count(*) AS events,
  sum(CASE WHEN refund_amount_usd > 0 THEN 1 ELSE 0 END) AS with_refund,
  round(avg(refund_amount_usd), 2) AS avg_refund,
  round(max(refund_amount_usd), 2) AS max_refund
FROM churn_events;

-- does anything in the account record flag churn risk upfront?
-- billing behaviour on churned vs retained subscriptions
SELECT s.churn_flag,
  s.billing_frequency,
  count(*) AS subs,
  round(100.0 * sum(CASE WHEN s.auto_renew_flag THEN 1 ELSE 0 END) / count(*), 1) AS auto_renew_pct
FROM subscriptions s
GROUP BY 1, 2
ORDER BY 1, 2;
