-- 3.1.1 Find active, highly rated producers
SELECT driver_id, driver_name, avg_rating
FROM  drivers
WHERE is_active = TRUE
AND avg_rating >= 4.5
ORDER BY avg_rating DESC
LIMIT 10;

-- 3.1.2 Find all possible event statuses
SELECT DISTINCT trip_status
FROM  trips;
-- There are not more than I expected

-- 3.1.3 Filter the events in two different ways
SELECT *
FROM trips
WHERE distance_km >10;

SELECT *
FROM trips
WHERE pickup_city IN ('Saigon','Hanoi');

-- 3.1.4  Find users whose names match a text pattern
SELECT driver_name
FROM drivers
WHERE driver_name LIKE 'Driver%';

SELECT trip_id, COALESCE(cancellation_reason, 'No reason provided') AS cancellation_reason
FROM trips
WHERE cancellation_reason IS NULL;

-- 3.1.5 Create query with calcualted/computed column

SELECT fare_amount,
       distance_km,
       ROUND(fare_amount / NULLIF(distance_km, 0), 2) AS fare_per_km,
       CASE
           WHEN distance_km IS NULL OR distance_km = 0 THEN 'Unknown'
           WHEN fare_amount / distance_km < 1.50 THEN 'Cheap'
           WHEN fare_amount / distance_km > 2.50 THEN 'Expensive'
           ELSE 'Average'
       END AS evaluation
FROM trips;
