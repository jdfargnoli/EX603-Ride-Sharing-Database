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

-- ============================================================================
-- Task 5.2 Part B: Explore RIGHT JOIN and FULL OUTER JOIN
-- Producer table = drivers, Event table = trips (same relationship as Part A)
-- Run this file against the ex603_rideshare database (schema: public).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. RIGHT JOIN that returns the same records as the Part A LEFT JOIN
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- The driver's unique ID
    d.driver_name,                      -- The driver's name
    COUNT(t.trip_id) AS trip_count      -- Trips per driver. COUNT(column) skips NULLs,
                                        -- so drivers with no trips show 0
FROM trips t                            -- The tables are SWAPPED compared with Part A:
                                        -- trips is now the left-hand table...
RIGHT JOIN drivers d                    -- ...and drivers is the right-hand table. A RIGHT
                                        -- JOIN preserves every row of the RIGHT table, so
                                        -- every driver is kept, just like the LEFT JOIN
    ON t.driver_id = d.driver_id        -- Same join condition as Part A
GROUP BY d.driver_id, d.driver_name     -- One summary row per driver
ORDER BY d.driver_id;                   -- Same sort order as Part A
-- Expected: 15 rows, with Driver_14 and Driver_15 showing trip_count = 0.


-- ----------------------------------------------------------------------------
-- 2. Verify that the LEFT JOIN and RIGHT JOIN results match
--    Matching row counts aren't enough, so EXCEPT compares the actual rows
--    in both directions. If both differences are 0, the results are identical.
-- ----------------------------------------------------------------------------
WITH left_result AS (                   -- The Part A LEFT JOIN, saved as a named result
    SELECT d.driver_id, d.driver_name, COUNT(t.trip_id) AS trip_count
    FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
    GROUP BY d.driver_id, d.driver_name
),
right_result AS (                       -- The RIGHT JOIN from query 1, saved the same way
    SELECT d.driver_id, d.driver_name, COUNT(t.trip_id) AS trip_count
    FROM trips t
    RIGHT JOIN drivers d ON t.driver_id = d.driver_id
    GROUP BY d.driver_id, d.driver_name
)
SELECT
    (SELECT COUNT(*) FROM left_result)  AS left_rows,           -- Rows from the LEFT JOIN
    (SELECT COUNT(*) FROM right_result) AS right_rows,          -- Rows from the RIGHT JOIN
    (SELECT COUNT(*) FROM (SELECT * FROM left_result
                           EXCEPT                                -- Rows in LEFT but not RIGHT
                           SELECT * FROM right_result) a) AS only_in_left,
    (SELECT COUNT(*) FROM (SELECT * FROM right_result
                           EXCEPT                                -- Rows in RIGHT but not LEFT
                           SELECT * FROM left_result) b) AS only_in_right;
-- Expected: 15, 15, 0, 0. The two queries return exactly the same rows.


-- ----------------------------------------------------------------------------
-- 3. FULL OUTER JOIN: matching AND unmatched records from BOTH tables
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- NULL here would mean a trip with no matching driver
    d.driver_name,                      -- Driver's name (NULL for an orphan trip)
    t.trip_id,                          -- NULL here means a driver with no trips
    CASE                                -- Label each row so the unmatched ones stand out
        WHEN d.driver_id IS NULL THEN 'trip with no driver'    -- Unmatched on the trips side
        WHEN t.trip_id   IS NULL THEN 'driver with no trips'   -- Unmatched on the drivers side
        ELSE 'matched'                                         -- A normal driver-trip pair
    END AS match_status
FROM drivers d
FULL OUTER JOIN trips t                 -- FULL OUTER keeps unmatched rows from BOTH sides,
    ON t.driver_id = d.driver_id        -- filling the missing side's columns with NULL
ORDER BY match_status, d.driver_id, t.trip_id;  -- Puts unmatched rows at the top
-- Expected: 202 rows = 200 matched + 2 'driver with no trips' + 0 'trip with no driver'.


-- 3b. Summary of the FULL OUTER JOIN: one count per match status
SELECT
    CASE
        WHEN d.driver_id IS NULL THEN 'trip with no driver'
        WHEN t.trip_id   IS NULL THEN 'driver with no trips'
        ELSE 'matched'
    END      AS match_status,           -- Same labels as query 3
    COUNT(*) AS row_count               -- How many rows fall in each category
FROM drivers d
FULL OUTER JOIN trips t ON t.driver_id = d.driver_id
GROUP BY match_status                   -- One output row per label
ORDER BY match_status;


-- ----------------------------------------------------------------------------
-- 4. Demonstration: what each join type can and can't see
--    The real data has no orphan trips (the foreign key prevents them), so this
--    adds ONE fake trip for a driver that doesn't exist (driver_id 99) inside a
--    temporary result. No table is changed.
-- ----------------------------------------------------------------------------
WITH trips_demo AS (
    SELECT trip_id, driver_id FROM trips          -- The real 200 trips
    UNION ALL                                     -- Plus...
    SELECT 9001, 99                               -- ...one fake trip with no real driver
)
SELECT 'LEFT JOIN' AS join_type,
       COUNT(*) FILTER (WHERE d.driver_id IS NULL) AS orphan_trips_seen,  -- Trips with no driver
       COUNT(*) FILTER (WHERE t.trip_id   IS NULL) AS idle_drivers_seen   -- Drivers with no trips
