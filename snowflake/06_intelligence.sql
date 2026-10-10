-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-telemetry alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TELEMETRY.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic feed-management knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.FEED_SOP_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.ROOT_CAUSE, s.CATEGORY
  FROM RAW.POND_DAILY r JOIN RAW.PONDS s ON s.ID = r.ENTITY_ID
  WHERE r.ROOT_CAUSE IS NOT NULL AND r.FEED_REFUSAL_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ROOT_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ROOT_CAUSE,
  CATEGORY || ' - ' || ROOT_CAUSE || ' feed-refusal response' AS TITLE,
  'Synthetic demo SOP. Species: ' || CATEGORY || '. Feed-refusal cause: ' || ROOT_CAUSE || '. '
  || 'Step 1: tell the feed technician on duty, record the event in the pond log and have the pond supervisor check the feed trays. '
  || 'Step 2: ' || CASE
       WHEN ROOT_CAUSE ILIKE '%dissolved oxygen%' THEN 'pause the next feeding, run the aerators and recheck dissolved oxygen before feeding resumes at a reduced ration.'
       WHEN ROOT_CAUSE ILIKE '%pellet%' THEN 'hold the current feed lot, sample pellets for size and water stability and switch to a retained lot until the check is back.'
       WHEN ROOT_CAUSE ILIKE '%temperature%' THEN 'move feeding to the cooler hours of the day and cut the ration until the water temperature settles.'
       WHEN ROOT_CAUSE ILIKE '%moult%' THEN 'reduce the ration for two days, keep feed trays in place and step the ration back up as trays clear.'
       WHEN ROOT_CAUSE ILIKE '%ammonia%' THEN 'cut the ration, increase water exchange where possible and recheck ammonia the next morning.'
       WHEN ROOT_CAUSE ILIKE '%algae%' THEN 'reduce feeding, increase aeration overnight and review the pond water colour with the farm manager.'
       WHEN ROOT_CAUSE ILIKE '%salinity drop%' THEN 'record salinity at the inlet and the pond, delay ration increases and agree the water management plan with the farm manager.'
       WHEN ROOT_CAUSE ILIKE '%overfeeding%' THEN 'remove uneaten feed where practical, recalculate the ration from the latest biomass sample and lower the next feeding.'
       WHEN ROOT_CAUSE ILIKE '%turbidity%' THEN 'check the inlet and pond banks, reduce the ration and watch the trays for two feedings.'
       WHEN ROOT_CAUSE ILIKE '%clogging%' THEN 'clean the auto-feeder hopper and spreader, check the feeder logs and hand-feed the missed ration if needed.'
       WHEN ROOT_CAUSE ILIKE '%ph swing%' THEN 'record morning and afternoon pH, reduce feeding at the extremes and review liming with the farm manager.'
       WHEN ROOT_CAUSE ILIKE '%salinity intrusion%' THEN 'close intake gates at high tide, delay ration increases and recheck salinity at each intake for 48 hours.'
       WHEN ROOT_CAUSE ILIKE '%heat wave%' THEN 'suspend midday feedings, run aerators through the night and restore the ration as water temperature falls.'
       ELSE 'document the issue, isolate the source and raise it with the regional farm manager.'
     END
  || ' Step 3: if uneaten feed stays above 80 kg or the hopper level above 90% after the response, keep the pond on the watch list. '
  || 'Step 4: confirm that the feed uptake rate has recovered and record the root cause in the pond register.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.FEED_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ROOT_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ROOT_CAUSE, CONTENT FROM SEARCH.FEED_SOP_DOCS);

