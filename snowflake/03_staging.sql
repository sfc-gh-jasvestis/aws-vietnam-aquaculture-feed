-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.POND_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.POND_DAILY observation
    LEFT JOIN RAW.PONDS pnd ON pnd.ID = observation.ENTITY_ID
    WHERE pnd.ID IS NULL OR observation.PLANNED_HOURS <= 0
       OR observation.OPERATING_HOURS < 0 OR observation.DOWNTIME_HOURS < 0
       OR observation.OPERATING_HOURS + observation.DOWNTIME_HOURS <> observation.PLANNED_HOURS
       OR observation.TRAYS_CLEARED < 0 OR observation.TRAYS_CLEARED > observation.TRAYS_CHECKED
       OR observation.FEED_TONNES < 0 OR observation.LOW_DO_ALERTS < 0 OR observation.BIOMASS_GAIN_KG < 0
       OR observation.RATION_REVIEW_DONE > observation.RATION_REVIEW_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
