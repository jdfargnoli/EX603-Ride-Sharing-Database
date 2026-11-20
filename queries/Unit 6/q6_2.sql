-- =====================================================================
-- Task 6.2: Compare each row to its neighbors
-- Part A: Row to row
-- =====================================================================
-- TOP PRODUCER: MONTHLY REVENUE, CUMULATIVE, DELTA, AND DIRECTION (2023)
-- One row for the year's top-earning driver, with four columns per month:
--   * revenue    : completed-trip fares that month
--   * cumulative : running total of revenue from January to that month
--   * delta      : this month's revenue minus last month's
--   * up/down    : 'up', 'down', or 'same' compared with last month
-- =====================================================================

-- STEP 1: top_driver
-- The driver with the most completed-trip revenue for the year.
-- driver_id breaks ties; LIMIT 1 keeps just that driver.
WITH top_driver AS (
    SELECT driver_id
    FROM trips
    WHERE trip_status = 'completed'
    GROUP BY driver_id
    ORDER BY SUM(fare_amount) DESC, driver_id
    LIMIT 1
),

-- STEP 2: months
-- The 12 month start dates of 2023, so months with no trips still show 0.
months AS (
    SELECT generate_series(DATE '2023-01-01', DATE '2023-12-01', interval '1 month')::date AS ms
),

-- STEP 3: monthly
-- The top driver's revenue for each month (12 rows).
monthly AS (
    SELECT d.driver_id,
           d.driver_name,
           EXTRACT(MONTH FROM m.ms)::int AS mn,        -- month number 1-12
           m.ms,                                        -- month start date, for ordering
           COALESCE(SUM(t.fare_amount), 0) AS revenue  -- 0 if no trips that month
    FROM top_driver td
    JOIN drivers d ON d.driver_id = td.driver_id
    CROSS JOIN months m                                 -- pair the driver with all 12 months
    LEFT JOIN trips t                                   -- LEFT JOIN keeps months with no trips
           ON t.driver_id = td.driver_id
          AND t.trip_status = 'completed'
          AND date_trunc('month', t.requested_at)::date = m.ms
    GROUP BY d.driver_id, d.driver_name, m.ms
),

-- STEP 4: changes
-- Window functions look across the 12 monthly rows in date order.
changes AS (
    SELECT *,
           -- CUMULATIVE: SUM(...) OVER (ORDER BY ms) adds up every month
           -- from January through the current month (a running total).
           SUM(revenue) OVER (ORDER BY ms) AS cumulative,

           -- DELTA: LAG looks back one month. Blank for January.
           revenue - LAG(revenue) OVER (ORDER BY ms) AS delta,

           -- DIRECTION: plain-word version of the delta.
           CASE WHEN LAG(revenue) OVER (ORDER BY ms) IS NULL THEN 'n/a'
                WHEN revenue > LAG(revenue) OVER (ORDER BY ms) THEN 'up'
                WHEN revenue < LAG(revenue) OVER (ORDER BY ms) THEN 'down'
                ELSE 'same' END AS direction
    FROM monthly
)

