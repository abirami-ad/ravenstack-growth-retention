-- 01_data_validation.sql
-- sanity checks before anything else. if these fail everything downstream is suspect.
-- run: python analysis/run.py analysis/01_data_validation.sql

-- row counts, one per table
select 'accounts' as tbl, count(*) as rows from accounts
UNION ALL SELECT 'subscriptions', count(*) FROM subscriptions
UNION ALL select 'feature_usage', count(*) from feature_usage
UNION ALL SELECT 'support_tickets', count(*) FROM support_tickets
UNION ALL SELECT 'churn_events', count(*) FROM churn_events
ORDER BY 1;

-- PK uniqueness (usage_id is known to dupe, checking how bad)
SELECT 'accounts.account_id' AS key, count(*) AS n, count(DISTINCT account_id) AS distinct_n FROM accounts
UNION ALL SELECT 'subscriptions.subscription_id', count(*), count(DISTINCT subscription_id) FROM subscriptions
UNION ALL SELECT 'feature_usage.usage_id', count(*), count(DISTINCT usage_id) FROM feature_usage
UNION ALL SELECT 'support_tickets.ticket_id', count(*), count(DISTINCT ticket_id) FROM support_tickets
UNION ALL SELECT 'churn_events.churn_event_id', count(*), count(DISTINCT churn_event_id) FROM churn_events
ORDER BY 1;

-- FK integrity (docs claim no orphans, verify)
SELECT 'usage -> subscriptions' AS fk, count(*) AS orphans FROM feature_usage f
  LEFT JOIN subscriptions s USING (subscription_id) WHERE s.subscription_id IS NULL
UNION ALL SELECT 'subscriptions -> accounts', count(*) FROM subscriptions s
  LEFT JOIN accounts a USING (account_id) WHERE a.account_id IS NULL
UNION ALL SELECT 'tickets -> accounts', count(*) FROM support_tickets t
  LEFT JOIN accounts a USING (account_id) WHERE a.account_id IS NULL
UNION ALL SELECT 'churn_events -> accounts', count(*) FROM churn_events c
  LEFT JOIN accounts a USING (account_id) WHERE a.account_id IS NULL;

-- the actual duplicate usage ids
SELECT usage_id, count(*) AS n FROM feature_usage GROUP BY 1 HAVING count(*) > 1 ORDER BY n DESC;

-- date sanity
SELECT
  min(signup_date) AS min_signup, max(signup_date) AS max_signup,
  min(churn_date)  AS min_churn,  max(churn_date)  AS max_churn
FROM accounts, churn_events; -- cartesian join to compare two tables, dumb but works here. proper way below
SELECT (SELECT min(signup_date) FROM accounts) AS min_signup,
       (SELECT max(signup_date) FROM accounts) AS max_signup,
       (SELECT min(usage_date) FROM feature_usage) AS min_usage,
       (SELECT max(usage_date) FROM feature_usage) AS max_usage,
       (SELECT min(churn_date) FROM churn_events) AS min_churn,
       (SELECT max(churn_date) FROM churn_events) AS max_churn;

-- end_date before start_date?
SELECT count(*) AS bad_ranges FROM subscriptions WHERE end_date IS NOT NULL AND end_date < start_date;

select count(*) as churn_before_signup from churn_events c join accounts a using (account_id) where c.churn_date < a.signup_date;

-- null profile per table
select 'accounts' as tbl,
  sum(account_name is null) as null_name, sum(seats is null) as null_seats,
  sum(signup_date is null) as null_signup from accounts
UNION ALL SELECT 'subscriptions', sum(arr_amount IS NULL), sum(mrr_amount IS NULL), sum(end_date IS NULL) FROM subscriptions
UNION ALL SELECT 'support_tickets', sum(satisfaction_score IS NULL), sum(closed_at IS NULL), sum(resolution_time_hours IS NULL) FROM support_tickets
UNION ALL SELECT 'churn_events', sum(feedback_text IS NULL), sum(reason_code IS NULL), sum(churn_date IS NULL) FROM churn_events;

-- categorical domains
SELECT DISTINCT industry FROM accounts ORDER BY 1;
SELECT DISTINCT referral_source FROM accounts ORDER BY 1;
SELECT DISTINCT plan_tier FROM accounts ORDER BY 1;
SELECT DISTINCT reason_code FROM churn_events ORDER BY 1;
SELECT DISTINCT billing_frequency FROM subscriptions;
SELECT DISTINCT priority FROM support_tickets ORDER BY 1;

-- the three "churn" counts side by side (they will not match, that's the point)
SELECT
  (SELECT count(*) FROM accounts WHERE churn_flag) AS account_churn,
  (SELECT count(*) FROM subscriptions WHERE churn_flag) AS subscription_churn,
  (SELECT count(*) FROM churn_events) AS churn_event_rows,
  (SELECT count(*) FROM churn_events WHERE is_reactivation) AS reactivations;

-- usage events dated after the account's last churn event (time leakage check)
-- note: only meaningful for account-level churn. churn_events on non-churned accounts
-- are billing/mid-relationship events, usage continuing after those is expected.
WITH last_churn AS (
  SELECT c.account_id, max(c.churn_date) AS churn_date
  FROM churn_events c JOIN accounts a USING (account_id)
  WHERE a.churn_flag
  GROUP BY 1
)
SELECT count(*) AS events_after_churn, count(DISTINCT s.account_id) AS accounts_affected
FROM feature_usage f
JOIN subscriptions s USING (subscription_id)
JOIN last_churn lc ON lc.account_id = s.account_id
WHERE f.usage_date > lc.churn_date;

-- usage events dated BEFORE account signup (found this the hard way: monthly
-- actives looked way too high for early months). over half the table.
-- rule adopted everywhere downstream: only signup <= usage_date <= churn counts
SELECT count(*) AS events_before_signup, count(DISTINCT s.account_id) AS accounts
FROM feature_usage f
JOIN subscriptions s USING (subscription_id)
JOIN accounts a USING (account_id)
WHERE f.usage_date < a.signup_date;

-- seats distribution (for bucketing later)
SELECT min(seats) AS min_seats, max(seats) AS max_seats, round(avg(seats),1) AS avg_seats,
  round(median(seats),1) AS median_seats FROM accounts;

-- TODO: country-level churn looked flat, dropped it (kept the query in git history... well, would have, if i used git)
