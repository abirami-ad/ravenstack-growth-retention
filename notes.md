# working notes

(dump of stuff i keep re-figuring out, half of this is probably wrong)

## questions to answer (from the kickoff)
- where is churn happening -> DevTools + event-sourced, sorted in 05
- why -> ??? usage looks flat?? need to check support next
- what do we do -> memo v2

## numbers i keep needing
- 110/500 = 22.0% account churn
- churned subs ARR = 14.15M, Ent = 11.12M of it (78.6%)
- event churn 30.2% vs partner 14.6%, chi2 p=0.02-ish, recheck exact number before quoting
- 6-20 seats worst size band (25.0%)
- median tenure at churn ~150d, 2/3 gone by month 6

## data landmines (found so far, there are probably more)
1. usage_id dupes (21 of them). dont join on it
2. 53% of usage rows PREDATE signup?? generator scatters usage across the whole
   window. monthly actives looked insane until i bounded everything
3. churn_events != churn_flag. 600 events, only 135 on actual churned accts
4. feedback text is 3 canned phrases. no text mining possible, wasted an hour

## dead ends so i dont retry them
- errors-by-feature vs churn: nothing
- country cohorts: 60% US, rest too thin
- beta users stick more: they dont (96.4% vs 98.2% used beta lol)
- activation threshold: swept 1..N, flat. do NOT let anyone put "3 features in
  30 days" in a slide

## todo
- [x] cohort heatmap
- [x] memo draft -> v2 after review
- [ ] tableau polish (colors still default tableau blue, whatever)
- [ ] re-run extracts before publishing
- [ ] double check the 6-20 seat thing, n=188 feels big enough to trust but still
