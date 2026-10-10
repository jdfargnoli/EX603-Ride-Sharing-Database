-- Task 3.3
-- 1 First as a subquery using IN or NOT IN.
SELECT DISTINCT rider_id
FROM trips
WHERE rider_id IN (
    SELECT rider_id FROM trips WHERE trip_status = 'disputed'
);

-- 2 Then as a Common Table Expression using WITH.
WITH disputed_riders AS (
    SELECT DISTINCT rider_id
    FROM trips
    WHERE trip_status = 'disputed'
)
SELECT rider_id
FROM disputed_riders
ORDER BY rider_id;

-- 3  Now try a third way, distinct from both — a different subquery form, a CASE-based construction, or a set-based approach.
SELECT rider_id,
       SUM(CASE WHEN trip_status = 'disputed' THEN 1 ELSE 0 END) AS disputed_trips
FROM trips
WHERE rider_id IS NOT NULL
GROUP BY rider_id
HAVING SUM(CASE WHEN trip_status = 'disputed' THEN 1 ELSE 0 END) > 0;