-- STEP 5: pivot into one row (12 months x 4 columns = 48 columns)
-- MAX(...) FILTER (WHERE mn = N) picks month N's value.
SELECT driver_id, driver_name,
    MAX(revenue) FILTER (WHERE mn=1)  AS "Jan revenue", MAX(cumulative) FILTER (WHERE mn=1)  AS "Jan cumulative", MAX(delta) FILTER (WHERE mn=1)  AS "Jan delta", MAX(direction) FILTER (WHERE mn=1)  AS "Jan up/down",
    MAX(revenue) FILTER (WHERE mn=2)  AS "Feb revenue", MAX(cumulative) FILTER (WHERE mn=2)  AS "Feb cumulative", MAX(delta) FILTER (WHERE mn=2)  AS "Feb delta", MAX(direction) FILTER (WHERE mn=2)  AS "Feb up/down",
    MAX(revenue) FILTER (WHERE mn=3)  AS "Mar revenue", MAX(cumulative) FILTER (WHERE mn=3)  AS "Mar cumulative", MAX(delta) FILTER (WHERE mn=3)  AS "Mar delta", MAX(direction) FILTER (WHERE mn=3)  AS "Mar up/down",
    MAX(revenue) FILTER (WHERE mn=4)  AS "Apr revenue", MAX(cumulative) FILTER (WHERE mn=4)  AS "Apr cumulative", MAX(delta) FILTER (WHERE mn=4)  AS "Apr delta", MAX(direction) FILTER (WHERE mn=4)  AS "Apr up/down",
    MAX(revenue) FILTER (WHERE mn=5)  AS "May revenue", MAX(cumulative) FILTER (WHERE mn=5)  AS "May cumulative", MAX(delta) FILTER (WHERE mn=5)  AS "May delta", MAX(direction) FILTER (WHERE mn=5)  AS "May up/down",
    MAX(revenue) FILTER (WHERE mn=6)  AS "Jun revenue", MAX(cumulative) FILTER (WHERE mn=6)  AS "Jun cumulative", MAX(delta) FILTER (WHERE mn=6)  AS "Jun delta", MAX(direction) FILTER (WHERE mn=6)  AS "Jun up/down",
    MAX(revenue) FILTER (WHERE mn=7)  AS "Jul revenue", MAX(cumulative) FILTER (WHERE mn=7)  AS "Jul cumulative", MAX(delta) FILTER (WHERE mn=7)  AS "Jul delta", MAX(direction) FILTER (WHERE mn=7)  AS "Jul up/down",
    MAX(revenue) FILTER (WHERE mn=8)  AS "Aug revenue", MAX(cumulative) FILTER (WHERE mn=8)  AS "Aug cumulative", MAX(delta) FILTER (WHERE mn=8)  AS "Aug delta", MAX(direction) FILTER (WHERE mn=8)  AS "Aug up/down",
    MAX(revenue) FILTER (WHERE mn=9)  AS "Sep revenue", MAX(cumulative) FILTER (WHERE mn=9)  AS "Sep cumulative", MAX(delta) FILTER (WHERE mn=9)  AS "Sep delta", MAX(direction) FILTER (WHERE mn=9)  AS "Sep up/down",
    MAX(revenue) FILTER (WHERE mn=10) AS "Oct revenue", MAX(cumulative) FILTER (WHERE mn=10) AS "Oct cumulative", MAX(delta) FILTER (WHERE mn=10) AS "Oct delta", MAX(direction) FILTER (WHERE mn=10) AS "Oct up/down",
    MAX(revenue) FILTER (WHERE mn=11) AS "Nov revenue", MAX(cumulative) FILTER (WHERE mn=11) AS "Nov cumulative", MAX(delta) FILTER (WHERE mn=11) AS "Nov delta", MAX(direction) FILTER (WHERE mn=11) AS "Nov up/down",
    MAX(revenue) FILTER (WHERE mn=12) AS "Dec revenue", MAX(cumulative) FILTER (WHERE mn=12) AS "Dec cumulative", MAX(delta) FILTER (WHERE mn=12) AS "Dec delta", MAX(direction) FILTER (WHERE mn=12) AS "Dec up/down"
FROM changes
GROUP BY driver_id, driver_name;

-- =====================================================================
-- Task 6.2: Compare each row to its neighbors
-- Part B: Cumulative and smoothed
-- =====================================================================
-- PLATFORM REVENUE OVER TIME (2023) - for leadership
-- One row per month, showing:
--   * monthly revenue and completed trips
--   * running total (year to date)
--   * 3-month moving average (the "recent" trend)
--   * progress against an annual target of $3,600
-- TARGET: $3,600 for the year, i.e. a steady pace of $300 per month.
-- =====================================================================

-- STEP 1: months
-- Every month of 2023 is listed, even if a month had no trips.
-- This matters because ROWS windows count ROWS, not calendar time:
-- if a month were missing, a "3-row" window would quietly stretch
-- across more than 3 months. Filling the gaps keeps 3 rows = 3 months.
WITH months AS (
    SELECT generate_series(DATE '2023-01-01', DATE '2023-12-01', interval '1 month')::date AS ms
),

-- STEP 2: monthly
-- Total completed-trip revenue and trip count per month, across all drivers.
monthly AS (
    SELECT m.ms,
           COUNT(t.trip_id)                AS trips,
           COALESCE(SUM(t.fare_amount), 0) AS revenue   -- 0 for a month with no trips
    FROM months m
    LEFT JOIN trips t
           ON date_trunc('month', t.requested_at)::date = m.ms
          AND t.trip_status = 'completed'
    GROUP BY m.ms
)

