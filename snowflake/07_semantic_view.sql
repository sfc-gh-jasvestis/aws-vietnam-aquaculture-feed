-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Feed Optimization
-- ============================================================================
USE DATABASE AQUACULTURE_FEED;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.AQUACULTURE_FEED_ANALYTICS
  COMMENT = 'Aquaculture & Seafood feed optimization analytics'
AS
  TABLES (
    CURATED.PERFORMANCE_DASHBOARD AS performance_dashboard,CURATED.TREND_ANALYTICS AS trend_analytics,CURATED.FORECAST_INPUT AS forecast_input,CURATED.OPERATIONAL_RISK AS operational_risk
  );
