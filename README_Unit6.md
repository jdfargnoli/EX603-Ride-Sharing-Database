# EX603 Ride-Sharing Database: Unit 6 Window Functions

A PostgreSQL model of a ride-sharing platform, analyzed with SQL window functions to answer the founder's question: **is the platform getting better or worse, and which drivers are carrying it?**

**Author:** Joseph D. Fargnoli

---

## Data model

The database `ex603_rideshare` has six tables and 298 rows, covering activity in 2023.

| Table | Rows | Role |
| --- | --- | --- |
| `riders` | 30 | Customers; `referred_by` is a self-referencing foreign key |
| `drivers` | 15 | **Producers**: the people who generate events |
| `driver_languages` | 23 | Languages each driver speaks (resolves a multivalued attribute) |
| `driver_badges` | 5 | Catalog of badge types |
| `driver_badge_awards` | 25 | Junction table linking drivers to the badges they earned |
| `trips` | 200 | **Events**: 156 completed, 34 cancelled, 10 disputed |

The main **metric** is `fare_amount`. Unless noted otherwise, revenue analyses use completed trips only.

## How to run

1. Create the database: `CREATE DATABASE ex603_rideshare;`
2. Run `rideshare.sql` against it (for example, in DataGrip: right-click the data source, then **SQL Scripts → Run SQL Script**). It drops and recreates every table, so it is safe to re-run.
3. Verify the load: you should see riders 30, drivers 15, driver_languages 23, driver_badges 5, driver_badge_awards 25, and trips 200.
4. Open any query file and run it. Every file is commented.

Tested on PostgreSQL 19 with DataGrip.

---

## Repository contents

> Rename the entries below to match your actual file names before committing.

| File | Task | What it does |
| --- | --- | --- |
| `rideshare.sql` | Setup | Creates the six tables and loads the sample data |
| `sql/6_1_1_event_vs_producer_avg.sql` | 6.1 #1 | Each trip next to its driver's average fare (`AVG OVER (PARTITION BY)`), plus the `GROUP BY` version for comparison |
| `sql/6_1_2_rank_three_ways.sql` | 6.1 #2 | Year-end revenue, trips and badges per driver, each ranked with `ROW_NUMBER`, `RANK` and `DENSE_RANK` side by side |
| `sql/6_1_3_ntile_bands.sql` | 6.1 #3 | Splits drivers into four bands by trip count with `NTILE(4)` |
| `sql/6_2a_row_to_row.sql` | 6.2 A | Previous and next fare per trip (`LAG`/`LEAD`) with a delta column, filtered to Driver_04 |
| `sql/6_2b_running_total_moving_avg.sql` | 6.2 B | Monthly platform revenue with a running total, a three-month moving average, and progress against a $3,600 target |
| `sql/6_2c_activity_gaps.sql` | 6.2 C | Finds gaps of 90+ days between a driver's consecutive trips (`LAG` in a CTE, filtered in the outer query) |
| `sql/6_3a_top3_per_driver.sql` | 6.3 A | Each driver's top three trips by fare (`RANK`, `FIRST_VALUE`, `LAST_VALUE`), ordered by annual revenue |
| `sql/6_3b_month_over_month.sql` | 6.3 B | Monthly revenue compared with the prior month (`DATE_TRUNC`, `LAG`, `NULLIF`, missing-month check) |
| `sql/badge_progression_quarterly.sql` | Extra | Cumulative badges per driver by quarter, with a trend label (`LAG`/`LEAD`) and a "Superstar" flag |
| `sql/driver_quarterly_metrics.sql` | Extra | Revenue, trips and badges per driver per quarter, with deltas and trends, and the top producer flagged |
| `sql/top_producer_monthly.sql` | Extra | The top-earning driver's monthly revenue, cumulative revenue, delta and up/down direction |
| `sql/failure_analysis.sql` | Finding | The four queries behind the trip-failure finding |
| `analysis/unit6.md` | Write-up | Answers to the Task 6.1–6.3 questions, plus the reflection |
| `analysis/unit6-finding.md` | Finding | The leadership finding on trip failures |

---

## Summary of results by task

### Task 6.1: Compute across a window without collapsing

- **Event vs. producer average:** the window version returns **156 rows** (every completed trip); `GROUP BY` returns **13** (one per driver). The averages are identical, but `GROUP BY` loses the individual trips, so it can't show which ones are unusual. **9 trips** are at least double their driver's average. The top one is Driver_08's $59.14 trip, at 2.48 times their average.
- **Ranking three ways:** the functions differ only on ties. Revenue has no ties. Drivers 8 and 10 tie at 19 trips (`ROW_NUMBER` 1 and 2, `RANK` 1 and 1, then 3, `DENSE_RANK` 1 and 1, then 2). Six drivers tie at two badges (`RANK` 4th, `DENSE_RANK` 3rd).
- **NTILE bands:** 15 drivers split into bands of 4, 4, 4 and 3, by position, not value. Drivers 7 and 12 tie at 14 trips, but the band boundary separates them.
- **Recommended leaderboard function:** `RANK`, because tied drivers share a place and the skipped number honestly shows how many drivers are ahead.