-- STEP 3: window calculations
SELECT
    to_char(ms, 'YYYY-MM') AS month,
    trips,
    revenue,

    -- RUNNING TOTAL: adds every month from the first row up to this one.
    SUM(revenue) OVER (ORDER BY ms
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,

    -- MOVING AVERAGE: this month plus the 2 before it (3 rows = 3 months).
    -- January and February average over fewer months because there are
    -- fewer rows before them.
    ROUND(AVG(revenue) OVER (ORDER BY ms
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m,

    -- TARGET PACE: where the running total should be if the platform
    -- earned exactly $300 every month (month number x 300).
    300 * ROW_NUMBER() OVER (ORDER BY ms) AS target_pace,

    -- AHEAD/BEHIND PACE: positive = ahead of target, negative = behind.
    SUM(revenue) OVER (ORDER BY ms ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        - 300 * ROW_NUMBER() OVER (ORDER BY ms) AS vs_pace,

    -- PERCENT OF ANNUAL TARGET reached so far.
    ROUND(100.0 * SUM(revenue) OVER (ORDER BY ms
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 3600, 1) AS pct_of_target
FROM monthly
ORDER BY ms;

-- With ROWS, the window moves one physical row at a time, so rows that tie on the ORDER BY value
-- are added one by one, in an arbitrary order.
-- With RANGE, tied rows are treated as peers and included all at once, so every tied row shows
-- the same running total. Here each month appears exactly once, so the two give identical results.
-- The difference would show up if this was run on individual trips that share the same timestamp


-- =====================================================================
-- Task 6.2: Compare each row to its neighbors
-- Part C: Where the series stops
-- =====================================================================
-- FIND DRIVER INACTIVITY GAPS
-- For each driver, compare every trip with the one before it (LAG) and
-- measure the silence in between. Keep only gaps of 90+ days.
-- Activity = any trip request assigned to the driver, whatever its
-- status: a cancelled or disputed trip still shows the driver was on
-- the platform taking requests.
-- =====================================================================

-- STEP 1: gaps
-- One row per trip, with the time since the same driver's previous trip.
-- LAG(...) OVER (PARTITION BY driver_id ORDER BY requested_at) looks back
-- one row within the same driver's trips, in time order.
-- A driver's first trip has no previous trip, so prev_trip_at is NULL.
WITH gaps AS (
    SELECT driver_id,
           LAG(trip_id)      OVER w AS prev_trip_id,
           LAG(requested_at) OVER w AS prev_trip_at,
           trip_id,
           requested_at,
           -- Gap in days, with fractions (e.g. 112.6)
           ROUND(EXTRACT(EPOCH FROM requested_at - LAG(requested_at) OVER w) / 86400, 1) AS gap_days
    FROM trips
    WINDOW w AS (PARTITION BY driver_id ORDER BY requested_at)
),

-- STEP 2: typical
-- Each driver's median gap, for context: is the long gap unusual
-- for THIS driver, or is this driver just always sporadic?
typical AS (
    SELECT driver_id,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap_days
    FROM gaps
    WHERE gap_days IS NOT NULL
    GROUP BY driver_id
)

-- STEP 3: keep only the long gaps
-- The WHERE must be out here, in the outer query. A window function
-- runs AFTER WHERE and HAVING in the same query, so it can't be
-- filtered there. Computing it in a CTE first makes gap_days an
-- ordinary column that WHERE can use.
SELECT g.driver_id,
       d.driver_name,
       d.is_active,
       g.prev_trip_id,
       g.prev_trip_at        AS last_trip_before_gap,
       g.trip_id,
       g.requested_at        AS first_trip_after_gap,
       g.gap_days,
       ROUND(t.median_gap_days::numeric, 1) AS typical_gap_days,
       ROUND((g.gap_days / t.median_gap_days)::numeric, 1) AS times_typical
FROM gaps g
JOIN drivers d ON d.driver_id = g.driver_id
JOIN typical t ON t.driver_id = g.driver_id
WHERE g.gap_days >= 90          -- the threshold for "stopped for a while"
ORDER BY g.gap_days DESC;