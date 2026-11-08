# Unit 5 Analysis — ROUTAI Ride-Sharing Database

**Schema roles:** event = `trips` · actor = `riders` · producer = `drivers` · catalog = `driver_badges` · junction = `driver_badge_awards`
**Theme:** failure state = rider no-show · frozen payout = driver bonuses · disputer = senior driver

All results below come from queries I ran in PostgreSQL against my `ex603_rideshare` database.

---

## Task 5.1

### 1. What feature or report on my platform could use the three-table join from Question 1? What information would it display?

My three-table join (`trips` → `riders` → `drivers`) would power a **Bonus Dispute Review screen**. A reviewer would use it when a senior driver disputes a bonus that was frozen because of rider no-shows. The same join could also support rider trip history, driver activity logs, and customer-support lookups.

For each trip, the screen would display the **trip ID, the rider's name (actor), the driver's name (producer), and the date and time the trip was requested**. Because `trips` is the fact table, I could also show the trip status, cancellation reason, pickup city, and fare without any extra joins. Filtered to no-shows, this gives the reviewer a timeline of evidence. In my data it shows that Rider_01 and Rider_21 each no-showed twice with different drivers, which suggests the riders, not the drivers, caused those failures.

### 2. Why is the junction table important for answering Question 2? What would make this analysis more difficult without it?

Drivers and badges have a many-to-many relationship: one driver can earn several badges, and one badge can go to many drivers. My junction table, `driver_badge_awards`, resolves this into two one-to-many links. It is the only place where a driver and a badge meet, so it is the only way to find which catalog tags my Assignment 4 producers share. Using it, I found that three of my four Five Star drivers also hold **Safe Driving**. Its composite primary key prevents duplicate awards, and its foreign keys ensure that every award references a real driver and a real badge.

Without the junction table, I would have to store badges in the `drivers` table. With a single badge column, a driver could hold only one badge, but Driver_10 holds four. Repeating columns (`badge_1`, `badge_2`, …) would break First Normal Form and make every query check several columns. A comma-separated list would need slow, error-prone string matching and couldn't be checked by a foreign key. None of these designs would have a place for the `awarded_on` date, so I would also lose the ability to analyze when badges were earned.

---

## Task 5.2

### 1. Which producers were excluded by the inner join? Report their identifiers.

My INNER JOIN returned 13 drivers and my LEFT JOIN returned 15, so **2 producers were excluded: `driver_id` 14 and `driver_id` 15**. I confirmed the same two drivers four ways: the LEFT JOIN anti-join, the FULL OUTER JOIN, `NOT EXISTS`, and `EXCEPT`.

| driver_id | driver_name | home_city | onboard_date | avg_rating | is_active |
|---|---|---|---|---|---|
| **14** | Driver_14 | Saigon | 2022-04-11 | 3.63 | true |
| **15** | Driver_15 | Hue | 2022-11-18 | 4.00 | true |

### 2. What does it mean when a producer has no events? What are some possible explanations?

**What the data shows:** Driver_14 and Driver_15 exist in `drivers` but are never referenced in `trips`. Both are marked `is_active = TRUE`, were onboarded in 2022, and have languages on file, yet neither had a trip anywhere in the period my data covers (2023-01-01 to 2023-12-28). Both also have a stored `avg_rating` despite having no trips to be rated on. Both live in the cities with the most drivers: Saigon has 5 drivers for 40 pickups and Hue has 4 for 40, compared with Danang's 1 driver for 43 pickups. Driver_14 has the lowest rating of all 15 drivers (3.63, against an average of 4.40).

**What would require further investigation:** The data shows *that* these drivers had no trips, but not *why*. My schema has no data on logins, online hours, onboarding steps, or dispatch offers, so each of these is a hypothesis, not a finding:

- They never completed onboarding, such as a vehicle inspection or background check.
- They registered but never went online.
- Their cities had too many drivers for the demand, so they weren't needed.
- The matching system passed them over, possibly because of a low starting rating.
- They left the platform, but `is_active` was never updated.
- Their trips were recorded under a different ID or lost in a data load.
- They are test or placeholder accounts.

The source of their stored ratings is also unexplained by the data.

### 3. How could a report based only on an inner join give leadership an incomplete picture of the platform?

**What the data shows:** An inner-join report lists 13 drivers instead of 15, which leaves out 13% of registered drivers without any warning. It reports **15.4 trips per driver (200 ÷ 13) instead of 13.3 (200 ÷ 15)**, and because every driver it includes has trips by definition, it shows apparent 100% utilization.

**The implication:** Leadership would overestimate productivity, never see idle capacity, and miss the onboarding and acquisition costs of drivers who produce no revenue. Any problem behind the idle drivers, whether onboarding, matching, or data quality, stays invisible, because the evidence is exactly the rows the inner join drops. The report looks complete while answering a narrower question: "How are drivers *with trips* performing?" instead of "How are *our drivers* performing?"

### 4. Why might leadership want to identify producers who have never been active?

- **Return on acquisition spending.** Each idle driver represents recruiting and onboarding costs with no return.
- **Accurate supply planning.** Recruiting, pricing, and expansion decisions should rely on drivers who are actually available, not drivers who are merely registered.
- **Fairness and retention.** If active drivers never receive trips, the matching system may be treating them unfairly. That connects to my theme: drivers who feel the platform works against them are the ones most likely to raise disputes or leave.
- **Risk and compliance.** Unused accounts that hold licence data are a security exposure and conflict with data-minimisation principles.
- **Data quality.** Ratings stored with no supporting trips raise questions about which other metrics may lack supporting data.

