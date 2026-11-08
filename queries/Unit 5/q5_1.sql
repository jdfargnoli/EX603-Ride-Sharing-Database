-- 5.1 Who are the people behind each trip event?
-- Who are the people behind each trip event?
-- This query joins three tables to display the actor who performed each event, the producer associated with the event,
-- and the event's date and time.
SELECT                                            -- Start the query; list the columns to return
    t.trip_id,                                    -- Unique ID of the trip (the event)
    r.rider_name    AS actor_rider,               -- Name of the rider who requested the trip (the actor)
    d.driver_name   AS producer_driver,           -- Name of the driver who fulfilled the trip (the producer)
    t.requested_at  AS event_datetime             -- When the trip was requested; the only timestamp every trip has
FROM trips   AS t                                 -- Start from the trips fact table, aliased as t
JOIN riders  AS r ON r.rider_id  = t.rider_id     -- Match each trip to its rider via fk_trips_actor
JOIN drivers AS d ON d.driver_id = t.driver_id    -- Match each trip to its driver via fk_trips_prod
ORDER BY trip_id;

-- 5.2 Do the producers identified in Assignment 4 share certain catalog credentials or tags?
-- This query connects the producer table to the catalog table through the junction table.
-- returning the producers associated with my theme's catalog tag.
-- Which drivers (producers) hold the theme's badge (catalog tag)?
SELECT                                                   -- Choose the columns to return
    d.driver_id,                                         -- Driver's unique ID
    d.driver_name,                                       -- Driver's name (the producer)
    d.avg_rating,                                        -- Driver's current average rating
    d.is_active,                                         -- Whether the driver is currently active
    b.badge_name,                                        -- The catalog tag being filtered on
    a.awarded_on                                         -- Date the badge was awarded (from the junction)
FROM drivers AS d                                        -- Start from the producer table
JOIN driver_badge_awards AS a ON a.driver_id = d.driver_id  -- Producer → junction (fk_driver_badge_awards_prod)
JOIN driver_badges       AS b ON b.badge_id  = a.badge_id   -- Junction → catalog (fk_driver_badge_awards_cat)
WHERE b.badge_name = 'Five Star'                         -- Keep only the theme's catalog tag
ORDER BY a.awarded_on, d.driver_id;                      -- Earliest award first; driver_id breaks ties

--5.3 How do the producers compare with one another?
-- Write a self join to compare records within the producer table.
-- Use the results to explore whether the producers identified in Assignment 4 share characteristics with other
-- producers or whether differences in activity levels may explain their performance.
--
-- Self join on the producer table (drivers)
-- Purpose: Compare each Five-Star driver with the other drivers who live in the
-- same city, and set their trip activity side by side, to test whether the
-- badge holders share traits with their peers or whether differences in
-- activity explain their higher ratings.

-- Open a Common Table Expression (CTE) named "activity". A CTE is a temporary,
-- named result set that exists only while this one query runs. It works like a
-- throwaway view and keeps the main query readable.
WITH activity AS (

    -- Return one row per driver. driver_id is the key we later join back on.
    SELECT d.driver_id,

           -- Count this driver's trips. COUNT(column) skips NULLs, so a driver
           -- with no trips gets 0 instead of 1 (the LEFT JOIN below produces
           -- one NULL row for such a driver, and that row is not counted).
           COUNT(t.trip_id) AS trips,

           -- Count only finished trips. FILTER (WHERE ...) is PostgreSQL's
           -- conditional aggregate: it counts just the rows that match the
           -- condition, which is cleaner than SUM(CASE WHEN ... THEN 1 END).
           COUNT(*) FILTER (WHERE t.trip_status = 'completed') AS completed,

           -- Count my theme's failure state: trips cancelled because the
           -- rider never showed up. These are the events that freeze a driver's
           -- bonus in my scenario.
           COUNT(*) FILTER (WHERE t.cancellation_reason = 'Rider no show') AS no_shows,

           -- Count trips whose outcome was disputed, which signals friction
           -- between the rider and the driver over that trip.
           COUNT(*) FILTER (WHERE t.trip_status = 'disputed') AS disputes

    -- Start from the full drivers table so that every driver gets a row,
    -- including drivers who have never taken a trip.
    FROM drivers AS d

    -- Attach each driver's trips. A LEFT JOIN keeps drivers with no matching
    -- trips (Driver_14 and Driver_15) and fills the trip columns with NULLs. An
    -- INNER JOIN would quietly drop those two drivers and skew the comparison.
    LEFT JOIN trips AS t ON t.driver_id = d.driver_id

    -- Collapse the many trip rows for each driver into one summary row, so
    -- the COUNTs above are calculated per driver.
    GROUP BY d.driver_id

-- Close the first CTE. The comma means another CTE follows in the same WITH.
),