-- ---------- Uneaten feed anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.UNEATEN_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, UNEATEN_FEED_KG::FLOAT AS UNEATEN_FEED
FROM RAW.POND_DAILY;
CREATE OR REPLACE VIEW ML.UNEATEN_TRAIN AS
SELECT * FROM ML.UNEATEN_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.UNEATEN_SERIES);
CREATE OR REPLACE VIEW ML.UNEATEN_DETECT AS
SELECT * FROM ML.UNEATEN_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.UNEATEN_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.UNEATEN_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.UNEATEN_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'UNEATEN_FEED',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.UNEATEN_FEED_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS UNEATEN_FEED, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.UNEATEN_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.UNEATEN_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'UNEATEN_FEED'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.FEED_ANALYTICS
  TABLES (
    ponds AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'ponds', 'fish ponds', 'culture ponds')
      COMMENT = 'One row per pond (entity), 90-day totals',
    risk AS ML.FEED_REFUSAL_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day feed-refusal event probability per pond',
    causes AS CURATED.FEED_REFUSAL_CAUSES PRIMARY KEY (ROOT_CAUSE)
      COMMENT = 'Feed-refusal events by root cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Grower-wide totals per day'
  )
  RELATIONSHIPS (risk_pond AS risk (ENTITY_ID) REFERENCES ponds)
  FACTS (
    ponds.trays_cleared_f AS TRAYS_CLEARED,
    ponds.trays_checked_f AS TRAYS_CHECKED,
    ponds.feed_tonnes_f AS FEED_TONNES,
    ponds.biomass_gain_kg_f AS BIOMASS_GAIN_KG,
    ponds.low_do_alerts_f AS LOW_DO_ALERTS,
    ponds.feed_refusals_f AS FEED_REFUSAL_COUNT,
    ponds.downtime_hours_f AS DOWNTIME_HOURS,
    ponds.operating_hours_f AS OPERATING_HOURS,
    ponds.planned_hours_f AS PLANNED_HOURS,
    risk.feed_refusal_prob_f AS FEED_REFUSAL_PROB_7D,
    causes.cause_refusals_f AS FEED_REFUSAL_COUNT,
    causes.cause_uncleared_f AS UNCLEARED_TRAYS,
    causes.cause_hours_f AS DOWNTIME_HOURS,
    daily.day_cleared_f AS TRAYS_CLEARED,
    daily.day_checked_f AS TRAYS_CHECKED,
    daily.day_feed_f AS FEED_TONNES,
    daily.day_refusals_f AS FEED_REFUSAL_COUNT
  )
  DIMENSIONS (
    ponds.pond_id AS ENTITY_ID WITH SYNONYMS = ('pond', 'entity', 'entity id', 'pond id'),
    ponds.pond_name AS ENTITY_NAME,
    ponds.farm_city AS REGION WITH SYNONYMS = ('region', 'city', 'farm city') COMMENT = 'Vietnamese city the farm is near',
    ponds.pond_species AS CATEGORY WITH SYNONYMS = ('species', 'species group', 'category'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.root_cause AS ROOT_CAUSE,
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    ponds.pond_count AS COUNT(ponds.pond_id) WITH SYNONYMS = ('number of entities', 'entity count', 'number of ponds'),
    ponds.feed_uptake_rate_pct AS 100 * SUM(ponds.trays_cleared_f) / NULLIF(SUM(ponds.trays_checked_f), 0)
      WITH SYNONYMS = ('feed uptake rate', 'tray clearance rate', 'trays cleared share') COMMENT = 'Feed trays cleared / feed trays checked',
    ponds.total_feed_refusals AS SUM(ponds.feed_refusals_f) WITH SYNONYMS = ('feed refusal events', 'refusal events'),
    ponds.feed_efficiency_kg_per_t AS SUM(ponds.biomass_gain_kg_f) / NULLIF(SUM(ponds.feed_tonnes_f), 0)
      WITH SYNONYMS = ('feed efficiency', 'gain per tonne of feed') COMMENT = 'kg biomass gain per tonne of feed dispensed',
    ponds.total_biomass_gain_kg AS SUM(ponds.biomass_gain_kg_f) WITH SYNONYMS = ('biomass gain', 'total gain'),
    ponds.total_feed_tonnes AS SUM(ponds.feed_tonnes_f) WITH SYNONYMS = ('feed dispensed', 'feed tonnes', 'feed used'),
    ponds.total_low_do_alerts AS SUM(ponds.low_do_alerts_f) WITH SYNONYMS = ('low oxygen alerts', 'dissolved oxygen alerts'),
    ponds.feeder_uptime_pct AS 100 * SUM(ponds.operating_hours_f) / NULLIF(SUM(ponds.planned_hours_f), 0),
    ponds.total_downtime_hours AS SUM(ponds.downtime_hours_f),
    risk.avg_feed_refusal_prob AS AVG(risk.feed_refusal_prob_f),
    causes.cause_refusals AS SUM(causes.cause_refusals_f),
    causes.cause_uncleared_trays AS SUM(causes.cause_uncleared_f),
    causes.cause_downtime_hours AS SUM(causes.cause_hours_f),
    daily.daily_feed_uptake_rate_pct AS 100 * SUM(daily.day_cleared_f) / NULLIF(SUM(daily.day_checked_f), 0),
    daily.daily_feed_tonnes AS SUM(daily.day_feed_f),
    daily.daily_feed_refusals AS SUM(daily.day_refusals_f)
  )
  COMMENT = 'Synthetic Vietnam aquaculture feed analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.FEED_AGENT
  COMMENT = 'Feed-management assistant over a synthetic Vietnamese aquaculture grower'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Use only what the tools return. Say that the data is synthetic and that thresholds are demo settings, not aquaculture standards. Quote pond IDs, and give every number with its unit."
  orchestration: "Use feed_analyst for feed uptake rate, feed-refusal events, feed dispensed, biomass gain and feed efficiency, low-oxygen alerts, auto-feeder uptime, ponds, cities, risk and root causes. Use sop_search for feed-refusal response procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: feed_analyst
      description: "Feed uptake rate, feed-refusal events, feed dispensed, biomass gain and feed efficiency, low-oxygen alerts, auto-feeder uptime, root causes and feed-refusal risk scores per pond"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic feed-refusal response SOPs by species and cause"
tool_resources:
  feed_analyst:
    semantic_view: __DEMO_DB__.APP.FEED_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.FEED_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-telemetry alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), POND_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, UNEATEN_FEED_KG FLOAT, HOPPER_LEVEL_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION VN_AQUACULTURE_FEED_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALARMS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (POND_ID, EVENT_TS, UNEATEN_FEED_KG, HOPPER_LEVEL_PCT, SOP_HINT)
    SELECT t.POND_ID, t.EVENT_TS, t.UNEATEN_FEED_KG, t.HOPPER_LEVEL_PCT,
           'Check ' || s.CATEGORY || ' SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TELEMETRY t
    JOIN RAW.PONDS s ON s.ID = t.POND_ID
    LEFT JOIN ML.FEED_REFUSAL_RISK_SCORES r ON r.ENTITY_ID = t.POND_ID
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.POND_ID = t.POND_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('VN_AQUACULTURE_FEED_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Vietnam aquaculture feed pond-sensor alarm',
      'New live-telemetry alarms logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_ALARM_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TELEMETRY t
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.POND_ID = t.POND_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALARMS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.FEED_REFUSAL_CAUSES REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.FEED_REFUSAL_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.FEED_REFUSAL_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.FEED_REFUSAL_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'POND_AGE_YEARS', POND_AGE_YEARS, 'UNEATEN_FEED_KG', UNEATEN_FEED_KG,
             'HOPPER_LEVEL_PCT', HOPPER_LEVEL_PCT, 'UNEATEN_FEED_7D', UNEATEN_FEED_7D, 'FEED_REFUSALS_30D', FEED_REFUSALS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:FEED_REFUSAL::FLOAT, 4) AS FEED_REFUSAL_PROB_7D,
         CASE WHEN PRED:probability:FEED_REFUSAL::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:FEED_REFUSAL::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
