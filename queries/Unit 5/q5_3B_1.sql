5_3_B_1  Examine a Query Execution Plan
EXPLAIN
SELECT t.trip_id, r.rider_name AS actor_rider, d.driver_name AS producer_driver,
       t.requested_at AS event_datetime
FROM trips   AS t
JOIN riders  AS r ON r.rider_id  = t.rider_id
JOIN drivers AS d ON d.driver_id = t.driver_id
ORDER BY trip_id;
