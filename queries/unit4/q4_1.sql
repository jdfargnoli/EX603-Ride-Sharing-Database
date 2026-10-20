# Task 4.1 Question #1
SELECT
    COUNT(*)                    AS total_trips,
    SUM(fare_amount)            AS total_fare,
    ROUND(AVG(fare_amount), 2)  AS avg_fare,
    MIN(fare_amount)            AS min_fare,
    MAX(fare_amount)            AS max_fare,
    COUNT(DISTINCT rider_id) AS DistinctRiders
FROM trips;

# Task 4.1 Question #2
SELECT
    driver_id                   AS producer_id,
    COUNT(*)                    AS event_count,
    ROUND(AVG(fare_amount), 2)  AS avg_metric
FROM trips
GROUP BY driver_id
ORDER BY event_count DESC, driver_id;

#  Task 4.1 Question #3
# This approach sets the threshols as the median
SELECT
    driver_id                   AS producer_id,
    COUNT(*)                    AS event_count,
    ROUND(AVG(fare_amount), 2)  AS avg_metric
FROM trips
GROUP BY driver_id
HAVING COUNT(*) >= (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cnt)
    FROM (SELECT COUNT(*) AS cnt FROM trips GROUP BY driver_id) AS c
)
ORDER BY event_count DESC, driver_id;

# This approach chooses a threshold of the number of trips - I have chosen 12
SELECT
    driver_id                   AS producer_id,
    COUNT(*)                    AS event_count,
    ROUND(AVG(fare_amount), 2)  AS avg_metric
FROM trips
GROUP BY driver_id
HAVING COUNT(*) >= 12
ORDER BY event_count DESC, driver_id;


# Task 4.1 Question #4
SELECT
    CASE
        WHEN pickup_city IN ('Hanoi', 'Haiphong')       THEN 'North'
        WHEN pickup_city IN ('Hue', 'Danang', 'Saigon') THEN 'South'
        ELSE 'Unassigned'
    END                          AS region,
    COUNT(*)                     AS event_count,
    ROUND(AVG(fare_amount), 2)   AS avg_fare
FROM trips
GROUP BY region
ORDER BY event_count DESC;