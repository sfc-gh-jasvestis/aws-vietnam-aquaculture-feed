-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Feed Optimization
-- ============================================================================
USE DATABASE AQUACULTURE_FEED;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.AQUACULTURE_FEED_AGENT
  COMMENT = 'Feed Optimization AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'AQUACULTURE_FEED.APP.AQUACULTURE_FEED_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'AQUACULTURE_FEED.SEARCH.AQUACULTURE_FEED_SEARCH', TOOL_DESCRIPTION => 'Search documents for Aquaculture & Seafood information')
  )
  SYSTEM_PROMPT = 'You are the Feed Optimization Agent for Vietnamese aquaculture & seafood operations in An Giang & Dong Thap.';
