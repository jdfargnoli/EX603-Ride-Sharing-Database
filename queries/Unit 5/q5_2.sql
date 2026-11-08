-- Task 5.2: Find Records That Joins May Exclude
-- Part A: Compare INNER JOIN and LEFT JOIN
-- ============================================================================
-- Task 5.2 Part A: Compare INNER JOIN and LEFT JOIN
-- Producer table = drivers (the people who carry out trips)
-- Event table    = trips   (one row per trip; trips.driver_id points to drivers)
-- Goal: show which drivers an INNER JOIN silently drops, and count them.
-- ============================================================================
-- ----------------------------------------------------------------------------
-- 1. LEFT JOIN: return ALL producers, including those who never had an event
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- The driver's unique ID (primary key of drivers)
    d.driver_name,                      -- The driver's name, so the output is readable
    COUNT(t.trip_id) AS trip_count      -- Number of trips for this driver. COUNT(column)
                                        -- skips NULLs, so a driver with no trips shows 0
FROM drivers d                          -- Start from drivers, aliased as "d". In a LEFT JOIN
                                        -- this left-hand table is the one that is preserved
LEFT JOIN trips t                       -- Attach trips, aliased as "t". LEFT JOIN keeps every
                                        -- driver even when no trip matches, and fills the
                                        -- trip columns with NULL for those drivers
    ON t.driver_id = d.driver_id        -- Join condition: a trip belongs to a driver when
                                        -- the IDs match (the fk_trips_prod foreign key)
GROUP BY d.driver_id, d.driver_name     -- Collapse each driver's many trip rows into one
                                        -- summary row so COUNT works per driver
ORDER BY d.driver_id;                   -- Sort by driver ID so results are easy to compare
-- Expected: 15 rows (every driver). Driver_14 and Driver_15 show trip_count = 0.


-- ----------------------------------------------------------------------------
-- 2. INNER JOIN: the equivalent query, but only matched rows are kept
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- Same columns as query 1 so the results line up
    d.driver_name,                      -- Driver's name
    COUNT(t.trip_id) AS trip_count      -- Always 1 or more here, because drivers with
                                        -- no trips never make it into the result
FROM drivers d                          -- Same starting table as query 1
INNER JOIN trips t                      -- The ONLY change from query 1: INNER instead of
                                        -- LEFT. A row is kept only when a match exists in
                                        -- BOTH tables; unmatched drivers are dropped
    ON t.driver_id = d.driver_id        -- Same join condition as query 1
GROUP BY d.driver_id, d.driver_name     -- One summary row per driver
ORDER BY d.driver_id;                   -- Same sort order as query 1
-- Expected: 13 rows. Driver_14 and Driver_15 are missing.


-- ----------------------------------------------------------------------------
-- 3. Compare the results: how many producers does the INNER JOIN exclude?
--    Each line in the SELECT list is a small subquery that returns one number,
--    so the output is a single row with three counts side by side.
-- ----------------------------------------------------------------------------
SELECT
    -- Count of distinct drivers returned by the LEFT JOIN (query 1)
    (SELECT COUNT(DISTINCT d.driver_id)             -- DISTINCT counts each driver once,
                                                    -- even though a driver can appear on
                                                    -- many joined trip rows
       FROM drivers d
       LEFT JOIN trips t ON t.driver_id = d.driver_id)  AS left_join_count,

    -- Count of distinct drivers returned by the INNER JOIN (query 2)
    (SELECT COUNT(DISTINCT d.driver_id)
       FROM drivers d
       INNER JOIN trips t ON t.driver_id = d.driver_id) AS inner_join_count,

    -- Count of drivers the INNER JOIN excludes: drivers whose LEFT JOIN row has
    -- no matching trip. When no trip matches, t.trip_id is NULL, so filtering on
    -- "t.trip_id IS NULL" keeps exactly the unmatched drivers.
    (SELECT COUNT(*)
       FROM drivers d
       LEFT JOIN trips t ON t.driver_id = d.driver_id
       WHERE t.trip_id IS NULL)                         AS excluded_count;
-- Expected: left_join_count = 15, inner_join_count = 13, excluded_count = 2.


-- ----------------------------------------------------------------------------
-- 4. List the producers the INNER JOIN excludes (an "anti-join")
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- ID of each excluded driver
    d.driver_name                       -- Name of each excluded driver
FROM drivers d                          -- Start from every driver
LEFT JOIN trips t                       -- LEFT JOIN so drivers without trips are kept,
    ON t.driver_id = d.driver_id        -- with NULLs in the trip columns
WHERE t.trip_id IS NULL                 -- Keep ONLY the rows where no trip matched.
                                        -- These are exactly the drivers query 2 dropped
ORDER BY d.driver_id;                   -- Sort by driver ID
-- Expected: Driver_14 and Driver_15. Both are active drivers who have never
-- been assigned a trip, so no row in trips references driver_id 14 or 15.