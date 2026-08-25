# Feed Optimization

Feed Optimization for Vietnam - ML.FORECAST and Dynamic Tables power real-time feed optimization intelligence for aquaculture & seafood in An Giang & Dong Thap.

## Architecture

Vietnam aquaculture & seafood faces increasing complexity in feed optimization. Decision-makers in An Giang & Dong Thap need real-time intelligence and ML-powered recommendations.

```mermaid
flowchart LR
    S3[S3 Data Landing] --> SP[Snowpipe]
    SPS --> RAW
    RAW --> DT[Dynamic Tables]
    DT --> ML[ML Functions]
    DT --> SEARCH[Cortex Search]
    DT --> SV[Semantic View]
    SV --> AGENT[Cortex Agent]
    SEARCH --> AGENT
    DT --> APP[React App SPCS]
    SM[SageMaker] --> DT
    BR[Bedrock] --> APP
    DT --> QS[QuickSight + Q]
```

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | PERFORMANCE_DASHBOARD / TREND_ANALYTICS / FORECAST_INPUT / OPERATIONAL_RISK |
| ML Functions | ML.FORECAST + ML.ANOMALY_DETECTION |
| Cortex AI | COMPLETE, SUMMARIZE, AI_CLASSIFY |
| Cortex Search | 100 documents indexed |
| Cortex Agent | AQUACULTURE_FEED_AGENT |
| Semantic View | AQUACULTURE_FEED_ANALYTICS |
| React App (SPCS) | 5 tabs + DemoGuide |


## AWS Services

| Service | Role in Demo |
|---------|-------------|
| AWS IoT Core | Ingest real-time data from aquaculture & seafood systems |
| Amazon SageMaker | Feed Optimization ML models |
| AWS Glue | ETL and data transformation |
| Apache Iceberg (S3) | Open table format for data sharing |
| Amazon Bedrock (Claude) | Generate feed optimization recommendations |
| Amazon QuickSight + Q | Feed Optimization dashboard with NL queries |


## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Vo Van Khanh** | VP Operations | "What are the key feed optimization metrics?" "Which areas need attention?" |
| **Bui Thi Hong** | Nutrition Specialist | "Show me the trend analysis." "Which operations are underperforming?" |


## Data

| Table | Rows | Description |
|-------|------|-------------|
| OPERATIONS | 100,000 | Core operational records for feed optimization |
| METRICS | 500,000 | Time-series performance metrics |
| ASSETS | 5,000 | Asset and entity master data |
| EVENTS | 200,000 | Operational events and incidents |
| DOCUMENTS | 100 | SOPs, reports, and compliance docs |


## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex AI enabled (ML Functions, Search, Agent)
- Warehouse: AQUACULTURE_WH (Medium)
- AWS CLI with access (us-west-2)

### Deployment

```bash
snowsql -f snowflake/00_setup.sql
snowsql -f snowflake/01_marketplace_install.sql
snowsql -f snowflake/02_raw_tables.sql
snowsql -f snowflake/03_staging.sql
snowsql -f snowflake/04_dynamic_tables.sql
snowsql -f snowflake/05_search.sql
snowsql -f snowflake/06_ml_models.sql
snowsql -f snowflake/07_semantic_view.sql
snowsql -f snowflake/08_agent.sql
```

### React App (SPCS)
```bash
cd app && npm ci && npm run build
docker build -t aws-vietnam-aquaculture-feed-app .
docker push bdiqc8sm-default.registry.snowflakecomputing.com/aquaculture_feed/app/aws_vietnam_aquaculture_feed/app:latest
```

### Demo Mode
Open the app URL with `?demo=true` for presenter view.

## Build Modes

### Snowflake Only
Run scripts 00-08 (skip AWS-specific integration). Uses:
- **Snowpipe Streaming SDK** instead of AWS IoT Core
- **ML.FORECAST + ML.ANOMALY_DETECTION** instead of Amazon SageMaker
- **Dynamic Tables** instead of AWS Glue
- **Snowflake-managed Iceberg Tables** instead of Apache Iceberg (S3)
- **Cortex Complete** instead of Amazon Bedrock (Claude)
- **Snowflake Intelligence (Cortex Analyst)** instead of Amazon QuickSight + Q

### Full AWS + Snowflake
Run all scripts including AWS integration. Deploy QuickSight dashboard from `quicksight/`.

## Business Impact

Industry research and Snowflake customer outcomes:
- **Vietnam's aquaculture feed market is $4.5B annually — feed accounts for 50-70% of total shrimp production cost** — [Alltech Global Feed Survey](https://www.alltech.com/feed-survey)
- **Feed Conversion Ratio (FCR) optimization from 1.5 to 1.2 saves $2,000/hectare/cycle — AI reduces waste by 20-30%** — [World Aquaculture Society](https://www.was.org/articles)
- **Vietnam has 280+ feed mills producing 8M tonnes annually — CP Group, De Heus, and Grobest are top producers** — [MARD Vietnam](https://www.mard.gov.vn/en/Pages/default.aspx)
- **Cargill achieved 12% feed efficiency improvement across Asian aquaculture operations using IoT + analytics** — [Cargill Aqua Nutrition](https://www.cargill.com/animal-nutrition/aqua)
- **Sysco** (Snowflake customer): unified supplier quality and traceability data on Snowflake across 330K+ restaurant customers and 600K+ delivery points -- [snowflake.com/customers/sysco](https://www.snowflake.com/en/customers/all-customers/case-study/sysco/)

## Key Demo Numbers

- **100K operations** tracked in An Giang & Dong Thap
- **500K metrics** time-series data points
- **5K assets** monitored
- **100 docs** searchable


## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty.