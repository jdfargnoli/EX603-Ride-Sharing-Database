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

**Query reviewed:** the three-table join from Task 5.1, Question 1, which answers "Who are the people behind the events?"

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.trip_id,
       r.rider_name   AS actor_rider,
       d.driver_name  AS producer_driver,
       t.requested_at AS event_datetime
FROM trips t
JOIN riders  r ON r.rider_id  = t.rider_id
JOIN drivers d ON d.driver_id = t.driver_id
ORDER BY t.trip_id;
```

`EXPLAIN ANALYZE` actually runs the query. That is safe here because the query is a read-only `SELECT`. I would not use it on `INSERT`, `UPDATE`, or `DELETE` statements outside a transaction that I roll back.

### 1. Capture the full execution plan

**Answer:** This is the full plan from PostgreSQL 16, captured after running `ANALYZE` to refresh the table statistics:

```
Sort  (cost=16.93..17.43 rows=200 width=35) (actual time=0.137..0.146 rows=200 loops=1)
  Sort Key: t.trip_id
  Sort Method: quicksort  Memory: 37kB
  Buffers: shared hit=1 read=4
  ->  Hash Join  (cost=3.01..9.29 rows=200 width=35) (actual time=0.044..0.106 rows=200 loops=1)
        Hash Cond: (t.driver_id = d.driver_id)
        Buffers: shared hit=1 read=4
        ->  Hash Join  (cost=1.68..7.28 rows=200 width=29) (actual time=0.026..0.068 rows=200 loops=1)
              Hash Cond: (t.rider_id = r.rider_id)
              Buffers: shared read=4
              ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=24) (actual time=0.008..0.025 rows=200 loops=1)
                    Buffers: shared read=3
              ->  Hash  (cost=1.30..1.30 rows=30 width=13) (actual time=0.013..0.014 rows=30 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 10kB
                    Buffers: shared read=1
                    ->  Seq Scan on riders r  (cost=0.00..1.30 rows=30 width=13) (actual time=0.007..0.009 rows=30 loops=1)
                          Buffers: shared read=1
        ->  Hash  (cost=1.15..1.15 rows=15 width=14) (actual time=0.012..0.012 rows=15 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on drivers d  (cost=0.00..1.15 rows=15 width=14) (actual time=0.006..0.007 rows=15 loops=1)
                    Buffers: shared hit=1
Planning Time: 0.286 ms
Execution Time: 0.174 ms
```

Reading from the bottom up, PostgreSQL does the following:

1. Reads all 30 riders and builds a hash table from them.
2. Scans all 200 trips and probes that hash table to attach each rider.
3. Reads all 15 drivers into a second hash table.
4. Probes the second hash table to attach each driver.
5. Sorts the 200 results by `trip_id` in memory.

The estimated row counts match the actual counts at every step (200, 30, 15), so the planner's statistics were accurate.

### 2. Identify the join algorithm or algorithms used

**Answer:** **Two Hash Joins.** The first joins `trips` to `riders` on `rider_id`, and the second joins that result to `drivers` on `driver_id`. All three tables are read with **Sequential Scans**, and the final ordering uses an in-memory **quicksort**. No Nested Loop or Merge Join appears in this plan.

**A note on what I observed.** Before I ran `ANALYZE`, the same query produced a different plan. PostgreSQL guessed 100 riders instead of 30 and chose a **Hash Join** for riders plus a **Nested Loop** with Memoize and an **Index Scan on `drivers_pkey`** for drivers. Join algorithms depend on the statistics the planner has, so a plan captured in another environment may differ from mine.

### 3. Explain why PostgreSQL may have selected these algorithms, considering table sizes and available indexes

**Answer:**

- **The tables are tiny.** `trips` occupies 3 pages (200 rows), and `riders` and `drivers` occupy 1 page each (30 and 15 rows). Reading a whole one-page table sequentially is cheaper than walking an index, so Seq Scans win.
- **Every trip needs a match.** The query has no `WHERE` clause, so all 200 trips must be joined. A Hash Join reads the small table once into memory (10 kB and 9 kB here) and then matches each trip in one pass, which is the cheapest approach when most rows on both sides take part.
- **The available indexes don't help this query.** The only indexes are primary keys and unique constraints: `trips_pkey`, `riders_pkey`, `drivers_pkey`, and the email and licence unique indexes. There is **no index on `trips.rider_id` or `trips.driver_id`**, because PostgreSQL does not automatically index foreign-key columns. The primary-key indexes on `riders` and `drivers` could support a Nested Loop, and the planner used one when its estimates were wrong, but with accurate statistics, hashing the whole small table was cheaper than 200 separate index lookups.
- **Merge Join wasn't chosen** because it needs both inputs sorted on the join key. `trips` isn't stored in `rider_id` or `driver_id` order, so sorting it first would cost more than hashing.

### 4. Predict which part of the query might become less efficient as the dataset grows

**Answer:** My prediction is that the **Sequential Scan on `trips`** and the **final Sort** would degrade first, followed by the hash tables if `riders` grows very large.

- **The Seq Scan on `trips` grows in direct proportion to the data.** `trips` is the high-volume fact table. At millions of trips, every run reads the whole table. This matters most for the Bonus Dispute screen, which filters to one driver: without an index on `trips.driver_id`, PostgreSQL would still scan every trip to find that driver's few no-shows.
- **The Sort grows faster than the data.** Sorting costs roughly n log n. Once the result no longer fits in `work_mem` (4 MB by default), PostgreSQL switches from an in-memory quicksort to an external merge sort that writes to disk.
- **The hash tables can spill to disk.** If `riders` grows into the millions, its hash table may exceed `work_mem`. The plan would then show `Batches` greater than 1, meaning parts of the join are processed in rounds from disk.
- **I expect the join algorithms to change.** With larger tables and selective filters, PostgreSQL may switch to Nested Loops with index lookups, or to Merge Joins.

**What I would test:** I would add indexes on the foreign-key columns, then rerun `EXPLAIN ANALYZE` on a larger dataset to measure whether they help:

```sql
CREATE INDEX idx_trips_driver_id ON trips (driver_id);
CREATE INDEX idx_trips_rider_id  ON trips (rider_id);
```

At 200 rows the planner would probably ignore them. Their value would only show up at larger volumes or in filtered queries, so I would treat this as a prediction to verify, not a proven result.

---

## Task 5.4: Recommendations

My analysis found two groups of drivers who need attention, but they have very different problems. The first group works but keeps running into failed trips. The second group never got started at all. Treating them the same way would be a mistake, so I recommend a separate action for each.

### Group 1: Drivers who fail often — Driver_02 and Driver_03

**What I found:** Across the platform, about 6% of trips end with the rider not showing up. Driver_02 had 3 rider no-shows in 16 trips (about 19%), and Driver_03 had 2 in 13 trips (about 15%). That's roughly three times the platform average. Driver_04's rate looks similar, but it comes from a single no-show in only 6 trips, which is too few to draw a conclusion.

The important detail is *who* failed. In all five of these no-shows, it was the **rider** who didn't appear, and they were five different riders. Two of those riders, Rider_01 and Rider_21, also failed to show up for other drivers. On the evidence I have, these drivers are not unreliable. They are on the receiving end of unreliable riders.

**My recommendation: protect these drivers instead of penalizing them.** Before any driver bonus is frozen because of no-shows, a person should review the trips. Rider no-shows should not count against the driver, and any bonus frozen for that reason should be released. At the same time, the platform should deal with the real cause by warning, or charging a fee to, riders who repeatedly fail to show up.

**What I can't tell from the data:** My data doesn't record how long the driver waited or whether they were at the right pickup spot, so I can't rule out a driver-side cause. A reviewer should check this before releasing a bonus. Driver_03 is also already marked inactive. It would be worth finding out whether frozen bonuses played a part in that driver leaving.

### Group 2: Drivers who never started — Driver_14 and Driver_15

**What I found:** Both drivers are listed as active and joined in 2022, but neither completed a single trip during the whole year of data. There is nothing in their records to judge them on, good or bad.

**My recommendation: contact them, then either activate them or close their accounts.** The first step is a simple phone call or message to find out what happened. They might have an unfinished onboarding step, be unsure how to start, or no longer be interested. Drivers who want to drive should get help finishing setup and a small first-trip incentive, ideally pointing them toward areas that need more drivers. Accounts that don't respond within a set period, such as 30 days, should be closed, and their personal information handled according to the company's data policy. I would also remove the ratings stored for these drivers, since they have never had a trip to be rated on.

### Why the two responses differ

The first group has a **fairness problem**: they are doing the work, and the failures mostly come from riders, so the right response is to protect their pay and fix rider behavior. The second group has an **activation problem**: no work has happened at all, so the right response is to find out why and either get them started or close the account. Applying a bonus penalty to Group 2 would have no effect, and treating Group 1 as inactive would punish people who are actually driving.

---

## Reflection

In Task 5.3, PostgreSQL joined my three tables with two hash joins. That choice made sense because every table was small enough to fit in memory and the query needed every trip. Several changes to my data or schema could lead it to choose differently.

The biggest factor is **table size**. If `trips` grew to millions of rows, the full scan and the sort would get much slower. If `riders` became too large to hash in memory, PostgreSQL might process the join from disk in several rounds or switch to a **merge join** on sorted inputs.

**Indexes** matter as well. My schema has no indexes on `trips.driver_id` or `trips.rider_id`. If I added them and filtered the query to one driver, as my Bonus Dispute screen would, PostgreSQL would likely use a **nested loop** that looks up only the matching rows instead of scanning everything.

That connects to the **number of matching records**. Hash joins work well when most rows take part, while nested loops work well when only a few do.

Finally, I saw that **statistics** matter. Before I ran `ANALYZE`, PostgreSQL guessed the wrong number of riders and chose a nested loop. That showed me the planner makes its choice from its estimates, not the true row counts, so keeping statistics current is part of getting good performance.

---

## References

1. PostgreSQL Global Development Group. *PostgreSQL Documentation*, §14.1 "Using EXPLAIN." https://www.postgresql.org/docs/current/using-explain.html
2. PostgreSQL Global Development Group. *PostgreSQL Documentation*, §51.5 "Planner/Optimizer" (nested loop, merge join, and hash join strategies). https://www.postgresql.org/docs/current/planner-optimizer.html
3. PostgreSQL Global Development Group. *PostgreSQL Documentation*, `ANALYZE` and §14.2 "Statistics Used by the Planner." https://www.postgresql.org/docs/current/planner-stats.html
4. PostgreSQL Global Development Group. *PostgreSQL Documentation*, §20.4.1 "Memory" (`work_mem`). https://www.postgresql.org/docs/current/runtime-config-resource.html
5. PostgreSQL Global Development Group. *PostgreSQL Documentation*, §7.2.1.1 "Joined Tables" and §9.24 "Subquery Expressions." https://www.postgresql.org/docs/current/queries-table-expressions.html
6. Elmasri, R. & Navathe, S. B. *Fundamentals of Database Systems*, 7th ed. Pearson, 2016. Query processing and join algorithms; ER-to-relational mapping of M:N relationships.
7. Kimball, R. & Ross, M. *The Data Warehouse Toolkit*, 3rd ed. Wiley, 2013. Fact tables, dimensions, and bridge tables.
