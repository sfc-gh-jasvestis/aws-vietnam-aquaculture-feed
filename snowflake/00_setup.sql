-- Generated from generator/demo_specs/aws-vietnam-aquaculture-feed.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-vietnam-aquaculture-feed
-- This is the schema that is actually deployed for VIETNAM_AQUACULTURE_FEED.

-- VIETNAM_AQUACULTURE_FEED  (Feed Optimization)
-- generated from generator/demo_specs/aws-vietnam-aquaculture-feed.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS VIETNAM_AQUACULTURE_FEED;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_FEED.RAW;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_FEED.CURATED;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_FEED.APP;
USE DATABASE VIETNAM_AQUACULTURE_FEED;

-- 5 real regions; entity names carry their region so the two always agree
