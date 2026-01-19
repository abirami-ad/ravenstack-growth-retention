# RavenStack — Growth & Retention Review and Recommendation

**To:** Product Leadership
**From:** Abi (Growth/Product)
**Date:** January 2025
**Re:** Where retention is breaking, and what I'd do about it

---

## Executive summary

We churn 22% of accounts (110 of 500 over two years). The churn is concentrated, not general: DevTools accounts churn at 31%, event-sourced accounts at 30.2% (vs 14.6% for partner-sourced), and mid-size teams (6–20 seats) at 25%. Two things I expected to explain this don't: churned accounts use the product about as much as retained ones (no pre-churn usage drop, equal CSAT, similar ticket volume), and no individual feature separates churners from stayers. What customers tell us is feature gaps (19% of churn events, the #1 code, and the clear leader for Enterprise), followed by budget and support. Revenue-wise the exposure is lopsided: roughly $14.2M ARR sits on churned subscriptions and **Enterprise is 78.6% of it ($11.12M)** even though Enterprise churn *rate* is unremarkable.

I recommend two things: (1) a feature-fit discovery loop for Enterprise (interviews + a structured churn-exit survey, feeding a roadmap decision — the data can't tell us *which* capability is missing, only that fit, not usage, is the stated problem), and (2) an experiment on event-sourced accounts targeting the month 4–6 window where their retention curve starts sliding versus partner. Neither is a dashboard. Both are cheap relative to $14M of recurring revenue at risk.

## 1. Problem

Leadership asked: where is retention breaking down, what behaviours are associated with churn, which segments deserve attention, and what should we do. Scope: all 500 accounts, Jan 2023 – Dec 2024, ~5,000 subscriptions, 25,000 usage events, 2,000 support tickets, 600 churn events. Metric definitions are pinned in `analysis/README.md` — worth skimming, because this dataset has three different things called "churn" and they disagree (22.0% account churn vs 9.7% subscription churn vs 600 event rows).

## 2. Key findings

**Retention breaks along acquisition and vertical, not plan.**

| segment | churn | n |
|---|---|---|
| DevTools | 31.0% | 113 |
| Event-sourced | 30.2% | 96 |
| Partner-sourced | 14.6% | 89 |
| Cybersecurity | 16.0% | 100 |
| 6–20 seats | 25.0% | 188 |
| Plan tiers (Basic/Pro/Ent) | 21.9–22.1% | — |

The event-vs-partner gap is statistically real (chi-sq 5.55, p=0.018); the omnibus tests across all industries/sources are borderline (p=0.066/0.079), which at n=500 I read as "strong signal, modest sample," not noise. The intersection is ugly: DevTools × event churns at 43.5% (n=23, directional only).

**It is not an engagement problem.** Churned accounts average 21.2 usage events vs 23.4 for retained, touch 14.9 vs 16.0 distinct features, and their usage is flat right up to the churn date (avg usage/event count 9.9 in the last 30 days vs 10.0 in days 31–90 before). CSAT is 4.0 vs 3.95. First response is actually *faster* for churned accounts. Support escalations are the one modest mover (20.9% of churned accounts hit by ≥1 escalation vs 17.4%). I went looking for an activation signal in first-30-day feature breadth and found nothing: 24.0% churn at 0–2 features vs 25.2% at 3–5. No cliff, no gradient, no cutoff I'd defend.

**Customers say it's fit and money.** Reason codes on 600 churn events: features 19.0%, budget 17.3%, support 17.3%, unknown 15.8%, competitor 15.3%, pricing 15.2%. For Enterprise, features is the #1 code by a wider margin; Basic and Pro lead with support. Budget + pricing together are a third of all events.

**Event-sourced accounts decay late, not early.** Their pooled activity retention matches partner-sourced accounts through ~month 5 (~85–89%) and slides from month 6 on, ending near 75% at M9-M11 while partner holds ~90%. If onboarding (day 0–30) were the problem, the curves would split early. They don't.

## 3. Customer and revenue impact

$1.18M MRR / $14.15M ARR sits on churned subscriptions. Enterprise accounts for $11.12M of that, Pro $2.16M, Basic $0.87M — churn *rates* are near-identical across plans, so the difference is purely deal size. DevTools carries the most at-risk ARR by industry ($8.0M). Median tenure at churn is 151 days and two-thirds of churners leave inside 180 days, so whatever we fix has to act inside the first two quarters of the relationship.

## 4. Root-cause hypotheses (hypotheses, not findings)

- **H1 — expectation mismatch at acquisition.** Event-sourced accounts were sold a story at a booth/webinar that the product doesn't operationalise for them, and value erodes once the initial use case stalls (consistent with the late slide, flat usage — they don't disengage, they just don't renew).
- **H2 — feature-fit gap for power/Enterprise use cases.** Consistent with the #1 reason code and Enterprise revenue concentration. The data cannot say *which* capability is missing; feedback text is canned ("missing features", "switched to competitor").
- **H3 — mid-market packaging/price friction.** Budget+pricing ≈ 32% of events and the 6–20 seat band churns most; consistent with seats-based pricing biting teams as they grow.

## 5. Recommendation

Two tracks, deliberately not "build feature X":

1. **Feature-fit discovery loop (Enterprise, 4 weeks).** Structured churn-exit interviews for every Enterprise churn going forward (we get ~34/yr), a 3-question exit survey replacing the current free-text field, and a synthesis deck answering: are the missing capabilities one roadmap theme or scattered? Decision gate: if 2+ of the next 5 Enterprise churn events cite the same theme, it goes to roadmap planning with the $11M exposure attached to it.
2. **Event-source lifecycle experiment (below).** Cheaper, faster, and it targets the largest churn-rate gap we can actually manipulate.

Explicitly deprioritized: usage-volume nudges ("re-engagement" campaigns) — the data argues churners look engaged; onboarding-day-one rework — the divergence starts around month 4–6, not month 1; and a churn-prediction model — we don't have a prediction problem - we have a decision problem.

## 6. Proposed experiment

**Hypothesis:** event-sourced accounts that receive a structured value checkpoint in months 4–6 (usage review against their stated goals, captured at signup, plus a live "are we delivering" 20-min call offer) will retain materially better at M9 than event-sourced accounts without it.

- **Who:** new event-sourced signups (all industries), randomised at signup, 50/50.
- **Control:** current journey. **Treatment:** month-4 value checkpoint + month-6 check-in.
- **Primary metric:** M9 activity retention (currently ~75% for event-sourced vs ~90% partner — the gap we're buying back).
- **Secondary:** MRR retention on the cohort; reason-code mix at churn (does "features"/"budget" share drop?).
- **Guardrails:** support ticket volume per account, CSAT, trial→paid conversion (must not regress).
- **Duration:** 9 months minimum for the primary read (that's the honest cost of an M9 endpoint). Full power (~400/arm to detect 8pts at α=0.05, power 0.8) is unrealistic at our event signup volume (~50/yr), so I'd pre-register a supplementary 90-day proxy: month 4–6 activity drop-off rate, and accept a directional readout on M9. Better to know the limitation now than pretend.

If H1 is wrong and checkpoints don't move retention, that's still information — it points spend at packaging (H3) instead.

## 7. Success metrics (for the overall initiative, not just the experiment)

- Account churn, event-sourced segment: 30% → ≤22% (parity with base) within 2 quarters of full rollout
- Enterprise ARR on churned subs: run-rate down 30% within 12 months (via theme identification + roadmap response)
- M9 retention gap, event vs partner: 14pts → ≤7pts
- Zero regression on guardrails (CSAT, trial→paid, ticket volume)

## 8. Risks and limitations

Synthetic dataset (Rivalytics/RavenStack) — methodology transfer is the point, not the absolute numbers. n=500 means segment intersections are directional at best. Correlation ≠ causation throughout: acquisition source "associates with" churn, we have not established mechanism. No interview data exists yet — H1–H3 are inferences from behaviour + reason codes. Recent cohorts are right-censored (cohort analysis uses 2023 signups only). 53% of raw usage events predate the account's signup date (generator artifact); every usage metric here bounds activity to signup → churn, which is the only defensible window. And the dataset's trial funnel is degenerate (every trial-first account converts — 86/86), so I don't quote a trial→paid number; upgrade rate (61% of accounts upgrade at least once) is the honest growth metric available.

## 9. Next steps

1. Approve exit-survey/interview instrument (draft by Friday)
2. Stand up experiment randomisation + tracking before next event campaign pulls signups
3. Re-run this analysis quarterly; the cohort matrix and segment table are already automated in `analysis/`