FROM drivers d LEFT JOIN trips_demo t ON t.driver_id = d.driver_id
UNION ALL
SELECT 'RIGHT JOIN',
       COUNT(*) FILTER (WHERE d.driver_id IS NULL),
       COUNT(*) FILTER (WHERE t.trip_id   IS NULL)
FROM drivers d RIGHT JOIN trips_demo t ON t.driver_id = d.driver_id
UNION ALL
SELECT 'FULL OUTER JOIN',
       COUNT(*) FILTER (WHERE d.driver_id IS NULL),
       COUNT(*) FILTER (WHERE t.trip_id   IS NULL)
FROM drivers d FULL OUTER JOIN trips_demo t ON t.driver_id = d.driver_id;
-- Expected: LEFT sees 0 orphans and 2 idle drivers; RIGHT sees 1 orphan and 0 idle
-- drivers; FULL OUTER sees both (1 and 2).

-- ============================================================================
-- Task 5.2 Part C: Find producers with no events using two approaches
-- Producer table = drivers, Event table = trips
-- Run this file against the ex603_rideshare database (schema: public).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Approach 1: NOT EXISTS
--    Checks each driver one at a time and keeps the driver only if
--    no trip can be found for them.
-- ----------------------------------------------------------------------------
SELECT
    d.driver_id,                        -- The driver's unique ID
    d.driver_name                       -- The driver's name
FROM drivers d                          -- Look at every driver, one row at a time
WHERE NOT EXISTS (                      -- Keep this driver only if the subquery below
                                        -- returns NO rows at all
    SELECT 1                            -- The value selected doesn't matter; EXISTS only
                                        -- asks whether at least one row comes back
    FROM trips t                        -- Search the event table...
    WHERE t.driver_id = d.driver_id     -- ...for any trip belonging to THIS driver. Because
                                        -- it refers to d from the outer query, this is a
                                        -- "correlated" subquery that reruns for each driver
)
ORDER BY d.driver_id;                   -- Sort by driver ID
-- Expected: Driver_14 and Driver_15.


-- ----------------------------------------------------------------------------
-- 2. Approach 2: EXCEPT
--    Works with whole sets: take every driver ID, then subtract every
--    driver ID that appears on a trip. Whatever is left never had a trip.
-- ----------------------------------------------------------------------------
SELECT driver_id                        -- Set A: every driver ID that exists
FROM drivers
EXCEPT                                  -- Remove from Set A every value found in Set B
                                        -- (EXCEPT also removes duplicates from the result)
SELECT driver_id                        -- Set B: every driver ID that appears on a trip
FROM trips                              -- (many trips share a driver, but EXCEPT only
                                        -- cares whether the value is present)
ORDER BY driver_id;                     -- Sort the remaining IDs
-- Expected: 14 and 15. EXCEPT can only return the column both sides share
-- (driver_id), so names aren't included here.


-- 2b. The same EXCEPT result with driver names added back
SELECT
    d.driver_id,                        -- Driver ID
    d.driver_name                       -- Driver name, looked up from the drivers table
FROM drivers d
WHERE d.driver_id IN (                  -- Keep drivers whose ID is in the EXCEPT result
    SELECT driver_id FROM drivers       -- All driver IDs...
    EXCEPT
    SELECT driver_id FROM trips         -- ...minus driver IDs that have trips
)
ORDER BY d.driver_id;
-- Expected: Driver_14 and Driver_15.


-- ----------------------------------------------------------------------------
-- 3. Compare the two approaches
--    Save each result under a name, then use EXCEPT in both directions to
--    check whether either approach found a driver the other one missed.
-- ----------------------------------------------------------------------------
WITH not_exists_result AS (             -- Driver IDs found by Approach 1
    SELECT d.driver_id
    FROM drivers d
    WHERE NOT EXISTS (SELECT 1 FROM trips t WHERE t.driver_id = d.driver_id)
),
except_result AS (                      -- Driver IDs found by Approach 2
    SELECT driver_id FROM drivers
    EXCEPT
    SELECT driver_id FROM trips
)
SELECT
    (SELECT COUNT(*) FROM not_exists_result) AS not_exists_count,   -- How many Approach 1 found
    (SELECT COUNT(*) FROM except_result)     AS except_count,       -- How many Approach 2 found
    (SELECT COUNT(*) FROM (SELECT * FROM not_exists_result
                           EXCEPT                                    -- Found by 1 but not by 2
                           SELECT * FROM except_result) a) AS only_in_not_exists,
    (SELECT COUNT(*) FROM (SELECT * FROM except_result
                           EXCEPT                                    -- Found by 2 but not by 1
                           SELECT * FROM not_exists_result) b) AS only_in_except;
-- Expected: 2, 2, 0, 0. Both approaches identify exactly the same drivers.