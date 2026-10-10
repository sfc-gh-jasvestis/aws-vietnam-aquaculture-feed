-- Synthetic pond-day feeding observations for a fictional Vietnamese aquaculture
-- grower with farms around four Mekong Delta cities. Nothing is seeded as a
-- prediction. Randomness is HASH-seeded, so every rebuild is reproducible:
-- per-pond area, pond age and feed-refusal propensity, weekly feeding
-- seasonality and a ration step-up day, drift between ration reviews,
-- species-weighted feed-refusal causes, and two regional water events.
-- Thresholds are internal demo thresholds, not aquaculture standards.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.PONDS AS
WITH ponds AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS POND_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 30))
), draws AS (
  SELECT POND_INDEX,
         MOD(ABS(HASH(POND_INDEX, 'vnfeed_age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(POND_INDEX, 'vnfeed_rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(POND_INDEX, 'vnfeed_review')), 1000000) / 1e6 AS U_INSP,
         MOD(ABS(HASH(POND_INDEX, 'vnfeed_discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(POND_INDEX, 'vnfeed_capacity')), 1000000) / 1e6 AS U_CAPACITY
  FROM ponds
)
SELECT 'PND-' || LPAD(POND_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic pond ' || LPAD(POND_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (7 and 5 are coprime): every city and species
       -- is present, with Can Tho and Long Xuyen largest.
       CASE MOD(POND_INDEX, 7) WHEN 0 THEN 'Can Tho' WHEN 1 THEN 'Can Tho'
            WHEN 2 THEN 'Long Xuyen' WHEN 3 THEN 'Long Xuyen'
            WHEN 4 THEN 'Ca Mau' ELSE 'Soc Trang' END AS REGION,
       CASE MOD(POND_INDEX, 5) WHEN 0 THEN 'Pangasius' WHEN 1 THEN 'Whiteleg Shrimp'
            WHEN 2 THEN 'Black Tiger Shrimp' WHEN 3 THEN 'Tilapia'
            ELSE 'Giant Freshwater Prawn' END AS CATEGORY,
       POND_INDEX,
       -- Years the pond has been in production, by species.
       ROUND(CASE MOD(POND_INDEX, 5) WHEN 0 THEN 6 + U_AGE * 9 WHEN 1 THEN 2 + U_AGE * 5
                  WHEN 2 THEN 10 + U_AGE * 8 ELSE 3 + U_AGE * 10 END, 1) AS POND_AGE_YEARS,
       ROUND(0.6 + U_CAPACITY * 2.2, 2) AS AREA_HA,
       -- Base daily feed-refusal probability 0.6%-3.6%; ~15% of ponds are chronic (x3).
       (0.006 + U_RATE * 0.03) * IFF(U_RATE > 0.85, 3, 1) AS BASE_FEED_REFUSAL_RATE,
       7 * (1 + FLOOR(U_INSP * 3)) AS RATION_REVIEW_INTERVAL_DAYS,
       0.52 + U_DISCIPLINE * 0.46 AS RATION_REVIEW_COMPLETION_PROB,
       -- Planned feed per day (tonnes): pond area x synthetic ration by species.
       ROUND((0.6 + U_CAPACITY * 2.2) * 1.15
             * CASE MOD(POND_INDEX, 5) WHEN 0 THEN 1.00 WHEN 1 THEN 0.45 WHEN 2 THEN 0.30
                    WHEN 3 THEN 0.62 ELSE 0.26 END, 3) AS DAILY_CAPACITY,
       -- Biomass gain (kg per tonne of feed), synthetic and by species.
       CASE MOD(POND_INDEX, 5) WHEN 0 THEN 630 WHEN 1 THEN 760 WHEN 2 THEN 610
            WHEN 3 THEN 680 ELSE 520 END * (0.9 + U_AGE * 0.2) AS GAIN_RATE,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.POND_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two city-wide water events in the window.
  SELECT * FROM VALUES (29, 'Soc Trang', 'Salinity intrusion', 7.0),
                       (61, 'Ca Mau', 'Heat wave', 8.0)
    AS o(DAY_INDEX, REGION, EVENT_CAUSE, HOURS)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.POND_INDEX, s.CATEGORY, s.REGION, s.POND_AGE_YEARS,
         s.BASE_FEED_REFUSAL_RATE, s.RATION_REVIEW_INTERVAL_DAYS, s.RATION_REVIEW_COMPLETION_PROB,
         s.DAILY_CAPACITY, s.GAIN_RATE, d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         24.0 AS PLANNED_HOURS,
         MOD(d.DAY_INDEX + s.POND_INDEX * 5, s.RATION_REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_RATION_REVIEW,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_exc')), 1000000) / 1e6 AS U_EXC,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_down')), 1000000) / 1e6 + 1e-6 AS U_DOWN,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_reviewdone')), 1000000) / 1e6 AS U_INSPDONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_hit')), 1000000) / 1e6 AS U_HIT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnfeed_do')), 1000000) / 1e6 AS U_GRV,
         e.EVENT_CAUSE, e.HOURS AS EVENT_HOURS
  FROM RAW.PONDS s CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), loaded AS (
  SELECT *,
         IFF(DAYS_SINCE_RATION_REVIEW = 0, 1, 0) AS RATION_REVIEW_DUE,
         IFF(DAYS_SINCE_RATION_REVIEW = 0 AND U_INSPDONE < RATION_REVIEW_COMPLETION_PROB, 1, 0) AS RATION_REVIEW_DONE,
         -- Ration drift builds between reviews; skipped reviews carry it over.
         DAYS_SINCE_RATION_REVIEW / RATION_REVIEW_INTERVAL_DAYS + (1 - RATION_REVIEW_COMPLETION_PROB) AS WEAR,
         -- Low-oxygen episode: 8 of every 26 days per pond (staggered).
         IFF(MOD(DAY_INDEX + POND_INDEX * 7, 26) < 8, 1, 0) AS STRESS,
         -- Feed: weekly low day and a ration step-up on day 44 (+55%) easing over 3 days.
         ROUND(DAILY_CAPACITY * (0.72 + 0.24 * U_VOLUME)
               * IFF(MOD(DAY_INDEX, 7) = 5, 0.78, 1.0)
               * CASE DAY_INDEX - 44 WHEN 0 THEN 1.55 WHEN 1 THEN 1.35 WHEN 2 THEN 1.15 ELSE 1.0 END, 3) AS FEED_TONNES
  FROM base
), feed_refusals AS (
  SELECT *, FEED_TONNES / DAILY_CAPACITY AS LOAD_RATIO,
         LEAST(0.5, BASE_FEED_REFUSAL_RATE * (0.4 + 1.6 * WEAR) * (0.3 + FEED_TONNES / DAILY_CAPACITY)
                    * (1 + POND_AGE_YEARS / 25) * (1 + 2.3 * STRESS)) AS P_EXC
  FROM loaded
), counted AS (
  SELECT *,
         CASE WHEN EVENT_HOURS IS NOT NULL THEN 1
              WHEN U_EXC < P_EXC / 4 THEN 2
              WHEN U_EXC < P_EXC THEN 1
              ELSE 0 END AS FEED_REFUSAL_COUNT
  FROM feed_refusals
)
, timed AS (
  SELECT *,
         -- Auto-feeder offline hours: exponential, mean depends on species.
         CASE WHEN FEED_REFUSAL_COUNT = 0 THEN 0.0
              WHEN EVENT_HOURS IS NOT NULL THEN EVENT_HOURS
              ELSE LEAST(20.0, ROUND(FEED_REFUSAL_COUNT * (0.5 - LN(U_DOWN) *
                   CASE CATEGORY WHEN 'Pangasius' THEN 2.6 WHEN 'Whiteleg Shrimp' THEN 3.2
                                 WHEN 'Black Tiger Shrimp' THEN 3.8 WHEN 'Tilapia' THEN 2.2 ELSE 3.4 END), 1))
         END AS DOWNTIME_HOURS,
         -- Share of checked feed trays found cleared (feed eaten).
         LEAST(0.995, GREATEST(0.50,
           CASE CATEGORY WHEN 'Pangasius' THEN 0.958 WHEN 'Whiteleg Shrimp' THEN 0.941
                         WHEN 'Black Tiger Shrimp' THEN 0.932 WHEN 'Tilapia' THEN 0.955 ELSE 0.938 END
           - 0.024 * WEAR - 0.045 * GREATEST(0, LOAD_RATIO - 0.9) - 0.007 * U_NOISE
           - FEED_REFUSAL_COUNT * (0.09 + 0.11 * U_HIT))) AS UPTAKE_RATE,
         14 + FLOOR(U_VOLUME * 12) AS TRAYS_CHECKED
  FROM counted
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE, PLANNED_HOURS, DOWNTIME_HOURS,
       PLANNED_HOURS - DOWNTIME_HOURS AS OPERATING_HOURS,
       FEED_REFUSAL_COUNT,
       CASE WHEN FEED_REFUSAL_COUNT = 0 THEN 'None'
            WHEN EVENT_CAUSE IS NOT NULL THEN EVENT_CAUSE
            WHEN CATEGORY = 'Pangasius' THEN IFF(U_CAUSE < 0.5, 'Low dissolved oxygen', IFF(U_CAUSE < 0.8, 'Pellet quality drift', 'Water temperature swing'))
            WHEN CATEGORY = 'Whiteleg Shrimp' THEN IFF(U_CAUSE < 0.55, 'Moulting cycle', 'Ammonia spike')
            WHEN CATEGORY = 'Black Tiger Shrimp' THEN IFF(U_CAUSE < 0.6, 'Algae bloom crash', 'Salinity drop')
            WHEN CATEGORY = 'Tilapia' THEN IFF(U_CAUSE < 0.6, 'Overfeeding residue', 'Turbidity rise')
            ELSE IFF(U_CAUSE < 0.6, 'Feeder clogging', 'pH swing') END AS ROOT_CAUSE,
       RATION_REVIEW_DUE, RATION_REVIEW_DONE,
       TRAYS_CHECKED,
       FLOOR(TRAYS_CHECKED * UPTAKE_RATE) AS TRAYS_CLEARED,
       FEED_TONNES,
       ROUND(FEED_TONNES * GAIN_RATE * (1 - 0.05 * U_NOISE - 0.03 * WEAR), 1) AS BIOMASS_GAIN_KG,
       IFF(U_GRV < 0.02 + 0.045 * FEED_REFUSAL_COUNT + 0.012 * STRESS, 1, 0) AS LOW_DO_ALERTS,
       ROUND(11 + 17 * WEAR + 24 * GREATEST(0, LOAD_RATIO - 0.8) + 11 * STRESS + 29 * FEED_REFUSAL_COUNT + U_NOISE * 5, 1) AS UNEATEN_FEED_KG,
       ROUND(LEAST(100, 100 * LOAD_RATIO * (0.74 + 0.1 * U_NOISE) + 6 * STRESS + 4 * FEED_REFUSAL_COUNT), 1) AS HOPPER_LEVEL_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM timed;

-- Auto-feeder coverage per pond (snapshot): pond hectares versus hectares served by auto-feeders.
CREATE TABLE RAW.FEEDER_COVERAGE AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Pangasius' THEN 'Riverside earthen pond' WHEN 'Whiteleg Shrimp' THEN 'HDPE-lined pond'
                     WHEN 'Black Tiger Shrimp' THEN 'Extensive earthen pond' WHEN 'Tilapia' THEN 'Earthen pond'
                     ELSE 'Rice-prawn rotation pond' END AS POND_TYPE,
       AREA_HA AS POND_HA,
       ROUND(AREA_HA * (0.32 + MOD(ABS(HASH(ID, 'vnfeed_avail')), 1000) / 1000 * 0.48), 2) AS AUTOFEEDER_HA,
       MOD(ABS(HASH(ID, 'vnfeed_order')), 3) AS PLANNED_HA,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.PONDS;
