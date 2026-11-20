-- =====================================================================
-- Task 6.1: Compute across a window without collapsing
-- 1. Compare each event to its producer's average
-- I LOOKED AT DRIVER BADGE PROGRESSION BY QUARTER (2023 - only year available)
-- One row per driver. For each quarter this shows:
--   * the cumulative badge count and the badge names earned so far
--   * the quarter to quarter change in number of badges (and new badges earned that quarter)
--   * a trend label built with LAG and LEAD (increasing or decreasing)
-- A final column flags "Superstar" drivers for those drivers who had 2 consecutive quarters of increasing badge count.
-- The query is built in steps using CTEs (WITH ... AS), which act like
-- temporary named tables that exist only while this query runs.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: quarters
-- Builds a small list of the four quarter start dates for 2023:
-- 2023-01-01, 2023-04-01, 2023-07-01, 2023-10-01.
-- generate_series(start, stop, step) creates one row per value,
-- stepping 3 months at a time. ::date converts the result to a date.
-- ---------------------------------------------------------------------
WITH quarters AS (
    SELECT generate_series(DATE '2023-01-01', DATE '2023-10-01', interval '3 months')::date AS qs
),

-- ---------------------------------------------------------------------
-- STEP 2: per_quarter
-- Produces one row for every driver in every quarter
-- (15 drivers x 4 quarters = 60 rows), with three calculated values.
-- ---------------------------------------------------------------------
per_quarter AS (
    SELECT d.driver_id,
           d.driver_name,
           d.licence_number,      -- unique per driver, guaranteed by the schema
           q.qs,                  -- the quarter's start date

           -- CHANGE: badges awarded INSIDE this quarter only.
           -- FILTER limits which rows this COUNT includes: awards on or
           -- after the quarter start and before the next quarter starts.
           COUNT(a.badge_id) FILTER (WHERE a.awarded_on >= q.qs
                                       AND a.awarded_on <  q.qs + interval '3 months') AS change,

           -- CUMULATIVE: every badge awarded up to the END of this quarter.
           -- No lower limit, so earlier quarters are included.
           -- That is what makes it a running total.
           COUNT(a.badge_id) FILTER (WHERE a.awarded_on <  q.qs + interval '3 months') AS cumulative,

           -- BADGES: names of all badges earned up to the end of this quarter,
           -- joined into one text value like "Safe Driving, Five Star".
           -- ORDER BY a.awarded_on lists them in the order they were earned.
           STRING_AGG(b.badge_name, ', ' ORDER BY a.awarded_on)
               FILTER (WHERE a.awarded_on < q.qs + interval '3 months') AS badges

    FROM drivers d

    -- CROSS JOIN pairs every driver with every quarter, so a quarter with
    -- no awards still gets a row (with zeros) instead of being missing.
    CROSS JOIN quarters q

    -- LEFT JOIN keeps drivers who have no awards at all.
    -- A plain JOIN would drop them from the results.
    LEFT JOIN driver_badge_awards a ON a.driver_id = d.driver_id

    -- Looks up each badge's name from the badge catalog table.
    LEFT JOIN driver_badges b ON b.badge_id = a.badge_id

    -- Collapse rows so we get one row per driver per quarter.
    GROUP BY d.driver_id, d.driver_name, d.licence_number, q.qs
),

-- ---------------------------------------------------------------------
-- STEP 3: with_trend
-- Adds a trend label to each driver-quarter row using window functions.
--   LAG(change)  = the change value from the PREVIOUS quarter
--   LEAD(change) = the change value from the NEXT quarter
-- The trend compares those two neighbours:
--   previous < next  -> 'increasing'
--   previous = next  -> 'steady'
--   previous > next  -> 'decreasing'
-- Q1 has no previous quarter and Q4 has no next quarter, so LAG or LEAD
-- returns NULL there, and we label those 'n/a'.
-- ---------------------------------------------------------------------
with_trend AS (
    SELECT *,
           CASE
               WHEN LAG(change) OVER w IS NULL OR LEAD(change) OVER w IS NULL THEN 'n/a'
               WHEN LAG(change) OVER w <  LEAD(change) OVER w THEN 'increasing'
               WHEN LAG(change) OVER w =  LEAD(change) OVER w THEN 'steady'
               ELSE 'decreasing'
           END AS trend
    FROM per_quarter

    -- Defines the window "w" used above:
    -- PARTITION BY driver_id = look only at the same driver's rows
    -- ORDER BY qs            = in date order, so "previous" and "next"
    --                          mean the neighbouring quarters
    WINDOW w AS (PARTITION BY driver_id ORDER BY qs)
)

