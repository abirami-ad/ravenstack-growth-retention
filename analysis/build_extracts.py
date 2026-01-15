"""Build flat CSV extracts for the Tableau workbook -> data/processed/

One row per account / month / cohort cell / feature / plan. Everything the
dashboard needs is precomputed here so the workbook stays calc-free
(easier to maintain, renewing the data = just re-running this).
"""
from pathlib import Path

import duckdb
import pandas as pd

pd.set_option("display.max_columns", 50)  # handy when poking at these in a console

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)

con = duckdb.connect()
con.execute("SET enable_progress_bar = false;")
for t in ["accounts", "subscriptions", "feature_usage", "support_tickets", "churn_events"]:
    con.execute(
        f"CREATE VIEW {t} AS SELECT * FROM read_csv_auto('{RAW / f'ravenstack_{t}.csv'}', header=true)"
    )

# ---- account level ---------------------------------------------------------------------------------------------------------------
# usage stats are pre-churn only (no-leakage rule, see analysis/README.md)
acct = con.execute(
    """
WITH last_churn AS (
  SELECT a.account_id, max(c.churn_date) AS churn_date
  FROM accounts a JOIN churn_events c USING (account_id)
  WHERE a.churn_flag GROUP BY 1, a.account_id
), usage AS (
  SELECT s.account_id,
    count(*) AS events,
    count(DISTINCT f.feature_name) AS distinct_features,
    sum(f.usage_count) AS usage_count,
    sum(f.usage_duration_secs) / 3600.0 AS hours_used,
    sum(f.error_count) AS errors
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  LEFT JOIN last_churn lc ON lc.account_id = s.account_id
  WHERE f.usage_date <= COALESCE(lc.churn_date, DATE '2024-12-31')
  GROUP BY 1
), f30 AS (
  SELECT s.account_id, count(DISTINCT f.feature_name) AS feats_30d
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) BETWEEN 0 AND 30
  GROUP BY 1
), tkt AS (
  SELECT account_id,
    count(*) AS tickets,
    max(escalation_flag::INT) AS escalated,
    avg(satisfaction_score) AS csat
  FROM support_tickets GROUP BY 1
), first_sub AS (
  SELECT account_id, is_trial FROM subscriptions s1
  QUALIFY row_number() OVER (PARTITION BY account_id ORDER BY start_date, subscription_id) = 1
), rev AS (
  SELECT account_id,
    sum(CASE WHEN churn_flag THEN 0 ELSE mrr_amount END) AS mrr_active
  FROM subscriptions GROUP BY 1
), upg AS (
  SELECT account_id, max(upgrade_flag::INT) AS ever_upgraded FROM subscriptions GROUP BY 1
)
SELECT a.account_id, a.account_name, a.industry, a.country, a.signup_date, a.referral_source,
  a.plan_tier, a.seats, a.is_trial AS currently_trial, a.churn_flag,
  lc.churn_date,
  COALESCE(u.events, 0) AS events, COALESCE(u.distinct_features, 0) AS distinct_features,
  COALESCE(u.usage_count, 0) AS usage_count, COALESCE(u.hours_used, 0) AS hours_used,
  COALESCE(u.errors, 0) AS errors, COALESCE(f30.feats_30d, 0) AS feats_30d,
  COALESCE(tkt.tickets, 0) AS tickets, COALESCE(tkt.escalated, 0) AS escalated, tkt.csat,
  COALESCE(rev.mrr_active, 0) AS mrr_active, COALESCE(upg.ever_upgraded, 0) AS ever_upgraded,
  CASE WHEN fs.is_trial THEN 'trial' ELSE 'paid' END AS first_sub_type
FROM accounts a
LEFT JOIN last_churn lc USING (account_id)
LEFT JOIN usage u USING (account_id)
LEFT JOIN f30 USING (account_id)
LEFT JOIN tkt USING (account_id)
LEFT JOIN first_sub fs USING (account_id)
LEFT JOIN rev USING (account_id)
LEFT JOIN upg USING (account_id)
"""
).df()

acct["tenure_days"] = (
    acct.churn_date.fillna(pd.Timestamp("2024-12-31")) - acct.signup_date
).dt.days
acct["seat_band"] = pd.cut(
    acct.seats, [0, 5, 20, 50, 999], labels=["A 1-5", "B 6-20", "C 21-50", "D 50+"]
).astype(str)
acct["activation_band"] = pd.cut(
    acct.feats_30d, [-1, 2, 5, 10, 15, 999],
    labels=["A 0-2", "B 3-5", "C 6-10", "D 11-15", "E 16+"],
).astype(str)

