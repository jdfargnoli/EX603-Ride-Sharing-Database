-- =====================================================================
-- Task 6.3: Build the reporting patterns
-- Part A: Top N per category
-- =====================================================================
-- TOP 3 TRIPS BY FARE FOR EACH DRIVER,
-- ORDERED BY EACH DRIVER'S TOTAL REVENUE FOR THE YEAR
-- =====================================================================

-- STEP 1: ranked
-- Rank each driver's completed trips by fare, highest first.
-- TIE HANDLING AT THIRD PLACE: RANK() gives tied trips the same rank,
-- so a tie at 3rd keeps BOTH trips (that driver returns 4 rows).
-- Equal fares deserve equal places; dropping one would be arbitrary.
-- Use ROW_NUMBER() with a tiebreaker if exactly 3 rows are required.
WITH ranked AS (
    SELECT t.driver_id,
           t.trip_id,
           t.requested_at,
           t.pickup_city,
           t.fare_amount,
           RANK() OVER (PARTITION BY t.driver_id
                        ORDER BY t.fare_amount DESC) AS fare_rank,

           -- YEAR TOTAL: all of the driver's completed fares for the year.
           -- No ORDER BY in this window, so it covers every one of the
           -- driver's trips. It's calculated HERE, before the top-3
           -- filter, so it counts every trip, not just the top three.
           SUM(t.fare_amount) OVER (PARTITION BY t.driver_id) AS year_total,

           -- FIRST_VALUE: the driver's single best fare
           FIRST_VALUE(t.fare_amount) OVER (PARTITION BY t.driver_id
                                            ORDER BY t.fare_amount DESC) AS best_fare,

           -- LAST_VALUE: the driver's lowest fare. The explicit frame is
           -- required; the default frame stops at the current row.
           LAST_VALUE(t.fare_amount) OVER (PARTITION BY t.driver_id
                                           ORDER BY t.fare_amount DESC
                                           ROWS BETWEEN UNBOUNDED PRECEDING
                                                    AND UNBOUNDED FOLLOWING) AS lowest_fare
    FROM trips t
    WHERE t.trip_status = 'completed'
),

-- STEP 2: top3
-- Keep only each driver's top 3 trips, and rank the drivers by
-- their year total. DENSE_RANK gives drivers with equal totals the
-- same place. Ranking here, after the filter, is safe because every
-- row of a driver carries the same year_total.
top3 AS (
    SELECT r.*,
           DENSE_RANK() OVER (ORDER BY r.year_total DESC) AS driver_rank
    FROM ranked r
    WHERE r.fare_rank <= 3
)

-- STEP 3: output, highest-earning driver for the year first
SELECT t.driver_rank,
       t.driver_id,
       d.driver_name,
       t.year_total,
       t.fare_rank,
       t.trip_id,
       t.requested_at,
       t.pickup_city,
       t.fare_amount,
       t.best_fare,
       ROUND(100.0 * t.fare_amount / t.best_fare, 1) AS pct_of_best,
       t.lowest_fare
FROM top3 t
JOIN drivers d ON d.driver_id = t.driver_id
ORDER BY t.driver_rank,     -- biggest year total first
         t.driver_id,       -- tiebreaker if two drivers share a total
         t.fare_rank;       -- each driver's trips in rank order

-- =====================================================================
-- Task 6.3: Build the reporting patterns
-- Part B: Period over period
-- =====================================================================
-- MONTH-OVER-MONTH PLATFORM PERFORMANCE (completed trips)
-- For each month: trips, revenue, change vs the previous month,
-- percent change, and a check that the previous row really is
-- the previous calendar month.
-- =====================================================================

-- STEP 1: monthly
-- Group completed trips into calendar months.
-- DATE_TRUNC('month', ...) snaps each trip to the 1st of its month.
-- Only months that HAVE trips appear here, which is exactly why the
-- missing-month check below is needed.
WITH monthly AS (
    SELECT DATE_TRUNC('month', requested_at)::date AS month_start,
           COUNT(*)         AS trips,
           SUM(fare_amount) AS revenue
    FROM trips
    WHERE trip_status = 'completed'
    GROUP BY DATE_TRUNC('month', requested_at)::date
),

-- STEP 2: compared
-- LAG looks back one ROW in month order. It doesn't know about the
-- calendar, so we also grab the previous row's month to verify it.
compared AS (
    SELECT month_start,
           trips,
           revenue,
           LAG(month_start) OVER (ORDER BY month_start) AS prev_month_start,
           LAG(revenue)     OVER (ORDER BY month_start) AS prev_revenue,
           LAG(trips)       OVER (ORDER BY month_start) AS prev_trips
    FROM monthly
)

-- STEP 3: output
SELECT to_char(month_start, 'YYYY-MM') AS month,
       trips,
       revenue,
       prev_revenue,
       revenue - prev_revenue AS revenue_change,

       -- PERCENT CHANGE: NULLIF turns a previous revenue of 0 into NULL,
       -- so the division returns NULL instead of crashing with
       -- "division by zero".
       ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 1) AS revenue_pct_change,

       trips - prev_trips AS trips_change,

       -- MISSING-MONTH CHECK: the previous row should be exactly one
       -- month earlier. If it isn't, months were skipped and the
       -- comparison above is NOT a true month-over-month change.
       CASE WHEN prev_month_start IS NULL THEN 'first month'
            WHEN prev_month_start = month_start - interval '1 month' THEN 'ok'
            ELSE 'GAP: previous row is ' || to_char(prev_month_start, 'YYYY-MM')
       END AS month_check,

       -- Plain-word verdict for leadership
       CASE WHEN prev_revenue IS NULL THEN 'n/a'
            WHEN revenue > prev_revenue THEN 'better'
            WHEN revenue < prev_revenue THEN 'worse'
            ELSE 'flat'
       END AS verdict
FROM compared
ORDER BY month_start;