### Task 6.2: Compare each row to its neighbors

- **Row to row:** Driver_04's fares run $8.95 → $14.34 → $70.86 → $22.77 (deltas +$5.39, +$56.52, −$48.09). The spike was a long trip at the maximum 2.0× surge, not a change in driver performance.
- **Running total and moving average:** against a **$3,600** annual target, revenue reached **$3,418.75 (95%)**. It was ahead of pace only in February and furthest behind in August (about $173). The three-month moving average peaked at **$340.26** in October and ended at **$278.28**, below the $300 monthly pace. A full twelve-month calendar is generated first, because `ROWS` counts rows, not months.
- **ROWS vs. RANGE:** `ROWS` adds tied `ORDER BY` values one row at a time, while `RANGE` adds them as a group. Each month appears once here, so both give the same result.
- **Activity gaps:** Driver_09 had a **112-day** gap (January 5 to April 28), about seven times their usual gap. 61 trips from 11 other drivers were recorded during that time, so it wasn't a platform outage, but the data can't tell whether the driver left or a driver-specific recording problem occurred.

### Task 6.3: Build the reporting patterns

- **Top N per driver:** 39 rows (three per driver for 13 drivers), with no ties at third place. Ties would be kept by `RANK`. `LAST_VALUE` uses an explicit `UNBOUNDED` frame. The top annual earner is Driver_08 ($452.56). Driver_10's top three are all within a dollar of each other, while Driver_04's are dominated by one surge trip.
- **Month over month:** every month passes the missing-month check. Revenue improved in **8 months** and declined in **3** (March −70%, June, November −48%), with large swings because each month has only 8 to 17 completed trips.

---

## Key findings

1. **The platform finished 2023 at 95% of target.** Revenue was $3,418.75 against $3,600. The shortfall, $181.25, is only about **nine completed trips** at the average fare of $21.92.
2. **Revenue is volatile and concentrated.** Monthly changes of 50% or more are common at this volume. The top three drivers (Driver_08, Driver_10, Driver_06) produced about 36% of revenue, and two drivers recorded no trips.
3. **The trip-failure problem is flat, not improving.** **44 of 200 trips (22%) failed.** Quarterly failure rates were 24.5%, 20.8%, 25.5% and 16.7%, and the two halves of the year were nearly identical (22.8% vs. 21.2%). Q4's improvement rests on only 8 failures, too few to call a trend.
4. **Most failures have fixable causes.** Rider no-shows (12) and rider cancellations (8) make up 59% of cancellations, followed by payment failures (7) and driver unavailability (7). None of the 10 disputes has a recorded reason.

## Recommendations for next quarter

- **Re-engage drivers.** Reach out to idle drivers and to anyone silent for more than twice their usual gap. Closing the revenue shortfall takes about nine more trips.
- **Reduce rider no-shows.** Add a pickup confirmation step and a modest no-show fee.
- **Fix payment failures.** Pre-authorize payment when a trip is requested, and retry automatically if the charge fails.
- **Capture dispute reasons.** Require a reason code, so disputes can be analyzed.
- **Monitor with thresholds.** Target a failure rate of 15% or less, and alert when the three-month revenue average falls below the $300 monthly pace or any month-over-month change exceeds ±30%.

## Limitations

- **Small sample.** One year, 200 trips and 15 drivers, so percentages swing heavily from month to month.
- **No status history.** `is_active` is an undated snapshot (it marks Driver_09 inactive even though they drove until December), so gaps can't be separated into departures and recording losses.
- **Events only.** There is no availability or session data, so a driver who was online but received no requests looks the same as one who stopped driving.
- **Improvements:** add a driver status history with timestamps, session and ingestion logs, and multiple years of data.

## Reflection highlights

- **Window functions keep rows; aggregates collapse them.** Questions like "is this trip unusual?" or "what was each driver's year-to-date revenue at each trip?" need every row together with its group or its neighbors. `GROUP BY` can only give the summary.
- **Every technique carries a decision.** Tie handling decides who counts as equal, the frame decides what "recent" means, and even "unusual" needed a definition (double the driver's own average).
- **`ROWS` counts rows, not time.** Missing months quietly corrupt moving averages and month-over-month comparisons unless the calendar is filled in first.
- **A window function can't be filtered in its own query.** Ranks and gaps must be calculated in a CTE and filtered in the outer query.

See [`analysis/unit6.md`](analysis/unit6.md) for the full write-up and [`analysis/unit6-finding.md`](analysis/unit6-finding.md) for the leadership finding.
