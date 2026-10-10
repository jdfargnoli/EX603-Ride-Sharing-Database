-- Task 3.2 Find the bug
-- 3.2.1 Pick a nullable column on your event or producer table. If the dataset has no NULLs in it, insert a few deliberately and say that you did.
SELECT cancellation_reason
FROM trips
WHERE cancellation_reason != 'Rider no show';
-- notice that the WHERE skipped the NULLS (22 items)

SELECT cancellation_reason
FROM trips
WHERE cancellation_reason = 'NULL';
-- doesn't return anything

SELECT COUNT(*) AS total_trips
FROM trips;
-- this is the total number of trips (200)

SELECT COUNT(*) AS null_count
FROM trips
WHERE cancellation_reason IS NULL;
-- Count number of Nulls (166)

SELECT COUNT(*) AS rider_no_show_count
FROM trips
WHERE cancellation_reason = 'Rider no show';
-- 12 Rider no show
-- 12 are Ruder nwo show , 22 are other reasons that are not Rider no show = 34 - there are 200 total rides so 166 did not show up
-- 12 + 22 + 166 = 200

-- 3.2.3 Write a second query counting the rows the first one silently omitted, and show that the two counts do not sum to
-- the table total.
SELECT COUNT(*) AS no_show_or_null_count
FROM trips
WHERE LOWER(cancellation_reason) = 'rider no show'
   OR cancellation_reason IS NULL;
-- 178 were Rider ho show or NULL
-- 12 Rider no show + 166 NULL = 178

--3.2.4 Repair the first query using an explicit IS NULL condition or COALESCE, so it returns what you intended
    SELECT COUNT(*) AS no_show_or_null_count
FROM trips
WHERE LOWER(cancellation_reason) != 'rider no show'
   OR cancellation_reason IS NULL;
-- 178 were Rider ho show or NULL
-- 22 are NOT Rider no show + 166 NULL = 188
-- This is what I actually would have expected to see if I ran my first query adn knew that there were 200 entries

-- If I search for the number of cancellation_reasons that are not "Rider no show" I get 22
-- If I search for the number of cancellation_reasons that are "Rider no show" I get 12
-- When I search for the total number of entries I get 200
-- Leaves one to ask where are the remaining (200 - 12 - 22) = 166 entries?
-- I can not identify where all of teh entries are
-- I should have gotten 166 + 22 rows for cancellation_reason != "Rider no show"