out_df = pd.DataFrame(
    {
        "Account Id": acct.account_id,
        "Industry": acct.industry,
        "Country": acct.country,
        "Signup Date": acct.signup_date.dt.strftime("%Y-%m-%d"),
        "Signup Month": acct.signup_date.dt.strftime("%Y-%m"),
        "Referral Source": acct.referral_source,
        "Plan": acct.plan_tier,
        "Seats": acct.seats,
        "Seat Band": acct.seat_band,
        "First Sub Type": acct.first_sub_type,
        "Churned": acct.churn_flag.map({True: "Yes", False: "No"}),
        "Churn Rate": acct.churn_flag.astype(int),
        "Churn Date": acct.churn_date.dt.strftime("%Y-%m-%d").fillna(""),
        "Tenure Days": acct.tenure_days,
        "Ever Upgraded": acct.ever_upgraded,
        "Upgraded": acct.ever_upgraded,
        "Events": acct.events,
        "Distinct Features": acct.distinct_features,
        "Usage Count": acct.usage_count,
        "Hours Used": acct.hours_used.round(1),
        "Errors": acct.errors,
        "Features First 30d": acct.feats_30d,
        "Activation Band": acct.activation_band,
        "Tickets": acct.tickets,
        "Escalated": acct.escalated,
        "Csat": acct.csat.round(2),
        "Mrr Active": acct.mrr_active,
        "Account Count": 1,
        "Scope": "All accounts",
    }
)
out_df.to_csv(OUT / "account_metrics.csv", index=False)

# ---- monthly summary ------------------------------------------------------------------------------------------------------------
monthly = con.execute(
    """
WITH months AS (
  SELECT CAST(DATE '2023-01-01' + (i * INTERVAL 1 MONTH) AS DATE) AS month
  FROM range(0, 24) AS t(i)
), active AS (
  SELECT date_trunc('month', f.usage_date)::DATE AS month, count(DISTINCT a.account_id) AS active_accounts
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a ON a.account_id = s.account_id AND f.usage_date >= a.signup_date
  GROUP BY 1
), new_subs AS (
  SELECT date_trunc('month', start_date)::DATE AS month, count(*) AS new_subs,
    sum(mrr_amount) AS new_mrr
  FROM subscriptions GROUP BY 1
), churned AS (
  SELECT date_trunc('month', start_date)::DATE AS month,
    sum(CASE WHEN churn_flag THEN mrr_amount ELSE 0 END) AS churned_mrr
  FROM subscriptions GROUP BY 1
), acct_churn AS (
  SELECT date_trunc('month', c.churn_date)::DATE AS month, count(DISTINCT a.account_id) AS account_churns
  FROM churn_events c JOIN accounts a USING (account_id) WHERE a.churn_flag GROUP BY 1
)
SELECT m.month, COALESCE(a.active_accounts, 0) AS active_accounts,
  COALESCE(n.new_subs, 0) AS new_subs, COALESCE(n.new_mrr, 0) AS new_mrr,
  COALESCE(ch.churned_mrr, 0) AS churned_mrr, COALESCE(ac.account_churns, 0) AS account_churns
FROM months m
LEFT JOIN active a USING (month)
LEFT JOIN new_subs n USING (month)
LEFT JOIN churned ch USING (month)
LEFT JOIN acct_churn ac USING (month)
ORDER BY m.month
"""
).df()
# note: Month ships as YYYY-MM string, keeps the workbook types simple
monthly["Month"] = monthly.month.dt.strftime("%Y-%m")
monthly[
    ["Month", "active_accounts", "new_subs", "new_mrr", "churned_mrr", "account_churns"]
].rename(
    columns={
        "active_accounts": "Active Accounts", "new_subs": "New Subs", "new_mrr": "New Mrr",
        "churned_mrr": "Churned Mrr", "account_churns": "Account Churns",
    }
).to_csv(OUT / "monthly_summary.csv", index=False)

# long format for the MRR movement chart (two series, one measure: plays nicer
# in Tableau than two pills on a shelf)
ml = monthly.melt(id_vars="Month", value_vars=["new_mrr", "churned_mrr"],
                  var_name="kind", value_name="mrr")
ml["kind"] = ml.kind.map({"new_mrr": "New MRR", "churned_mrr": "Churned MRR"})
ml[["Month", "kind", "mrr"]].rename(columns={"kind": "Kind", "mrr": "Mrr"}).to_csv(
    OUT / "monthly_mrr_long.csv", index=False
)