-- Second CTE, named "five_star": the producers identified in Assignment 4.
-- Keeping this list in one place means I can change the badge once and the
-- whole query follows.
five_star AS (

    -- Return only the IDs of drivers who hold the badge. That's all the main
    -- query needs for its "is this a badge holder?" checks.
    SELECT a.driver_id

    -- Start from the junction table, which records which driver earned which
    -- badge and when. It resolves the many-to-many relationship between
    -- drivers and badges.
    FROM driver_badge_awards AS a

    -- Join the junction to the catalog table so it can filter by the badge's
    -- readable name instead of a numeric ID.
    JOIN driver_badges AS b ON b.badge_id = a.badge_id

    -- Keep only the theme's catalog tag. badge_name is guaranteed unique by
    -- the uq_driver_badges_name constraint, so this matches exactly one badge.
    WHERE b.badge_name = 'Five Star'

-- Close the second CTE. No comma follows, so the main query starts next.
)

-- Main query: list the columns that put each badge holder next to a peer.
SELECT

    -- The Five Star driver's name. The "f" alias is the left-hand copy of the
    -- drivers table, which holds only badge holders (enforced in WHERE below).
    f.driver_name                     AS five_star_driver,

    -- The city both drivers live in. Because the join requires the cities to
    -- match, f.home_city and p.home_city are always equal, so showing one is
    -- enough.
    f.home_city,

    -- The badge holder's stored average rating (0.00–5.00, enforced by the
    -- ck_drivers_metric CHECK constraint).
    f.avg_rating                      AS f_rating,

    -- The badge holder's total trip count, taken from the activity CTE. This
    -- is their activity level.
    fa.trips                          AS f_trips,

    -- The peer driver's name. The "p" alias is the right-hand copy of the
    -- same drivers table. Two aliases on one table are what make this a
    -- self join.
    p.driver_name                     AS peer_driver,

    -- The peer's average rating, for direct comparison with f_rating.
    p.avg_rating                      AS p_rating,

    -- The peer's total trip count, for direct comparison with f_trips.
    pa.trips                          AS p_trips,

    -- A true/false flag showing whether the peer also holds the Five Star
    -- badge. If badge holders clustered in one city, this would show true;
    -- in the data it's false in every row.
    p.driver_id IN (SELECT driver_id FROM five_star) AS peer_is_five_star,

    -- The rating difference, badge holder minus peer. A positive value means
    -- the badge holder is rated higher than this same-city peer.
    f.avg_rating - p.avg_rating       AS rating_gap,

    -- The trip-volume difference, badge holder minus peer. A negative value
    -- means the badge holder drove fewer trips, which is the pattern to look
    -- for when testing whether lower activity goes with higher ratings.
    fa.trips - pa.trips               AS trip_gap

-- First copy of the drivers table, aliased "f" (focus). These rows are the
-- drivers being examined: the badge holders.
FROM drivers AS f

-- Second copy of the SAME drivers table, aliased "p" (peer). Joining a table
-- to itself is the self join. Each row of f is paired with matching rows of p.
JOIN drivers AS p

  -- Join condition 1: pair drivers who share a home city. Home city is the
  -- "shared characteristic" being tested.
  ON  p.home_city = f.home_city

  -- Join condition 2: exclude pairs where a driver is matched with themselves.
  -- Without this, every badge holder would appear once next to their own
  -- record, which is a meaningless comparison.
  AND p.driver_id <> f.driver_id

-- Attach the badge holder's activity summary from the first CTE, using "fa"
-- (focus activity) as the alias so its columns can be told apart from the peer's.
JOIN activity AS fa ON fa.driver_id = f.driver_id

-- Attach the peer's activity summary from the same CTE under a different alias,
-- "pa" (peer activity). One CTE serves both sides because it has two aliases.
JOIN activity AS pa ON pa.driver_id = p.driver_id

-- Restrict the left side (f) to Five Star drivers only. The peer side (p) is
-- left unrestricted, so badge holders are compared with everyone in their city.
WHERE f.driver_id IN (SELECT driver_id FROM five_star)

-- Sort first by badge holder, so each one's comparisons appear together, then
-- by peer ID within each group, so the output is the same every time you run it.
ORDER BY f.driver_id, p.driver_id;-- auto-generated definition
-- Unexpected: LocalDataSource
