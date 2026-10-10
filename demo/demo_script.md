# Vietnam Aquaculture Feed

**Vietnam - Aquaculture**
Use case: Pond feeding operations and feed-refusal risk

> Pond feed management for a fictional Vietnamese aquaculture grower: 30 synthetic pangasius, shrimp, tilapia and prawn ponds near Can Tho, Long Xuyen, Ca Mau and Soc Trang, curated by dynamic tables, ranked by a holdout-tested feed-refusal risk model, with a feed demand forecast and AI answers that cite their SQL and SOPs. All rations and thresholds are demo settings, not aquaculture standards.

## Why Snowflake

- **Dynamic tables** reconcile feed uptake rate, feed-refusal events, auto-feeder uptime and coverage from RAW pond data, with checks in `run_core.py`
- **Feed-refusal risk classification** gives a holdout-evaluated next-7-day feed-refusal probability per pond
- **Feed demand forecast** projects 14 days of grower-wide feed tonnes with prediction intervals
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live telemetry**: a native simulator (Snowflake only) or IoT Core, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.PONDS` (30 rows) |
| Fact table | `RAW.POND_DAILY` (2,700 pond-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `FEED_REFUSAL_CAUSES`, `TREND_ANALYSIS` |
| ML | `ML.FEED_REFUSAL_RISK_SCORES`, `ML.FEED_REFUSAL_RISK_HOLDOUT_METRICS`, `ML.FEED_FORECAST`, `ML.UNEATEN_FEED_ANOMALIES` |

Cities: Can Tho, Long Xuyen, Ca Mau, Soc Trang.
Species: Pangasius, Whiteleg Shrimp, Black Tiger Shrimp, Tilapia, Giant Freshwater Prawn.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Feed Uptake Rate | 87.4% |
| Feed-Refusal Events | 390 |
| Feed Efficiency | 619.7 kg gain/t feed |
| Feed Dispensed (t) | 2,227 |
| Auto-Feeder Uptime | 97.8% |
| Ponds Monitored | 30 |
| Auto-Feeder Coverage | 59.2% |
| Low-Oxygen Alerts | 78 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily feed uptake rate, uncleared feed trays by feed-refusal cause, pond table
2. Predictive: holdout metrics, risk bands, 14-day feed demand forecast, uneaten feed anomalies
3. Pond Feeding: auto-feeder uptime, auto-feeder coverage, ration review completion against feed uptake rate, then generate the action memo
4. Live IoT: run `CALL APP.SIMULATE_TELEMETRY(20)` (Snowflake only) or `python aws/publish_telemetry.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_ALARM_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- Pond-level feed uptake rate spans 83.4% to 90.6%; Long Xuyen trails the other cities at 86.2%.
- Of the 13 feed-refusal causes, Low dissolved oxygen accounts for the most uncleared feed trays.
- In the synthetic rates, Whiteleg Shrimp ponds convert the most feed into biomass gain (703.2 kg/t) and Giant Freshwater Prawn ponds the least (500.5 kg/t).
- On a time-based holdout the risk model scores precision 0.50 and recall 0.69 at 0.5, against a 0.40 base rate. Position it as a triage list, not a guarantee.
- The Soc Trang salinity intrusion and the Ca Mau heat wave are city-wide water events, so they are left out of the feed-refusal labels.
- No figure is a feeding recommendation; all rations and thresholds are internal to the demo.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