# ---- cohort matrix (2023 cohorts, 12 months, activity based) ----------------
coh = con.execute(
    """
WITH activity AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('month', a.signup_date, f.usage_date) BETWEEN 0 AND 11
), cohorts AS (
  SELECT account_id, strftime(signup_date, '%Y-%m') AS cohort
  FROM accounts WHERE signup_date < '2024-01-01'
)
SELECT c.cohort, a.month_index AS months_since_signup,
  count(DISTINCT c.account_id) AS cohort_size,
  count(DISTINCT a.account_id) AS active_accounts
FROM cohorts c LEFT JOIN activity a ON a.account_id = c.account_id
GROUP BY 1, 2
"""
).df()
coh["pct_active"] = coh.active_accounts / coh.cohort_size
coh.rename(
    columns={
        "cohort": "Cohort", "months_since_signup": "Months Since Signup",
        "cohort_size": "Cohort Size", "active_accounts": "Active Accounts",
        "pct_active": "Pct Active",
    }
).to_csv(OUT / "cohort_retention.csv", index=False)

# ---- pooled retention curves by referral source ----------------------------
curves = con.execute(
    """
WITH activity AS (
  SELECT DISTINCT s.account_id, date_diff('month', a.signup_date, f.usage_date) AS month_index
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('month', a.signup_date, f.usage_date) BETWEEN 0 AND 11
), cohorts AS (
  SELECT account_id, referral_source FROM accounts WHERE signup_date < '2024-01-01'
)
SELECT c.referral_source, a.month_index AS months_since_signup,
  count(DISTINCT c.account_id) AS accounts, count(DISTINCT a.account_id) AS active_accounts
FROM cohorts c LEFT JOIN activity a ON a.account_id = c.account_id
GROUP BY 1, 2
"""
).df()
curves["pct_active"] = curves.active_accounts / curves.accounts
curves.rename(
    columns={
        "referral_source": "Referral Source", "months_since_signup": "Months Since Signup",
        "accounts": "Accounts", "pct_active": "Pct Active",
    }
)[["Referral Source", "Months Since Signup", "Accounts", "Pct Active"]].to_csv(
    OUT / "referral_curves.csv", index=False
)

# ---- churn reasons x plan ---------------------------------------------------
reasons = con.execute(
    """
SELECT c.reason_code AS reason, a.plan_tier AS plan, count(*) AS events
FROM churn_events c JOIN accounts a USING (account_id)
GROUP BY 1, 2
"""
).df()
reasons.columns = ["Reason", "Plan", "Events"]
reasons.to_csv(OUT / "churn_reasons.csv", index=False)

# ---- per-feature adoption vs churn ------------------------------------------
feat = con.execute(
    """
WITH base AS (SELECT account_id, churn_flag FROM accounts WHERE signup_date <= '2024-06-30'),
adopters AS (
  SELECT DISTINCT f.feature_name, s.account_id
  FROM feature_usage f
  JOIN subscriptions s USING (subscription_id)
  JOIN accounts a USING (account_id)
  WHERE date_diff('day', a.signup_date, f.usage_date) <= 60
), errs AS (
  SELECT feature_name, sum(error_count) AS errors, count(*) AS events
  FROM feature_usage GROUP BY 1
)
SELECT f.feature_name AS feature,
  count(DISTINCT CASE WHEN ad.account_id IS NOT NULL AND ad.feature_name = f.feature_name THEN ad.account_id END) AS adopters,
  avg(CASE WHEN ad.account_id IS NOT NULL AND ad.feature_name = f.feature_name THEN b.churn_flag::INT END) AS adopter_churn,
  avg(CASE WHEN NOT EXISTS (SELECT 1 FROM adopters a2 WHERE a2.feature_name = f.feature_name AND a2.account_id = b.account_id) THEN b.churn_flag::INT END) AS nonadopter_churn,
  COALESCE(e.errors, 0) AS errors, COALESCE(e.events, 0) AS events
FROM (SELECT DISTINCT feature_name FROM adopters) f
CROSS JOIN base b
LEFT JOIN adopters ad ON ad.feature_name = f.feature_name AND ad.account_id = b.account_id
LEFT JOIN errs e ON e.feature_name = f.feature_name
GROUP BY f.feature_name, e.errors, e.events
"""
).df()
feat["delta"] = (feat.adopter_churn - feat.nonadopter_churn) * 100
feat.columns = ["Feature", "Adopters", "Adopter Churn", "Nonadopter Churn", "Errors", "Events", "Delta"]
feat.to_csv(OUT / "feature_metrics.csv", index=False)

# ---- plan revenue impact ----------------------------------------------------
plans = con.execute(
    """
SELECT plan_tier AS plan, count(*) AS churned_subs,
  sum(mrr_amount) AS mrr_lost, sum(arr_amount) AS arr_lost
FROM subscriptions WHERE churn_flag GROUP BY 1 ORDER BY arr_lost DESC
"""
).df()
plans.columns = ["Plan", "Churned Subs", "Mrr Lost", "Arr Lost"]
plans.to_csv(OUT / "plan_impact.csv", index=False)

print("wrote extracts to", OUT)
for f in sorted(OUT.glob("*.csv")):
    print(f" {f.name}: {sum(1 for _ in open(f)) - 1} rows")