-- ---------------------------------------------------------------------
-- STEP 4: final pivot
-- Turns the 4 rows per driver back into ONE row per driver,
-- with separate columns for each quarter.
-- MAX(...) FILTER (WHERE qs = <date>) picks the value from the one row
-- for that quarter. MAX is used only because there is exactly one
-- value to pick; it does not change anything.
-- ---------------------------------------------------------------------
SELECT driver_id, driver_name, licence_number,

    -- ----- Quarter 1 -----
    -- Shows e.g. "2: Safe Driving, Five Star". || joins text together.
    -- COALESCE swaps a NULL (no badges yet) for an empty string,
    -- so the cell shows "0: " instead of being blank.
    MAX(cumulative || ': ' || COALESCE(badges, '')) FILTER (WHERE qs = DATE '2023-01-01') AS "2023-Q1",
    MAX(change) FILTER (WHERE qs = DATE '2023-01-01') AS "Q1 change",
    MAX(trend)  FILTER (WHERE qs = DATE '2023-01-01') AS "Q1 trend",

    -- ----- Quarter 2 -----
    MAX(cumulative || ': ' || COALESCE(badges, '')) FILTER (WHERE qs = DATE '2023-04-01') AS "2023-Q2",
    MAX(change) FILTER (WHERE qs = DATE '2023-04-01') AS "Q2 change",
    MAX(trend)  FILTER (WHERE qs = DATE '2023-04-01') AS "Q2 trend",

    -- ----- Quarter 3 -----
    MAX(cumulative || ': ' || COALESCE(badges, '')) FILTER (WHERE qs = DATE '2023-07-01') AS "2023-Q3",
    MAX(change) FILTER (WHERE qs = DATE '2023-07-01') AS "Q3 change",
    MAX(trend)  FILTER (WHERE qs = DATE '2023-07-01') AS "Q3 trend",

    -- ----- Quarter 4 -----
    MAX(cumulative || ': ' || COALESCE(badges, '')) FILTER (WHERE qs = DATE '2023-10-01') AS "2023-Q4",
    MAX(change) FILTER (WHERE qs = DATE '2023-10-01') AS "Q4 change",
    MAX(trend)  FILTER (WHERE qs = DATE '2023-10-01') AS "Q4 trend",

    -- ----- Superstar flag -----
    -- A driver is a Superstar if their cumulative total went UP in both
    -- Q2 and Q3, which is the same as having a change above zero in both.
    -- The "doesn't go down in Q4" rule needs no check: badges are never
    -- removed, so a cumulative total can't decrease.
    CASE WHEN MAX(change) FILTER (WHERE qs = DATE '2023-04-01') > 0
          AND MAX(change) FILTER (WHERE qs = DATE '2023-07-01') > 0
         THEN 'Superstar' ELSE '' END AS superstar

FROM with_trend
GROUP BY driver_id, driver_name, licence_number   -- one output row per driver
ORDER BY driver_id;                                -- list drivers in ID order


