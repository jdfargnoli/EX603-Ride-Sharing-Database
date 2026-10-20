# Task 4.2 Part A
SELECT
    driver_id                                                        AS producer_id,
    COUNT(*)                                                         AS total_events,
    SUM(CASE WHEN trip_status IN ('cancelled', 'disputed')
             THEN 1 ELSE 0 END)                                      AS failure_events,
    ROUND(100.0 * SUM(CASE WHEN trip_status IN ('cancelled', 'disputed')
                           THEN 1 ELSE 0 END) / COUNT(*), 1)         AS failure_pct
FROM trips
GROUP BY driver_id
ORDER BY failure_pct DESC, total_events DESC, driver_id;

# Task 4.2 Part B
WITH trips_by_region AS (
    SELECT
        CASE
            WHEN pickup_city IN ('Hanoi', 'Haiphong')       THEN 'North'
            WHEN pickup_city IN ('Hue', 'Danang', 'Saigon') THEN 'South'
            ELSE 'Unassigned'
        END AS region,
        trip_status,
        fare_amount
    FROM trips
)
SELECT
    CASE WHEN GROUPING(region) = 1 THEN 'PLATFORM TOTAL'
         ELSE region END                                              AS region,
    CASE WHEN GROUPING(region) = 1 THEN 'Grand total'
         ELSE 'Regional subtotal' END                                 AS row_type,
    COUNT(*)                                                          AS total_events,
    SUM(CASE WHEN trip_status IN ('cancelled','disputed')
             THEN 1 ELSE 0 END)                                       AS failure_events,
    ROUND(100.0 * SUM(CASE WHEN trip_status IN ('cancelled','disputed')
                           THEN 1 ELSE 0 END) / COUNT(*), 1)          AS failure_pct,
    SUM(fare_amount)                                                  AS total_fare,
    ROUND(AVG(CASE WHEN trip_status = 'completed'
                   THEN fare_amount END), 2)                          AS avg_completed_fare
FROM trips_by_region
GROUP BY ROLLUP (region)
ORDER BY GROUPING(region), region;

# $ask 4.2 Part C
WITH producer_summary AS (            -- Step 1: one row per producer
    SELECT
        driver_id,
        COUNT(*)                                                     AS total_events,
        SUM(CASE WHEN trip_status IN ('cancelled','disputed')
                 THEN 1 ELSE 0 END)                                  AS failure_events,
        SUM(CASE WHEN trip_status = 'completed'
                 THEN fare_amount ELSE 0 END)                        AS completed_fare,
        SUM(CASE WHEN trip_status = 'completed'
                 THEN 1 ELSE 0 END)                                  AS completed_events
    FROM trips
    GROUP BY driver_id
)
SELECT                                 -- Step 2: filter + second aggregation
    COUNT(*)                                                         AS high_volume_producers,
    SUM(total_events)                                                AS events_covered,
    ROUND(AVG(total_events), 1)                                      AS avg_events_per_producer,
    ROUND(AVG(100.0 * failure_events / total_events), 1)             AS avg_failure_pct,
    ROUND(100.0 * SUM(failure_events) / SUM(total_events), 1)        AS pooled_failure_pct,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP
           (ORDER BY 100.0 * failure_events / total_events))::numeric, 1) AS median_failure_pct,
    ROUND(SUM(completed_fare) / NULLIF(SUM(completed_events), 0), 2) AS baseline_avg_fare
FROM producer_summary
WHERE total_events >= 12;              -- high-volume threshold (match your Q3 choice)