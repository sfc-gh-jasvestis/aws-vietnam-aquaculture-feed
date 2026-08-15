-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Feed Optimization
-- ============================================================================
USE DATABASE AQUACULTURE_FEED;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.AQUACULTURE_FEED_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, CATEGORY
  WAREHOUSE = AQUACULTURE_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.DOCUMENTS
);