Whether any of these concerns actually applies to Driver_14 and Driver_15 depends on the investigation described in question 2.

### 5. What action could leadership take based on these findings?

1. **Investigate first.** Check onboarding records and app logins, and contact both drivers. This turns the hypotheses in question 2 into facts before any decision is made.
2. **Re-engage or deactivate.** Help drivers who want to drive finish onboarding or offer a first-trip incentive. Set `is_active = FALSE` for drivers who have left.
3. **Audit the matching system** for bias against new or low-rated drivers, especially in cities with more drivers than demand.
4. **Rebalance supply** by encouraging drivers in crowded cities like Saigon and Hue to serve areas with fewer drivers, such as Danang.
5. **Fix the rating rule** so `avg_rating` stays `NULL` until a driver's first rated trip.
6. **Track zero-activity drivers as a KPI** using `LEFT JOIN` or `NOT EXISTS`, and require reports about the driver base to use outer joins, so idle drivers are always counted.

---

## Task 5.3

### 1. Capture the full execution plan

EXPLAIN
SELECT t.trip_id, r.rider_name AS actor_rider, d.driver_name AS producer_driver,
       t.requested_at AS event_datetime
FROM trips   AS t
JOIN riders  AS r ON r.rider_id  = t.rider_id
JOIN drivers AS d ON d.driver_id = t.driver_id
ORDER BY trip_id;
Sort  (cost=4.14..4.19 rows=20 width=29)
  Sort Key: t.trip_id
  ->  Hash Join  (cost=2.34..3.71 rows=20 width=29)
        Hash Cond: (t.driver_id = d.driver_id)
        ->  Hash Join  (cost=1.23..2.50 rows=20 width=24)
              Hash Cond: (t.rider_id = r.rider_id)
              ->  Seq Scan on trips t  (cost=0.00..1.20 rows=20 width=20)
              ->  Hash  (cost=1.10..1.10 rows=10 width=12)
                    ->  Seq Scan on riders r  (cost=0.00..1.10 rows=10 width=12)
        ->  Hash  (cost=1.05..1.05 rows=5 width=13)
              ->  Seq Scan on drivers d  (cost=0.00..1.05 rows=5 width=13)

### 2. Identify the join algorithm or algorithms used

The plan uses two Hash Joins: trips ⋈ riders on rider_id, then that result ⋈ drivers on driver_id. A Sort node handles ORDER BY, and all three tables are read with sequential scans. No Nested Loop or Merge Join is used at this size.

### 3. Explain why PostgreSQL may have selected these algorithms, considering table sizes and available indexes

The tables are very small. Each fits in one disk page, so reading the whole table is cheaper than using the primary-key indexes, which would mean reading the index and then the table.
Every row must be joined. With no WHERE filter, building a small in-memory hash of riders and of drivers and checking each trip against it once is the cheapest approach. PostgreSQL hashes the smaller table and streams the larger one, trips, through it.
Merge Join wasn’t chosen because it requires both inputs sorted on the join key, and sorting trips by rider_id and again by driver_id would cost more than hashing.
Indexes are available but unused. The primary keys are indexed automatically, but at this size the planner estimates them as more expensive. The foreign-key columns trips.rider_id and trips.driver_id have no indexes, because PostgreSQL doesn’t create them automatically.

### 4. Predict which part of the query might become less efficient as the dataset grows

The Sort for ORDER BY trip_id. It’s already the most expensive node. With millions of rows it can exceed memory (work_mem) and spill to disk.
The full scan of trips. Without a WHERE clause, every trip is processed every time, so the cost grows in direct proportion to the table’s size.
The hash tables. If riders or drivers grows too large for memory, the Hash Joins must split their work into batches on disk.

To test this, I scaled the tables to 1 million trips. PostgreSQL switched to Nested Loops with Index Scans and Memoize. It read trips in trip_id order through trips_pkey, which eliminated the Sort, and cached the rider and driver lookups. Execution time rose from 0.05 ms to about 676 ms. The plan adapts, but the cost of reading every trip remains.

---

## Reflection

In Task 5.3, PostgreSQL joined my three tables using two hash joins. That made sense: every table was small enough to fit in memory, and the query needed every trip. Several changes to my data or schema could lead PostgreSQL to choose a different algorithm.

The biggest factor is **table size**. If `trips` grew to millions of rows, scanning and sorting the whole table on every run would become slow. If `riders` grew too large to hash in memory, PostgreSQL might process the join from disk in several rounds or switch to a **merge join** that works through both tables in sorted order.

**Indexes** matter as well. My schema has no indexes on `trips.driver_id` or `trips.rider_id`. If I added them and filtered the query to a single driver, as my Bonus Dispute screen would, PostgreSQL would likely use a **nested loop**. That looks up only the matching rows instead of reading every trip, which would be much faster at large volumes.

This connects to the **number of matching records**. Hash joins work well when most rows take part in the join, and nested loops work well when only a few do.

Finally, I learned that **statistics** matter. Before I ran `ANALYZE`, PostgreSQL guessed there were 100 riders instead of 30 and chose a nested loop. The planner bases its choice on its estimates, not the true row counts, so keeping statistics current is part of keeping queries fast.