-- =====================================================================
-- Task 6.1: Compute across a window without collapsing
-- 2. Rank producers three ways
-- DRIVER YEAR-END COMPARISON AND RANKINGS (2023)
-- One row per driver showing three full-year totals:
--   1. revenue generated (completed trips only)
--   2. number of completed trips
--   3. number of badges earned
-- Each total is ranked three different ways, side by side:
--   ROW_NUMBER : 1, 2, 3, 4 ...  every row gets a unique number,
--                even when values tie (the tie order is arbitrary)
--   RANK       : 1, 2, 2, 4 ...  ties share a rank, then the next
--                rank skips ahead by the number of tied rows
--   DENSE_RANK : 1, 2, 2, 3 ...  ties share a rank, with no gaps
-- The three functions only differ when values tie, which is why the
-- badge columns (lots of ties) show the contrast most clearly.
-- The query is built in steps using CTEs (WITH ... AS), which act like
-- temporary named tables that exist only while this query runs.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: trip_y
-- Adds up each driver's trips for the year.
-- Only 'completed' trips count; cancelled and disputed trips are left
-- out of both revenue and the ride count.
-- Drivers with no completed trips won't appear here at all; they are
-- filled in with zeros in step 3.
-- ---------------------------------------------------------------------
WITH trip_y AS (
    SELECT driver_id,
           SUM(fare_amount) AS revenue,   -- total fares collected
           COUNT(*)         AS rides      -- number of completed trips
    FROM trips
    WHERE trip_status = 'completed'
    GROUP BY driver_id                    -- one row per driver
),

-- ---------------------------------------------------------------------
-- STEP 2: badge_y
-- Counts each driver's badge awards for the year.
-- Each row in driver_badge_awards is one badge given to one driver,
-- so counting rows per driver gives their badge total.
-- All awards in this dataset fall in 2023, so no date filter is needed.
-- ---------------------------------------------------------------------
badge_y AS (
    SELECT driver_id,
           COUNT(*) AS badges
    FROM driver_badge_awards
    GROUP BY driver_id
),

-- ---------------------------------------------------------------------
-- STEP 3: Totals
-- Combines everything into one row per driver.
-- Trips and badges were summarized separately in steps 1 and 2 BEFORE
-- joining. Joining the raw trips and badges tables directly would
-- multiply rows (every trip paired with every badge) and inflate
-- the totals.
-- ---------------------------------------------------------------------
totals AS (
    SELECT d.driver_id,
           d.driver_name,
           d.licence_number,              -- unique per driver, guaranteed by the schema

           -- COALESCE turns a missing value (NULL) into 0, so a driver
           -- with no trips or no badges shows 0 instead of a blank.
           COALESCE(t.revenue, 0) AS year_revenue,
           COALESCE(t.rides, 0)   AS year_rides,
           COALESCE(b.badges, 0)  AS year_badges

    -- Start from the drivers table so EVERY driver is included.
    FROM drivers d

    -- LEFT JOIN keeps drivers even if they have no matching row
    -- in trip_y or badge_y. A plain JOIN would drop them.
    LEFT JOIN trip_y  t ON t.driver_id = d.driver_id
    LEFT JOIN badge_y b ON b.driver_id = d.driver_id
)

-- ---------------------------------------------------------------------
-- STEP 4: Final output with rankings
-- These are window functions: OVER (ORDER BY ...) looks at ALL drivers'
-- values to work out where each driver stands, without collapsing rows.
-- DESC means the highest value gets rank 1.
-- Each metric has its own independent set of three rankings.
-- ---------------------------------------------------------------------
SELECT driver_id, driver_name, licence_number,

    -- ----- Revenue -----
    -- Fare totals rarely tie exactly, so these three columns will
    -- probably all read the same, 1 through 15.
    year_revenue,
    ROW_NUMBER() OVER (ORDER BY year_revenue DESC) AS revenue_row_number,
    RANK()       OVER (ORDER BY year_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY year_revenue DESC) AS revenue_dense_rank,

    -- ----- Trips -----
    -- Ride counts are whole numbers, so some ties are likely, and you
    -- may start to see RANK and DENSE_RANK pull apart.
    year_rides,
    ROW_NUMBER() OVER (ORDER BY year_rides DESC) AS rides_row_number,
    RANK()       OVER (ORDER BY year_rides DESC) AS rides_rank,
    DENSE_RANK() OVER (ORDER BY year_rides DESC) AS rides_dense_rank,

    -- ----- Badges -----
    -- Badge counts range only from 0 to 4, so many drivers tie.
    -- This is where the three functions differ the most:
    --   ROW_NUMBER still counts 1 to 15,
    --   RANK repeats numbers for ties and then skips,
    --   DENSE_RANK repeats numbers for ties with no gaps.
    year_badges,
    ROW_NUMBER() OVER (ORDER BY year_badges DESC) AS badges_row_number,
    RANK()       OVER (ORDER BY year_badges DESC) AS badges_rank,
    DENSE_RANK() OVER (ORDER BY year_badges DESC) AS badges_dense_rank

