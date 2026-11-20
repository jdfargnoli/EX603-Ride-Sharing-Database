# Finding: Trip Failures in 2023

**Failure** = a trip that ended `cancelled` or `disputed` instead of `completed`.

## Is the failure problem getting better or worse?

**Neither. It is flat, at about one trip in five.** In 2023, 44 of 200 trips failed (22%) *(Query 1)*. By quarter, the failure rate was 24.5%, 20.8%, 25.5% and then 16.7% *(Query 2)*. Q4 was the best quarter, but it represents only 8 failures, and the first and second halves of the year are nearly identical: 22.8% and 21.2%. Monthly rates swing from 0% in April to 40% in June *(Query 3)*, so with 11 to 21 trips a month, no single month signals a trend. Disputes clustered mid-year, with 8 of the 10 falling between June and September *(Query 3)*.

## What should the team do next quarter?

Most failures come from fixable causes *(Query 4)*:

- **Rider no-shows (12) and rider cancellations (8)** make up 59% of all cancellations. Add a pickup confirmation step and a modest no-show fee.
- **Payment failures (7)** can be fixed in the product. Pre-authorize payment when a trip is requested, and retry automatically if the charge fails.
- **Driver unavailable (7).** Fold this into the driver re-engagement push.
- **Disputes (10)** have no recorded reason at all *(Query 4)*. Require a reason code, so the team can see what is going wrong.

**Target:** a failure rate of 15% or less in Q1, tracked monthly against a three-month moving average so that one bad month doesn't trigger a false alarm.

## Supporting queries

```sql
-- Query 1: overall failure rate
SELECT COUNT(*) AS trips,
       COUNT(*) FILTER (WHERE trip_status <> 'completed') AS failures,
       ROUND(100.0 * COUNT(*) FILTER (WHERE trip_status <> 'completed') / COUNT(*), 1) AS failure_pct
FROM trips;                                      -- 200 | 44 | 22.0

-- Query 2: failure rate by quarter
SELECT EXTRACT(QUARTER FROM requested_at) AS qtr,
       COUNT(*) AS trips,
       COUNT(*) FILTER (WHERE trip_status <> 'completed') AS failures,
       ROUND(100.0 * COUNT(*) FILTER (WHERE trip_status <> 'completed') / COUNT(*), 1) AS failure_pct
FROM trips
GROUP BY 1 ORDER BY 1;                           -- 24.5 | 20.8 | 25.5 | 16.7

-- Query 3: monthly failure rate, change vs the prior month, and disputes
WITH m AS (
    SELECT DATE_TRUNC('month', requested_at)::date AS month_start,
           COUNT(*) AS trips,
           COUNT(*) FILTER (WHERE trip_status <> 'completed') AS failures,
           COUNT(*) FILTER (WHERE trip_status = 'disputed')   AS disputes
    FROM trips GROUP BY 1
)
SELECT to_char(month_start, 'YYYY-MM') AS month, trips, failures, disputes,
       ROUND(100.0 * failures / trips, 1) AS failure_pct,
       ROUND(100.0 * failures / trips, 1)
         - LAG(ROUND(100.0 * failures / trips, 1)) OVER (ORDER BY month_start) AS pct_point_change,
       CASE WHEN LAG(month_start) OVER (ORDER BY month_start) IS NULL THEN 'first'
            WHEN LAG(month_start) OVER (ORDER BY month_start) = month_start - INTERVAL '1 month' THEN 'ok'
            ELSE 'GAP' END AS month_check
FROM m ORDER BY month_start;                     -- Apr 0.0%, Jun 40.0%, all months 'ok'

-- Query 4: failures by status and reason
SELECT trip_status,
       COALESCE(cancellation_reason, '(no reason recorded)') AS reason,
       COUNT(*) AS trips
FROM trips
WHERE trip_status <> 'completed'
GROUP BY 1, 2 ORDER BY 3 DESC;                   -- no show 12, disputed/no reason 10, ...
```
