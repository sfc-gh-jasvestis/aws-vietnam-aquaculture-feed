# Feed Optimization

**Vietnam - Aquaculture & Seafood**
Use case: Feed Optimization

> Feed Optimization for Vietnam - ML.FORECAST and Dynamic Tables power real-time feed optimization intelligence for aquaculture & seafood in An Giang & Dong Thap.

## Why Snowflake

Snowflake delivers feed optimization intelligence for Vietnamese aquaculture & seafood - Dynamic Tables maintain real-time dashboards, ML.FORECAST projects key metrics, and Cortex AI generates recommendations

- **ML.FORECAST for feed optimization** - Only demo for Vietnamese aquaculture & seafood
- **ML.ANOMALY_DETECTION early warning** - Detects deviations before impact
- **AI recommendations** - Cortex AI actionable guidance
- **Vietnamese context** - Local names, VND economics

## What is deployed

| | |
|---|---|
| Database | `VIETNAM_AQUACULTURE_FEED` |
| Service | `VIETNAM_AQUACULTURE_FEED_APP` |
| Compute pool | `SEA_DEMOS_VIETNAM_POOL` |
| Dimension table | `RAW.PONDS` (20 rows) |
| Fact table | `RAW.FEED_EVENTS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | VND (₫) |

Regions in play: Ho Chi Minh City, Hanoi, Binh Duong, Dong Nai, Can Tho
Segments: Starter Feed, Grower Feed, Finisher Feed, Premium Blend

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh VIETNAM_AQUACULTURE_FEED
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Feed Produced (MTD) | `124K MT` | total across Ponds |
| FCR (Avg) | `1.42` | average per event |
| Raw Material Cost | `₫847B` | total across Ponds |
| Farms Supplied | `4,200` | total across Ponds |
| Protein Content | `32%` | average per event |
| Omega-3 Level | `2.4%` | average per event |
| Pellet Durability | `97%` | average per event |


## Demo flow

1. Overview
2. Analytics
3. AI Intelligence
4. Ask AI
5. Architecture

## Talking points

- **100K operations** - tracked in An Giang & Dong Thap
- **500K metrics** - time-series data points
- **5K assets** - monitored
- **100 docs** - searchable

## Business impact

- Vietnam aquaculture & seafood sector growing rapidly (GSO Vietnam)
- AI improves outcomes 15-30% (McKinsey)
- Vietnam FDI strong in this sector (MPI)
- Real-time analytics reduces response 60-80% (Gartner)

---
Generated from `generator/demo_specs/aws-vietnam-aquaculture-feed.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-vietnam-aquaculture-feed` instead.