FROM totals

-- Sort the output by revenue, highest first.
-- Change this to ORDER BY year_badges DESC to line up the badge ties
-- and see the three ranking styles side by side more clearly.
ORDER BY year_revenue DESC;


-- =====================================================================
-- Task 6.1: Compute across a window without collapsing
-- 3. Sort producers into four bands
-- =====================================================================
-- DRIVER RIDE QUARTILES USING NTILE(4) (2023)
-- Splits all 15 drivers ("producers") into four groups by their number
-- of completed rides. Group 1 = busiest drivers, group 4 = least busy.
--
-- HOW NTILE WORKS
-- NTILE(n) sorts the rows, then deals them into n groups that are as
-- equal in size as possible. It works purely by POSITION in the sorted
-- list, not by value. With 15 drivers and 4 groups:
--   15 / 4 = 3 remainder 3, so the first 3 groups get one extra row.
--   Group sizes: 4, 4, 4, 3.
--
-- THE TIE PROBLEM
-- Because NTILE only counts positions, drivers with the SAME ride count
-- can be split across two groups if a cut falls between them.
-- In this data, drivers 7 and 12 both have 14 rides, sitting at
-- positions 4 and 5. Group 1 holds only 4 drivers, so one of them lands
-- in group 1 and the other in group 2, despite identical numbers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: trip_y
-- Counts each driver's completed trips for the year.
-- Cancelled and disputed trips are excluded.
-- Drivers with no completed trips won't appear here; they are added
-- back with a count of 0 in the main query below.
-- ---------------------------------------------------------------------
WITH trip_y AS (
    SELECT driver_id,
           COUNT(*) AS rides
    FROM trips
    WHERE trip_status = 'completed'
    GROUP BY driver_id                 -- one row per driver
)

-- ---------------------------------------------------------------------
-- STEP 2: assign each driver to a quartile
-- ---------------------------------------------------------------------
SELECT d.driver_id,
       d.driver_name,

       -- COALESCE turns a missing count (NULL) into 0, so drivers with
       -- no completed trips still appear, with 0 rides.
       COALESCE(t.rides, 0) AS year_rides,

       -- NTILE(4) is a window function: OVER (...) tells it how to
       -- order ALL drivers before cutting them into 4 groups.
       --   COALESCE(t.rides, 0) DESC : most rides first, so group 1
       --                               holds the busiest drivers
       --   d.driver_id               : TIEBREAKER. When two drivers
       --                               have the same ride count, the
       --                               lower ID goes first. Without it,
       --                               PostgreSQL doesn't guarantee which
       --                               tied driver lands where, so the
       --                               result could change between runs.
       --                               The tiebreaker makes it
       --                               repeatable, but the split is still
       --                               arbitrary: driver 7 is placed in
       --                               group 1 only because 7 < 12.
       NTILE(4) OVER (ORDER BY COALESCE(t.rides, 0) DESC, d.driver_id) AS ride_quartile

-- Start from the drivers table so EVERY driver is included.
FROM drivers d

-- LEFT JOIN keeps drivers who have no completed trips.
-- A plain JOIN would drop them, leaving fewer than 15 rows and
-- changing the group sizes.
LEFT JOIN trip_y t ON t.driver_id = d.driver_id

-- Show group 1 first, and the busiest drivers first within each group.
ORDER BY ride_quartile, year_rides DESC;

-- ---------------------------------------------------------------------
-- WHAT TO EXPECT
--   Group 1 (4 drivers): 19, 19, 17, 14   <- driver 7
--   Group 2 (4 drivers): 14, 13, 12, 11   <- driver 12, tied with driver 7
--   Group 3 (4 drivers):  9,  9,  8,  7
--   Group 4 (3 drivers):  4,  0,  0
-- Only the group 1 / group 2 boundary splits a tie in this data.
-- If tied drivers must stay together, use a value-based method such as
-- PERCENT_RANK or CUME_DIST instead, accepting unequal group sizes.
-- ---------------------------------------------------------------------