-- 5.2 Find Records That Joins May Exclude
-- Part A: Compare INNER JOIN and LEFT JOIN
-- Write two queries to compare the results of an inner join and a left join
-- ============================================================================
-- 5.2 Part A: Compare INNER JOIN and LEFT JOIN
-- Producer = drivers, Event = trips
-- ============================================================================

-- 5.2.1 LEFT JOIN: return ALL producers, including those with no events
SELECT
    d.driver_id,                                  -- Driver's unique ID
    d.driver_name,                                -- Driver's name (the producer)
    d.home_city,                                  -- Driver's home city
    d.is_active,                                  -- Whether the driver is currently active
    COUNT(t.trip_id)    AS trip_count,            -- Counts non-NULL trip IDs only, so 0 for drivers with no trips
    MIN(t.requested_at) AS first_trip,            -- Earliest trip; NULL when the driver has no trips
    MAX(t.requested_at) AS last_trip              -- Latest trip; NULL when the driver has no trips
FROM drivers AS d                                 -- Drivers is the preserved (left) table
LEFT JOIN trips AS t                              -- Keep every driver, even with no matching trip
       ON t.driver_id = d.driver_id               -- Match on fk_trips_prod
GROUP BY d.driver_id, d.driver_name, d.home_city, d.is_active  -- One row per driver
ORDER BY d.driver_id;                             -- Sort by driver ID

-- 5.2.2 INNER JOIN: the equivalent query, matched rows only
SELECT
    d.driver_id,                                  -- Driver's unique ID
    d.driver_name,                                -- Driver's name (the producer)
    d.home_city,                                  -- Driver's home city
    d.is_active,                                  -- Whether the driver is currently active
    COUNT(t.trip_id)    AS trip_count,            -- Always 1 or more, since unmatched drivers are dropped
    MIN(t.requested_at) AS first_trip,            -- Earliest trip
    MAX(t.requested_at) AS last_trip              -- Latest trip
FROM drivers AS d                                 -- Same starting table
INNER JOIN trips AS t                             -- Keep only drivers that have a matching trip
        ON t.driver_id = d.driver_id              -- Same join condition as 5.2.1
GROUP BY d.driver_id, d.driver_name, d.home_city, d.is_active  -- One row per driver
ORDER BY d.driver_id;                             -- Sort by driver ID

-- 5.2.3 Compare: how many producers does the INNER JOIN exclude?
WITH left_result AS (                             -- Distinct drivers returned by the LEFT JOIN
    SELECT DISTINCT d.driver_id
    FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
),
inner_result AS (                                 -- Distinct drivers returned by the INNER JOIN
    SELECT DISTINCT d.driver_id
    FROM drivers d
    INNER JOIN trips t ON t.driver_id = d.driver_id
)
SELECT
    (SELECT COUNT(*) FROM left_result)  AS left_join_producers,   -- Producers in the LEFT JOIN
    (SELECT COUNT(*) FROM inner_result) AS inner_join_producers,  -- Producers in the INNER JOIN
    (SELECT COUNT(*) FROM left_result)
  - (SELECT COUNT(*) FROM inner_result) AS producers_excluded;    -- The required count

-- 5.2.4 Identify the missing producers (anti-join)
SELECT
    d.driver_id,                                  -- Driver's unique ID
    d.driver_name,                                -- Driver's name
    d.home_city,                                  -- Home city
    d.onboard_date,                               -- When the driver joined
    d.avg_rating,                                 -- Stored rating
    d.is_active                                   -- Active flag
FROM drivers AS d                                 -- Every driver
LEFT JOIN trips AS t ON t.driver_id = d.driver_id -- Attach trips where they exist
WHERE t.trip_id IS NULL                           -- Keep only drivers with no matching trip
ORDER BY d.driver_id;